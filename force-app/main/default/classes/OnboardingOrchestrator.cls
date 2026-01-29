public with sharing class OnboardingOrchestrator {
   

    /**
     * @description Registers a new candidate, explicitly setting Resume_Status__c to false.
     * @param fullName The full name of the candidate.
     * @param phone The phone number of the candidate.
     * @param email The email address of the candidate.
     * @return The ID of the newly created Candidate__c record.
     */
    @AuraEnabled
    public static Id registerCandidate(String fullName, String phone, String email) {
        // Instantiate the candidate record
        Candidate__c newCandidate = new Candidate__c(
            Name = fullName,
            Phone__c = phone,
            Email__c = email,
            Resume_Status__c = false // <-- NEW: Explicitly set status to false on creation
        );

        try {
            insert newCandidate;
            return newCandidate.Id;
        } catch (Exception e) {
            Onb_ErrorLogService.logError('OnboardingOrchestrator.registerCandidate', 'Failed to create candidate', e);
            throw new AuraHandledException('There was an error creating your profile: ' + e.getMessage());
        }
    }

 

//    @AuraEnabled(cacheable = false)
//     public static ResumeWebhookService.ResumePayload fetchResumePreview(Id candidateId) {
//         try {
//             // 1) Callout first (NO DML before callout)
//             ResumeWebhookService.ResumePayload payload = ResumeWebhookService.callWebhookAndParse();

//             // 2) Best-effort audit AFTER callout
//             try {
//                 Onb_ActivationAuditWriter.write(
//                     'RESUME_PREVIEW_REQUESTED', 'Preview requested from UI', candidateId
//                 );
//             } catch (Exception logEx) {
//                 Onb_ErrorLogService.logError(
//                     'OnboardingOrchestrator.fetchResumePreview.audit', logEx
//                 );
//             }
//             return payload;
//         } catch (ResumeWebhookService.CalloutException ex) {
//             Onb_ErrorLogService.logError(
//                 'OnboardingOrchestrator.fetchResumePreview', ex
//             );
//             throw new AuraHandledException(ex.getMessage());
//         } catch (Exception ex) {
//             Onb_ErrorLogService.logError(
//                 'OnboardingOrchestrator.fetchResumePreview', ex
//             );
//             throw new AuraHandledException(ex.getMessage());
//         }
//     }


   
//  @AuraEnabled
//     public static void persistVerifiedData(Id candidateId, String firstName, String lastName, String location, String email, String phone, String yearsExperience, String skills) {
//         // Your existing, correct logic for merging skills into the Skills__c field
//         // This method does not need to change.
//         System.debug('persistVerifiedData called for candidateId: ' + candidateId);
//         System.debug('New skills to add: ' + skills);

//         List<Candidate__c> candidates = [
//             SELECT Id, Name, Email__c, Phone__c, Location__c, Years_of_Experience__c, Raw_Resume_Payload__c, Skills__c
//             FROM Candidate__c
//             WHERE Id = :candidateId
//             LIMIT 1
//         ];

//         if (candidates.isEmpty()) {
//             System.debug('FATAL: No Candidate__c record found with Id: ' + candidateId);
//             throw new AuraHandledException('Candidate not found.');
//         }

//         Candidate__c candidateToUpdate = candidates[0];
//         candidateToUpdate.Name = firstName + ' ' + lastName;
//         candidateToUpdate.Email__c = email;
//         candidateToUpdate.Phone__c = phone;
//         candidateToUpdate.Location__c = location;

//         if (String.isNotBlank(yearsExperience)) {
//             try {
//                 candidateToUpdate.Years_of_Experience__c = Decimal.valueOf(yearsExperience);
//             } catch (Exception e) {
//                 System.debug('Could not parse yearsExperience: ' + yearsExperience);
//             }
//         }

//         ResumeWebhookService.ResumePayload payload = ResumeWebhookService.callWebhookAndParse();
//         candidateToUpdate.Raw_Resume_Payload__c = JSON.serialize(payload);

//         Set<String> allSkills = new Set<String>();
//         String existingSkillsString = candidateToUpdate.Skills__c;
//         if (String.isNotBlank(existingSkillsString)) {
//             for(String skill : existingSkillsString.split('\\s*,\\s*')) {
//                 if(String.isNotBlank(skill)) {
//                     allSkills.add(skill.trim());
//                 }
//             }
//         }

//         if (String.isNotBlank(skills)) {
//             for(String skill : skills.split('\\s*,\\s*')) {
//                 if(String.isNotBlank(skill)) {
//                     allSkills.add(skill.trim());
//                 }
//             }
//         }

//         List<String> sortedSkills = new List<String>(allSkills);
//         sortedSkills.sort();
//         candidateToUpdate.Skills__c = String.join(sortedSkills, ', ');
        
//         try {
//             update candidateToUpdate;
//             Onb_ActivationAuditWriter.write('RESUME_DATA_PERSISTED', 'Verified resume data and skills were updated.', candidateId);
//         } catch (Exception ex) {
//             System.debug('DML Exception in persistVerifiedData: ' + ex.getMessage() + ' at line ' + ex.getLineNumber());
//             Onb_ErrorLogService.logError('OnboardingOrchestrator.persistVerifiedData', ex);
//             throw new AuraHandledException('Failed to save candidate data: ' + ex.getMessage());
//         }
//     }
    
    
   

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
