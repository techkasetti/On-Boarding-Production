@isTest
private class GeminiAPIServiceTest {
    
    @isTest
    static void testListAvailableModels() {
        Test.setMock(HttpCalloutMock.class, new GeminiAPIServiceMock('listModels'));
        
        Test.startTest();
        String result = GeminiAPIService.listAvailableModels();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.contains('gemini'), 'Result should contain model names');
    }
    
    @isTest
    static void testCallGeminiAPISuccess() {
        Test.setMock(HttpCalloutMock.class, new GeminiAPIServiceMock('generateContent'));
        
        Test.startTest();
        GeminiAPIService.GeminiResponse response = GeminiAPIService.callGeminiAPI(
            'System prompt',
            'User prompt'
        );
        Test.stopTest();
        
        System.assertEquals(true, response.success, 'Response should be successful');
        System.assertNotEquals(null, response.candidates, 'Candidates should not be null');
    }
    
    @isTest
    static void testCallGeminiAPIWithModel() {
        Test.setMock(HttpCalloutMock.class, new GeminiAPIServiceMock('generateContent'));
        
        Test.startTest();
        GeminiAPIService.GeminiResponse response = GeminiAPIService.callGeminiAPI(
            'System prompt',
            'User prompt',
            'gemini-2.5-flash'
        );
        Test.stopTest();
        
        System.assertEquals(true, response.success, 'Response should be successful');
    }
    
    @isTest
    static void testExtractContent() {
        Test.setMock(HttpCalloutMock.class, new GeminiAPIServiceMock('generateContent'));
        
        Test.startTest();
        GeminiAPIService.GeminiResponse response = GeminiAPIService.callGeminiAPI(
            'System prompt',
            'User prompt'
        );
        String content = GeminiAPIService.extractContent(response);
        Test.stopTest();
        
        System.assertNotEquals(null, content, 'Content should not be null');
        System.assert(content.contains('Hello'), 'Content should contain response text');
    }
    
    @isTest
    static void testTestConnection() {
        Test.setMock(HttpCalloutMock.class, new GeminiAPIServiceMock('generateContent'));
        
        Test.startTest();
        String result = GeminiAPIService.testConnection();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testCallGeminiAPIError() {
        Test.setMock(HttpCalloutMock.class, new GeminiAPIServiceMock('error'));
        
        Test.startTest();
        GeminiAPIService.GeminiResponse response = GeminiAPIService.callGeminiAPI(
            'System prompt',
            'User prompt'
        );
        Test.stopTest();
        
        System.assertEquals(false, response.success, 'Response should fail');
        System.assertNotEquals(null, response.errorMessage, 'Error message should be present');
    }
    
    // Mock class for HTTP callouts
    private class GeminiAPIServiceMock implements HttpCalloutMock {
        String responseType;
        
        public GeminiAPIServiceMock(String responseType) {
            this.responseType = responseType;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (responseType == 'listModels') {
                res.setStatusCode(200);
                res.setBody('{"models":[{"name":"models/gemini-2.5-flash","supportedGenerationMethods":["generateContent"]}]}');
            } else if (responseType == 'generateContent') {
                res.setStatusCode(200);
                res.setBody('{"candidates":[{"content":{"parts":[{"text":"Hello from Gemini!"}],"role":"model"},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":10,"candidatesTokenCount":5,"totalTokenCount":15}}');
            } else if (responseType == 'error') {
                res.setStatusCode(400);
                res.setBody('{"error":{"message":"Invalid request"}}');
            }
            
            return res;
        }
    }
}