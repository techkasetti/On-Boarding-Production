public class GeminiAPIService {
    
    // Use v1beta API with correct model naming
    private static final String API_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta';
    
    // Get your free API key from: https://ai.google.dev
    private static final String API_KEY = 'AIzaSyArLfrFoYEk05mFDkBQ72B4SQfuOFrVudQ';
    
    /**
     * List all available models to find the right one
     */
    public static String listAvailableModels() {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(API_BASE_URL + '/models?key=' + API_KEY);
            req.setMethod('GET');
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('=== LIST MODELS RESPONSE ===');
            System.debug('Status: ' + res.getStatusCode());
            System.debug('Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                // Parse and extract model names
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> models = (List<Object>) response.get('models');
                
                List<String> modelNames = new List<String>();
                for (Object modelObj : models) {
                    Map<String, Object> model = (Map<String, Object>) modelObj;
                    String modelName = (String) model.get('name');
                    List<Object> methods = (List<Object>) model.get('supportedGenerationMethods');
                    
                    // Only show models that support generateContent
                    if (methods != null && methods.contains('generateContent')) {
                        // Extract just the model ID from "models/gemini-pro"
                        String modelId = modelName.substringAfter('models/');
                        modelNames.add(modelId);
                    }
                }
                
                return 'Available models: ' + String.join(modelNames, ', ');
            } else {
                return 'ERROR: ' + res.getStatusCode() + ' - ' + res.getBody();
            }
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }
    
    public class GeminiRequest {
        public List<Content> contents;
        public GenerationConfig generationConfig;
        
        public GeminiRequest() {
            this.contents = new List<Content>();
            this.generationConfig = new GenerationConfig();
        }
    }
    
    public class Content {
        public List<Part> parts;
        
        public Content() {
            this.parts = new List<Part>();
        }
    }
    
    public class Part {
        public String text;
        
        public Part(String text) {
            this.text = text;
        }
    }
    
    public class GenerationConfig {
        public Decimal temperature;
        public Integer maxOutputTokens;
        
        public GenerationConfig() {
            this.temperature = 0.7;
            this.maxOutputTokens = 4000;
        }
    }
    
    public class GeminiResponse {
        public List<Candidate> candidates;
        public UsageMetadata usageMetadata;
        public Boolean success;
        public String errorMessage;
        
        public GeminiResponse() {
            this.success = false;
        }
    }
    
    public class Candidate {
        public Content content;
        public String finishReason;
    }
    
    public class UsageMetadata {
        public Integer promptTokenCount;
        public Integer candidatesTokenCount;
        public Integer totalTokenCount;
    }
    
    /**
     * Main method to call Gemini API with a specific model
     */
    public static GeminiResponse callGeminiAPI(String systemPrompt, String userPrompt, String modelName) {
        GeminiRequest request = new GeminiRequest();
        
        // Combine system and user prompts
        String combinedPrompt = systemPrompt + '\n\n' + userPrompt;
        
        Content userContent = new Content();
        userContent.parts.add(new Part(combinedPrompt));
        request.contents.add(userContent);
        
        return sendRequest(request, modelName);
    }
    
    /**
     * Overload with default model selection
     */
    public static GeminiResponse callGeminiAPI(String systemPrompt, String userPrompt) {
        // Available models from your Google AI Studio account (as of Jan 2026)
        // All of these support generateContent method
        String[] modelsToTry = new String[] {
            'gemini-2.5-flash',      // Fast, newest version (RECOMMENDED)
            'gemini-2.5-pro',        // Most capable, slower
            'gemini-2.0-flash-exp',  // Experimental flash version
            'gemini-2.0-flash',      // Stable 2.0 flash
            'gemini-1.5-flash',      // Older flash version
            'gemini-1.5-pro'         // Older pro version
        };
        
        GeminiResponse lastResponse = null;
        
        for (String model : modelsToTry) {
            System.debug('Trying model: ' + model);
            lastResponse = callGeminiAPI(systemPrompt, userPrompt, model);
            
            if (lastResponse.success) {
                System.debug('Success with model: ' + model);
                return lastResponse;
            }
            
            System.debug('Failed with model ' + model + ': ' + lastResponse.errorMessage);
        }
        
        // If all failed, return the last error
        return lastResponse;
    }
    
    /**
     * Send HTTP request to Gemini
     */
    private static GeminiResponse sendRequest(GeminiRequest request, String modelName) {
        GeminiResponse response = new GeminiResponse();
        
        try {
            HttpRequest req = new HttpRequest();
            String endpoint = API_BASE_URL + '/models/' + modelName + ':generateContent?key=' + API_KEY;
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            
            String body = JSON.serialize(request, true);
            req.setBody(body);
            
            System.debug('=== GEMINI API REQUEST ===');
            System.debug('Model: ' + modelName);
            System.debug('Endpoint: ' + endpoint);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('=== GEMINI API RESPONSE ===');
            System.debug('Status: ' + res.getStatusCode());
            System.debug('Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                response = (GeminiResponse) JSON.deserialize(res.getBody(), GeminiResponse.class);
                response.success = true;
            } else {
                response.success = false;
                response.errorMessage = 'HTTP ' + res.getStatusCode() + ': ' + res.getBody();
            }
            
        } catch (Exception e) {
            response.success = false;
            response.errorMessage = e.getMessage();
            System.debug('ERROR in Gemini API call: ' + e.getMessage());
        }
        
        return response;
    }
    
    /**
     * Extract text content from response
     */
    public static String extractContent(GeminiResponse response) {
        if (response == null || !response.success || response.candidates == null || response.candidates.isEmpty()) {
            return null;
        }
        
        Candidate candidate = response.candidates[0];
        if (candidate.content == null || candidate.content.parts == null || candidate.content.parts.isEmpty()) {
            return null;
        }
        
        return candidate.content.parts[0].text;
    }
    
    /**
     * Test method - first lists models, then tries to connect
     */
    public static String testConnection() {
        // First, list available models
        String modelsList = listAvailableModels();
        System.debug('Available Models: ' + modelsList);
        
        // Then try to use the API
        GeminiResponse response = callGeminiAPI(
            'You are a helpful assistant.',
            'Say "Hello from Gemini!" if you can hear me.'
        );
        
        if (response.success) {
            return extractContent(response);
        } else {
            return 'ERROR: ' + response.errorMessage;
        }
    }
}