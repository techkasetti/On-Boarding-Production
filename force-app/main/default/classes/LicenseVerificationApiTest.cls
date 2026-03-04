@IsTest
private class LicenseVerificationApiTest {
    private static Candidate__c createCandidateWithContact(String suffix) {
        Contact con = new Contact(LastName = 'Provider ' + suffix, Email = 'provider.' + suffix + '@example.com');
        insert con;

        Candidate__c c = new Candidate__c(
            Full_Name__c = 'LV Candidate ' + suffix,
            Email__c = 'lv.' + suffix + '@example.com',
            Contact__c = con.Id
        );
        insert c;
        return c;
    }

    private static RestRequest buildRequest(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/license-verification';
        req.httpMethod = 'POST';
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        return req;
    }

    private static Map<String, Object> invokeAndParse(String body) {
        RestContext.request = buildRequest(body);
        RestContext.response = new RestResponse();
        LicenseVerificationApi.createLicenseVerification();

        if (RestContext.response.responseBody == null) {
            return new Map<String, Object>();
        }
        return (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
    }

    @IsTest
    static void testMissingBodyInvalidJsonMissingFieldsAndDateValidation() {
        Map<String, Object> res1 = invokeAndParse(null);
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('MISSING_BODY', res1.get('errorCode'));

        Map<String, Object> res2 = invokeAndParse('not-json');
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('INVALID_JSON', res2.get('errorCode'));

        Map<String, Object> res3 = invokeAndParse('{"candidateId":"a0F000000000001AAA"}');
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('MISSING_REQUIRED_FIELDS', res3.get('errorCode'));

        Candidate__c c = createCandidateWithContact('dates');
        Contact provider = new Contact(LastName = 'Provider LV');
        insert provider;

        String badIssue = JSON.serialize(new Map<String, Object>{
            'candidateId' => String.valueOf(c.Id),
            'licenseNumber' => 'LIC-1',
            'licenseType' => 'Medical',
            'issuingAuthority' => 'State Board',
            'issueDate' => 'bad-date',
            'expirationDate' => String.valueOf(Date.today().addDays(30)),
            'status' => 'Pending Verification',
            'providerId' => String.valueOf(provider.Id),
            'nameOnLicense' => 'Dr Test'
        });

        Map<String, Object> res4 = invokeAndParse(badIssue);
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('INVALID_ISSUE_DATE', res4.get('errorCode'));

        String badExp = JSON.serialize(new Map<String, Object>{
            'candidateId' => String.valueOf(c.Id),
            'licenseNumber' => 'LIC-2',
            'licenseType' => 'Medical',
            'issuingAuthority' => 'State Board',
            'issueDate' => String.valueOf(Date.today()),
            'expirationDate' => 'bad-date',
            'status' => 'Pending Verification',
            'providerId' => String.valueOf(provider.Id),
            'nameOnLicense' => 'Dr Test'
        });

        Map<String, Object> res5 = invokeAndParse(badExp);
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('INVALID_EXPIRATION_DATE', res5.get('errorCode'));
    }

    @IsTest
    static void testExpiredLicensePathAndSuccessAndDmlError() {
        Candidate__c c = createCandidateWithContact('main');
        Contact provider = new Contact(LastName = 'Provider Main');
        insert provider;

        // Expired branch: should not insert new LicenseVerification__c
        String expiredPayload = JSON.serialize(new Map<String, Object>{
            'candidateId' => String.valueOf(c.Id),
            'licenseNumber' => 'LIC-EXP',
            'licenseType' => 'Medical',
            'issuingAuthority' => 'State Board',
            'issueDate' => String.valueOf(Date.today().addYears(-2)),
            'expirationDate' => String.valueOf(Date.today().addDays(-1)),
            'status' => 'Pending Verification',
            'providerId' => String.valueOf(provider.Id),
            'nameOnLicense' => 'Dr Expired'
        });

        Integer beforeExpired = [SELECT Count() FROM LicenseVerification__c WHERE Candidate__c = :c.Id];
        Map<String, Object> expiredRes = invokeAndParse(expiredPayload);
        Integer afterExpired = [SELECT Count() FROM LicenseVerification__c WHERE Candidate__c = :c.Id];

        System.assertEquals(beforeExpired, afterExpired, 'Expired branch should not insert record.');
        System.assert(expiredRes.isEmpty() || expiredRes.get('success') == null);

        // Success branch (non-expired)
        String validPayload = JSON.serialize(new Map<String, Object>{
            'candidateId' => String.valueOf(c.Id),
            'licenseNumber' => 'LIC-OK',
            'licenseType' => 'Medical',
            'issuingAuthority' => 'State Board',
            'issueDate' => String.valueOf(Date.today().addYears(-1)),
            'expirationDate' => String.valueOf(Date.today().addYears(1)),
            'status' => 'Pending Verification',
            'providerId' => String.valueOf(provider.Id),
            'nameOnLicense' => 'Dr Valid'
        });

        Map<String, Object> okRes = invokeAndParse(validPayload);
        System.assertEquals(201, RestContext.response.statusCode);
        System.assertEquals(true, okRes.get('success'));
        System.assertEquals(null, okRes.get('errorCode'));
        System.assertNotEquals(null, okRes.get('licenseVerificationId'));

        // DML error branch: invalid candidate id with otherwise valid payload
        String dmlErrorPayload = JSON.serialize(new Map<String, Object>{
            'candidateId' => 'a0F000000000001AAA',
            'licenseNumber' => 'LIC-DML',
            'licenseType' => 'Medical',
            'issuingAuthority' => 'State Board',
            'issueDate' => String.valueOf(Date.today().addYears(-1)),
            'expirationDate' => String.valueOf(Date.today().addYears(1)),
            'status' => 'Pending Verification',
            'providerId' => String.valueOf(provider.Id),
            'nameOnLicense' => 'Dr Invalid'
        });

        Map<String, Object> dmlRes = invokeAndParse(dmlErrorPayload);
        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals('DML_ERROR', dmlRes.get('errorCode'));
    }
}
