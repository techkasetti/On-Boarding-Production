trigger CandidateTrigger on Candidate__c (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        CandidateTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
