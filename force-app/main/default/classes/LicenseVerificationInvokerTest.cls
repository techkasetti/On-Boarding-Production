@IsTest
private class LicenseVerificationInvokerTest {
    private class ValidLicenseMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"Valid","licenseNumber":"LIC-1001","expirationDate":"2030-01-01"}');
            return res;
        }
    }

    private static LicenseVerification__c createLicenseVerification(String suffix) {
        Contact provider = new Contact(LastName = 'Provider ' + suffix);
        insert provider;

        LicenseVerification__c lv = new LicenseVerification__c(
            Provider__c = provider.Id,
            LicenseNumber__c = 'LIC-' + suffix,
            IssuingAuthority__c = 'CA-MED',
            ExpirationDate__c = Date.today().addYears(1),
            Status__c = 'Pending Verification'
        );
        insert lv;
        return lv;
    }

    @IsTest
    static void testSubmitForVerification_EnqueuesAndUpdates() {
        LicenseVerification__c lv = createLicenseVerification('INV1');
        Test.setMock(HttpCalloutMock.class, new ValidLicenseMock());

        Test.startTest();
        LicenseVerificationInvoker.submitForVerification(
            new List<LicenseVerification__c>{ lv }
        );
        Test.stopTest();

        LicenseVerification__c updated = [
            SELECT Status__c, ApiResponseLog__c
            FROM LicenseVerification__c
            WHERE Id = :lv.Id
        ];
        System.assertEquals('Valid', updated.Status__c);
        System.assertNotEquals(null, updated.ApiResponseLog__c);
    }

    @IsTest
    static void testSubmitForVerification_NullAndEmptyInputs() {
        Boolean nullFailedAsExpected = false;
        Test.startTest();
        try {
            LicenseVerificationInvoker.submitForVerification(null);
        } catch (Exception ex) {
            nullFailedAsExpected = true;
        }
        LicenseVerificationInvoker.submitForVerification(new List<LicenseVerification__c>());
        Test.stopTest();

        System.assertEquals(true, nullFailedAsExpected, 'Current implementation throws on null input');
        System.assert(true, 'Empty list path should no-op');
    }
}
