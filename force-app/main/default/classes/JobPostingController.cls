public with sharing class JobPostingController {
    
    @AuraEnabled(cacheable=true)
    public static List<Job_Posting__c> getJobPostings(
        String keyword, 
        String location, 
        String datePosted, 
        String experienceLevel
    ) {
        try {
            String query = 'SELECT Id, Name, Category__c, Location__c, Description__c, Experience_Level__c, CreatedDate, CreatedBy.Name, LastModifiedDate ' +
                          'FROM Job_Posting__c ' +
                          'WHERE Id != null';
            
            Map<String, Object> bindVars = new Map<String, Object>();
            
            // Keyword filter - searches in Name and Category only (Description is Long Text Area and not filterable)
            if (String.isNotBlank(keyword)) {
                String searchTerm = '%' + String.escapeSingleQuotes(keyword) + '%';
                query += ' AND (Name LIKE :searchTerm OR Category__c LIKE :searchTerm)';
                bindVars.put('searchTerm', searchTerm);
            }
            
            // Location filter
            if (String.isNotBlank(location)) {
                String locationTerm = '%' + String.escapeSingleQuotes(location) + '%';
                query += ' AND Location__c LIKE :locationTerm';
                bindVars.put('locationTerm', locationTerm);
            }
            
            // Date posted filter
            if (String.isNotBlank(datePosted) && datePosted != 'all') {
                if (datePosted == '24h') {
                    query += ' AND CreatedDate >= LAST_N_DAYS:1';
                } else if (datePosted == 'week') {
                    query += ' AND CreatedDate >= LAST_N_DAYS:7';
                } else if (datePosted == 'month') {
                    query += ' AND CreatedDate >= LAST_N_DAYS:30';
                }
            }
            
            // Experience level filter
            if (String.isNotBlank(experienceLevel) && experienceLevel != 'all') {
                query += ' AND Experience_Level__c = :experienceLevel';
                bindVars.put('experienceLevel', experienceLevel);
            }
            
            // Order by most recent first
            query += ' ORDER BY CreatedDate DESC LIMIT 100';
            
            // Execute dynamic query with bind variables
            List<Job_Posting__c> results = Database.query(query);
            
            return results;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching job postings: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String applyToJob(Id jobId, Id candidateId) {
        try {
            // Add your application logic here
            // For example, create an Application record or update candidate status
            
            // Example: Create a custom Application object record
            // Application__c application = new Application__c(
            //     Job_Posting__c = jobId,
            //     Candidate__c = candidateId,
            //     Status__c = 'Applied',
            //     Application_Date__c = Date.today()
            // );
            // insert application;
            
            return 'Application submitted successfully';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error applying to job: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String saveJob(Id jobId, Id userId) {
        try {
            // Add your save job logic here
            // For example, create a Saved Job record
            
            // Example: Create a custom Saved_Job__c record
            // Saved_Job__c savedJob = new Saved_Job__c(
            //     Job_Posting__c = jobId,
            //     User__c = userId,
            //     Saved_Date__c = Date.today()
            // );
            // insert savedJob;
            
            return 'Job saved successfully';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error saving job: ' + e.getMessage());
        }
    }
}