public without sharing class JobPostingController {
    

    // @AuraEnabled(cacheable=true)
    // public static List<Job_Posting__c> getJobPostings(
    //     String keyword, 
    //     String location, 
    //     String datePosted, 
    //     String experienceLevel
    // ) {
    //     try {
    //         String query = 'SELECT Id, Name, Category__c, Location__c, Description__c, Experience_Level__c, Status__c, CreatedDate, CreatedBy.Name, LastModifiedDate ' +
    //                       'FROM Job_Posting__c ' +
    //                       'WHERE Status__c IN (\'Active\', \'Open\')';
            
    //         Map<String, Object> bindVars = new Map<String, Object>();
            
    //         if (String.isNotBlank(keyword)) {
    //             String searchTerm = '%' + String.escapeSingleQuotes(keyword) + '%';
    //             query += ' AND (Name LIKE :searchTerm OR Category__c LIKE :searchTerm)';
    //             bindVars.put('searchTerm', searchTerm);
    //         }
            
    //         if (String.isNotBlank(location)) {
    //             String locationTerm = '%' + String.escapeSingleQuotes(location) + '%';
    //             query += ' AND Location__c LIKE :locationTerm';
    //             bindVars.put('locationTerm', locationTerm);
    //         }
            
    //         if (String.isNotBlank(datePosted) && datePosted != 'all') {
    //             if (datePosted == '24h') {
    //                 query += ' AND CreatedDate >= LAST_N_DAYS:1';
    //             } else if (datePosted == 'week') {
    //                 query += ' AND CreatedDate >= LAST_N_DAYS:7';
    //             } else if (datePosted == 'month') {
    //                 query += ' AND CreatedDate >= LAST_N_DAYS:30';
    //             }
    //         }
            
    //         if (String.isNotBlank(experienceLevel) && experienceLevel != 'all') {
    //             query += ' AND Experience_Level__c = :experienceLevel';
    //             bindVars.put('experienceLevel', experienceLevel);
    //         }
            
    //         query += ' ORDER BY CreatedDate DESC LIMIT 100';
            
    //         List<Job_Posting__c> results = Database.query(query);
            
    //         return results;
            
    //     } catch (Exception e) {
    //         throw new AuraHandledException('Error fetching job postings: ' + e.getMessage());
    //     }
    // }
    
    // /**
    //  * Check if the current user is a guest (not logged in)
    //  * @return true if user is guest, false if authenticated
    //  */
    // @AuraEnabled(cacheable=true)
    // public static Boolean isGuestUser() {
    //     try {
    //         // Check if running user is guest
    //         User currentUser = [SELECT Id, IsPortalEnabled, ContactId, UserType 
    //                            FROM User 
    //                            WHERE Id = :UserInfo.getUserId() 
    //                            LIMIT 1];
            
    //         // Guest users have UserType = 'Guest' and no ContactId
    //         return currentUser.UserType == 'Guest' || currentUser.ContactId == null;
            
    //     } catch (Exception e) {
    //         // If there's an error, assume guest for safety
    //         return true;
    //     }
    // }
    
    // /**
    //  * Get the current logged-in user's Contact information
    //  * @return Contact record or null if guest user
    //  */
    // @AuraEnabled(cacheable=true)
    // public static Contact getCurrentUserContact() {
    //     try {
    //         User currentUser = [SELECT Id, ContactId 
    //                            FROM User 
    //                            WHERE Id = :UserInfo.getUserId() 
    //                            LIMIT 1];
            
    //         if (currentUser.ContactId != null) {
    //             return [SELECT Id, Name, Email, Phone, FirstName, LastName 
    //                    FROM Contact 
    //                    WHERE Id = :currentUser.ContactId 
    //                    LIMIT 1];
    //         }
            
    //         return null;
            
    //     } catch (Exception e) {
    //         throw new AuraHandledException('Error fetching user contact: ' + e.getMessage());
    //     }
    // }
    
    // @AuraEnabled
    // public static String applyToJob(Id jobId, Id candidateId) {
    //     try {
    //         // Verify user is logged in
    //         if (isGuestUser()) {
    //             throw new AuraHandledException('You must be logged in to apply for jobs');
    //         }
            
    //         // Your application logic here
    //         // For example, create a Job_Application__c record
            
    //         return 'Application submitted successfully';
            
    //     } catch (Exception e) {
    //         throw new AuraHandledException('Error applying to job: ' + e.getMessage());
    //     }
    // }
    
    // @AuraEnabled
    // public static String saveJob(Id jobId, Id userId) {
    //     try {
    //         // Verify user is logged in
    //         if (isGuestUser()) {
    //             throw new AuraHandledException('You must be logged in to save jobs');
    //         }
            
    //         // Your save logic here
            
    //         return 'Job saved successfully';
            
    //     } catch (Exception e) {
    //         throw new AuraHandledException('Error saving job: ' + e.getMessage());
    //     }
    // }

 
    
    @AuraEnabled(cacheable=true)
    public static List<Job_Posting__c> getJobPostings(
        String keyword, 
        String location, 
        String datePosted, 
        String experienceLevel
    ) {
        try {
            String query = 'SELECT Id, Name, Category__c, Location__c, Description__c, Experience_Level__c, Status__c, CreatedDate, CreatedBy.Name, LastModifiedDate ' +
                          'FROM Job_Posting__c ' +
                          'WHERE Status__c IN (\'Active\', \'Open\')';
            
            Map<String, Object> bindVars = new Map<String, Object>();
            
            if (String.isNotBlank(keyword)) {
                String searchTerm = '%' + String.escapeSingleQuotes(keyword) + '%';
                query += ' AND (Name LIKE :searchTerm OR Category__c LIKE :searchTerm)';
                bindVars.put('searchTerm', searchTerm);
            }
            
            if (String.isNotBlank(location)) {
                String locationTerm = '%' + String.escapeSingleQuotes(location) + '%';
                query += ' AND Location__c LIKE :locationTerm';
                bindVars.put('locationTerm', locationTerm);
            }
            
            if (String.isNotBlank(datePosted) && datePosted != 'all') {
                if (datePosted == '24h') {
                    query += ' AND CreatedDate >= LAST_N_DAYS:1';
                } else if (datePosted == 'week') {
                    query += ' AND CreatedDate >= LAST_N_DAYS:7';
                } else if (datePosted == 'month') {
                    query += ' AND CreatedDate >= LAST_N_DAYS:30';
                }
            }
            
            if (String.isNotBlank(experienceLevel) && experienceLevel != 'all') {
                query += ' AND Experience_Level__c = :experienceLevel';
                bindVars.put('experienceLevel', experienceLevel);
            }
            
            query += ' ORDER BY CreatedDate DESC LIMIT 100';
            
            List<Job_Posting__c> results = Database.query(query);
            
            return results;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching job postings: ' + e.getMessage());
        }
    }
    
    /**
     * Check if the current user is a guest (not logged in)
     * @return true if user is guest, false if authenticated
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isGuestUser() {
        try {
            Id currentUserId = UserInfo.getUserId();
            System.debug('=== isGuestUser Method Called ===');
            System.debug('Current User ID: ' + currentUserId);
            System.debug('User Type: ' + UserInfo.getUserType());
            
            User currentUser = [SELECT Id, IsPortalEnabled, ContactId, UserType, Username 
                               FROM User 
                               WHERE Id = :currentUserId 
                               LIMIT 1];
            
            System.debug('User Record: ' + currentUser);
            System.debug('User Type from query: ' + currentUser.UserType);
            System.debug('ContactId: ' + currentUser.ContactId);
            
            // Guest users have UserType = 'Guest' and no ContactId
            Boolean isGuest = currentUser.UserType == 'Guest' || currentUser.ContactId == null;
            
            System.debug('Is Guest: ' + isGuest);
            System.debug('=== isGuestUser Method Completed ===');
            
            return isGuest;
            
        } catch (Exception e) {
            System.debug('Error in isGuestUser: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            // If there's an error, assume guest for safety
            return true;
        }
    }
    
    /**
     * Get Candidate ID for the current logged-in user
     * Dynamically retrieves: Current User -> Contact -> Candidate
     * @return Map containing candidateId and candidateName
     */
    @AuraEnabled
    public static Map<String, String> getCandidateIdForCurrentUser() {
        try {
            Map<String, String> result = new Map<String, String>();
            
            // Step 1: Get the current logged-in user's ID dynamically
            Id currentUserId = UserInfo.getUserId();
            System.debug('=== getCandidateIdForCurrentUser Method Called ===');
            System.debug('Current User ID: ' + currentUserId);
            System.debug('User Type: ' + UserInfo.getUserType());
            
            // Step 2: Get current user's contact ID
            // Query: SELECT Id, ContactId FROM User WHERE Id = :currentUserId
            List<User> users = [SELECT Id, ContactId, Username, UserType 
                               FROM User 
                               WHERE Id = :currentUserId 
                               LIMIT 1];
            
            if (users.isEmpty()) {
                System.debug('ERROR: User not found');
                throw new AuraHandledException('User not found');
            }
            
            User currentUser = users[0];
            System.debug('Current User Record: ' + currentUser);
            System.debug('Current User Contact ID: ' + currentUser.ContactId);
            
            if (currentUser.ContactId == null) {
                System.debug('ERROR: No contact associated with user');
                throw new AuraHandledException('No contact associated with this user. Please contact administrator to link your account.');
            }
            
            // Step 3: Get candidate record from contact
            // Query: SELECT Id, Name FROM Candidate__c WHERE Contact__c = :contactId
            List<Candidate__c> candidates = [SELECT Id, Name, Email__c, Phone__c, Location__c
                                            FROM Candidate__c 
                                            WHERE Contact__c = :currentUser.ContactId 
                                            LIMIT 1];
            
            System.debug('Candidates Query Result: ' + candidates);
            System.debug('Candidates found: ' + candidates.size());
            
            if (candidates.isEmpty()) {
                System.debug('ERROR: No candidate profile found');
                throw new AuraHandledException('No candidate profile found for this user. Please contact administrator to create your candidate profile.');
            }
            
            Candidate__c candidate = candidates[0];
            System.debug('Candidate ID: ' + candidate.Id);
            System.debug('Candidate Name: ' + candidate.Name);
            
            // Return candidate data
            result.put('candidateId', candidate.Id);
            result.put('candidateName', candidate.Name);
            
            System.debug('Returning result: ' + result);
            System.debug('=== getCandidateIdForCurrentUser Method Completed Successfully ===');
            
            return result;
            
        } catch (Exception e) {
            System.debug('=== ERROR in getCandidateIdForCurrentUser ===');
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('Line Number: ' + e.getLineNumber());
            throw new AuraHandledException('Error fetching candidate data: ' + e.getMessage());
        }
    }
    
    /**
     * Get the current logged-in user's Contact information
     * @return Contact record or null if guest user
     */
    @AuraEnabled(cacheable=true)
    public static Contact getCurrentUserContact() {
        try {
            User currentUser = [SELECT Id, ContactId 
                               FROM User 
                               WHERE Id = :UserInfo.getUserId() 
                               LIMIT 1];
            
            if (currentUser.ContactId != null) {
                return [SELECT Id, Name, Email, Phone, FirstName, LastName 
                       FROM Contact 
                       WHERE Id = :currentUser.ContactId 
                       LIMIT 1];
            }
            
            return null;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching user contact: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String applyToJob(Id jobId, Id candidateId) {
        try {
            // Verify user is logged in
            if (isGuestUser()) {
                throw new AuraHandledException('You must be logged in to apply for jobs');
            }
            
            // Your application logic here
            // For example, create a Job_Application__c record
            
            return 'Application submitted successfully';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error applying to job: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String saveJob(Id jobId, Id userId) {
        try {
            // Verify user is logged in
            if (isGuestUser()) {
                throw new AuraHandledException('You must be logged in to save jobs');
            }
            
            // Your save logic here
            
            return 'Job saved successfully';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error saving job: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String createJobFromNLP(String userInput) {
        try {
            System.debug('Received NLP input: ' + userInput);
            
            Map<String, Object> jobData = AIJobPostingService.processNLPInput(userInput);
            System.debug('Parsed job data: ' + jobData);
            
            String jobId = AIJobPostingService.createJobPosting(jobData);
            System.debug('Created job posting: ' + jobId);
            
            return jobId;
            
        } catch (Exception e) {
            System.debug('Error in createJobFromNLP: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error processing request: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> createJobsFromCSV(String csvContent) {
        try {
            System.debug('Received CSV content length: ' + csvContent.length());
            
            List<Map<String, Object>> jobDataList = CSVJobPostingProcessor.parseCSV(csvContent);
            System.debug('Parsed ' + jobDataList.size() + ' jobs from CSV');
            
            List<String> createdIds = CSVJobPostingProcessor.createJobPostingsFromCSV(jobDataList);
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'count' => createdIds.size(),
                'ids' => createdIds
            };
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error in createJobsFromCSV: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error processing CSV: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Job_Posting__c> getRecentJobPostings() {
        try {
            return [
                SELECT Id, Name, Category__c, Location__c, Experience_Level__c,
                       Specialization__c, Status__c, Start_Date__c, End_Date__c, 
                       Description__c
                FROM Job_Posting__c
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        } catch (Exception e) {
            System.debug('Error in getRecentJobPostings: ' + e.getMessage());
            throw new AuraHandledException('Error loading job postings: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Job_Posting__c getJobPostingDetails(String jobId) {
        try {
            return [
                SELECT Id, Name, Category__c, Location__c, Experience_Level__c,
                       Specialization__c, Status__c, Start_Date__c, End_Date__c,
                       Description__c
                FROM Job_Posting__c
                WHERE Id = :jobId
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('Error in getJobPostingDetails: ' + e.getMessage());
            throw new AuraHandledException('Error loading job details: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String updateJobPosting(String jobData) {
        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(jobData);
            
            Job_Posting__c job = new Job_Posting__c();
            job.Id = (String) data.get('Id');
            
            if (data.containsKey('Name')) {
                job.Name = (String) data.get('Name');
            }
            if (data.containsKey('Category__c')) {
                job.Category__c = (String) data.get('Category__c');
            }
            if (data.containsKey('Location__c')) {
                job.Location__c = (String) data.get('Location__c');
            }
            if (data.containsKey('Experience_Level__c')) {
                job.Experience_Level__c = (String) data.get('Experience_Level__c');
            }
            if (data.containsKey('Specialization__c')) {
                String spec = (String) data.get('Specialization__c');
                job.Specialization__c = String.isNotBlank(spec) ? spec : null;
            }
            if (data.containsKey('Status__c')) {
                job.Status__c = (String) data.get('Status__c');
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
    
    @AuraEnabled
    public static String testGeminiConnection() {
        try {
            return AIJobPostingService.testGeminiConnection();
        } catch (Exception e) {
            throw new AuraHandledException('Error testing Gemini: ' + e.getMessage());
        }
    }
}