@IsTest
private class ScreeningHttpMockTest {
    @IsTest
    static void testRespondReturnsExpectedPayload() {
        ScreeningHttpMock mock = new ScreeningHttpMock();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('https://example.test/screening');

        Test.startTest();
        HttpResponse res = mock.respond(req);
        Test.stopTest();

        System.assertEquals(200, res.getStatusCode());
        System.assertEquals('application/json', res.getHeader('Content-Type'));

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        System.assertEquals('TEST', (String) body.get('candidateId'));
        System.assertEquals('mock-corr-1', (String) body.get('correlationId'));
        System.assert(body.containsKey('decisions'));

        List<Object> decisions = (List<Object>) body.get('decisions');
        System.assertEquals(1, decisions.size());
    }
}
