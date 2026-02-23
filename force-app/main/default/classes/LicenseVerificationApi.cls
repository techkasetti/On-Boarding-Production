@RestResource(urlMapping='/license-verification')
global with sharing class LicenseVerificationApi {
    global class LicenseVerificationRequest {
        public String candidateId;
        public String licenseNumber;
        public String licenseType;
        public String issuingAuthority;
        public String issueDate;
        public String expirationDate;
        public String status;
        public String certificateUrl;
        public String providerId; // New field for Provider reference           
        public String nameOnLicense;
    }

    global class LicenseVerificationResponse {
        public Boolean success;
        public String message;
        public String errorCode;
        public Id licenseVerificationId;
    }

    @HttpPost
    global static void createLicenseVerification() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        res.addHeader('Content-Type', 'application/json');

        LicenseVerificationResponse responseBody = new LicenseVerificationResponse();
        responseBody.success = false;

        String rawBody = req.requestBody == null ? null : req.requestBody.toString();

        if (String.isBlank(rawBody)) {
            res.statusCode = 400;
            responseBody.message = 'Request body is required.';
            responseBody.errorCode = 'MISSING_BODY';
            res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
            return;
        }

        LicenseVerificationRequest payload;

        try {
            payload = (LicenseVerificationRequest) JSON.deserialize(rawBody, LicenseVerificationRequest.class);
        } catch (Exception ex) {
            res.statusCode = 400;
            responseBody.message = 'Invalid JSON payload.';
            responseBody.errorCode = 'INVALID_JSON';
            res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
            return;
        }

        List<String> missingFields = new List<String>();

        if (String.isBlank(payload.candidateId)) {
            missingFields.add('candidateId');
        }

        if (String.isBlank(payload.licenseNumber)) {
            missingFields.add('licenseNumber');
        }

        if (String.isBlank(payload.issuingAuthority)) {
            missingFields.add('issuingAuthority');
        }

        if (String.isBlank(payload.issueDate)) {
            missingFields.add('issueDate');
        }

        if (String.isBlank(payload.expirationDate)) {
            missingFields.add('expirationDate');
        }

        if (String.isBlank(payload.status)) {
            missingFields.add('status');
        }
       
            if (String.isBlank(payload.providerId)) {
                missingFields.add('providerId');
            }       
            if (String.isBlank(payload.nameOnLicense)) {
                missingFields.add('nameOnLicense');
            }

        if (!missingFields.isEmpty()) {
            res.statusCode = 400;
            responseBody.message = 'Missing required fields: ' + String.join(missingFields, ', ');
            responseBody.errorCode = 'MISSING_REQUIRED_FIELDS';
            res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
            return;
        }

        Date issueDateValue;

        try {
            issueDateValue = Date.valueOf(payload.issueDate);
        } catch (Exception ex) {
            res.statusCode = 400;
            responseBody.message = 'Invalid issueDate format. Expected yyyy-MM-dd.';
            responseBody.errorCode = 'INVALID_ISSUE_DATE';
            res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
            return;
        }

        Date expirationDateValue;

        try {
            expirationDateValue = Date.valueOf(payload.expirationDate);
        } catch (Exception ex) {
            res.statusCode = 400;
            responseBody.message = 'Invalid expirationDate format. Expected yyyy-MM-dd.';
            responseBody.errorCode = 'INVALID_EXPIRATION_DATE';
            res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
            return;
        }

if (expirationDateValue < Date.today()) {

    try {
      Candidate__c candidate = [
    SELECT Id, Contact__c,
           Contact__r.Name,
           Contact__r.Email
    FROM Candidate__c
    WHERE Id = :payload.candidateId
    LIMIT 1
];

        if (candidate != null && candidate.Contact__r != null && String.isNotBlank(candidate.Contact__r.Email)) {

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { candidate.Contact__r.Email });
            mail.setSubject('Action Required: Expired Medical License');

            String body = 'Dear ' + candidate.Contact__r.Name + ',\n\n'
                + 'Our records indicate that the medical license you submitted '
                + '(License Number: ' + payload.licenseNumber + ') '
                + 'expired on ' + expirationDateValue.format() + '.\n\n'
                + 'Please upload a valid and renewed license certificate '
                + 'to continue your verification process.\n\n'
                + 'If you believe this is incorrect, please contact the compliance team.\n\n'
                + 'Regards,\nCompliance Department';

            mail.setPlainTextBody(body);
            mail.setSaveAsActivity(false);

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }

    } catch (Exception emailEx) {
        System.debug('Failed to send expiration email: ' + emailEx.getMessage());
    }
}else{
    System.debug('License is not expired');

        LicenseVerification__c licenseRecord = new LicenseVerification__c();

        licenseRecord.Candidate__c = payload.candidateId;
        licenseRecord.LicenseNumber__c = payload.licenseNumber;
        //licenseRecord.License_Type__c = payload.licenseType;
        licenseRecord.IssuingAuthority__c = payload.issuingAuthority;
       // licenseRecord.Issue_Date__c = issueDateValue;
        licenseRecord.ExpirationDate__c = expirationDateValue;
        licenseRecord.Status__c = payload.status;
       // licenseRecord.Certificate_URL__c = payload.certificateUrl;
        licenseRecord.Provider__c = payload.providerId;
        licenseRecord.Name_On_License__c = payload.nameOnLicense; 
        
        

        try {
            insert licenseRecord;
        } catch (DmlException dmlEx) {
            res.statusCode = 400;
            responseBody.message = 'Failed to insert LicenseVerification__c record: ' + dmlEx.getDmlMessage(0);
            responseBody.errorCode = 'DML_ERROR';
            res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
            return;
        } catch (Exception ex) {
            res.statusCode = 500;
            responseBody.message = 'Unexpected error while processing request: ' + ex.getMessage();
            responseBody.errorCode = 'UNEXPECTED_ERROR';
            res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
            return;
        }

        res.statusCode = 201;
        responseBody.success = true;
        responseBody.message = 'LicenseVerification__c record created successfully.';
        responseBody.errorCode = null;
        responseBody.licenseVerificationId = licenseRecord.Id;

        res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
}
    }
}