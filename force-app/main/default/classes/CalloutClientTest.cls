@IsTest
private class CalloutClientTest {
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getEndpoint().contains('callout:Middleware_Webhook/test/path'));
            System.assertEquals('corr-123', req.getHeader('X-Correlation-Id'));
            System.assertEquals('corr-123', req.getHeader('Idempotency-Key'));
            System.assertEquals('{"ok":true}', req.getBody());

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    @IsTest
    static void testPostToWebhook_Success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        HttpResponse response = CalloutClient.postToWebhook('test/path', '{"ok":true}', 'corr-123');
        Test.stopTest();

        System.assertEquals(200, response.getStatusCode());
        System.assertEquals('ok', response.getBody());
    }

    @IsTest
    static void testPostToWebhook_ThrowsHandledCalloutException() {
        Boolean thrown = false;
        try {
            Test.startTest();
            CalloutClient.postToWebhook(null, null, null);
            Test.stopTest();
            System.assert(false, 'Expected callout exception in test context without mock');
        } catch (Exception ex) {
            thrown = true;
            System.assert(!String.isBlank(ex.getMessage()), 'Expected exception message');
        }
        System.assertEquals(true, thrown, 'Expected exception to be thrown');
    }
}
