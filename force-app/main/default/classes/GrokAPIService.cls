public class GrokAPIService {
    
    // Store your API key in a Custom Metadata Type or Custom Setting (recommended)
    // For now, you can use a constant for testing
    private static final String API_BASE_URL = 'https://api.x.ai/v1';
    private static final String CHAT_ENDPOINT = '/chat/completions';
    private static final String DEFAULT_MODEL = 'grok-beta';
    
    // TODO: Move this to Custom Metadata Type or Protected Custom Settings
    // For testing only - replace with your actual API key
    private static final String API_KEY = 'xai-MPXkrm3waQrb8ElwdoPPpPOThpB9tscxZMHUSXj0n3rV2gBUwPqXa7EECYXRgtXmzaW1GQGB17oy5alM';
    
    public class GrokRequest {
        public String model;
        public List<Message> messages;
        public Decimal temperature;
        public Integer max_tokens;
        public Boolean stream;
        
        public GrokRequest() {
            this.model = DEFAULT_MODEL;
            this.temperature = 0.7;
            this.max_tokens = 4000;
            this.stream = false;
            this.messages = new List<Message>();
        }
    }
    
    public class Message {
        public String role;
        public String content;
        
        public Message(String role, String content) {
            this.role = role;
            this.content = content;
        }
    }
    
    public class GrokResponse {
        public String id;
        public String objectType;
        public Long created;
        public String model;
        public List<Choice> choices;
        public Usage usage;
        public Boolean success;
        public String errorMessage;
        
        public GrokResponse() {
            this.success = false;
        }
    }
    
    public class Choice {
        public Integer index1;
        public Message message;
        public String finish_reason;
    }
    
    public class Usage {
        public Integer prompt_tokens;
        public Integer completion_tokens;
        public Integer total_tokens;
    }
    
    /**
     * Main method to call Grok API
     */
    public static GrokResponse callGrokAPI(String systemPrompt, String userPrompt) {
        GrokRequest request = new GrokRequest();
        
        request.messages.add(new Message('system', systemPrompt));
        request.messages.add(new Message('user', userPrompt));
        
        return sendRequest(request);
    }
    
    /**
     * Send HTTP request to Grok with Bearer token authentication
     */
    private static GrokResponse sendRequest(GrokRequest request) {
        GrokResponse response = new GrokResponse();
        
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(API_BASE_URL + CHAT_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + API_KEY); // Bearer token authentication
            req.setTimeout(120000);
            
            String body = JSON.serialize(request, true);
            req.setBody(body);
            
            System.debug('=== GROK API REQUEST ===');
            System.debug('Endpoint: ' + req.getEndpoint());
            System.debug('Body: ' + body);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('=== GROK API RESPONSE ===');
            System.debug('Status: ' + res.getStatusCode());
            System.debug('Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                response = (GrokResponse) JSON.deserialize(res.getBody(), GrokResponse.class);
                response.success = true;
            } else {
                response.success = false;
                response.errorMessage = 'HTTP ' + res.getStatusCode() + ': ' + res.getBody();
            }
            
        } catch (Exception e) {
            response.success = false;
            response.errorMessage = e.getMessage();
            System.debug('ERROR in Grok API call: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return response;
    }
    
    /**
     * Extract text content from response
     */
    public static String extractContent(GrokResponse response) {
        if (response == null || !response.success || response.choices == null || response.choices.isEmpty()) {
            return null;
        }
        
        return response.choices[0].message.content;
    }
    
    /**
     * Test method for quick verification
     */
    public static String testConnection() {
        GrokResponse response = callGrokAPI(
            'You are a helpful assistant.',
            'Say "Hello from Grok!" if you can hear me.'
        );
        
        if (response.success) {
            return extractContent(response);
        } else {
            return 'ERROR: ' + response.errorMessage;
        }
    }
}