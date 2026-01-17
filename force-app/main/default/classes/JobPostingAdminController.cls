// public with sharing class JobPostingAdminController {
    
//     @AuraEnabled(cacheable=true)
//     public static List<Job_Posting__c> getJobPostings() {
//         try {
//             return [
//                 SELECT Id, Name, Description__c, Location__c, Status__c, 
//                        Specialization__c, Category__c, Experience_Level__c,
//                        CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name
//                 FROM Job_Posting__c
//                 ORDER BY CreatedDate DESC
//                 LIMIT 1000
//             ];
//         } catch (Exception e) {
//             throw new AuraHandledException('Error fetching job postings: ' + e.getMessage());
//         }
//     }

//     @AuraEnabled
//     public static List<Job_Posting__c> saveJobPostings(List<Job_Posting__c> jobPostings) {
//         if (jobPostings == null || jobPostings.isEmpty()) {
//             throw new AuraHandledException('Job Posting data cannot be null or empty.');
//         }
        
//         try {
//             // Validate required fields
//             for (Job_Posting__c job : jobPostings) {
//                 if (String.isBlank(job.Name)) {
//                     throw new AuraHandledException('Job Posting Name is required.');
//                 }
//             }
            
//             upsert jobPostings;
//             return jobPostings;
            
//         } catch (DmlException e) {
//             throw new AuraHandledException('Error saving job postings: ' + e.getDmlMessage(0));
//         } catch (Exception e) {
//             throw new AuraHandledException('Error saving job postings: ' + e.getMessage());
//         }
//     }

//     @AuraEnabled
//     public static void deleteJobPosting(Id jobPostingId) {
//         if (jobPostingId == null) {
//             throw new AuraHandledException('Job Posting ID cannot be null.');
//         }
        
//         try {
//             Job_Posting__c jobToDelete = [
//                 SELECT Id 
//                 FROM Job_Posting__c 
//                 WHERE Id = :jobPostingId 
//                 LIMIT 1
//             ];
            
//             delete jobToDelete;
            
//         } catch (QueryException e) {
//             throw new AuraHandledException('Job Posting not found.');
//         } catch (DmlException e) {
//             throw new AuraHandledException('Error deleting job posting: ' + e.getDmlMessage(0));
//         } catch (Exception e) {
//             throw new AuraHandledException('Error deleting job posting: ' + e.getMessage());
//         }
//     }

//     @AuraEnabled(cacheable=true)
//     public static List<Map<String, String>> getPicklistValues(String fieldName) {
//         List<Map<String, String>> picklistOptions = new List<Map<String, String>>();
        
//         try {
//             if (String.isBlank(fieldName)) {
//                 throw new AuraHandledException('Field name cannot be blank.');
//             }
            
//             Schema.DescribeFieldResult fieldResult;
            
//             // Get the appropriate field based on fieldName parameter
//             if (fieldName == 'Status__c') {
//                 fieldResult = Job_Posting__c.Status__c.getDescribe();
//             } else if (fieldName == 'Category__c') {
//                 fieldResult = Job_Posting__c.Category__c.getDescribe();
//             } else if (fieldName == 'Experience_Level__c') {
//                 fieldResult = Job_Posting__c.Experience_Level__c.getDescribe();
//             } else if (fieldName == 'Specialization__c') {
//                 fieldResult = Job_Posting__c.Specialization__c.getDescribe();
//             } else {
//                 throw new AuraHandledException('Invalid field name: ' + fieldName);
//             }
            
//             List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
            
//             for (Schema.PicklistEntry entry : picklistEntries) {
//                 if (entry.isActive()) {
//                     Map<String, String> option = new Map<String, String>();
//                     option.put('label', entry.getLabel());
//                     option.put('value', entry.getValue());
//                     picklistOptions.add(option);
//                 }
//             }
            
//             return picklistOptions;
            
//         } catch (Exception e) {
//             throw new AuraHandledException('Error fetching picklist values: ' + e.getMessage());
//         }
//     }
    
//     @AuraEnabled(cacheable=true)
//     public static Map<String, Object> getJobStatistics() {
//         Map<String, Object> stats = new Map<String, Object>();
        
//         try {
//             // Get total count
//             Integer totalJobs = [SELECT COUNT() FROM Job_Posting__c];
//             stats.put('totalJobs', totalJobs);
            
//             // Get count by status
//             List<AggregateResult> statusCounts = [
//                 SELECT Status__c, COUNT(Id) cnt 
//                 FROM Job_Posting__c 
//                 GROUP BY Status__c
//             ];
            
//             Map<String, Integer> statusMap = new Map<String, Integer>();
//             for (AggregateResult ar : statusCounts) {
//                 String status = (String)ar.get('Status__c');
//                 Integer count = (Integer)ar.get('cnt');
//                 statusMap.put(status != null ? status : 'Unknown', count);
//             }
//             stats.put('statusBreakdown', statusMap);
            
//             return stats;
            
//         } catch (Exception e) {
//             throw new AuraHandledException('Error fetching statistics: ' + e.getMessage());
//         }
//     }
// }
public with sharing class JobPostingAdminController {
    
    @AuraEnabled(cacheable=true)
    public static List<Job_Posting__c> getJobPostings() {
        try {
            return [
                SELECT Id, Name, Description__c, Location__c, Status__c, 
                       Specialization__c, Category__c, Experience_Level__c,
                       Start_Date__c, End_Date__c,
                       CreatedDate, CreatedBy.Name, LastModifiedDate, LastModifiedBy.Name
                FROM Job_Posting__c
                ORDER BY CreatedDate DESC
                LIMIT 1000
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
            // Validate required fields
            for (Job_Posting__c job : jobPostings) {
                if (String.isBlank(job.Name)) {
                    throw new AuraHandledException('Job Posting Name is required.');
                }
                
                // Validate date logic
                if (job.Start_Date__c != null && job.End_Date__c != null) {
                    if (job.End_Date__c < job.Start_Date__c) {
                        throw new AuraHandledException('End Date cannot be before Start Date.');
                    }
                }
            }
            
            upsert jobPostings;
            return jobPostings;
            
        } catch (DmlException e) {
            throw new AuraHandledException('Error saving job postings: ' + e.getDmlMessage(0));
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

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPicklistValues(String fieldName) {
        List<Map<String, String>> picklistOptions = new List<Map<String, String>>();
        
        try {
            if (String.isBlank(fieldName)) {
                throw new AuraHandledException('Field name cannot be blank.');
            }
            
            Schema.DescribeFieldResult fieldResult;
            
            // Get the appropriate field based on fieldName parameter
            if (fieldName == 'Status__c') {
                fieldResult = Job_Posting__c.Status__c.getDescribe();
            } else if (fieldName == 'Category__c') {
                fieldResult = Job_Posting__c.Category__c.getDescribe();
            } else if (fieldName == 'Experience_Level__c') {
                fieldResult = Job_Posting__c.Experience_Level__c.getDescribe();
            } else if (fieldName == 'Specialization__c') {
                fieldResult = Job_Posting__c.Specialization__c.getDescribe();
            } else {
                throw new AuraHandledException('Invalid field name: ' + fieldName);
            }
            
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
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getJobStatistics() {
        Map<String, Object> stats = new Map<String, Object>();
        
        try {
            // Get total count
            Integer totalJobs = [SELECT COUNT() FROM Job_Posting__c];
            stats.put('totalJobs', totalJobs);
            
            // Get count by status
            List<AggregateResult> statusCounts = [
                SELECT Status__c, COUNT(Id) cnt 
                FROM Job_Posting__c 
                GROUP BY Status__c
            ];
            
            Map<String, Integer> statusMap = new Map<String, Integer>();
            for (AggregateResult ar : statusCounts) {
                String status = (String)ar.get('Status__c');
                Integer count = (Integer)ar.get('cnt');
                statusMap.put(status != null ? status : 'Unknown', count);
            }
            stats.put('statusBreakdown', statusMap);
            
            return stats;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching statistics: ' + e.getMessage());
        }
    }
}