
/* trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    Set<Id> candidateIdsToUpdate = new Set<Id>();

    // 1. Collect the IDs of all Candidates who just had a file linked to them
    for (ContentDocumentLink cdl : Trigger.new) {
        // Check if the linked record is a Candidate__c object
        if (String.valueOf(cdl.LinkedEntityId.getSObjectType()) == 'Candidate__c') {
            candidateIdsToUpdate.add(cdl.LinkedEntityId);
        }
    }

    // 2. If we have candidates to update, prepare a list for a single DML operation
    if (!candidateIdsToUpdate.isEmpty()) {
        List<Candidate__c> candidates = new List<Candidate__c>();
        for (Id candidateId : candidateIdsToUpdate) {
            candidates.add(new Candidate__c(
                Id = candidateId,
                Resume_Status__c = true // Set the status to true
            ));
        }

        // 3. Perform the update
        try {
            update candidates;
            System.debug('Set Resume_Status__c to true for ' + candidates.size() + ' candidates.');
        } catch (Exception e) {
            System.debug('Error updating Candidate resume status: ' + e.getMessage());
            // In a real application, you would add more robust error logging here.
        }
    }
}
*/
trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
    System.debug('=== ContentDocumentLinkTrigger FIRED ===');
    System.debug('Number of records: ' + Trigger.new.size());
    
    Set<Id> candidateIdsToUpdate = new Set<Id>();

    for (ContentDocumentLink cdl : Trigger.new) {
        System.debug('--- Processing CDL: ' + cdl.Id + ' ---');
        System.debug('LinkedEntityId: ' + cdl.LinkedEntityId);
        System.debug('LinkedEntityId Type: ' + (cdl.LinkedEntityId != null ? String.valueOf(cdl.LinkedEntityId.getSObjectType()) : 'null'));
        
        // Check if the linked record is a Candidate__c object
        if (cdl.LinkedEntityId != null && String.valueOf(cdl.LinkedEntityId.getSObjectType()) == 'Candidate__c') {
            System.debug('✅ This is a Candidate link!');
            candidateIdsToUpdate.add(cdl.LinkedEntityId);
        } else {
            System.debug('❌ NOT a Candidate link (Type: ' + (cdl.LinkedEntityId != null ? String.valueOf(cdl.LinkedEntityId.getSObjectType()) : 'null') + ')');
        }
    }

    System.debug('Candidates to update: ' + candidateIdsToUpdate);
    System.debug('Count: ' + candidateIdsToUpdate.size());

    if (!candidateIdsToUpdate.isEmpty()) {
        List<Candidate__c> candidates = new List<Candidate__c>();
        for (Id candidateId : candidateIdsToUpdate) {
            candidates.add(new Candidate__c(
                Id = candidateId,
                Resume_Status__c = true
            ));
        }

        try {
            update candidates;
            System.debug('✅ Updated ' + candidates.size() + ' candidates - Resume_Status__c = true');
        } catch (Exception e) {
            System.debug('❌ Error updating candidates: ' + e.getMessage());
        }
    } else {
        System.debug('⚠️ No candidates to update!');
    }
    
    System.debug('=== ContentDocumentLinkTrigger COMPLETED ===');
}