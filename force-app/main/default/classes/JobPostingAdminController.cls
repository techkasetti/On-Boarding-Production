public with sharing class JobPostingAdminController {
    @AuraEnabled(cacheable=true)
    public static List<Job_Posting__c> getJobPostings() {
        try {
            return [
                SELECT Id, Name, Description__c, Location__c, Status__c, Specialization__c, Category__c
                FROM Job_Posting__c
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching job postings: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Job_Posting__c> saveJobPostings(List<Job_Posting__c> jobPostings) {
        if (jobPostings == null || jobPostings.isEmpty()) {
            throw new AuraHandledException('Job Posting data cannot be null or empty.');
        }
        try {
            upsert jobPostings;
            return jobPostings;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving job postings: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteJobPosting(Id jobPostingId) {
        if (jobPostingId == null) {
            throw new AuraHandledException('Job Posting ID cannot be null.');
        }
        try {
            delete new Job_Posting__c(Id = jobPostingId);
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting job posting: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPicklistValues() {
        List<Map<String, String>> picklistOptions = new List<Map<String, String>>();
        try {
            Schema.DescribeFieldResult fieldResult = Job_Posting__c.Status__c.getDescribe();
            List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
            for (Schema.PicklistEntry f: ple) {
                Map<String, String> option = new Map<String, String>();
                option.put('label', f.getLabel());
                option.put('value', f.getValue());
                picklistOptions.add(option);
            }
            return picklistOptions;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching picklist values: ' + e.getMessage());
        }
    }
}
