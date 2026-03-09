public with sharing class DocflowDashboardController {

    public class DashboardData {
        @AuraEnabled public List<DocumentLifecycleConfiguration__c> documents   { get; set; }
        // @AuraEnabled public List<Candidate__c> documents   { get; set; }
        @AuraEnabled public List<Signature_Request__c>              sigRequests { get; set; }
        @AuraEnabled public List<Audit_Trail__c>                    auditTrails { get; set; }
    }

    @AuraEnabled(cacheable=false)
    public static DashboardData getDashboardData() {
        DashboardData result = new DashboardData();
         result.documents    = new List<DocumentLifecycleConfiguration__c>();
        // result.documents    = new List<Candidate__c>();
        result.sigRequests  = new List<Signature_Request__c>();
        result.auditTrails  = new List<Audit_Trail__c>();

        try {
            result.documents = [
                SELECT Id, Name, Status__c, CreatedDate,
                       Employee_Name__c, Company_Name__c,
                       Contract_Type__c, ContractType__c,
                       Region__c, Role__c,
                       Effective_Date__c, Expiry_Date__c,
                       ContentDocumentString__c,
                       AI_Model_Used__c
                FROM DocumentLifecycleConfiguration__c
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
              
        } catch (Exception e) {
            System.debug('DocflowDashboard - documents query failed: ' + e.getMessage());
        }

        try {
            result.sigRequests = [
                SELECT Id, Status__c, SignerName__c, SignerEmail__c,
                       SignatureMethod__c,
                       CompletedDate__c, CreatedDate,
                       Fraud_Risk_Level__c, Fraud_Score__c,
                       Document_Lifecycle_Configuration__c
                FROM Signature_Request__c
                ORDER BY CreatedDate DESC
                LIMIT 500
            ];
        } catch (Exception e) {
            System.debug('DocflowDashboard - sigRequests query failed: ' + e.getMessage());
        }

        try {
            result.auditTrails = [
                SELECT Id, Action__c, Details__c, CreatedDate
                FROM Audit_Trail__c
                ORDER BY CreatedDate DESC
                LIMIT 20
            ];
        } catch (Exception e) {
            System.debug('DocflowDashboard - auditTrails query failed: ' + e.getMessage());
        }

        return result;
    }

      @AuraEnabled(cacheable=true)
    public static List<Candidate__c> getClearedCandidates() {
            // public static List<Job_Application__c> getClearedCandidates() {


        return [
            SELECT Id, Name, Status__c
            FROM Candidate__c
            WHERE Id IN (
                SELECT Candidate__c
                FROM Job_Application__c
                WHERE Status__c = 'Background Check Cleared'
                AND Candidate__c != null
            )
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];
                // return    [ SELECT 
                // Id, 
                // Name, 
                // Status__c, 
                // Candidate__r.Name, 
                // Candidate__r.Status__c 
                // FROM Job_Application__c 
                // WHERE Status__c = 'Background Check Cleared' 
                // AND Candidate__c != null
                // ORDER BY CreatedDate DESC 
                // LIMIT 500];
            }
}