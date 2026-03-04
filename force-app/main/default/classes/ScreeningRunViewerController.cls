public with sharing class ScreeningRunViewerController {
    @AuraEnabled(cacheable=true)
    public static List<Onboarding_Run__c> fetchRecentRuns(){
        if (!Schema.getGlobalDescribe().containsKey('Onboarding_Run__c')) return new List<Onboarding_Run__c>();
        return [SELECT Id, Name, Status__c, Jurisdiction__c, TriggeredRules__c, ScoreJSON__c, CreatedDate FROM Onboarding_Run__c ORDER BY CreatedDate DESC LIMIT 25];
    }

    @AuraEnabled
    public static Onboarding_Run__c fetchRunById(Id id){
        if (id == null || !Schema.getGlobalDescribe().containsKey('Onboarding_Run__c')) return null;
        return [SELECT Id, Name, Status__c, Jurisdiction__c, TriggeredRules__c, ScoreJSON__c FROM Onboarding_Run__c WHERE Id = :id LIMIT 1];
    }
}