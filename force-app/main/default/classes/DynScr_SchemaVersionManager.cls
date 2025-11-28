public with sharing class DynScr_SchemaVersionManager {

    @AuraEnabled(cacheable=true)
    public static List<DynScr_SchemaVersion__mdt> getVersions() {
        return [
            SELECT Version__c, AppliedAt__c
            FROM DynScr_SchemaVersion__mdt
            ORDER BY Version__c DESC
        ];
    }
}
