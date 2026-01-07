
// Trigger on Screening_Override__c
trigger ScreeningOverrideTrigger on Screening_Override__c (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        ScreeningOverrideHandler.handleApprovedOverrides(Trigger.new, Trigger.oldMap);
    }
}