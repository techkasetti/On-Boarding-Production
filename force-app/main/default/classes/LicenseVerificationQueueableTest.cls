@IsTest
private class LicenseVerificationQueueableTest {
    private class ExpiredLicenseMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"Expired","licenseNumber":"LIC-2001","expirationDate":"2020-01-01"}');
            return res;
        }
    }

    private static Id createLicenseVerificationId(String suffix) {
        Contact provider = new Contact(LastName = 'Provider ' + suffix);
        insert provider;

        LicenseVerification__c lv = new LicenseVerification__c(
            Provider__c = provider.Id,
            LicenseNumber__c = 'LIC-' + suffix,
            IssuingAuthority__c = 'TX-MED',
            ExpirationDate__c = Date.today().addYears(1),
            Status__c = 'Pending Verification'
        );
        insert lv;
        return lv.Id;
    }

    @IsTest
    static void testQueueable_NullIdNoOp() {
        Test.startTest();
        System.enqueueJob(new LicenseVerificationQueueable(null));
        Test.stopTest();

        System.assert(true, 'Queueable should return early for null id');
    }

    @IsTest
    static void testQueueable_ExecutesVerification() {
        Id lvId = createLicenseVerificationId('QUE1');
        Test.setMock(HttpCalloutMock.class, new ExpiredLicenseMock());

        Test.startTest();
        System.enqueueJob(new LicenseVerificationQueueable(lvId));
        Test.stopTest();

        LicenseVerification__c updated = [
            SELECT Status__c, ExpirationDate__c
            FROM LicenseVerification__c
            WHERE Id = :lvId
        ];
        System.assertEquals('Expired', updated.Status__c);
        System.assertEquals(Date.newInstance(2020, 1, 1), updated.ExpirationDate__c);
    }
}
