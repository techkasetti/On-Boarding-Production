@IsTest
private class OnboardingOrchestratorV2Test {
    private class WebhookOkMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody('{"ok":true}');
            return r;
        }
    }

    @IsTest
    static void testFetchResumePreviewV2() {
        Test.setMock(HttpCalloutMock.class, new WebhookOkMock());
        Test.startTest();
        String body = OnboardingOrchestratorV2.fetchResumePreviewV2(null);
        Test.stopTest();
        System.assert(String.isNotBlank(body));
    }

    @IsTest
    static void testPersistStructuredResumeDataValidation() {
        try {
            OnboardingOrchestratorV2.persistStructuredResumeData('bad-json');
            System.assert(false, 'Expected parse exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            OnboardingOrchestratorV2.persistStructuredResumeData('{"a":1}');
            System.assert(false, 'Expected missing candidate id exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
