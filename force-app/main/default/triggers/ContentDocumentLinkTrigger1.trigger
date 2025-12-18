// force-app/main/default/triggers/ContentDocumentLinkTrigger.trigger
trigger ContentDocumentLinkTrigger1 on ContentDocumentLink (after insert) {
    // Set<Id> candidateIds = new Set<Id>();
    // for (ContentDocumentLink cdl : Trigger.new) {
    //     if (String.valueOf(cdl.LinkedEntityId.getSObjectType()) == 'Candidate__c') {
    //         candidateIds.add(cdl.LinkedEntityId);
    //     }
    // }

    // if (!candidateIds.isEmpty()) {
    //     List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();
    //     for (Id candId : candidateIds) {
    //         candidatesToUpdate.add(new Candidate__c(
    //             Id = candId,
    //             ResumeParsedStatus__c = 'Parsing In Progress'
    //         ));
    //     }
    //     update candidatesToUpdate;
    // }
}