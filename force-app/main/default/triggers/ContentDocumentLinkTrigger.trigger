    trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    
        Map<Id, Id> contentVersionIdToCandidateId = new Map<Id, Id>();
    
        // 1. Filter for links related to the Candidate__c object
        Set<Id> candidateIds = new Set<Id>();
        Set<Id> contentDocIds = new Set<Id>();
        for (ContentDocumentLink cdl : Trigger.new) {
            // Get the type of object the file is linked to
            String linkedEntityType = String.valueOf(cdl.LinkedEntityId.getSObjectType());
    
            if (linkedEntityType == 'Candidate__c') {
                candidateIds.add(cdl.LinkedEntityId);
                contentDocIds.add(cdl.ContentDocumentId);
            }
        }
    
        if (contentDocIds.isEmpty()) {
            return;
        }
    
        // 2. Get the latest ContentVersion ID for each ContentDocument
        Map<Id, Id> docIdToLatestVersionId = new Map<Id, Id>();
        for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN :contentDocIds AND IsLatest = TRUE]) {
            docIdToLatestVersionId.put(cv.ContentDocumentId, cv.Id);
        }
        
        // 3. Map the ContentVersion ID to the corresponding Candidate ID
        for (ContentDocumentLink cdl : Trigger.new) {
            if(String.valueOf(cdl.LinkedEntityId.getSObjectType()) == 'Candidate__c' && docIdToLatestVersionId.containsKey(cdl.ContentDocumentId)){
                Id latestVersionId = docIdToLatestVersionId.get(cdl.ContentDocumentId);
                contentVersionIdToCandidateId.put(latestVersionId, cdl.LinkedEntityId);
            }
        }
    
        // 4. Call the future method if there's anything to process
        if (!contentVersionIdToCandidateId.isEmpty()) {
            S3Uploader.uploadToS3(contentVersionIdToCandidateId);
        }
    }
    