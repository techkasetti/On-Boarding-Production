public with sharing class CandidateTriggerHandler {
    /**
     * @description Handles logic after a Candidate__c record is updated.
     * It compares old and new field values and creates history records for any changes.
     * @param newCandidates The list of candidates from Trigger.new.
     * @param oldCandidateMap The map of old candidate versions from Trigger.oldMap.
     */
    public static void handleAfterUpdate(List<Candidate__c> newCandidates, Map<Id, Candidate__c> oldCandidateMap) {
        List<Candidate_History__c> historiesToCreate = new List<Candidate_History__c>();
        Id currentUser = UserInfo.getUserId();

        // Get a map of all fields for the Candidate__c object
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Candidate__c.fields.getMap();

        for (Candidate__c newCand : newCandidates) {
            Candidate__c oldCand = oldCandidateMap.get(newCand.Id);

            // Iterate over every field to check for changes
            for (String fieldName : fieldMap.keySet()) {
                Object oldValue = oldCand.get(fieldName);
                Object newValue = newCand.get(fieldName);

                // Compare old and new values. If they are different, create a history record.
                if (oldValue != newValue) {
                    historiesToCreate.add(new Candidate_History__c(
                        Candidate__c = newCand.Id,
                        Changed_By__c = currentUser,
                        Changed_Field__c = fieldMap.get(fieldName).getDescribe().getLabel(), // Store the user-friendly label
                        Previous_Value__c = String.valueOf(oldValue),
                        New_Value__c = String.valueOf(newValue)
                    ));
                }
            }
        }

        if (!historiesToCreate.isEmpty()) {
            insert historiesToCreate;
        }
    }
}
