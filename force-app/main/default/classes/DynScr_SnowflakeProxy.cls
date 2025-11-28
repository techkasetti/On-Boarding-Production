public with sharing class DynScr_SnowflakeProxy {

    public static Map<String, Object> score(Map<String, Object> payload) {

        String endpoint = 'callout:SnowflakeCompliance/scoring';

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(endpoint);
        req.setHeader('Content-Type','application/json');
        req.setBody(JSON.serialize(payload));

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        }
        return new Map<String, Object>{ 'error' => 'Snowflake scoring failed' };
    }
}
