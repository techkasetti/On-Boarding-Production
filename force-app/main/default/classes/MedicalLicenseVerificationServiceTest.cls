@IsTest
private class MedicalLicenseVerificationServiceTest {
    private class ServerErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('error');
            return res;
        }
    }

    private static Id createLicenseVerificationId(String suffix) {
        Contact provider = new Contact(LastName = 'Provider ' + suffix);
        insert provider;

        LicenseVerification__c lv = new LicenseVerification__c(
            Provider__c = provider.Id,
            LicenseNumber__c = 'LIC-' + suffix,
            IssuingAuthority__c = 'NY-MED',
            ExpirationDate__c = Date.today().addYears(1),
            Status__c = 'Pending Verification'
        );
        insert lv;
        return lv.Id;
    }

    @IsTest
    static void testVerifyLicense_Non200SetsManualReview() {
        Id lvId = createLicenseVerificationId('MED1');
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());

        Test.startTest();
        MedicalLicenseVerificationService.verifyLicense(lvId);
        Test.stopTest();

        LicenseVerification__c updated = [
            SELECT Status__c, ApiRequestLog__c, ApiResponseLog__c
            FROM LicenseVerification__c
            WHERE Id = :lvId
        ];
        System.assertEquals('Requires Manual Review', updated.Status__c);
        System.assertNotEquals(null, updated.ApiRequestLog__c);
        System.assertNotEquals(null, updated.ApiResponseLog__c);
    }

    @IsTest
    static void testVerifyLicense_InvalidIdNoThrow() {
        Id lvId = createLicenseVerificationId('MED2');
        delete new LicenseVerification__c(Id = lvId);

        Test.startTest();
        MedicalLicenseVerificationService.verifyLicense(lvId);
        Test.stopTest();

        System.assert(true, 'Method should swallow missing-record exception');
    }
}
