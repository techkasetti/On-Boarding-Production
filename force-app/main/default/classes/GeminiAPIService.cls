public class GeminiAPIService {
    
  
    private static final String API_BASE_URL = 'callout:Gemini_API/v1beta';

    /**
     * List all available models to find the right one
     */
    public static String listAvailableModels() {
        try {
            HttpRequest req = new HttpRequest();
            
           
            req.setEndpoint(API_BASE_URL + '/models');

            req.setMethod('GET');
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('=== LIST MODELS RESPONSE ===');
            System.debug('Status: ' + res.getStatusCode());
            System.debug('Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> models = (List<Object>) response.get('models');
                
                List<String> modelNames = new List<String>();
                for (Object modelObj : models) {
                    Map<String, Object> model = (Map<String, Object>) modelObj;
                    String modelName = (String) model.get('name');
                    List<Object> methods = (List<Object>) model.get('supportedGenerationMethods');
                    
                    if (methods != null && methods.contains('generateContent')) {
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

    /* ----------------------- Request Models -------------------------- */

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

    /* ----------------------- Response Models -------------------------- */

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
     * Main Gemini call
     */
    public static GeminiResponse callGeminiAPI(String systemPrompt, String userPrompt, String modelName) {
        GeminiRequest request = new GeminiRequest();
        
        String combinedPrompt = systemPrompt + '\n\n' + userPrompt;
        
        Content userContent = new Content();
        userContent.parts.add(new Part(combinedPrompt));
        request.contents.add(userContent);
        
        return sendRequest(request, modelName);
    }

    public static GeminiResponse callGeminiAPI(String systemPrompt, String userPrompt) {
        String[] modelsToTry = new String[] {
            'gemini-2.5-flash',
            'gemini-2.5-pro',
            'gemini-2.0-flash-exp',
            'gemini-2.0-flash',
            'gemini-1.5-flash',
            'gemini-1.5-pro'
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
        
        return lastResponse;
    }

    /**
     * Send request to Gemini
     */
    private static GeminiResponse sendRequest(GeminiRequest request, String modelName) {
        GeminiResponse response = new GeminiResponse();
        
        try {
            HttpRequest req = new HttpRequest();

      
            String endpoint = API_BASE_URL + '/models/' + modelName + ':generateContent';
            
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);
            req.setBody(JSON.serialize(request, true));
            
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
     * Extract text
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
     * Test connection
     */
    public static String testConnection() {
        String modelsList = listAvailableModels();
        System.debug('Available Models: ' + modelsList);
        
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


