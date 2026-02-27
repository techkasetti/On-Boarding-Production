@IsTest
private class ResumeParserMockTest {
    @IsTest
    static void testRespondPayload() {
        ResumeParserMock mock = new ResumeParserMock();
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('https://example.test/resume');

        Test.startTest();
        HttpResponse res = mock.respond(req);
        Test.stopTest();

        System.assertEquals(200, res.getStatusCode());
        System.assertEquals('application/json', res.getHeader('Content-Type'));

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        System.assert(body.containsKey('name'));
        System.assertEquals('eleanor@example.com', (String) body.get('email'));
        System.assert(body.containsKey('licenses'));
        System.assert(body.containsKey('certifications'));
        System.assert(body.containsKey('skills'));
    }
}
