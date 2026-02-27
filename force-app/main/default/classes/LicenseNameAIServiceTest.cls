@IsTest
private class LicenseNameAIServiceTest {
    private class AiSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"candidates":[{"content":{"parts":[{"text":"{\\"decision\\":\\"match\\",\\"score\\":0.95,\\"reason\\":\\"High similarity\\",\\"requires_manual_review\\":false}"}]}}]}'
            );
            return res;
        }
    }

    private class AiFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('error');
            return res;
        }
    }

    private static LicenseVerification__c createLicenseVerification(String suffix, String nameOnLicense) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Candidate ' + suffix,
            Email__c = 'candidate.' + suffix + '@example.com'
        );
        insert c;
        Contact provider = new Contact(LastName = 'Provider ' + suffix);
        insert provider;

        LicenseVerification__c lv = new LicenseVerification__c(
            Candidate__c = c.Id,
            Provider__c = provider.Id,
            Name_On_License__c = nameOnLicense,
            LicenseNumber__c = 'LIC-' + suffix,
            IssuingAuthority__c = 'CA',
            ExpirationDate__c = Date.today().addYears(1),
            Status__c = 'Pending Verification'
        );
        insert lv;
        return lv;
    }

    @IsTest
    static void testRunForLicenseVerifications_SuccessPath() {
        LicenseVerification__c lv = createLicenseVerification('AI1', 'Candidate AI1');
        Test.setMock(HttpCalloutMock.class, new AiSuccessMock());

        Test.startTest();
        LicenseNameAIService.runForLicenseVerifications(new Set<Id>{ lv.Id });
        Test.stopTest();

        LicenseVerification__c updated = [
            SELECT Name_Match_AI_Score__c, Name_Match_AI_Decision__c, Name_Match_AI_Reason__c, Requires_Manual_Review__c
            FROM LicenseVerification__c
            WHERE Id = :lv.Id
        ];
        System.assertEquals('Match', updated.Name_Match_AI_Decision__c);
        System.assert(updated.Name_Match_AI_Score__c > 0);
        System.assertEquals(false, updated.Requires_Manual_Review__c);
    }

    @IsTest
    static void testRunForLicenseVerifications_FallbackReview() {
        LicenseVerification__c lv = createLicenseVerification('AI2', 'Different Name');
        Test.setMock(HttpCalloutMock.class, new AiFailureMock());

        Test.startTest();
        LicenseNameAIService.runForLicenseVerifications(new Set<Id>{ lv.Id });
        Test.stopTest();

        LicenseVerification__c updated = [
            SELECT Name_Match_AI_Decision__c, Requires_Manual_Review__c
            FROM LicenseVerification__c
            WHERE Id = :lv.Id
        ];
        System.assertEquals('Review', updated.Name_Match_AI_Decision__c);
        System.assertEquals(true, updated.Requires_Manual_Review__c);
    }

    @IsTest
    static void testRunForLicenseVerifications_NullAndEmptyNoOp() {
        Test.startTest();
        LicenseNameAIService.runForLicenseVerifications(null);
        LicenseNameAIService.runForLicenseVerifications(new Set<Id>());
        Test.stopTest();
        System.assert(true);
    }
}
