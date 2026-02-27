// public with sharing class CalloutClient {
//     /*
//      * Simple callout client using a Named Credential called 'Middleware_Webhook_Site'
//      * For demo, you'll configure Named Credential to point to your webhook.site URL (or to https://webhook.site/<id>).
//      *
//      * Methods:
//      *   postToWebhook(path, payload, correlationId) -> returns HttpResponse body string
//      */

//     public class CalloutException extends Exception {}

//     public static HttpResponse postToWebhook(String path, String jsonPayload, String correlationId) {
//         // path should be the path after the Named Credential base URL. If you want to call the full URL, you may pass '' and include complete URL in Named Credential
//         String endpoint = 'callout:Middleware_Webhook_Site';
//         if (!String.isBlank(path)) {
//             if (path.startsWith('/')) path = path.substring(1);
//             endpoint = endpoint + '/' + path;
//         }
//         HttpRequest req = new HttpRequest();
//         req.setEndpoint(endpoint);
//         req.setMethod('POST');
//         req.setHeader('Content-Type','application/json');
//         if (!String.isBlank(correlationId)) req.setHeader('X-Correlation-Id', correlationId);
//         // Idempotency header sample
//         req.setHeader('Idempotency-Key', correlationId == null ? String.valueOf(Math.abs(Crypto.getRandomInteger())) : correlationId);
//         req.setBody(jsonPayload == null ? '{}' : jsonPayload);
//         Http http = new Http();
//         try {
//             HttpResponse res = http.send(req);
//             return res;
//         } catch (System.CalloutException ex) {
//             throw new CalloutException('Callout failed: ' + ex.getMessage());
//         }
//     }
// }
public with sharing class CalloutClient {
    /*
     * Simple callout client using a Named Credential called 'Middleware_Webhook'
     * Configure Named Credential to point to your webhook.site URL or your middleware host.
     *
     * Methods:
     *   postToWebhook(path, payload, correlationId) -> returns HttpResponse
     */

    public class CalloutException extends Exception {}

    public static HttpResponse postToWebhook(String path, String jsonPayload, String correlationId) {
        String endpoint = 'callout:Middleware_Webhook';
        if (!String.isBlank(path)) {
            if (path.startsWith('/')) path = path.substring(1);
            endpoint = endpoint + '/' + path;
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type','application/json');
        if (!String.isBlank(correlationId)) req.setHeader('X-Correlation-Id', correlationId);
        req.setHeader('Idempotency-Key', correlationId == null ? String.valueOf(Math.abs(Crypto.getRandomInteger())) : correlationId);
        req.setBody(jsonPayload == null ? '{}' : jsonPayload);

        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            return res;
        } catch (System.CalloutException ex) {
            throw new CalloutException('Callout failed: ' + ex.getMessage());
        }
    }
}