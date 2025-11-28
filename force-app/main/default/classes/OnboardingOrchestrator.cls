public with sharing class OnboardingOrchestrator {
    /**
     * @description Registers a new candidate by delegating to the CandidateIntakeController.
     * @param fullName The full name of the candidate.
     * @param phone The phone number of the candidate.
     * @param email The email address of the candidate.
     * @return The ID of the newly created Candidate__c record.
     */
    @AuraEnabled
    public static Id registerCandidate(String fullName, String phone, String email) {
        // Delegate to CandidateIntakeController so logic is centralized
        return CandidateIntakeController.registerCandidate(fullName, phone, email);
    }

    /**
     * @description Fetches and parses a resume from an external service for the preview panel.
     * @param candidateId The ID of the Candidate__c record.
     * @return A DTO containing the parsed resume data.
     */
    @AuraEnabled(cacheable = false)
    public static ResumeWebhookService.ResumePayload fetchResumePreview(Id candidateId) {
        try {
            // 1) Callout first (NO DML before callout)
            ResumeWebhookService.ResumePayload payload = ResumeWebhookService.callWebhookAndParse();

            // 2) Best-effort audit AFTER callout
            try {
                Onb_ActivationAuditWriter.write(
                    'RESUME_PREVIEW_REQUESTED', 'Preview requested from UI', candidateId
                );
            } catch (Exception logEx) {
                Onb_ErrorLogService.logError(
                    'OnboardingOrchestrator.fetchResumePreview.audit', logEx
                );
            }
            return payload;
        } catch (ResumeWebhookService.CalloutException ex) {
            Onb_ErrorLogService.logError(
                'OnboardingOrchestrator.fetchResumePreview', ex
            );
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            Onb_ErrorLogService.logError(
                'OnboardingOrchestrator.fetchResumePreview', ex
            );
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /**
     * @description Persists the verified/edited data from the resume preview panel.
     * @param candidateId The ID of the Candidate__c to update.
     * @param firstName The verified first name.
     * @param lastName The verified last name.
     * @param location The verified location.
     * @param email The verified email.
     * @param phone The verified phone.
     * @param yearsExperience The verified years of experience.
     * @param skills A comma-separated string of skills.
     */
    // @AuraEnabled
    // public static void persistVerifiedData(Id candidateId, String firstName, String lastName, String location, String email, String phone, String yearsExperience, String skills) {
    //     // --- DEBUGGING: Check if data is arriving in Apex correctly ---
    //     System.debug('persistVerifiedData called with candidateId: ' + candidateId + ', Name: ' + firstName + ' ' + lastName + ', Email: ' + email);
    //     System.debug('Skills received: ' + skills);
        
    //     // 1. Fetch the original, canonical payload to store the raw JSON for auditing
    //     ResumeWebhookService.ResumePayload payload = ResumeWebhookService.callWebhookAndParse();
    //     String rawJsonForStorage = JSON.serialize(payload);

    //     // 2. Find the Candidate__c record to update
    //     List<Candidate__c> candidates = [
    //         SELECT Id, Name, Email__c, Phone__c, Location__c, Years_of_Experience__c, Raw_Resume_Payload__c
    //         FROM Candidate__c
    //         WHERE Id = :candidateId
    //         LIMIT 1
    //     ];

    //     if (candidates.isEmpty()) {
    //         // --- DEBUGGING: Check if the candidate record was found ---
    //         System.debug('FATAL: No Candidate__c record found with Id: ' + candidateId);
    //         throw new AuraHandledException('Candidate not found.');
    //     }

    //     Candidate__c candidateToUpdate = candidates[0];

    //     // 3. Update the Candidate__c record with the verified data
    //     candidateToUpdate.Name = firstName + ' ' + lastName;
    //     candidateToUpdate.Email__c = email;
    //     candidateToUpdate.Phone__c = phone;
    //     candidateToUpdate.Location__c = location;
    //     if (String.isNotBlank(yearsExperience)) {
    //         candidateToUpdate.Years_of_Experience__c = Decimal.valueOf(yearsExperience);
    //     }
    //     candidateToUpdate.Raw_Resume_Payload__c = rawJsonForStorage;

    //     // 4. Prepare the new skill records
    //     List<Candidate_Skill__c> skillsToInsert = new List<Candidate_Skill__c>();
    //     if (String.isNotBlank(skills)) {
    //         List<String> skillNames = skills.split(',');
    //         for (String skillName : skillNames) {
    //             String trimmedSkill = skillName.trim();
    //             if (String.isNotBlank(trimmedSkill)) {
    //                 skillsToInsert.add(new Candidate_Skill__c(
    //                     Candidate__c = candidateId,
    //                     Skill_Name__c = trimmedSkill
    //                 ));
    //             }
    //         }
    //     }

    //     // 5. Delete old skills to prevent duplicates, then insert the new set
    //     List<Candidate_Skill__c> existingSkills = [SELECT Id FROM Candidate_Skill__c WHERE Candidate__c = :candidateId];

    //     try {
    //         // --- DEBUGGING: Check right before the DML operations ---
    //         System.debug('Attempting DML operations. Candidate to update: ' + candidateToUpdate);
    //         System.debug('Skill records to insert: ' + skillsToInsert.size() + '. Skill records to delete: ' + existingSkills.size());

    //         update candidateToUpdate; // Save changes to the candidate record
    //         if (!existingSkills.isEmpty()) {
    //             delete existingSkills; // Clean up old skills
    //         }
    //         if (!skillsToInsert.isEmpty()) {
    //             insert skillsToInsert; // Insert the new, verified skills
    //         }
    //         Onb_ActivationAuditWriter.write('RESUME_DATA_PERSISTED', 'Verified resume data and skills saved', candidateId);
    //     } catch (Exception ex) {
    //         // --- DEBUGGING: This is the MOST IMPORTANT log if something fails ---
    //         System.debug('DML Exception in persistVerifiedData: ' + ex.getMessage() + ' at line ' + ex.getLineNumber());
    //         System.debug('Stack Trace: ' + ex.getStackTraceString());
    //         Onb_ErrorLogService.logError('OnboardingOrchestrator.persistVerifiedData', ex);
    //         throw new AuraHandledException('Failed to save candidate data: ' + ex.getMessage());
    //     }
    // }
// @AuraEnabled
// public static void persistVerifiedData(Id candidateId, String firstName, String lastName, String location, String email, String phone, String yearsExperience, String skills) {
//     System.debug('persistVerifiedData called for candidateId: ' + candidateId);
//     System.debug('New skills to add: ' + skills);

//     // 1. Find the Candidate__c record to update, ensuring the new Skills__c field is included.
//     List<Candidate__c> candidates = [
//         SELECT Id, Name, Email__c, Phone__c, Location__c, Years_of_Experience__c, Raw_Resume_Payload__c, Skills__c
//         FROM Candidate__c
//         WHERE Id = :candidateId
//         LIMIT 1
//     ];

//     if (candidates.isEmpty()) {
//         System.debug('FATAL: No Candidate__c record found with Id: ' + candidateId);
//         throw new AuraHandledException('Candidate not found.');
//     }

//     Candidate__c candidateToUpdate = candidates[0];

//     // 2. Update the standard candidate fields
//     candidateToUpdate.Name = firstName + ' ' + lastName;
//     candidateToUpdate.Email__c = email;
//     candidateToUpdate.Phone__c = phone;
//     candidateToUpdate.Location__c = location;
//     if (String.isNotBlank(yearsExperience)) {
//         try {
//             candidateToUpdate.Years_of_Experience__c = Decimal.valueOf(yearsExperience);
//         } catch (Exception e) {
//             System.debug('Could not parse yearsExperience: ' + yearsExperience);
//         }
//     }

//     // Fetch and store the raw payload for auditing if needed
//     ResumeWebhookService.ResumePayload payload = ResumeWebhookService.callWebhookAndParse();
//     candidateToUpdate.Raw_Resume_Payload__c = JSON.serialize(payload);

//     // 3. NEW: Merge and Deduplicate Logic for Skills
//     // Use a Set to automatically handle uniqueness.
//     Set<String> allSkills = new Set<String>();

//     // Add existing skills from the record to the Set
//     String existingSkillsString = candidateToUpdate.Skills__c;
//     System.debug('Existing skills on record: ' + existingSkillsString);
//     if (String.isNotBlank(existingSkillsString)) {
//         for(String skill : existingSkillsString.split('\\s*,\\s*')) {
//             if(String.isNotBlank(skill)) {
//                 allSkills.add(skill.trim());
//             }
//         }
//     }

//     // Add new skills from the input to the Set
//     if (String.isNotBlank(skills)) {
//         for(String skill : skills.split('\\s*,\\s*')) {
//              if(String.isNotBlank(skill)) {
//                 allSkills.add(skill.trim());
//             }
//         }
//     }
    
//     // Convert the unique Set back to a List so we can sort it.
//     List<String> sortedSkills = new List<String>(allSkills);
//     sortedSkills.sort();

//     // Join the sorted, unique list back into a single string and update the field.
//     candidateToUpdate.Skills__c = String.join(sortedSkills, ', ');
//     System.debug('Final merged skills to save: ' + candidateToUpdate.Skills__c);
    
//     // 4. Perform the final DML update
//     try {
//         update candidateToUpdate; // Save all changes to the candidate record
//         Onb_ActivationAuditWriter.write('RESUME_DATA_PERSISTED', 'Verified resume data and skills were updated.', candidateId);
//     } catch (Exception ex) {
//         System.debug('DML Exception in persistVerifiedData: ' + ex.getMessage() + ' at line ' + ex.getLineNumber());
//         System.debug('Stack Trace: ' + ex.getStackTraceString());
//         Onb_ErrorLogService.logError('OnboardingOrchestrator.persistVerifiedData', ex);
//         throw new AuraHandledException('Failed to save candidate data: ' + ex.getMessage());
//     }
// }


   
    @AuraEnabled
    public static void persistVerifiedData(Id candidateId, String firstName, String lastName, String location, String email, String phone, String yearsExperience, String skills) {
        // Your existing, correct logic for merging skills into the Skills__c field
        // This method does not need to change.
        System.debug('persistVerifiedData called for candidateId: ' + candidateId);
        System.debug('New skills to add: ' + skills);

        List<Candidate__c> candidates = [
            SELECT Id, Name, Email__c, Phone__c, Location__c, Years_of_Experience__c, Raw_Resume_Payload__c, Skills__c
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];

        if (candidates.isEmpty()) {
            System.debug('FATAL: No Candidate__c record found with Id: ' + candidateId);
            throw new AuraHandledException('Candidate not found.');
        }

        Candidate__c candidateToUpdate = candidates[0];
        candidateToUpdate.Name = firstName + ' ' + lastName;
        candidateToUpdate.Email__c = email;
        candidateToUpdate.Phone__c = phone;
        candidateToUpdate.Location__c = location;

        if (String.isNotBlank(yearsExperience)) {
            try {
                candidateToUpdate.Years_of_Experience__c = Decimal.valueOf(yearsExperience);
            } catch (Exception e) {
                System.debug('Could not parse yearsExperience: ' + yearsExperience);
            }
        }

        ResumeWebhookService.ResumePayload payload = ResumeWebhookService.callWebhookAndParse();
        candidateToUpdate.Raw_Resume_Payload__c = JSON.serialize(payload);

        Set<String> allSkills = new Set<String>();
        String existingSkillsString = candidateToUpdate.Skills__c;
        if (String.isNotBlank(existingSkillsString)) {
            for(String skill : existingSkillsString.split('\\s*,\\s*')) {
                if(String.isNotBlank(skill)) {
                    allSkills.add(skill.trim());
                }
            }
        }

        if (String.isNotBlank(skills)) {
            for(String skill : skills.split('\\s*,\\s*')) {
                if(String.isNotBlank(skill)) {
                    allSkills.add(skill.trim());
                }
            }
        }

        List<String> sortedSkills = new List<String>(allSkills);
        sortedSkills.sort();
        candidateToUpdate.Skills__c = String.join(sortedSkills, ', ');
        
        try {
            update candidateToUpdate;
            Onb_ActivationAuditWriter.write('RESUME_DATA_PERSISTED', 'Verified resume data and skills were updated.', candidateId);
        } catch (Exception ex) {
            System.debug('DML Exception in persistVerifiedData: ' + ex.getMessage() + ' at line ' + ex.getLineNumber());
            Onb_ErrorLogService.logError('OnboardingOrchestrator.persistVerifiedData', ex);
            throw new AuraHandledException('Failed to save candidate data: ' + ex.getMessage());
        }
    }
    
 

    /**
     * @description Fetches available jobs, now without filtering by skills.
     * @param category The general category of jobs (e.g., 'Medical') - This is now ignored.
     * @param specializations A list of specific job roles - This is now ignored.
     * @return A list of the 5 most recent Job_Posting__c records.
     */
    // @AuraEnabled(cacheable=true)
    // public static List<Job_Posting__c> getAvailableJobs(String category, List<String> specializations) {
    //     System.debug('--- getAvailableJobs method started (Unfiltered Version) ---');
    //     System.debug('Received category (ignored): ' + category);
    //     System.debug('Received specializations (ignored): ' + JSON.serialize(specializations));
        
    //     try {
    //         // This query now IGNORES the filters and fetches the 5 most recent jobs to ensure results are always shown.
    //         List<Job_Posting__c> jobsFound = [
    //             SELECT Id, Name, Description__c, Location__c
    //             FROM Job_Posting__c
    //             WITH SECURITY_ENFORCED
    //             ORDER BY CreatedDate DESC
    //             LIMIT 5
    //         ];

    //         System.debug('Query executed. Found ' + jobsFound.size() + ' jobs.');
    //         return jobsFound;
            
    //     } catch (Exception e) {
    //         System.debug('Error fetching job postings: ' + e.getMessage());
    //         throw new AuraHandledException('An error occurred while fetching jobs.');
    //     }
    // }


/**
 * @description Fetches the 5 most recent job postings, regardless of their status.
 * @return A list of the 5 most recent Job_Posting__c records.
 */
@AuraEnabled(cacheable=true)
public static List<Job_Posting__c> getAvailableJobs() {
    System.debug('--- getAvailableJobs method started (Unfiltered by Status) ---');
    try {
        List<Job_Posting__c> jobsFound = [
            SELECT Id, Name, Description__c, Location__c, Specialization__c // CRITICAL: This field MUST be included
            FROM Job_Posting__c
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];
        System.debug('Query executed. Found ' + jobsFound.size() + ' jobs.');
        return jobsFound;
    } catch (Exception e) {
        System.debug('Error fetching job postings: ' + e.getMessage());
        throw new AuraHandledException('An error occurred while fetching jobs.');
    }
}


    @AuraEnabled
    public static void recordJobInterestOnCandidate(Id candidateId, Id jobPostingId) {
        // Validate inputs
        if (candidateId == null || jobPostingId == null) {
            throw new AuraHandledException('Candidate ID and Job Posting ID are required to record interest.');
        }

        try {
            // Only update the lookup field
            Candidate__c candidateToUpdate = new Candidate__c(
                Id = candidateId,
                Interested_In_Job__c = jobPostingId
            );
            update candidateToUpdate;
        } catch (Exception e) {
            System.debug('Error updating Candidate with job interest: ' + e.getMessage());
            throw new AuraHandledException('Failed to record job interest: ' + e.getMessage());
        }
    }
   
/**
 * @description Fetches screening questions for a given specialization, ordered by the 'Order__c' field.
 * @param specialization The specialization of the selected job (e.g., 'Dermatology').
 * @return A list of Screening_Question__c records.
 */
// In OnboardingOrchestrator.cls

@AuraEnabled(cacheable=true)
public static List<Screening_Question__c> getScreeningQuestions(String specialization) {
    // Return immediately if the specialization is blank
    if (String.isBlank(specialization)) {
        return new List<Screening_Question__c>();
    }

    try {
        // This is the correct SOQL syntax.
        // It will find matches if the data is clean (no extra spaces, correct spelling).
        return [
            SELECT Id, Question_Text__c, Order__c
            FROM Screening_Question__c
            WHERE Specialization__c = :specialization
            ORDER BY Order__c ASC
        ];
    } catch (Exception e) {
        System.debug('Error fetching screening questions: ' + e.getMessage());
        throw new AuraHandledException('An error occurred while fetching questions.');
    }
}


/**
 * @description Saves a candidate's answer to a specific screening question.
 * @param candidateId The ID of the Candidate__c record.
 * @param questionId The ID of the Screening_Question__c record being answered.
 * @param answerText The text of the candidate's answer.
 * @return The ID of the newly created Candidate_Answer__c record.
 */
@AuraEnabled
public static Id saveCandidateAnswer(Id candidateId, Id questionId, String answerText) {
    try {
        Candidate_Answer__c newAnswer = new Candidate_Answer__c(
            Candidate__c = candidateId,
            Screening_Question__c = questionId,
            Answer_Text__c = answerText
        );
        insert newAnswer;
        return newAnswer.Id;
    } catch (Exception e) {
        // In a real application, log this error more formally
        System.debug('Error saving candidate answer: ' + e.getMessage());
        throw new AuraHandledException('Could not save the answer. Please try again.');
    }
}

}
