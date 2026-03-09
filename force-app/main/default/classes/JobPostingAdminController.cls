// JobPostingAdminController.apex - COMPREHENSIVE VERSION (Manual Admin + AI Console)
public with sharing class JobPostingAdminController {
    
    // ==================== MANUAL ADMIN METHODS (Original) ====================
    
    /**
     * Get all Job Postings with related child records for admin table
     */
    @AuraEnabled
    public static List<Job_Posting__c> getJobPostings() {
        try {
            return [
                SELECT Id, Name, Job_Title__c, Account__c , Description__c, 
                       Category__c, Role_Type__c, Department__c,
                       Employment_Type__c, Shift_Type__c,
                       Min_Experience_Years__c, Max_Experience_Years__c,
                       Start_Date__c, End_Date__c, Job_Status__c,
                       Facility_Name__c, City__c, State__c, Country__c,
                       Credentialing_Required__c, Privilege_Scope__c,
                       CreatedDate, CreatedBy.Name, 
                       LastModifiedDate, LastModifiedBy.Name,
                       
                       // Child relationships
                       (SELECT Id, Degree_Name__c, Mandatory__c 
                        FROM Education_Requirements__r),
                       
                       (SELECT Id, License_Name__c, Issuing_Authority__c, 
                               Active_Required__c, Expiry_Check_Required__c 
                        FROM License_Requirements__r),
                       
                       (SELECT Id, Certification_Name__c, Mandatory__c 
                        FROM Certification_Requirements__r),
                       
                       (SELECT Id, Skill_Name__c, Skill_Level__c, Mandatory__c 
                        FROM Job_Clinical_Skill__r),
                       
                       (SELECT Id, Procedure_Name__c, Critical__c 
                        FROM Job_Procedure_Requirements__r),
                       
                       (SELECT Id, Compliance_Name__c, Mandatory__c 
                        FROM Job_Compliance_Requirements__r)
                       
                FROM Job_Posting__c
                ORDER BY CreatedDate DESC
                LIMIT 1000
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching job postings: ' + e.getMessage());
        }
    }

    /**
     * Save Job Posting with all child records (Manual Admin)
     */
    @AuraEnabled
    public static String saveJobPosting(String jobPostingData) {
        if (String.isBlank(jobPostingData)) {
            throw new AuraHandledException('Job Posting data cannot be null or empty.');
        }
        
        Savepoint sp = Database.setSavepoint();
        
        try {
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(jobPostingData);
            
            // Extract and save main Job Posting record
            Map<String, Object> jobPostingMap = (Map<String, Object>) dataMap.get('jobPosting');
            Job_Posting__c jobPosting = parseJobPosting(jobPostingMap);
            
            // Validate required fields
            validateJobPosting(jobPosting);
            
            // Save or update Job Posting
            upsert jobPosting;
            
            // Process child records
            processEducationRequirements(jobPosting.Id, dataMap);
            processLicenseRequirements(jobPosting.Id, dataMap);
            processCertificationRequirements(jobPosting.Id, dataMap);
            processClinicalSkills(jobPosting.Id, dataMap);
            processProcedureRequirements(jobPosting.Id, dataMap);
            processComplianceRequirements(jobPosting.Id, dataMap);
            
            return jobPosting.Id;
            
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error saving job posting: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error saving job posting: ' + e.getMessage());
        }
    }

    /**
     * Delete Job Posting (cascade deletes child records automatically)
     */
    @AuraEnabled
    public static void deleteJobPosting(Id jobPostingId) {
        if (jobPostingId == null) {
            throw new AuraHandledException('Job Posting ID cannot be null.');
        }
        
        try {
            Job_Posting__c jobToDelete = [
                SELECT Id 
                FROM Job_Posting__c 
                WHERE Id = :jobPostingId 
                LIMIT 1
            ];
            
            delete jobToDelete;
            
        } catch (QueryException e) {
            throw new AuraHandledException('Job Posting not found.');
        } catch (DmlException e) {
            throw new AuraHandledException('Error deleting job posting: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting job posting: ' + e.getMessage());
        }
    }

    /**
     * Get picklist values for a field
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPicklistValues(String fieldName) {
        List<Map<String, String>> picklistOptions = new List<Map<String, String>>();
        
        try {
            if (String.isBlank(fieldName)) {
                throw new AuraHandledException('Field name cannot be blank.');
            }
            
            Schema.DescribeFieldResult fieldResult = getFieldDescribe(fieldName);
            List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
            
            for (Schema.PicklistEntry entry : picklistEntries) {
                if (entry.isActive()) {
                    Map<String, String> option = new Map<String, String>();
                    option.put('label', entry.getLabel());
                    option.put('value', entry.getValue());
                    picklistOptions.add(option);
                }
            }
            
            return picklistOptions;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching picklist values: ' + e.getMessage());
        }
    }

    // ==================== AI CONSOLE METHODS (New) ====================
    
    /**
     * Create job posting from natural language input using AI
     */
    @AuraEnabled
    public static String createJobFromNLP(String userInput) {
        try {
            System.debug('Received NLP input: ' + userInput);
            
            // Process input with AI to extract structured data
            Map<String, Object> aiData = AIJobPostingService.processNLPInput(userInput);
            System.debug('AI processed data: ' + JSON.serializePretty(aiData));
            
            // Create comprehensive job posting with all child records
            String jobId = AIJobPostingService.createComprehensiveJobPosting(aiData);
            System.debug('Created comprehensive job posting: ' + jobId);
            
            return jobId;
            
        } catch (Exception e) {
            System.debug('Error in createJobFromNLP: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error processing request: ' + e.getMessage());
        }
    }
    
/**
 * This uses AI enrichment to extract child requirements from job descriptions
 */

@AuraEnabled
public static Map<String, Object> createJobsFromCSV(String csvContent) {
    try {
        System.debug('Received CSV content length: ' + csvContent.length());
        
        // NEW: Parse CSV AND enrich with AI-extracted child requirements
        List<Map<String, Object>> enrichedJobDataList = CSVJobPostingProcessor.parseAndEnrichCSV(csvContent);
        System.debug('Parsed and enriched ' + enrichedJobDataList.size() + ' jobs from CSV');
        
        List<String> createdIds = new List<String>();
        List<String> errors = new List<String>();
        
        // Create each job with its child records
        for (Integer i = 0; i < enrichedJobDataList.size(); i++) {
            try {
                Map<String, Object> enrichedJobData = enrichedJobDataList[i];
                
                // Use existing comprehensive creation method
                String jobId = AIJobPostingService.createComprehensiveJobPosting(enrichedJobData);
                createdIds.add(jobId);
                
                System.debug('Successfully created job ' + (i + 1) + ' with ID: ' + jobId);
                
            } catch (Exception e) {
                String errorMsg = 'Row ' + (i + 2) + ': ' + e.getMessage();
                errors.add(errorMsg);
                System.debug(errorMsg);
            }
        }
        
        Map<String, Object> result = new Map<String, Object>{
            'success' => !createdIds.isEmpty(),
            'count' => createdIds.size(),
            'ids' => createdIds,
            'errors' => errors
        };
        
        System.debug('CSV Processing Complete - Created: ' + createdIds.size() + ', Errors: ' + errors.size());
        
        return result;
        
    } catch (Exception e) {
        System.debug('Error in createJobsFromCSV: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error processing CSV: ' + e.getMessage());
    }
}
    /**
     * Get recent job postings for AI console view
     * Cacheable for @wire decorator - use refreshApex to get fresh data
     */
    @AuraEnabled(cacheable=true)
    public static List<Job_Posting__c> getRecentJobPostings() {
        try {
            return [
                SELECT Id, Name, Job_Title__c, Category__c, Role_Type__c, Department__c,
                       City__c, State__c, Country__c, Facility_Name__c,
                       Min_Experience_Years__c, Max_Experience_Years__c,
                       Job_Status__c, Start_Date__c, End_Date__c, 
                       Description__c, Credentialing_Required__c,
                       CreatedDate, LastModifiedDate
                FROM Job_Posting__c
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        } catch (Exception e) {
            System.debug('Error in getRecentJobPostings: ' + e.getMessage());
            throw new AuraHandledException('Error loading job postings: ' + e.getMessage());
        }
    }
    
    /**
     * Get job posting with all child records for AI console view
     */
    @AuraEnabled
    public static Map<String, Object> getJobPostingWithDetails(String jobId) {
        try {
            Job_Posting__c job = [
                SELECT Id, Name, Job_Title__c, Account__c , Description__c,
                       Category__c, Role_Type__c, Department__c,
                       Employment_Type__c, Shift_Type__c,
                       Min_Experience_Years__c, Max_Experience_Years__c,
                       Start_Date__c, End_Date__c, Job_Status__c,
                       Facility_Name__c, City__c, State__c, Country__c,
                       Credentialing_Required__c, Privilege_Scope__c,
                       
                       (SELECT Id, Degree_Name__c, Mandatory__c 
                        FROM Education_Requirements__r),
                       
                       (SELECT Id, License_Name__c, Issuing_Authority__c, 
                               Active_Required__c, Expiry_Check_Required__c
                        FROM License_Requirements__r),
                       
                       (SELECT Id, Certification_Name__c, Mandatory__c 
                        FROM Certification_Requirements__r),
                       
                       (SELECT Id, Skill_Name__c, Skill_Level__c, Mandatory__c 
                        FROM Job_Clinical_Skill__r),
                       
                       (SELECT Id, Procedure_Name__c, Critical__c 
                        FROM Job_Procedure_Requirements__r),
                       
                       (SELECT Id, Compliance_Name__c, Mandatory__c 
                        FROM Job_Compliance_Requirements__r)
                       
                FROM Job_Posting__c
                WHERE Id = :jobId
                LIMIT 1
            ];
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('jobPosting', job);
            result.put('educationRequirements', job.Education_Requirements__r);
            result.put('licenseRequirements', job.License_Requirements__r);
            result.put('certificationRequirements', job.Certification_Requirements__r);
            result.put('clinicalSkills', job.Job_Clinical_Skill__r);
            result.put('procedureRequirements', job.Job_Procedure_Requirements__r);
            result.put('complianceRequirements', job.Job_Compliance_Requirements__r);
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error in getJobPostingWithDetails: ' + e.getMessage());
            throw new AuraHandledException('Error loading job details: ' + e.getMessage());
        }
    }
    
    /**
     * Update job posting (for AI console quick edits)
     */
    @AuraEnabled
    public static String updateJobPosting(String jobData) {
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(jobData);
            
            Job_Posting__c job = new Job_Posting__c();
            job.Id = (String) data.get('Id');
            
            if (data.containsKey('Job_Title__c')) {
                job.Job_Title__c = (String) data.get('Job_Title__c');
            }
            if (data.containsKey('Category__c')) {
                job.Category__c = (String) data.get('Category__c');
            }
            if (data.containsKey('Role_Type__c')) {
                job.Role_Type__c = (String) data.get('Role_Type__c');
            }
            if (data.containsKey('Department__c')) {
                job.Department__c = (String) data.get('Department__c');
            }
            if (data.containsKey('City__c')) {
                job.City__c = (String) data.get('City__c');
            }
            if (data.containsKey('State__c')) {
                job.State__c = (String) data.get('State__c');
            }
            if (data.containsKey('Country__c')) {
                job.Country__c = (String) data.get('Country__c');
            }
            if (data.containsKey('Facility_Name__c')) {
                job.Facility_Name__c = (String) data.get('Facility_Name__c');
            }
            if (data.containsKey('Min_Experience_Years__c')) {
                Object exp = data.get('Min_Experience_Years__c');
                job.Min_Experience_Years__c = exp != null ? Decimal.valueOf(String.valueOf(exp)) : null;
            }
            if (data.containsKey('Max_Experience_Years__c')) {
                Object exp = data.get('Max_Experience_Years__c');
                job.Max_Experience_Years__c = exp != null ? Decimal.valueOf(String.valueOf(exp)) : null;
            }
            if (data.containsKey('Start_Date__c')) {
                String startDateStr = (String) data.get('Start_Date__c');
                job.Start_Date__c = String.isNotBlank(startDateStr) ? Date.valueOf(startDateStr) : null;
            }
            if (data.containsKey('End_Date__c')) {
                String endDateStr = (String) data.get('End_Date__c');
                job.End_Date__c = String.isNotBlank(endDateStr) ? Date.valueOf(endDateStr) : null;
            }
            if (data.containsKey('Description__c')) {
                job.Description__c = (String) data.get('Description__c');
            }
            
            update job;
            
            return 'Success';
            
        } catch (Exception e) {
            System.debug('Error in updateJobPosting: ' + e.getMessage());
            throw new AuraHandledException('Error updating job posting: ' + e.getMessage());
        }
    }
    
    /**
     * Test Gemini API connection
     */
    @AuraEnabled
    public static String testGeminiConnection() {
        try {
            return AIJobPostingService.testGeminiConnection();
        } catch (Exception e) {
            throw new AuraHandledException('Error testing Gemini: ' + e.getMessage());
        }
    }

    // ==================== PRIVATE HELPER METHODS (Original Admin) ====================

    /**
     * Parse Job Posting from map
     */
    private static Job_Posting__c parseJobPosting(Map<String, Object> jobMap) {
        Job_Posting__c job = new Job_Posting__c();
        
        if (jobMap.containsKey('Id') && jobMap.get('Id') != null) {
            job.Id = (Id) jobMap.get('Id');
        }

        if (jobMap.containsKey('Account__c') && jobMap.get('Account__c') != null) {
            job.Account__c = (Id) jobMap.get('Account__c');
        }

        job.Job_Title__c = (String) jobMap.get('Job_Title__c');
        job.Description__c = (String) jobMap.get('Description__c');
        job.Category__c = (String) jobMap.get('Category__c');
        job.Role_Type__c = (String) jobMap.get('Role_Type__c');
        job.Department__c = (String) jobMap.get('Department__c');
        job.Employment_Type__c = (String) jobMap.get('Employment_Type__c');
        job.Shift_Type__c = (String) jobMap.get('Shift_Type__c');
        
        if (jobMap.get('Min_Experience_Years__c') != null) {
            job.Min_Experience_Years__c = Decimal.valueOf(String.valueOf(jobMap.get('Min_Experience_Years__c')));
        }
        if (jobMap.get('Max_Experience_Years__c') != null) {
            job.Max_Experience_Years__c = Decimal.valueOf(String.valueOf(jobMap.get('Max_Experience_Years__c')));
        }
        
        if (jobMap.get('Start_Date__c') != null) {
            job.Start_Date__c = Date.valueOf((String) jobMap.get('Start_Date__c'));
        }
        if (jobMap.get('End_Date__c') != null) {
            job.End_Date__c = Date.valueOf((String) jobMap.get('End_Date__c'));
        }
        
        job.Facility_Name__c = (String) jobMap.get('Facility_Name__c');
        job.City__c = (String) jobMap.get('City__c');
        job.State__c = (String) jobMap.get('State__c');
        job.Country__c = (String) jobMap.get('Country__c');
        job.Credentialing_Required__c = (Boolean) jobMap.get('Credentialing_Required__c');
        job.Privilege_Scope__c = (String) jobMap.get('Privilege_Scope__c');
        
        return job;
    }

    /**
     * Validate Job Posting fields
     */
    private static void validateJobPosting(Job_Posting__c job) {
        if (String.isBlank(job.Job_Title__c)) {
            throw new AuraHandledException('Job Title is required.');
        }
        if (String.isBlank(job.Category__c)) {
            throw new AuraHandledException('Category is required.');
        }
        if (String.isBlank(job.Role_Type__c)) {
            throw new AuraHandledException('Role Type is required.');
        }
        if (String.isBlank(job.Employment_Type__c)) {
            throw new AuraHandledException('Employment Type is required.');
        }
        if (String.isBlank(job.Facility_Name__c)) {
            throw new AuraHandledException('Facility Name is required.');
        }
        if (String.isBlank(job.City__c) || String.isBlank(job.State__c) || String.isBlank(job.Country__c)) {
            throw new AuraHandledException('Complete location (City, State, Country) is required.');
        }
        if (job.Start_Date__c == null) {
            throw new AuraHandledException('Start Date is required.');
        }
        if (job.Start_Date__c != null && job.End_Date__c != null && job.End_Date__c < job.Start_Date__c) {
            throw new AuraHandledException('End Date cannot be before Start Date.');
        }
    }

    /**
     * Process Education Requirements
     */
    private static void processEducationRequirements(Id jobPostingId, Map<String, Object> dataMap) {
        delete [SELECT Id FROM Job_Education_Requirement__c WHERE Job_Posting__c = :jobPostingId];
        
        List<Object> eduList = (List<Object>) dataMap.get('educationRequirements');
        if (eduList == null || eduList.isEmpty()) return;
        
        List<Job_Education_Requirement__c> eduRecords = new List<Job_Education_Requirement__c>();
        for (Object obj : eduList) {
            Map<String, Object> eduMap = (Map<String, Object>) obj;
            Job_Education_Requirement__c edu = new Job_Education_Requirement__c();
            edu.Job_Posting__c = jobPostingId;
            edu.Degree_Name__c = (String) eduMap.get('Degree_Name__c');
            edu.Mandatory__c = (Boolean) eduMap.get('Mandatory__c');
            eduRecords.add(edu);
        }
        
        if (!eduRecords.isEmpty()) {
            insert eduRecords;
        }
    }

    /**
     * Process License Requirements
     */
    private static void processLicenseRequirements(Id jobPostingId, Map<String, Object> dataMap) {
        delete [SELECT Id FROM Job_License_Requirement__c WHERE Job_Posting__c = :jobPostingId];
        
        List<Object> licList = (List<Object>) dataMap.get('licenseRequirements');
        if (licList == null || licList.isEmpty()) return;
        
        List<Job_License_Requirement__c> licRecords = new List<Job_License_Requirement__c>();
        for (Object obj : licList) {
            Map<String, Object> licMap = (Map<String, Object>) obj;
            Job_License_Requirement__c lic = new Job_License_Requirement__c();
            lic.Job_Posting__c = jobPostingId;
            lic.License_Name__c = (String) licMap.get('License_Name__c');
            lic.Issuing_Authority__c = (String) licMap.get('Issuing_Authority__c');
            lic.Active_Required__c = (Boolean) licMap.get('Active_Required__c');
            lic.Expiry_Check_Required__c = (Boolean) licMap.get('Expiry_Check_Required__c');
            licRecords.add(lic);
        }
        
        if (!licRecords.isEmpty()) {
            insert licRecords;
        }
    }

    /**
     * Process Certification Requirements
     */
    private static void processCertificationRequirements(Id jobPostingId, Map<String, Object> dataMap) {
        delete [SELECT Id FROM Job_Certification_Requirement__c WHERE Job_Posting__c = :jobPostingId];
        
        List<Object> certList = (List<Object>) dataMap.get('certificationRequirements');
        if (certList == null || certList.isEmpty()) return;
        
        List<Job_Certification_Requirement__c> certRecords = new List<Job_Certification_Requirement__c>();
        for (Object obj : certList) {
            Map<String, Object> certMap = (Map<String, Object>) obj;
            Job_Certification_Requirement__c cert = new Job_Certification_Requirement__c();
            cert.Job_Posting__c = jobPostingId;
            cert.Certification_Name__c = (String) certMap.get('Certification_Name__c');
            cert.Mandatory__c = (Boolean) certMap.get('Mandatory__c');
            certRecords.add(cert);
        }
        
        if (!certRecords.isEmpty()) {
            insert certRecords;
        }
    }

    /**
     * Process Clinical Skills
     */
    private static void processClinicalSkills(Id jobPostingId, Map<String, Object> dataMap) {
        delete [SELECT Id FROM Job_Clinical_Skill__c WHERE Job_Posting__c = :jobPostingId];
        
        List<Object> skillList = (List<Object>) dataMap.get('clinicalSkills');
        if (skillList == null || skillList.isEmpty()) return;
        
        List<Job_Clinical_Skill__c> skillRecords = new List<Job_Clinical_Skill__c>();
        for (Object obj : skillList) {
            Map<String, Object> skillMap = (Map<String, Object>) obj;
            Job_Clinical_Skill__c skill = new Job_Clinical_Skill__c();
            skill.Job_Posting__c = jobPostingId;
            skill.Skill_Name__c = (String) skillMap.get('Skill_Name__c');
            skill.Skill_Level__c = (String) skillMap.get('Skill_Level__c');
            skill.Mandatory__c = (Boolean) skillMap.get('Mandatory__c');
            skillRecords.add(skill);
        }
        
        if (!skillRecords.isEmpty()) {
            insert skillRecords;
        }
    }

    /**
     * Process Procedure Requirements
     */
    private static void processProcedureRequirements(Id jobPostingId, Map<String, Object> dataMap) {
        delete [SELECT Id FROM Job_Procedure_Requirement__c WHERE Job_Posting__c = :jobPostingId];
        
        List<Object> procList = (List<Object>) dataMap.get('procedureRequirements');
        if (procList == null || procList.isEmpty()) return;
        
        List<Job_Procedure_Requirement__c> procRecords = new List<Job_Procedure_Requirement__c>();
        for (Object obj : procList) {
            Map<String, Object> procMap = (Map<String, Object>) obj;
            Job_Procedure_Requirement__c proc = new Job_Procedure_Requirement__c();
            proc.Job_Posting__c = jobPostingId;
            proc.Procedure_Name__c = (String) procMap.get('Procedure_Name__c');
            proc.Critical__c = (Boolean) procMap.get('Critical__c');
            procRecords.add(proc);
        }
        
        if (!procRecords.isEmpty()) {
            insert procRecords;
        }
    }

    /**
     * Process Compliance Requirements
     */
    private static void processComplianceRequirements(Id jobPostingId, Map<String, Object> dataMap) {
        delete [SELECT Id FROM Job_Compliance_Requirement__c WHERE Job_Posting__c = :jobPostingId];
        
        List<Object> compList = (List<Object>) dataMap.get('complianceRequirements');
        if (compList == null || compList.isEmpty()) return;
        
        List<Job_Compliance_Requirement__c> compRecords = new List<Job_Compliance_Requirement__c>();
        for (Object obj : compList) {
            Map<String, Object> compMap = (Map<String, Object>) obj;
            Job_Compliance_Requirement__c comp = new Job_Compliance_Requirement__c();
            comp.Job_Posting__c = jobPostingId;
            comp.Compliance_Name__c = (String) compMap.get('Compliance_Name__c');
            comp.Mandatory__c = (Boolean) compMap.get('Mandatory__c');
            compRecords.add(comp);
        }
        
        if (!compRecords.isEmpty()) {
            insert compRecords;
        }
    }

    /**
     * Get field describe for picklist
     */
    private static Schema.DescribeFieldResult getFieldDescribe(String fieldName) {
        if (fieldName == 'Category__c') {
            return Job_Posting__c.Category__c.getDescribe();
        } else if (fieldName == 'Role_Type__c') {
            return Job_Posting__c.Role_Type__c.getDescribe();
        } else if (fieldName == 'Department__c') {
            return Job_Posting__c.Department__c.getDescribe();
        } else if (fieldName == 'Employment_Type__c') {
            return Job_Posting__c.Employment_Type__c.getDescribe();
        } else if (fieldName == 'Shift_Type__c') {
            return Job_Posting__c.Shift_Type__c.getDescribe();
        } else {
            throw new AuraHandledException('Invalid field name: ' + fieldName);
        }
    }
}