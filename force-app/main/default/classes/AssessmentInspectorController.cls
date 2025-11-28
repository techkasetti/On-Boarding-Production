public with sharing class AssessmentInspectorController {
    @AuraEnabled(cacheable=true)
    public static Onboarding_Run__c fetchAssessment(Id id){
        if (id == null || !Schema.getGlobalDescribe().containsKey('Onboarding_Run__c')) return null;
        return [SELECT Id, RawInput__c, TriggeredRules__c, Jurisdiction__c, ScoreJSON__c FROM Onboarding_Run__c WHERE Id = :id LIMIT 1];
    }
}
