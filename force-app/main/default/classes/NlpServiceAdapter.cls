public with sharing class NlpServiceAdapter {
    // This method would call an external NLP service to determine user intent.
    // For this example, we use simple keyword matching to simulate the NLP response.
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getIntent(String message) {
        Map<String, Object> result = new Map<String, Object>();
        
        // Simple mock logic for demonstration
        if (String.isNotBlank(message)) {
            if (message.toLowerCase().contains('hello') || message.toLowerCase().contains('hi')) {
                result.put('intent', 'greeting');
            } else if (message.contains('@')) {
                result.put('intent', 'provide_email');
                result.put('email', message.trim());
            } else {
                result.put('intent', 'provide_name');
                result.put('name', message.trim());
            }
        } else {
            result.put('intent', 'unknown');
        }
        return result;
    }
}
