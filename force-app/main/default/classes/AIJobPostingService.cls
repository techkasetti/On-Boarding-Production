// AIJobPostingService.cls - COMPREHENSIVE VERSION WITH ALL CHILD OBJECTS
public class AIJobPostingService {
    
    /**
     * Process natural language input and extract structured job posting data
     */
    public static Map<String, Object> processNLPInput(String userInput) {
        try {
            String systemPrompt = buildSystemPrompt();
            String userPrompt = buildComprehensiveJobPostingPrompt(userInput);
            
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
    return 'You are a precise data extraction assistant. ' +
           'Extract ONLY the information explicitly stated in the user input. ' +
           'Do NOT infer, assume, or add any information that is not clearly mentioned. ' +
           'Respond with ONLY a valid JSON object. ' +
           'No markdown formatting, no explanations, no additional text.';
}

private static String buildComprehensiveJobPostingPrompt(String userInput) {
    Map<String, List<String>> picklistValues = getPicklistValues();
    
    String prompt = 'Extract job posting details from user input. ONLY extract what is EXPLICITLY mentioned. DO NOT infer or add anything not stated.\n\n';
    prompt += 'Required JSON format:\n';
    prompt += '{\n';
    prompt += '  "jobPosting": {\n';
    prompt += '    "Job_Title__c": "exact job title mentioned OR null",\n';
    prompt += '    "Description__c": "description if provided OR null",\n';
    prompt += '    "Category__c": "Medical" (always set this),\n';
    prompt += '    "Role_Type__c": "MUST BE ONE OF: ' + String.join(picklistValues.get('Role_Type__c'), ', ') + ' OR null",\n';
    prompt += '    "Department__c": "MUST BE ONE OF: ' + String.join(picklistValues.get('Department__c'), ', ') + ' OR null",\n';
    prompt += '    "Employment_Type__c": "Full-time" (default if not mentioned),\n';
    prompt += '    "Shift_Type__c": "MUST BE ONE OF: ' + String.join(picklistValues.get('Shift_Type__c'), ', ') + ' OR null",\n';
    prompt += '    "Min_Experience_Years__c": number (extract minimum years) OR null,\n';
    prompt += '    "Max_Experience_Years__c": number (extract maximum years) OR null,\n';
    prompt += '    "Start_Date__c": "YYYY-MM-DD" (only if date mentioned) OR null,\n';
    prompt += '    "End_Date__c": "YYYY-MM-DD" (only if date mentioned) OR null,\n';
    prompt += '    "Facility_Name__c": "exact facility name" OR null,\n';
    prompt += '    "City__c": "exact city name" OR null,\n';
    prompt += '    "State__c": "exact state/province" OR null,\n';
    prompt += '    "Country__c": "exact country" OR null,\n';
    prompt += '    "Credentialing_Required__c": true (if mentioned) OR null,\n';
    prompt += '    "Privilege_Scope__c": "privileges description" (if mentioned) OR null\n';
    prompt += '  },\n';
    prompt += '  "educationRequirements": [\n';
    prompt += '    {"Degree_Name__c": "exact degree name", "Mandatory__c": true}\n';
    prompt += '    // ONLY include degrees explicitly mentioned in input\n';
    prompt += '  ],\n';
    prompt += '  "licenseRequirements": [\n';
    prompt += '    {\n';
    prompt += '      "License_Name__c": "exact license name",\n';
    prompt += '      "Issuing_Authority__c": "authority if mentioned OR reasonable authority based on country",\n';
    prompt += '      "Active_Required__c": true,\n';
    prompt += '      "Expiry_Check_Required__c": true\n';
    prompt += '    }\n';
    prompt += '    // ONLY include licenses/registrations explicitly mentioned\n';
    prompt += '  ],\n';
    prompt += '  "certificationRequirements": [\n';
    prompt += '    {"Certification_Name__c": "exact certification", "Mandatory__c": true}\n';
    prompt += '    // ONLY include certifications explicitly mentioned (BLS, ACLS, etc.)\n';
    prompt += '  ],\n';
    prompt += '  "clinicalSkills": [\n';
    prompt += '    {\n';
    prompt += '      "Skill_Name__c": "exact skill name",\n';
    
    // CRITICAL FIX: Use exact picklist values from Salesforce
    prompt += '      "Skill_Level__c": "MUST BE EXACTLY ONE OF: Basic, Intermediate, Advanced (map Expert→Advanced)",\n';
    
    prompt += '      "Mandatory__c": true\n';
    prompt += '    }\n';
    prompt += '    // ONLY include skills explicitly mentioned\n';
    prompt += '  ],\n';
    prompt += '  "procedureRequirements": [\n';
    prompt += '    {"Procedure_Name__c": "exact procedure", "Critical__c": true}\n';
    prompt += '    // ONLY include procedures explicitly mentioned (IV Cannulation, Wound Suturing, etc.)\n';
    prompt += '  ],\n';
    prompt += '  "complianceRequirements": [\n';
    prompt += '    {"Compliance_Name__c": "exact compliance", "Mandatory__c": true}\n';
    prompt += '    // ONLY include compliance explicitly mentioned (HIPAA, etc.)\n';
    prompt += '  ]\n';
    prompt += '}\n\n';
    prompt += '=== STRICT RULES ===\n';
    prompt += '1. Extract ONLY what is explicitly stated in the input\n';
    prompt += '2. Use null for any field not mentioned\n';
    prompt += '3. Use empty arrays [] if no requirements mentioned\n';
    prompt += '4. For "valid Medical Council Registration" or similar phrases, create a license requirement\n';
    prompt += '5. Match picklist values exactly (case-sensitive)\n';
    
    // CRITICAL FIX: Add skill level mapping rule
    prompt += '6. For Skill_Level__c: ONLY use "Basic", "Intermediate", or "Advanced". Map any "Expert" or "Proficient" to "Advanced"\n';
    
    prompt += '7. For experience "2-10 years", set Min_Experience_Years__c: 2, Max_Experience_Years__c: 10\n';
    prompt += '8. Return ONLY valid JSON - no markdown, no explanations, no extra text\n';
    prompt += '9. If you cannot parse something, use null rather than guessing\n\n';
    prompt += 'User Input:\n' + userInput;
    
    return prompt;
}
    private static Map<String, List<String>> getPicklistValues() {
        Map<String, List<String>> picklistMap = new Map<String, List<String>>();
        
        try {
            Schema.DescribeSObjectResult jobPostingDescribe = Job_Posting__c.SObjectType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = jobPostingDescribe.fields.getMap();
            
            List<String> picklistFields = new List<String>{
                'Category__c', 'Role_Type__c', 'Department__c', 'Employment_Type__c', 'Shift_Type__c'
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
            // Fallback values
            picklistMap.put('Category__c', new List<String>{'Medical'});
            picklistMap.put('Role_Type__c', new List<String>{'Doctor', 'Nurse', 'Technician', 'Paramedic'});
            picklistMap.put('Department__c', new List<String>{'Emergency', 'ICU', 'OPD', 'Surgery', 'Radiology'});
            picklistMap.put('Employment_Type__c', new List<String>{'Full-time', 'Part-time', 'Contract'});
            picklistMap.put('Shift_Type__c', new List<String>{'Day', 'Night', 'Rotational', 'Emergency'});
        }
        
        return picklistMap;
    }
    
    private static Map<String, Object> parseAIResponse(String aiResponse) {
        try {
            System.debug('===== PARSING AI RESPONSE =====');
            System.debug('Raw AI Response: ' + aiResponse);
            
            String cleanJson = aiResponse.trim();
            
            // Remove markdown code blocks if present
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
            
            System.debug('Parsed JSON Map - Keys: ' + result.keySet());
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error parsing AI response: ' + e.getMessage());
            System.debug('AI Response was: ' + aiResponse);
            throw new CalloutException('Failed to parse AI response: ' + e.getMessage());
        }
    }
    
    /**
     * Create comprehensive job posting with all child records
     */
   public static String createComprehensiveJobPosting(Map<String, Object> aiData) {
    Savepoint sp = Database.setSavepoint();
    
    try {
        System.debug('===== CREATING COMPREHENSIVE JOB POSTING =====');
        System.debug('AI Data: ' + JSON.serializePretty(aiData));
        
        // Extract main job posting data
        Map<String, Object> jobPostingData = (Map<String, Object>) aiData.get('jobPosting');
        
        // Create main Job Posting record
        Job_Posting__c jp = new Job_Posting__c();
        
        // Required fields with validation
        jp.Job_Title__c = getString(jobPostingData, 'Job_Title__c');
        if (String.isBlank(jp.Job_Title__c)) {
            throw new CalloutException('Job Title is required but not found in input');
        }
        
        jp.Category__c = getString(jobPostingData, 'Category__c');
        if (String.isBlank(jp.Category__c)) {
            jp.Category__c = 'Medical'; // Default
        }
        
        jp.Role_Type__c = getString(jobPostingData, 'Role_Type__c');
        if (String.isBlank(jp.Role_Type__c)) {
            throw new CalloutException('Role Type is required but not found in input');
        }
        
        jp.Employment_Type__c = getString(jobPostingData, 'Employment_Type__c');
        if (String.isBlank(jp.Employment_Type__c)) {
            jp.Employment_Type__c = 'Full-time'; // Default
        }
        
        jp.Facility_Name__c = getString(jobPostingData, 'Facility_Name__c');
        if (String.isBlank(jp.Facility_Name__c)) {
            throw new CalloutException('Facility Name is required but not found in input');
        }
        
        jp.City__c = getString(jobPostingData, 'City__c');
        if (String.isBlank(jp.City__c)) {
            throw new CalloutException('City is required but not found in input');
        }
        
        jp.State__c = getString(jobPostingData, 'State__c');
        if (String.isBlank(jp.State__c)) {
            throw new CalloutException('State is required but not found in input');
        }
        
        jp.Country__c = getString(jobPostingData, 'Country__c');
        if (String.isBlank(jp.Country__c)) {
            throw new CalloutException('Country is required but not found in input');
        }
        
        jp.Start_Date__c = getDate(jobPostingData, 'Start_Date__c');
        if (jp.Start_Date__c == null) {
            jp.Start_Date__c = Date.today().addDays(30); // Default to 30 days from today
        }
        
        // Optional fields
        jp.Description__c = getString(jobPostingData, 'Description__c');
        jp.Department__c = getString(jobPostingData, 'Department__c');
        jp.Shift_Type__c = getString(jobPostingData, 'Shift_Type__c');
        jp.End_Date__c = getDate(jobPostingData, 'End_Date__c');
        jp.Privilege_Scope__c = getString(jobPostingData, 'Privilege_Scope__c');
        
        // Numeric fields
        if (jobPostingData.containsKey('Min_Experience_Years__c')) {
            jp.Min_Experience_Years__c = getDecimal(jobPostingData, 'Min_Experience_Years__c');
        }
        if (jobPostingData.containsKey('Max_Experience_Years__c')) {
            jp.Max_Experience_Years__c = getDecimal(jobPostingData, 'Max_Experience_Years__c');
        }
        
        // Boolean fields
        jp.Credentialing_Required__c = getBoolean(jobPostingData, 'Credentialing_Required__c', false);
        
        System.debug('Job Posting to insert: ' + jp);
        insert jp;
        System.debug('Job Posting created with ID: ' + jp.Id);
        
        // Create child records ONLY if data exists
        createEducationRequirements(jp.Id, aiData);
        createLicenseRequirements(jp.Id, aiData);
        createCertificationRequirements(jp.Id, aiData);
        createClinicalSkills(jp.Id, aiData);
        createProcedureRequirements(jp.Id, aiData);
        createComplianceRequirements(jp.Id, aiData);
        
        return jp.Id;
        
    } catch (Exception e) {
        Database.rollback(sp);
        System.debug('Error creating comprehensive job posting: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw e;
    }
}
    // ==================== CHILD RECORD CREATION METHODS ====================
    
    private static void createEducationRequirements(Id jobPostingId, Map<String, Object> aiData) {
        List<Object> eduList = (List<Object>) aiData.get('educationRequirements');
        if (eduList == null || eduList.isEmpty()) return;
        
        List<Job_Education_Requirement__c> records = new List<Job_Education_Requirement__c>();
        
        for (Object obj : eduList) {
            Map<String, Object> eduMap = (Map<String, Object>) obj;
            Job_Education_Requirement__c edu = new Job_Education_Requirement__c();
            edu.Job_Posting__c = jobPostingId;
            edu.Degree_Name__c = getString(eduMap, 'Degree_Name__c');
            edu.Mandatory__c = getBoolean(eduMap, 'Mandatory__c', false);
            records.add(edu);
        }
        
        if (!records.isEmpty()) {
            insert records;
            System.debug('Created ' + records.size() + ' education requirements');
        }
    }
    
    private static void createLicenseRequirements(Id jobPostingId, Map<String, Object> aiData) {
        List<Object> licList = (List<Object>) aiData.get('licenseRequirements');
        if (licList == null || licList.isEmpty()) return;
        
        List<Job_License_Requirement__c> records = new List<Job_License_Requirement__c>();
        
        for (Object obj : licList) {
            Map<String, Object> licMap = (Map<String, Object>) obj;
            Job_License_Requirement__c lic = new Job_License_Requirement__c();
            lic.Job_Posting__c = jobPostingId;
            lic.License_Name__c = getString(licMap, 'License_Name__c');
            lic.Issuing_Authority__c = getString(licMap, 'Issuing_Authority__c');
            lic.Active_Required__c = getBoolean(licMap, 'Active_Required__c', false);
            lic.Expiry_Check_Required__c = getBoolean(licMap, 'Expiry_Check_Required__c', false);
            records.add(lic);
        }
        
        if (!records.isEmpty()) {
            insert records;
            System.debug('Created ' + records.size() + ' license requirements');
        }
    }
    
    private static void createCertificationRequirements(Id jobPostingId, Map<String, Object> aiData) {
        List<Object> certList = (List<Object>) aiData.get('certificationRequirements');
        if (certList == null || certList.isEmpty()) return;
        
        List<Job_Certification_Requirement__c> records = new List<Job_Certification_Requirement__c>();
        
        for (Object obj : certList) {
            Map<String, Object> certMap = (Map<String, Object>) obj;
            Job_Certification_Requirement__c cert = new Job_Certification_Requirement__c();
            cert.Job_Posting__c = jobPostingId;
            cert.Certification_Name__c = getString(certMap, 'Certification_Name__c');
            cert.Mandatory__c = getBoolean(certMap, 'Mandatory__c', false);
            records.add(cert);
        }
        
        if (!records.isEmpty()) {
            insert records;
            System.debug('Created ' + records.size() + ' certification requirements');
        }
    }
    
    private static void createClinicalSkills(Id jobPostingId, Map<String, Object> aiData) {
        List<Object> skillList = (List<Object>) aiData.get('clinicalSkills');
        if (skillList == null || skillList.isEmpty()) return;
        
        List<Job_Clinical_Skill__c> records = new List<Job_Clinical_Skill__c>();
        
        for (Object obj : skillList) {
            Map<String, Object> skillMap = (Map<String, Object>) obj;
            Job_Clinical_Skill__c skill = new Job_Clinical_Skill__c();
            skill.Job_Posting__c = jobPostingId;
            skill.Skill_Name__c = getString(skillMap, 'Skill_Name__c');
            skill.Skill_Level__c = getString(skillMap, 'Skill_Level__c');
            skill.Mandatory__c = getBoolean(skillMap, 'Mandatory__c', false);
            records.add(skill);
        }
        
        if (!records.isEmpty()) {
            insert records;
            System.debug('Created ' + records.size() + ' clinical skills');
        }
    }
    
    private static void createProcedureRequirements(Id jobPostingId, Map<String, Object> aiData) {
        List<Object> procList = (List<Object>) aiData.get('procedureRequirements');
        if (procList == null || procList.isEmpty()) return;
        
        List<Job_Procedure_Requirement__c> records = new List<Job_Procedure_Requirement__c>();
        
        for (Object obj : procList) {
            Map<String, Object> procMap = (Map<String, Object>) obj;
            Job_Procedure_Requirement__c proc = new Job_Procedure_Requirement__c();
            proc.Job_Posting__c = jobPostingId;
            proc.Procedure_Name__c = getString(procMap, 'Procedure_Name__c');
            proc.Critical__c = getBoolean(procMap, 'Critical__c', false);
            records.add(proc);
        }
        
        if (!records.isEmpty()) {
            insert records;
            System.debug('Created ' + records.size() + ' procedure requirements');
        }
    }
    
    private static void createComplianceRequirements(Id jobPostingId, Map<String, Object> aiData) {
        List<Object> compList = (List<Object>) aiData.get('complianceRequirements');
        if (compList == null || compList.isEmpty()) return;
        
        List<Job_Compliance_Requirement__c> records = new List<Job_Compliance_Requirement__c>();
        
        for (Object obj : compList) {
            Map<String, Object> compMap = (Map<String, Object>) obj;
            Job_Compliance_Requirement__c comp = new Job_Compliance_Requirement__c();
            comp.Job_Posting__c = jobPostingId;
            comp.Compliance_Name__c = getString(compMap, 'Compliance_Name__c');
            comp.Mandatory__c = getBoolean(compMap, 'Mandatory__c', false);
            records.add(comp);
        }
        
        if (!records.isEmpty()) {
            insert records;
            System.debug('Created ' + records.size() + ' compliance requirements');
        }
    }
    
    // ==================== HELPER METHODS ====================
    
    public static String getString(Map<String, Object> data, String key) {
        Object value = data.get(key);
        if (value == null || value == 'null') return null;
        String strValue = String.valueOf(value).trim();
        return String.isBlank(strValue) || strValue == 'null' ? null : strValue;
    }
    
    public static Date getDate(Map<String, Object> data, String key) {
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
            System.debug('Error parsing date for key ' + key + ': ' + e.getMessage());
        }
        
        return null;
    }
    
    public static Decimal getDecimal(Map<String, Object> data, String key) {
        Object value = data.get(key);
        if (value == null) return null;
        
        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception e) {
            System.debug('Error parsing decimal for key ' + key + ': ' + e.getMessage());
            return null;
        }
    }
    
    public static Boolean getBoolean(Map<String, Object> data, String key, Boolean defaultValue) {
        Object value = data.get(key);
        if (value == null) return defaultValue;
        
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        
        String strValue = String.valueOf(value).toLowerCase();
        if (strValue == 'true' || strValue == '1' || strValue == 'yes') {
            return true;
        } else if (strValue == 'false' || strValue == '0' || strValue == 'no') {
            return false;
        }
        
        return defaultValue;
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