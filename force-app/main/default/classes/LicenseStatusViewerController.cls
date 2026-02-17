public with sharing class LicenseStatusViewerController {

    public class LicenseRow {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String providerName { get; set; }
        @AuraEnabled public String licenseNumber { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Date expirationDate { get; set; }
        @AuraEnabled public Date lastVerifiedDate { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<LicenseRow> getLicenseVerifications(String statusFilter, Date expiringBefore) {
        List<LicenseVerification__c> records = [
            SELECT Id,
                   Name,
                   Provider__c,
                   Provider__r.Name,
                   LicenseNumber__c,
                  // State__c,
                   Status__c,
                   ExpirationDate__c
                //    LastVerifiedDate__c
            FROM LicenseVerification__c
            WHERE Status__c != null
            ORDER BY ExpirationDate__c ASC
            LIMIT 200
        ];

        Date maxExpiration = expiringBefore;
        List<LicenseRow> results = new List<LicenseRow>();

        for (LicenseVerification__c lv : records) {
            // Filter by status if provided
            if (statusFilter != null && statusFilter.trim().length() > 0) {
                if (lv.Status__c == null | lv.Status__c != statusFilter) {
                    continue;
                }
            }

            // Filter by expiration date if provided
            if (maxExpiration != null && lv.ExpirationDate__c != null) {
                if (lv.ExpirationDate__c > maxExpiration) {
                    continue;
                }
            }

            LicenseRow row = new LicenseRow();
            row.id = lv.Id;
            row.providerName = (lv.Provider__r != null ? lv.Provider__r.Name : null);
            row.licenseNumber = lv.LicenseNumber__c;
          //  row.state = lv.State__c;
            row.status = lv.Status__c;
            row.expirationDate = lv.ExpirationDate__c;
            // row.lastVerifiedDate = lv.LastVerifiedDate__c;

            results.add(row);
        }

        return results;
    }
}