
trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {
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
