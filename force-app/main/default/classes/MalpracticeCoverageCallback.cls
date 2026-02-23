@RestResource(urlMapping='/MalpracticeCoverageCallback/*')
global with sharing class MalpracticeCoverageCallback {

    // Wrapper for incoming JSON from the AI service
    global class MalpracticeCoverageCallbackRequest {
        public String  providerCredentialId;
        public Decimal coverage_per_claim;
        public Decimal coverage_aggregate;
        // NOTE: JSON field must be "coverageCurrency" (not "currency", which is reserved in Apex)
        public String  coverageCurrency;
        public String  policy_number;
        public String  carrier_name;
        public Date    effective_date;
        public Date    expiration_date;
        public Boolean meets_org_requirements;
        public Decimal ai_confidence;
        public String  notes;
    }

    // Wrapper for JSON response back to the AI/integration
    global class MalpracticeCoverageCallbackResponse {
        public String status;
        public String message;
        public String providerCredentialId;
    }

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        MalpracticeCoverageCallbackResponse responseBody = new MalpracticeCoverageCallbackResponse();
        responseBody.status  = 'ERROR';
        responseBody.message = 'Unknown error';

        try {
            // 1) Basic body validation
            String rawBody = (req.requestBody == null) ? null : req.requestBody.toString();
            if (String.isBlank(rawBody)) {
                res.statusCode = 400;
                responseBody.message = 'Request body is required.';
                res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
                return;
            }

            // 2) Deserialize JSON into strongly-typed wrapper
            MalpracticeCoverageCallbackRequest payload;
            try {
                payload = (MalpracticeCoverageCallbackRequest)
                    JSON.deserialize(rawBody, MalpracticeCoverageCallbackRequest.class);
            } catch (Exception e) {
                res.statusCode = 400;
                responseBody.message = 'Invalid JSON payload: ' + e.getMessage();
                res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
                return;
            }

            if (payload == null) {
                res.statusCode = 400;
                responseBody.message = 'Request payload is required.';
                res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
                return;
            }

            // 3) Validate providerCredentialId
            if (String.isBlank(payload.providerCredentialId)) {
                res.statusCode = 400;
                responseBody.message = 'providerCredentialId is required.';
                res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
                return;
            }

            Id providerCredentialId;
            try {
                providerCredentialId = (Id) payload.providerCredentialId;
            } catch (Exception e) {
                res.statusCode = 400;
                responseBody.message = 'providerCredentialId is not a valid Salesforce Id.';
                res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
                return;
            }

            // 4) Load the ProviderCredential__c record
            List<ProviderCredential__c> creds = [
                SELECT Id,
                       Has_Malpractice_Document__c,
                       Malpractice_Coverage_Amount__c,
                       Malpractice_Aggregate_Coverage__c,
                       Malpractice_Coverage_Currency__c,
                       Malpractice_Policy_Number__c,
                       Malpractice_Expiration_Date__c,
                       Malpractice_AI_Confidence__c,
                       Malpractice_AI_Notes__c,
                       Malpractice_Insurance_Verified__c,
                       Requires_Manual_Review__c
                FROM ProviderCredential__c
                WHERE Id = :providerCredentialId
                LIMIT 1
            ];

            if (creds.isEmpty()) {
                res.statusCode = 404;
                responseBody.message =
                    'ProviderCredential__c record not found for Id: ' +
                    String.escapeSingleQuotes(String.valueOf(providerCredentialId));
                responseBody.providerCredentialId = String.valueOf(providerCredentialId);
                res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
                return;
            }

            ProviderCredential__c cred = creds[0];

            // 5) Map AI output onto ProviderCredential__c fields

            // Per-claim coverage → amount field
            if (payload.coverage_per_claim != null) {
                cred.Malpractice_Coverage_Amount__c = payload.coverage_per_claim;
            }

            // Aggregate coverage
            if (payload.coverage_aggregate != null) {
                cred.Malpractice_Aggregate_Coverage__c = payload.coverage_aggregate;
            }

            // Currency (NOTE: expects JSON field "coverageCurrency")
            if (payload.coverageCurrency != null) {
                cred.Malpractice_Coverage_Currency__c = payload.coverageCurrency;
            }

            // Policy number
            if (payload.policy_number != null) {
                cred.Malpractice_Policy_Number__c = payload.policy_number;
            }

            // Expiration date
            if (payload.expiration_date != null) {
                cred.Malpractice_Expiration_Date__c = payload.expiration_date;
            }

            // AI confidence
            if (payload.ai_confidence != null) {
                cred.Malpractice_AI_Confidence__c = payload.ai_confidence;
            }

            // AI notes
            if (payload.notes != null) {
                cred.Malpractice_AI_Notes__c = payload.notes;
            }

            // Mark that we now have a malpractice document processed
            cred.Has_Malpractice_Document__c = true;

            // 6) Verification logic
            Boolean meetsRequirements = (payload.meets_org_requirements == true);
            Decimal confidence = (payload.ai_confidence == null) ? 0 : payload.ai_confidence;

            if (meetsRequirements && confidence >= 0.85) {
                cred.Malpractice_Insurance_Verified__c = true;
                cred.Requires_Manual_Review__c = false;
            } else {
                cred.Malpractice_Insurance_Verified__c = false;
                cred.Requires_Manual_Review__c = true;
            }

            // 7) Persist changes
            update cred;

            // 8) Successful response
            res.statusCode = 200;
            responseBody.status  = 'SUCCESS';
            responseBody.message = 'Malpractice coverage details processed successfully.';
            responseBody.providerCredentialId = String.valueOf(providerCredentialId);
            res.responseBody = Blob.valueOf(JSON.serialize(responseBody));

        } catch (Exception ex) {
            // 9) Hard failure
            res.statusCode = 500;
            responseBody.status  = 'ERROR';
            responseBody.message = 'Unhandled exception: ' + ex.getMessage();
            res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
        }
    }
}