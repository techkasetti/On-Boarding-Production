@RestResource(urlMapping='/dynamic-screening/v1/*')
global with sharing class DynScr_RestEndpoint {

    @HttpPost
    global static String runScreening() {
        RestRequest req = RestContext.request;
        Map<String,Object> payload =
            (Map<String,Object>) JSON.deserializeUntyped(req.requestBody.toString());

        Id tenantId = (Id) payload.get('tenantId');

        Id resultId = DynScr_Orchestrator.runScreening(tenantId, payload);

        return JSON.serialize(new Map<String,Object>{'resultId' => resultId});
    }
}
