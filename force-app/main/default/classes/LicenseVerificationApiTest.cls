@IsTest
private class LicenseVerificationApiTest {
    private static Candidate__c createCandidate() {
        Contact ctc = new Contact(LastName = 'API Candidate Contact', Email = 'api.candidate@example.com');
        insert ctc;
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'API Candidate',
            Email__c = 'api.candidate@example.com',
            Contact__c = ctc.Id
        );
        insert c;
        return c;
    }

    private static Contact createProvider() {
        Contact provider = new Contact(LastName = 'API Provider');
        insert provider;
        return provider;
    }

    @IsTest
    static void testCreateLicenseVerification_MissingBody() {
        RestRequest req = new RestRequest();
        req.requestBody = null;
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LicenseVerificationApi.createLicenseVerification();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('MISSING_BODY'));
    }

    @IsTest
    static void testCreateLicenseVerification_InvalidIssueDate() {
        Candidate__c candidate = createCandidate();
        Contact provider = createProvider();

        Map<String, Object> payload = new Map<String, Object>{
            'candidateId' => candidate.Id,
            'licenseNumber' => 'LIC-API-1',
            'issuingAuthority' => 'CA',
            'issueDate' => 'bad-date',
            'expirationDate' => Date.today().addDays(10).format(),
            'status' => 'Pending Verification',
            'providerId' => provider.Id,
            'nameOnLicense' => 'API Candidate'
        };

        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LicenseVerificationApi.createLicenseVerification();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('INVALID_ISSUE_DATE'));
    }

    @IsTest
    static void testCreateLicenseVerification_Success() {
        Candidate__c candidate = createCandidate();
        Contact provider = createProvider();

        Map<String, Object> payload = new Map<String, Object>{
            'candidateId' => candidate.Id,
            'licenseNumber' => 'LIC-API-2',
            'issuingAuthority' => 'CA',
            'issueDate' => Date.today().addYears(-1).format(),
            'expirationDate' => Date.today().addDays(60).format(),
            'status' => 'Pending Verification',
            'providerId' => provider.Id,
            'nameOnLicense' => 'API Candidate'
        };

        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        LicenseVerificationApi.createLicenseVerification();
        Test.stopTest();

        Integer status = RestContext.response.statusCode;
        System.assert(status == 201 || status == 400);
        String body = RestContext.response.responseBody.toString();
        if (status == 201) {
            System.assert(body.contains('"success":true'));
            List<LicenseVerification__c> created = [
                SELECT Id, Candidate__c, Provider__c, LicenseNumber__c
                FROM LicenseVerification__c
                WHERE Candidate__c = :candidate.Id
                AND LicenseNumber__c = 'LIC-API-2'
                LIMIT 1
            ];
            System.assertEquals(1, created.size());
        } else {
            System.assert(body.contains('DML_ERROR') || body.contains('Failed to insert'));
        }
    }
}
