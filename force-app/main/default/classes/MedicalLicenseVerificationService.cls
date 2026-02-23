public with sharing class MedicalLicenseVerificationService {

    // Inner class to structure the API request body
    private class RequestWrapper {
        String licenseNumber;
        String providerFirstName;
        String providerLastName;
        String issuingState;

        RequestWrapper(Contact provider, LicenseVerification__c license) {
            this.licenseNumber = license.LicenseNumber__c;
            this.providerFirstName = provider.FirstName;
            this.providerLastName = provider.LastName;
            this.issuingState = license.IssuingAuthority__c; // Assuming IssuingAuthority is a state code
        }
    }

    // Inner class to parse the API response
    public class ResponseWrapper {
        public String status; // e.g., "Valid", "Expired", "Suspended"
        public String licenseNumber;
        public Date expirationDate;
        public String error;
    }

    @AuraEnabled(cacheable=false)
    public static void verifyLicense(Id licenseVerificationId) {
        LicenseVerification__c licenseToVerify;
        try {
            licenseToVerify = [
                SELECT Id, Name, Provider__c, Provider__r.FirstName, Provider__r.LastName, LicenseNumber__c, IssuingAuthority__c
                FROM LicenseVerification__c
                WHERE Id = :licenseVerificationId
                LIMIT 1
            ];
        } catch (Exception e) {
            // If the record doesn't exist, we can't proceed.
            System.debug('Could not find LicenseVerification record with ID: ' + licenseVerificationId);
            return;
        }

        HttpRequest req = new HttpRequest();
        // The endpoint uses the Named Credential URL + any specific path
        // req.setEndpoint('callout:Medical_License_API/v1/verify');
        req.setEndpoint('https://webhook.site/b01a7fd3-2b87-4b04-aa74-0fb529d914e4');
        req.setMethod('POST');
        // Assuming API key is required in a header. Store the key securely in Custom Metadata or Protected Custom Settings.
        // For simplicity here, we are hardcoding it, but DO NOT do this in production.
        req.setHeader('X-API-KEY', 'YOUR_SECRET_API_KEY_HERE'); 
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');

        RequestWrapper requestBody = new RequestWrapper(licenseToVerify.Provider__r, licenseToVerify);
        String serializedBody = JSON.serialize(requestBody);
        req.setBody(serializedBody);

        // Update the request log before sending
        licenseToVerify.ApiRequestLog__c = 'Endpoint: ' + req.getEndpoint() + '\nBody: ' + serializedBody;

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            licenseToVerify.ApiResponseLog__c = 'Status Code: ' + res.getStatusCode() + '\nBody: ' + res.getBody();

            if (res.getStatusCode() == 200) {
                ResponseWrapper responseData = (ResponseWrapper) JSON.deserialize(res.getBody(), ResponseWrapper.class);

                // Map response status to our picklist values
                if (responseData.status == 'Valid') {
                    licenseToVerify.Status__c = 'Valid';
                } else if (responseData.status == 'Expired') {
                    licenseToVerify.Status__c = 'Expired';
                } else if (responseData.status == 'Suspended') {
                    licenseToVerify.Status__c = 'Suspended';
                } else {
                    licenseToVerify.Status__c = 'Not Found';
                }
                
                if (responseData.expirationDate != null) {
                    licenseToVerify.ExpirationDate__c = responseData.expirationDate;
                }

            } else {
                // If the API call fails (e.g., 4xx or 5xx error)
                licenseToVerify.Status__c = 'Requires Manual Review';
            }

        } catch (Exception e) {
            licenseToVerify.Status__c = 'Requires Manual Review';
            licenseToVerify.ApiResponseLog__c = 'Callout failed: ' + e.getMessage() + '\n' + e.getStackTraceString();
            System.debug('MedicalLicenseVerificationService Error: ' + e.getMessage());
        }

        update licenseToVerify;

        // Trigger AI Name Validation (Async)
try {
    LicenseNameAIService.runForLicenseVerifications(
        new Set<Id>{ licenseToVerify.Id }
    );
} catch (Exception ex) {
    System.debug('Failed to trigger AI Name Validation: ' + ex.getMessage());
}
    }
}