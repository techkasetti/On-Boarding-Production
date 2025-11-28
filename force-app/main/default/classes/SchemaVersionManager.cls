public with sharing class SchemaVersionManager {
    @AuraEnabled(cacheable=true)
    public static List<DynScr_SchemaVersion__mdt> getVersions(){
        if (!Schema.getGlobalDescribe().containsKey('DynScr_SchemaVersion__mdt')) return new List<DynScr_SchemaVersion__mdt>();
        return [SELECT Id, Version__c, AppliedAt__c FROM DynScr_SchemaVersion__mdt ORDER BY Version__c DESC];
    }

    @AuraEnabled
    public static Boolean activateVersion(String version){
        // Implementation: write an ActivationAudit__c row and flip a CustomSetting flag or CustomMetadata that indicates active schema.
        if (String.isBlank(version)) return false;
        if (!Schema.getGlobalDescribe().containsKey('ActivationAudit__c')) return false;
        ActivationAudit__c aa = new ActivationAudit__c(Action__c='SCHEMA_ACTIVATE', Notes__c='Version:'+version, Created_At__c=Datetime.now());
        insert aa;
        // Optionally update a CustomSetting / CustomMetadata - left as a no-op here for safety
        return true;
    }
}
