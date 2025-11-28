public with sharing class MultiStepOnboardingController {
    /**
     * @description Wrapper class for returning a structured document status to the LWC.
     */
    public class DocumentWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String DocumentName;
        @AuraEnabled public String status;
        @AuraEnabled public String rejectionReason;

        public DocumentWrapper(Document_Verification__c dv, String docTitle) {
            this.Id = dv.Id;
            this.DocumentName = docTitle;
            this.status = dv.Status__c;
            this.rejectionReason = dv.Rejection_Reason__c;
        }
    }

    /**
     * @description Finds an existing candidate by their email address to pre-populate the form.
     * @param email The candidate's email address.
     * @return A Candidate__c record if found, otherwise null.
     */
    @AuraEnabled(cacheable=true)
    public static Candidate__c findCandidateByEmail(String email) {
        if (String.isBlank(email)) {
            return null;
        }
        
        List<Candidate__c> candidates = [
            SELECT Id, FirstName__c, LastName__c, Phone__c, Street_Address__c, 
                   City__c, State__c, Zip_Code__c, Emergency_Contact_Name__c, 
                   Emergency_Contact_Phone__c
            FROM Candidate__c
            WHERE Email__c = :email
            LIMIT 1
        ];
        return candidates.isEmpty() ? null : candidates[0];
    }

    /**
     * @description Processes the intake form (from chat or web form), creating/updating the Candidate,
     * Conversation, and Onboarding Run records in a single transaction.
     * @param payload A map of string keys to object values containing all candidate data.
     * @return The ID of the created or updated Candidate__c record.
     */
    @AuraEnabled(cacheable=false)
    public static Id processCandidateDetails(Map<String, Object> payload) {
        if (payload == null || String.isBlank((String) payload.get('email'))) {
            throw new AuraHandledException('Payload and email address cannot be null.');
        }

        try {
            Candidate__c candidateToProcess = new Candidate__c(
                FirstName__c = (String) payload.get('firstName'),
                LastName__c = (String) payload.get('lastName'),
                Email__c = (String) payload.get('email'),
                Phone__c = (String) payload.get('phone'),
                Status__c = 'Intake Complete',
                Street_Address__c = (String) payload.get('streetAddress'),
                City__c = (String) payload.get('city'),
                State__c = (String) payload.get('state'),
                Zip_Code__c = (String) payload.get('zipCode'),
                Emergency_Contact_Name__c = (String) payload.get('emergencyContactName'),
                Emergency_Contact_Phone__c = (String) payload.get('emergencyContactPhone')
            );
            
            upsert candidateToProcess Email__c;
            Id candidateId = candidateToProcess.Id;

            Conversation__c conversation = new Conversation__c(
                Candidate__c = candidateId,
                Transcript__c = (String) payload.get('transcript')
            );
            insert conversation;

            Onboarding_Run__c onboardingRun = new Onboarding_Run__c(
                Candidate__c = candidateId,
                Status__c = 'Not Started'
            );
            insert onboardingRun;

            return candidateId;
        } catch (Exception e) {
            throw new AuraHandledException('Server error processing candidate details: ' + e.getMessage());
        }
    }

    /**
     * @description Creates a Document_Verification__c record, links the uploaded file,
     * and enqueues the asynchronous OCR job.
     */
    @AuraEnabled(cacheable=false)
    public static void initiateDocumentProcessing(Id candidateId, Id contentDocumentId) {
        if (candidateId == null || contentDocumentId == null) {
            throw new AuraHandledException('Candidate ID and Document ID are required.');
        }

        try {
            Document_Verification__c docVerification = new Document_Verification__c(
                Candidate__c = candidateId,
                Status__c = 'Pending OCR'
            );
            insert docVerification;

            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = docVerification.Id,
                ShareType = 'V'
            );
            insert cdl;

            System.enqueueJob(new DocumentOCRQueueable(docVerification.Id));
        } catch (Exception e) {
            throw new AuraHandledException('Failed to initiate document processing: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves the status of all documents associated with a candidate.
     */
    @AuraEnabled(cacheable=true)
    public static List<DocumentWrapper> getDocumentsForCandidate(Id candidateId) {
        if (candidateId == null) {
            return new List<DocumentWrapper>();
        }
        
        List<DocumentWrapper> wrappers = new List<DocumentWrapper>();
        for (Document_Verification__c dv : [
            SELECT Id, Status__c, Rejection_Reason__c, 
                   (SELECT ContentDocument.Title FROM ContentDocumentLinks ORDER BY SystemModstamp DESC LIMIT 1)
            FROM Document_Verification__c
            WHERE Candidate__c = :candidateId
            ORDER BY CreatedDate DESC
        ]) {
            String docTitle = 'Document Title Not Found';
            if (!dv.ContentDocumentLinks.isEmpty()) {
                docTitle = dv.ContentDocumentLinks[0].ContentDocument.Title;
            }
            wrappers.add(new DocumentWrapper(dv, docTitle));
        }
        return wrappers;
    }

    /**
     * @description Handles the re-upload of a rejected document.
     */
    @AuraEnabled(cacheable=false)
    public static void processReUpload(Id verificationId, Id newContentDocumentId) {
        if (verificationId == null || newContentDocumentId == null) {
            throw new AuraHandledException('Verification ID and new Content Document ID are required.');
        }

        try {
            Document_Verification__c originalVerification = [SELECT Candidate__c FROM Document_Verification__c WHERE Id = :verificationId];
            
            Document_Verification__c newVerification = new Document_Verification__c(
                Candidate__c = originalVerification.Candidate__c,
                Status__c = 'Pending OCR'
            );
            insert newVerification;

            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = newContentDocumentId,
                LinkedEntityId = newVerification.Id,
                ShareType = 'V'
            );
            insert cdl;

            System.enqueueJob(new DocumentOCRQueueable(newVerification.Id));
        } catch (Exception e) {
            throw new AuraHandledException('Failed to process re-upload: ' + e.getMessage());
        }
    }

    /**
     * @description Gets the next chat response from the orchestration service.
     */
    @AuraEnabled(cacheable=false)
    public static OnboardingOrchestrationService.ChatResponse getNextChatResponse(String currentStepKey, String userResponse, Map<String, Object> collectedData) {
        if (currentStepKey == 'getEmail') {
            Candidate__c existingCandidate = findCandidateByEmail(userResponse);
            if (existingCandidate != null) {
                return new OnboardingOrchestrationService.ChatResponse(
                    'An account with this email already exists. Please use the "Switch to Form" button to review your information.',
                    'start'
                );
            } else {
                collectedData.put('email', userResponse);
                return OnboardingOrchestrationService.getNextStep('getEmail_success', userResponse, collectedData);
            }
        }
        return OnboardingOrchestrationService.getNextStep(currentStepKey, userResponse, collectedData);
    }
}
