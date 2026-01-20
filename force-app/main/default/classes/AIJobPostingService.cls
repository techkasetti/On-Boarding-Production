public class AIJobPostingService {
    
    public static Map<String, Object> processNLPInput(String userInput) {
        try {
            String systemPrompt = buildSystemPrompt();
            String userPrompt = buildJobPostingPrompt(userInput);
            
            GeminiAPIService.GeminiResponse aiResponse = GeminiAPIService.callGeminiAPI(
                systemPrompt, 
                userPrompt
            );
            
            if (!aiResponse.success) {
                throw new CalloutException('Gemini API Error: ' + aiResponse.errorMessage);
            }
            
            String responseText = GeminiAPIService.extractContent(aiResponse);
            return parseAIResponse(responseText);
            
        } catch (Exception e) {
            System.debug('Error in processNLPInput: ' + e.getMessage());
            throw e;
        }
    }
    
    private static String buildSystemPrompt() {
        return 'You are a job posting assistant that extracts structured data from natural language descriptions. ' +
               'You must respond with ONLY a valid JSON object, no additional text, explanations, or markdown formatting. ' +
               'CRITICAL: Only extract dates if they are explicitly mentioned in the user input. If dates are NOT mentioned, set them to null.';
    }
    
    private static Map<String, List<String>> getPicklistValues() {
        Map<String, List<String>> picklistMap = new Map<String, List<String>>();
        
        try {
            Schema.DescribeSObjectResult jobPostingDescribe = Job_Posting__c.SObjectType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = jobPostingDescribe.fields.getMap();
            
            List<String> picklistFields = new List<String>{
                'Category__c', 'Experience_Level__c', 'Specialization__c', 'Status__c'
            };
            
            for (String fieldName : picklistFields) {
                Schema.SObjectField field = fieldMap.get(fieldName);
                if (field != null) {
                    Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                    List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
                    
                    List<String> values = new List<String>();
                    for (Schema.PicklistEntry entry : picklistEntries) {
                        if (entry.isActive()) {
                            values.add(entry.getLabel());
                        }
                    }
                    picklistMap.put(fieldName, values);
                }
            }
        } catch (Exception e) {
            System.debug('Error getting picklist values: ' + e.getMessage());
            picklistMap.put('Category__c', new List<String>{'Technology', 'Healthcare', 'Finance', 'Marketing', 'Sales', 'Operations', 'HR', 'Legal', 'Other'});
            picklistMap.put('Experience_Level__c', new List<String>{'Entry Level', 'Mid Level', 'Senior Level', 'Executive'});
            picklistMap.put('Specialization__c', new List<String>{'Psychiatrist', 'Dermatologist', 'Cardiologist', 'General Nurse', 'Radiologist'});
            picklistMap.put('Status__c', new List<String>{'Open', 'Closed'});
        }
        
        return picklistMap;
    }
    
    private static String buildJobPostingPrompt(String userInput) {
        Map<String, List<String>> picklistValues = getPicklistValues();
        
        String prompt = 'Extract job posting details from the following text and return ONLY a valid JSON object.\n\n';
        prompt += 'Required JSON format:\n';
        prompt += '{\n';
        prompt += '  "name": "job posting name/title (max 80 characters)",\n';
        prompt += '  "category": "MUST BE EXACTLY ONE OF: ' + String.join(picklistValues.get('Category__c'), ', ') + '",\n';
        prompt += '  "location": "city, state or remote (max 255 characters)",\n';
        prompt += '  "experienceLevel": "MUST BE EXACTLY ONE OF: ' + String.join(picklistValues.get('Experience_Level__c'), ', ') + '",\n';
        prompt += '  "specialization": "MUST BE EXACTLY ONE OF: ' + String.join(picklistValues.get('Specialization__c'), ', ') + ' (ONLY for healthcare, otherwise null)",\n';
        prompt += '  "description": "full detailed job description",\n';
        prompt += '  "status": "MUST BE EXACTLY ONE OF: ' + String.join(picklistValues.get('Status__c'), ', ') + '",\n';
        prompt += '  "startDate": "YYYY-MM-DD format OR null if not mentioned",\n';
        prompt += '  "endDate": "YYYY-MM-DD format OR null if not mentioned"\n';
        prompt += '}\n\n';
        prompt += 'CRITICAL RULES:\n';
        prompt += '- Category: Match user input to ONE of the valid values\n';
        prompt += '- Experience Level: Match to ONE of the valid values\n';
        prompt += '- Specialization: ONLY for healthcare category\n';
        prompt += '- Status: Match to ONE of the valid values\n';
        prompt += '- **DATES: ONLY extract if explicitly mentioned (e.g., "starts on Feb 1" or "from 2026-02-01"). If NOT mentioned, set to null**\n';
        prompt += '- Return ONLY the JSON object, no markdown, no explanations\n\n';
        prompt += 'User Input:\n' + userInput;
        
        return prompt;
    }
    
    private static Map<String, Object> parseAIResponse(String aiResponse) {
        try {
            System.debug('===== PARSING AI RESPONSE =====');
            System.debug('Raw AI Response: ' + aiResponse);
            
            String cleanJson = aiResponse.trim();
            
            if (cleanJson.startsWith('```json')) {
                cleanJson = cleanJson.substring(7);
            }
            if (cleanJson.startsWith('```')) {
                cleanJson = cleanJson.substring(3);
            }
            if (cleanJson.endsWith('```')) {
                cleanJson = cleanJson.substring(0, cleanJson.length() - 3);
            }
            
            cleanJson = cleanJson.trim();
            
            System.debug('Cleaned JSON: ' + cleanJson);
            
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(cleanJson);
            
            System.debug('Parsed JSON Map:');
            for (String key : result.keySet()) {
                System.debug('  ' + key + ' = ' + result.get(key));
            }
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error parsing AI response: ' + e.getMessage());
            System.debug('AI Response was: ' + aiResponse);
            throw new CalloutException('Failed to parse AI response: ' + e.getMessage());
        }
    }
    
    private static Map<String, Object> validatePicklistValues(Map<String, Object> jobData) {
        Map<String, List<String>> validPicklists = getPicklistValues();
        
        String category = getString(jobData, 'category');
        if (String.isNotBlank(category)) {
            String validCategory = findClosestMatch(category, validPicklists.get('Category__c'));
            if (validCategory != null) {
                jobData.put('category', validCategory);
            } else {
                jobData.put('category', validPicklists.get('Category__c')[0]);
            }
        }
        
        String expLevel = getString(jobData, 'experienceLevel');
        if (String.isNotBlank(expLevel)) {
            String validExpLevel = findClosestMatch(expLevel, validPicklists.get('Experience_Level__c'));
            if (validExpLevel != null) {
                jobData.put('experienceLevel', validExpLevel);
            } else {
                jobData.put('experienceLevel', validPicklists.get('Experience_Level__c')[0]);
            }
        }
        
        String specialization = getString(jobData, 'specialization');
        if (String.isNotBlank(specialization)) {
            String validSpecialization = findClosestMatch(specialization, validPicklists.get('Specialization__c'));
            if (validSpecialization != null) {
                jobData.put('specialization', validSpecialization);
            } else {
                jobData.put('specialization', null);
            }
        }
        
        String status = getString(jobData, 'status');
        if (String.isNotBlank(status)) {
            String validStatus = findClosestMatch(status, validPicklists.get('Status__c'));
            if (validStatus != null) {
                jobData.put('status', validStatus);
            } else {
                jobData.put('status', validPicklists.get('Status__c')[0]);
            }
        }
        
        return jobData;
    }
    
    private static String findClosestMatch(String value, List<String> validValues) {
        if (String.isBlank(value) || validValues == null || validValues.isEmpty()) {
            return null;
        }
        
        String normalized = value.trim().toLowerCase();
        
        for (String validValue : validValues) {
            if (validValue.toLowerCase() == normalized) {
                return validValue;
            }
        }
        
        String normalizedStripped = normalized.replaceAll('[^a-z0-9]', '');
        
        for (String validValue : validValues) {
            String validStripped = validValue.toLowerCase().replaceAll('[^a-z0-9]', '');
            if (validStripped == normalizedStripped) {
                return validValue;
            }
        }
        
        for (String validValue : validValues) {
            if (validValue.toLowerCase().contains(normalized) || normalized.contains(validValue.toLowerCase())) {
                return validValue;
            }
        }
        
        return null;
    }
    
    public static String createJobPosting(Map<String, Object> jobData) {
        try {
            System.debug('===== CREATING JOB POSTING =====');
            System.debug('Raw jobData: ' + JSON.serializePretty(jobData));
            
            jobData = validatePicklistValues(jobData);
            
            Job_Posting__c jp = new Job_Posting__c();
            
            String jobName = getString(jobData, 'name');
            if (String.isBlank(jobName)) {
                jobName = 'Job Posting - ' + DateTime.now().format('yyyy-MM-dd HH:mm');
            }
            jp.Name = jobName.length() > 80 ? jobName.substring(0, 80) : jobName;
            
            String category = getString(jobData, 'category');
            if (String.isNotBlank(category)) {
                jp.Category__c = category;
            }
            
            String location = getString(jobData, 'location');
            if (String.isNotBlank(location)) {
                jp.Location__c = location.length() > 255 ? location.substring(0, 255) : location;
            }
            
            String expLevel = getString(jobData, 'experienceLevel');
            if (String.isNotBlank(expLevel)) {
                jp.Experience_Level__c = expLevel;
            }
            
            String specialization = getString(jobData, 'specialization');
            if (String.isNotBlank(specialization)) {
                jp.Specialization__c = specialization;
            }
            
            String description = getString(jobData, 'description');
            if (String.isNotBlank(description)) {
                jp.Description__c = description.length() > 32768 ? description.substring(0, 32768) : description;
            }
            
            String status = getString(jobData, 'status');
            jp.Status__c = String.isNotBlank(status) ? status : 'Open';
            
            Date startDate = getDate(jobData, 'startDate');
            if (startDate != null) {
                jp.Start_Date__c = startDate;
                System.debug('Setting Start Date: ' + startDate);
            } else {
                System.debug('No start date provided - leaving blank');
            }
            
            Date endDate = getDate(jobData, 'endDate');
            if (endDate != null) {
                jp.End_Date__c = endDate;
                System.debug('Setting End Date: ' + endDate);
            } else {
                System.debug('No end date provided - leaving blank');
            }
            
            System.debug('Final Job Object: Name=' + jp.Name + ', Category=' + jp.Category__c + 
                        ', Start=' + jp.Start_Date__c + ', End=' + jp.End_Date__c);
            
            insert jp;
            
            System.debug('Job Posting created with ID: ' + jp.Id);
            return jp.Id;
            
        } catch (Exception e) {
            System.debug('Error creating job posting: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw e;
        }
    }
    private static String getString(Map<String, Object> data, String key) {
        Object value = data.get(key);
        if (value == null || value == 'null') return null;
        String strValue = String.valueOf(value).trim();
        return String.isBlank(strValue) || strValue == 'null' ? null : strValue;
    }
    
    private static Date getDate(Map<String, Object> data, String key) {
        Object value = data.get(key);
        if (value == null || value == 'null') return null;
        
        try {
            String dateStr = String.valueOf(value).trim();
            if (String.isBlank(dateStr) || dateStr == 'null') return null;
            
            List<String> parts = dateStr.split('-');
            if (parts.size() == 3) {
                return Date.newInstance(
                    Integer.valueOf(parts[0]), 
                    Integer.valueOf(parts[1]), 
                    Integer.valueOf(parts[2])
                );
            }
        } catch (Exception e) {
            System.debug('Error parsing date: ' + e.getMessage());
        }
        
        return null;
    }
    
    public static String testGeminiConnection() {
        try {
            String result = GeminiAPIService.testConnection();
            return 'Gemini Test Result: ' + result;
        } catch (Exception e) {
            return 'Gemini Test Error: ' + e.getMessage();
        }
    }
}