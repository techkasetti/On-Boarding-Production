public with sharing class CandidateTriggerHandler1 {
    // public static void handleAfterUpdate(List<Candidate__c> newCandidates, Map<Id, Candidate__c> oldMap) {
    //     Set<Id> candidateIdsToEvaluate = new Set<Id>();
    //     for (Candidate__c newCand : newCandidates) {
    //         Id oldJobId = (oldMap == null) ? null : oldMap.get(newCand.Id).Interested_In_Job__c;
    //         if (newCand.Interested_In_Job__c != null && newCand.Interested_In_Job__c != oldJobId) {
    //             candidateIdsToEvaluate.add(newCand.Id);
    //         }
    //     }
        
    //     if (!candidateIdsToEvaluate.isEmpty()) {
    //         System.enqueueJob(new ScreeningQueueable(new List<Id>(candidateIdsToEvaluate)));
    //     }
    // }
}
