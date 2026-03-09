@isTest
public class GeminiAPIServiceTest {
    
    /**
     * Mock class for successful HTTP responses
     */
    public class GeminiSuccessMock implements HttpCalloutMock {
        private String mockType;
        
        public GeminiSuccessMock(String type) {
            this.mockType = type;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            if (mockType == 'listModels') {
                res.setBody('{"models": [' +
                    '{"name": "models/gemini-2.5-flash", "supportedGenerationMethods": ["generateContent"]},' +
                    '{"name": "models/gemini-1.5-pro", "supportedGenerationMethods": ["generateContent", "embedContent"]},' +
                    '{"name": "models/text-embedding-004", "supportedGenerationMethods": ["embedContent"]}' +
                    ']}');
            } else if (mockType == 'generateContent') {
                res.setBody('{"candidates": [' +
                    '{"content": {"parts": [{"text": "Hello from Gemini!"}]}, "finishReason": "STOP"}' +
                    '], "usageMetadata": {' +
                    '"promptTokenCount": 10, "candidatesTokenCount": 5, "totalTokenCount": 15' +
                    '}}');
            }
            
            return res;
        }
    }
    
    /**
     * Mock class for failed HTTP responses
     */
    public class GeminiErrorMock implements HttpCalloutMock {
        private Integer statusCode;
        private String errorType;
        
        public GeminiErrorMock(Integer code, String type) {
            this.statusCode = code;
            this.errorType = type;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(statusCode);
            
            if (errorType == 'notFound') {
                res.setBody('{"error": {"code": 404, "message": "Model not found"}}');
            } else if (errorType == 'unauthorized') {
                res.setBody('{"error": {"code": 401, "message": "API key not valid"}}');
            } else if (errorType == 'quotaExceeded') {
                res.setBody('{"error": {"code": 429, "message": "Quota exceeded"}}');
            } else {
                res.setBody('{"error": {"code": 500, "message": "Internal server error"}}');
            }
            
            return res;
        }
    }
    
    /**
     * Mock for fallback scenario (first fails, second succeeds)
     */
    public class GeminiFallbackMock implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // First call fails
            if (callCount == 1) {
                res.setStatusCode(404);
                res.setBody('{"error": {"code": 404, "message": "Model not found"}}');
            } else {
                // Subsequent calls succeed
                res.setStatusCode(200);
                res.setBody('{"candidates": [' +
                    '{"content": {"parts": [{"text": "Success on fallback!"}]}, "finishReason": "STOP"}' +
                    '], "usageMetadata": {' +
                    '"promptTokenCount": 10, "candidatesTokenCount": 5, "totalTokenCount": 15' +
                    '}}');
            }
            
            return res;
        }
    }
    
    // =====================================================
    // TEST METHODS
    // =====================================================
    
    /**
     * Test listAvailableModels - Success
     */
    @isTest
    static void testListAvailableModels_Success() {
        Test.setMock(HttpCalloutMock.class, new GeminiSuccessMock('listModels'));
        
        Test.startTest();
        String result = GeminiAPIService.listAvailableModels();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.contains('Available models:'), 'Should contain available models text');
        System.assert(result.contains('gemini-2.5-flash'), 'Should contain gemini-2.5-flash');
        System.assert(result.contains('gemini-1.5-pro'), 'Should contain gemini-1.5-pro');
        System.assert(!result.contains('text-embedding-004'), 'Should not contain embedding-only model');
    }
    
    /**
     * Test listAvailableModels - Error
     */
    @isTest
    static void testListAvailableModels_Error() {
        Test.setMock(HttpCalloutMock.class, new GeminiErrorMock(401, 'unauthorized'));
        
        Test.startTest();
        String result = GeminiAPIService.listAvailableModels();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.startsWith('ERROR:'), 'Should return error message');
        System.assert(result.contains('401'), 'Should contain status code');
    }
    
    /**
     * Test listAvailableModels - Exception
     */
    @isTest
    static void testListAvailableModels_Exception() {
        // Don't set a mock to trigger exception
        Test.startTest();
        String result = GeminiAPIService.listAvailableModels();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.startsWith('ERROR:'), 'Should return error message');
    }
    
    /**
     * Test callGeminiAPI with specific model - Success
     */
    @isTest
    static void testCallGeminiAPI_WithModel_Success() {
        Test.setMock(HttpCalloutMock.class, new GeminiSuccessMock('generateContent'));
        
        Test.startTest();
        GeminiAPIService.GeminiResponse response = GeminiAPIService.callGeminiAPI(
            'You are a helpful assistant.',
            'Say hello',
            'gemini-2.5-flash'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertEquals(true, response.success, 'Response should be successful');
        System.assertNotEquals(null, response.candidates, 'Candidates should not be null');
        System.assertEquals(1, response.candidates.size(), 'Should have one candidate');
        System.assertNotEquals(null, response.usageMetadata, 'Usage metadata should not be null');
        System.assertEquals(15, response.usageMetadata.totalTokenCount, 'Total tokens should be 15');
    }
    
    /**
     * Test callGeminiAPI with specific model - Error
     */
    @isTest
    static void testCallGeminiAPI_WithModel_Error() {
        Test.setMock(HttpCalloutMock.class, new GeminiErrorMock(404, 'notFound'));
        
        Test.startTest();
        GeminiAPIService.GeminiResponse response = GeminiAPIService.callGeminiAPI(
            'You are a helpful assistant.',
            'Say hello',
            'invalid-model'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertEquals(false, response.success, 'Response should not be successful');
        System.assertNotEquals(null, response.errorMessage, 'Error message should not be null');
        System.assert(response.errorMessage.contains('404'), 'Error should contain 404 status');
    }
    
    /**
     * Test callGeminiAPI without model (fallback) - Success on first try
     */
    @isTest
    static void testCallGeminiAPI_Fallback_FirstSuccess() {
        Test.setMock(HttpCalloutMock.class, new GeminiSuccessMock('generateContent'));
        
        Test.startTest();
        GeminiAPIService.GeminiResponse response = GeminiAPIService.callGeminiAPI(
            'You are a helpful assistant.',
            'Say hello'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertEquals(true, response.success, 'Response should be successful');
    }
    
    /**
     * Test callGeminiAPI without model (fallback) - Success on second try
     */
    @isTest
    static void testCallGeminiAPI_Fallback_SecondSuccess() {
        Test.setMock(HttpCalloutMock.class, new GeminiFallbackMock());
        
        Test.startTest();
        GeminiAPIService.GeminiResponse response = GeminiAPIService.callGeminiAPI(
            'You are a helpful assistant.',
            'Say hello'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertEquals(true, response.success, 'Response should be successful on fallback');
    }
    
    /**
     * Test callGeminiAPI without model (fallback) - All models fail
     */
    @isTest
    static void testCallGeminiAPI_Fallback_AllFail() {
        Test.setMock(HttpCalloutMock.class, new GeminiErrorMock(429, 'quotaExceeded'));
        
        Test.startTest();
        GeminiAPIService.GeminiResponse response = GeminiAPIService.callGeminiAPI(
            'You are a helpful assistant.',
            'Say hello'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertEquals(false, response.success, 'Response should not be successful');
        System.assertNotEquals(null, response.errorMessage, 'Error message should not be null');
    }
    
    /**
     * Test extractContent - Success
     */
    @isTest
    static void testExtractContent_Success() {
        GeminiAPIService.GeminiResponse response = new GeminiAPIService.GeminiResponse();
        response.success = true;
        response.candidates = new List<GeminiAPIService.Candidate>();
        
        GeminiAPIService.Candidate candidate = new GeminiAPIService.Candidate();
        candidate.content = new GeminiAPIService.Content();
        candidate.content.parts = new List<GeminiAPIService.Part>();
        candidate.content.parts.add(new GeminiAPIService.Part('Hello from Gemini!'));
        
        response.candidates.add(candidate);
        
        Test.startTest();
        String content = GeminiAPIService.extractContent(response);
        Test.stopTest();
        
        System.assertNotEquals(null, content, 'Content should not be null');
        System.assertEquals('Hello from Gemini!', content, 'Content should match expected text');
    }
    
    /**
     * Test extractContent - Null response
     */
    @isTest
    static void testExtractContent_NullResponse() {
        Test.startTest();
        String content = GeminiAPIService.extractContent(null);
        Test.stopTest();
        
        System.assertEquals(null, content, 'Content should be null for null response');
    }
    
    /**
     * Test extractContent - Failed response
     */
    @isTest
    static void testExtractContent_FailedResponse() {
        GeminiAPIService.GeminiResponse response = new GeminiAPIService.GeminiResponse();
        response.success = false;
        
        Test.startTest();
        String content = GeminiAPIService.extractContent(response);
        Test.stopTest();
        
        System.assertEquals(null, content, 'Content should be null for failed response');
    }
    
    /**
     * Test extractContent - Empty candidates
     */
    @isTest
    static void testExtractContent_EmptyCandidates() {
        GeminiAPIService.GeminiResponse response = new GeminiAPIService.GeminiResponse();
        response.success = true;
        response.candidates = new List<GeminiAPIService.Candidate>();
        
        Test.startTest();
        String content = GeminiAPIService.extractContent(response);
        Test.stopTest();
        
        System.assertEquals(null, content, 'Content should be null for empty candidates');
    }
    
    /**
     * Test extractContent - Null content in candidate
     */
    @isTest
    static void testExtractContent_NullContent() {
        GeminiAPIService.GeminiResponse response = new GeminiAPIService.GeminiResponse();
        response.success = true;
        response.candidates = new List<GeminiAPIService.Candidate>();
        
        GeminiAPIService.Candidate candidate = new GeminiAPIService.Candidate();
        candidate.content = null;
        response.candidates.add(candidate);
        
        Test.startTest();
        String content = GeminiAPIService.extractContent(response);
        Test.stopTest();
        
        System.assertEquals(null, content, 'Content should be null when candidate content is null');
    }
    
    /**
     * Test extractContent - Empty parts
     */
    @isTest
    static void testExtractContent_EmptyParts() {
        GeminiAPIService.GeminiResponse response = new GeminiAPIService.GeminiResponse();
        response.success = true;
        response.candidates = new List<GeminiAPIService.Candidate>();
        
        GeminiAPIService.Candidate candidate = new GeminiAPIService.Candidate();
        candidate.content = new GeminiAPIService.Content();
        candidate.content.parts = new List<GeminiAPIService.Part>();
        response.candidates.add(candidate);
        
        Test.startTest();
        String content = GeminiAPIService.extractContent(response);
        Test.stopTest();
        
        System.assertEquals(null, content, 'Content should be null for empty parts');
    }
    
    /**
     * Test testConnection - Success
     */
    @isTest
    static void testTestConnection_Success() {
        Test.setMock(HttpCalloutMock.class, new GeminiSuccessMock('generateContent'));
        
        Test.startTest();
        String result = GeminiAPIService.testConnection();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Hello from Gemini!', result, 'Should return expected response');
    }
    
    /**
     * Test testConnection - Error
     */
    @isTest
    static void testTestConnection_Error() {
        Test.setMock(HttpCalloutMock.class, new GeminiErrorMock(500, 'serverError'));
        
        Test.startTest();
        String result = GeminiAPIService.testConnection();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.startsWith('ERROR:'), 'Should return error message');
    }
    
    /**
     * Test inner class constructors and methods
     */
    @isTest
    static void testInnerClasses() {
        Test.startTest();
        
        // Test GeminiRequest
        GeminiAPIService.GeminiRequest request = new GeminiAPIService.GeminiRequest();
        System.assertNotEquals(null, request.contents, 'Contents should be initialized');
        System.assertNotEquals(null, request.generationConfig, 'GenerationConfig should be initialized');
        
        // Test Content
        GeminiAPIService.Content content = new GeminiAPIService.Content();
        System.assertNotEquals(null, content.parts, 'Parts should be initialized');
        
        // Test Part
        GeminiAPIService.Part part = new GeminiAPIService.Part('Test text');
        System.assertEquals('Test text', part.text, 'Part text should match');
        
        // Test GenerationConfig
        GeminiAPIService.GenerationConfig config = new GeminiAPIService.GenerationConfig();
        System.assertEquals(0.7, config.temperature, 'Temperature should be 0.7');
        System.assertEquals(4000, config.maxOutputTokens, 'Max tokens should be 4000');
        
        // Test GeminiResponse
        GeminiAPIService.GeminiResponse response = new GeminiAPIService.GeminiResponse();
        System.assertEquals(false, response.success, 'Success should be false by default');
        
        Test.stopTest();
    }
    
    /**
     * Test with different HTTP status codes
     */
    @isTest
    static void testDifferentStatusCodes() {
        // Test 401 Unauthorized
        Test.setMock(HttpCalloutMock.class, new GeminiErrorMock(401, 'unauthorized'));
        
        Test.startTest();
        GeminiAPIService.GeminiResponse response401 = GeminiAPIService.callGeminiAPI(
            'System prompt',
            'User prompt',
            'gemini-2.5-flash'
        );
        Test.stopTest();
        
        System.assertEquals(false, response401.success, 'Should fail with 401');
        System.assert(response401.errorMessage.contains('401'), 'Error should mention 401');
    }
}