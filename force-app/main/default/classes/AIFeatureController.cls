public with sharing class AIFeatureController {

    @AuraEnabled(cacheable=true)
    public static List<AIFeature__c> getFeatures(){
        return [
            SELECT Id,
                   Name__c,
                   Description__c,
                   IsActive__c
            FROM AIFeature__c
            ORDER BY Name__c
        ];
    }

    @AuraEnabled
    public static void toggleFeature(Id featureId, Boolean status){

        AIFeature__c feature = new AIFeature__c(
            Id = featureId,
            IsActive__c = status
        );

        update feature;
    }

    @AuraEnabled
    public static void createFeature(String name, String description){

        AIFeature__c feature = new AIFeature__c(
            Name__c = name,
            Description__c = description,
            IsActive__c = false
        );

        insert feature;
    }
}
