@isTest
global class ScreeningHttpMock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        // Provide a 200 with a simple JSON body mimicking Snowflake decision
        res.setStatusCode(200);
        res.setHeader('Content-Type','application/json');
        Map<String,Object> body = new Map<String,Object>{
            'candidateId' => 'TEST',
            'decisions' => new List<Object>{ new Map<String,Object>{ 'ruleKey'=>'SAMPLE_RULE_FAIL_IF_EXP_LT_2','action'=>'AutoReject','score'=>0.9 } },
            'correlationId' => 'mock-corr-1'
        };
        res.setBody(JSON.serialize(body));
        return res;
    }
}
