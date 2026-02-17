@RestResource(urlMapping='/updateCandidateProfile/*')
global with sharing class CandidateProfileReceiver {

    @HttpPost 
    global static String processCandidateData() {
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();
        
        // 1. AUTHORIZATION
        // String reqApiKey = req.headers.get('x-api-key');
        // Map<String, ERP_System__mdt> authMap = ERP_System__mdt.getAll();
        // Boolean isAuthorized = false;
        
        // for (ERP_System__mdt metadataRecord : authMap.values()) {
        //     if (metadataRecord.x_api_key__c != null && metadataRecord.x_api_key__c.equalsIgnoreCase(reqApiKey)) {
        //         isAuthorized = true;
        //         break;   
        //     }
        // }

        // if (!isAuthorized) {
        //     return generateErrorResponse('401', 'Authorization failed. Invalid API Key');
        // }

        // 2. JSON PARSING
        Map<String, Object> inputJson;
        try {
            inputJson = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
        } catch(Exception e) {
            return generateErrorResponse('400', 'Invalid JSON format');
        }

        // 3. VALIDATION
        List<ExceptionDetails> validationErrors = new List<ExceptionDetails>();
        Boolean isValid = true;

        String candidateIdString = (String) inputJson.get('Candidate_Id');
        if (String.isBlank(candidateIdString)) {
            isValid = false;
            addError(validationErrors, '400', 'Candidate_Id', 'Candidate_Id is missing');
        }

        String serviceType = (String) inputJson.get('serviceType');
        if (String.isBlank(serviceType)) {
            isValid = false;
            addError(validationErrors, '400', 'serviceType', 'serviceType is missing');
        }

        if (!isValid) {
            String errorJson = generateValidationErrorResponse(validationErrors);
            if (!Test.isRunningTest()) throw new CandidateException(errorJson);
            return errorJson;
        }

        // 4. FETCH MAPPINGS
        try {
            Id candidateId = (Id) candidateIdString;

            List<JF_SF_Field_Mapping__c> mappingRecords = [
                SELECT Name, SF_Object1_Field_Name__c, ObjectNames1__c 
                FROM JF_SF_Field_Mapping__c 
                WHERE RecordType__c = 'Input JSON' 
                  AND Service_Type__r.Name = :serviceType
            ];

            if (mappingRecords.isEmpty()) {
                return generateErrorResponse('404', 'No Field Mappings found for Service Type: ' + serviceType);
            }

            Map<String, String> jfsfMap = new Map<String, String>(); 
            for (JF_SF_Field_Mapping__c jf : mappingRecords) {
                if (String.isNotBlank(jf.Name) && 
                    String.isNotBlank(jf.SF_Object1_Field_Name__c) && 
                    String.isNotBlank(jf.ObjectNames1__c)) {
                    jfsfMap.put(jf.Name, jf.SF_Object1_Field_Name__c + '#' + jf.ObjectNames1__c);
                }
            }

            return performDatabaseOperations(candidateId, jfsfMap, inputJson);

        } catch (Exception e) {
            System.debug('MAIN EXCEPTION: ' + e.getMessage());
            return generateErrorResponse('500', 'Processing Error: ' + e.getMessage());
        }
    }

    public static String performDatabaseOperations(Id candidateId, Map<String, String> jfsfMap, Map<String, Object> inputJsonMap) {
        
        List<Candidate__c> candidates = [SELECT Id FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
        if (candidates.isEmpty()) {
            return generateErrorResponse('404', 'Candidate record not found with Id: ' + candidateId);
        }

        Candidate__c candidateToUpdate = new Candidate__c(Id = candidateId);
        Boolean hasCandidateUpdates = false;
        Map<String, SObject> childObjectsMap = new Map<String, SObject>();

        Map<String, SObjectType> globalDescribe = Schema.getGlobalDescribe();

        for (String jsonKey : inputJsonMap.keySet()) {
            
            if (jsonKey == 'serviceType' || jsonKey == 'Candidate_Id') continue;

            if (jfsfMap.containsKey(jsonKey)) {
                
                String mappingValue = jfsfMap.get(jsonKey);
                String[] fieldParts = mappingValue.split('#');
                if (fieldParts.size() < 2) continue;

                String sObjectField = fieldParts[0]; 
                String rawObjectName  = fieldParts[1]; 
                
                // *** FIX: Clean the Object Name ***
                // If metadata says "Candidate__c.Research_Publication__c", we extract "Research_Publication__c"
                String sObjectName = rawObjectName;
                if (sObjectName.contains('.')) {
                    sObjectName = sObjectName.substringAfterLast('.');
                }

                Object jsonValue = inputJsonMap.get(jsonKey);

                // --- DATA TYPE HANDLING ---
                if (sObjectField.contains('Year') && jsonValue instanceof String) {
                    String strVal = (String)jsonValue;
                    if (strVal.contains('-')) {
                        jsonValue = Decimal.valueOf(strVal.split('-')[0]);
                    }
                }
                else if (jsonValue instanceof String && Pattern.matches('\\d{4}-\\d{2}-\\d{2}', (String)jsonValue)) {
                    try {
                        jsonValue = Date.valueOf((String)jsonValue);
                    } catch(Exception e) { /* ignore */ }
                }

                // --- OBJECT POPULATION ---
                if (sObjectName == 'Candidate__c') {
                    candidateToUpdate.put(sObjectField, jsonValue);
                    hasCandidateUpdates = true;
                } else {
                    // Check if Object exists in Schema
                    SObjectType sTokenType = globalDescribe.get(sObjectName);
                    if (sTokenType == null) {
                        System.debug('WARNING: Object "' + sObjectName + '" (from ' + rawObjectName + ') not found in Schema. Skipping.');
                        continue; 
                    }

                    if (!childObjectsMap.containsKey(sObjectName)) {
                        SObject newChild = sTokenType.newSObject();
                        newChild.put('Candidate__c', candidateId); 
                        childObjectsMap.put(sObjectName, newChild);
                    }
                    
                    try {
                        childObjectsMap.get(sObjectName).put(sObjectField, jsonValue);
                    } catch (Exception e) {
                        System.debug('Error putting field ' + sObjectField + ': ' + e.getMessage());
                    }
                }
            }
        }

        Savepoint sp = Database.setSavepoint();
        try {
            if (hasCandidateUpdates) {
                update candidateToUpdate;
            }

            if (!childObjectsMap.isEmpty()) {
                insert childObjectsMap.values();
            }

            JSONGenerator gen = JSON.createGenerator(true);
            gen.writeStartObject();     
            gen.writeFieldName('Success');
            gen.writeStartObject();
            gen.writeStringField('status', 'Processed Successfully');
            gen.writeStringField('candidateId', candidateId);
            gen.writeNumberField('childRecordsCreated', childObjectsMap.size());
            gen.writeEndObject();
            gen.writeEndObject();
            return gen.getAsString();

        } catch (Exception ex) {
            Database.rollback(sp);
            return generateErrorResponse('500', 'Database Error: ' + ex.getMessage());
        }
    }

    // UTILITY METHODS
    private static void addError(List<ExceptionDetails> listDetails, String code, String field, String msg) {
        ExceptionDetails e = new ExceptionDetails();
        e.code = code;
        e.field = field;
        e.message = msg;
        listDetails.add(e);
    }

    private static String generateErrorResponse(String code, String message) {
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        gen.writeStringField('code', code);
        gen.writeStringField('message', message);
        gen.writeEndObject();
        return gen.getAsString().replace('/', '').replace('\n', '');
    }

    private static String generateValidationErrorResponse(List<ExceptionDetails> details) {
        JSONGenerator gen = JSON.createGenerator(true);
        gen.writeStartObject();
        gen.writeStringField('code', '400');
        gen.writeStringField('message', 'Validation Failed');
        gen.writeFieldName('errors');
        gen.writeStartArray();
        for (ExceptionDetails e : details) {
            gen.writeStartObject();
            gen.writeStringField('code', e.code);
            gen.writeStringField('field', e.field);
            gen.writeStringField('message', e.message);
            gen.writeEndObject();
        }
        gen.writeEndArray();
        gen.writeEndObject();
        return gen.getAsString();
    }

    public class CandidateException extends Exception {}
    public class ExceptionDetails { 
        public String code;
        public String field;
        public String message;
    }
}