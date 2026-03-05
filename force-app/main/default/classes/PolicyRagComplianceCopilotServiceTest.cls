@IsTest
private class PolicyRagComplianceCopilotServiceTest {

    private class BaseMock implements HttpCalloutMock {
        private String text;

        BaseMock(String text) {
            this.text = text;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            Map<String, Object> body = new Map<String, Object>{
                'candidates' => new List<Object>{
                    new Map<String, Object>{
                        'content' => new Map<String, Object>{
                            'parts' => new List<Object>{
                                new Map<String, Object>{ 'text' => text }
                            }
                        }
                    }
                }
            };

            res.setBody(JSON.serialize(body));
            return res;
        }
    }

    private class BadJsonMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            Map<String, Object> body = new Map<String, Object>{
                'candidates' => new List<Object>{
                    new Map<String, Object>{
                        'content' => new Map<String, Object>{
                            'parts' => new List<Object>{
                                new Map<String, Object>{ 'text' => 'not-json' }
                            }
                        }
                    }
                }
            };

            res.setBody(JSON.serialize(body));
            return res;
        }
    }

    private static Candidate__c createCandidate(String suffix) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'RAG Candidate ' + suffix,
            Email__c = 'rag.' + suffix + '@example.com'
        );
        insert c;
        return c;
    }

    private static List<PolicyRagComplianceCopilotService.PolicyChunkInput> buildChunks(String idValue) {
        PolicyRagComplianceCopilotService.PolicyChunkInput chunk =
            new PolicyRagComplianceCopilotService.PolicyChunkInput();
        chunk.chunkId = idValue;
        chunk.source = 'policy/hipaa.md';
        chunk.content = 'HIPAA training completed is required before PHI access.';

        return new List<PolicyRagComplianceCopilotService.PolicyChunkInput>{ chunk };
    }

    @IsTest
    static void testEvaluateSuccessWithValidCitation() {
        Candidate__c candidate = createCandidate('success');

        String aiJson =
            '{"decision":"ALLOW","answer":"Candidate may proceed with conditions.",' +
            '"reasoning":"HIPAA is completed per chunk evidence.",' +
            '"citations":["chunk_12"],"missing_information":[],"confidence":0.84}';

        PolicyRagComplianceCopilotService.CopilotRequest req =
            new PolicyRagComplianceCopilotService.CopilotRequest();
        req.question = 'Can this candidate proceed if HIPAA is completed?';
        req.candidateId = candidate.Id;
        req.jurisdiction = 'US';
        req.retrievedChunks = buildChunks('chunk_12');

        Test.setMock(HttpCalloutMock.class, new BaseMock(aiJson));

        Test.startTest();
        PolicyRagComplianceCopilotService.CopilotResponse res =
            PolicyRagComplianceCopilotService.evaluate(req);
        Test.stopTest();

        System.assertEquals(true, res.success, res.message);
        System.assertEquals('ALLOW', res.decision, res.message);
        System.assertEquals(1, res.citations.size());
        System.assertEquals('chunk_12', res.citations[0]);
        System.assertEquals(0.840, res.confidence);
    }

    @IsTest
    static void testEvaluateWithoutChunksReturnsInsufficientEvidence() {
        Candidate__c candidate = createCandidate('nochunks');

        PolicyRagComplianceCopilotService.CopilotRequest req =
            new PolicyRagComplianceCopilotService.CopilotRequest();
        req.question = 'Can candidate proceed?';
        req.candidateId = candidate.Id;
        req.jurisdiction = 'US';
        req.retrievedChunks = new List<PolicyRagComplianceCopilotService.PolicyChunkInput>();

        Test.startTest();
        PolicyRagComplianceCopilotService.CopilotResponse res =
            PolicyRagComplianceCopilotService.evaluate(req);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals('MANUAL_REVIEW', res.decision);
        System.assert(res.answer.contains('Insufficient policy evidence'));
    }

    @IsTest
    static void testInvalidDecisionAndInvalidCitationDowngradesToManualReview() {
        Candidate__c candidate = createCandidate('invaliddecision');

        String aiJson =
            '{"decision":"GO_AHEAD","answer":"Proceed","reasoning":"Some reason",' +
            '"citations":["not_present_chunk"],"missing_information":[],"confidence":1.5}';

        PolicyRagComplianceCopilotService.CopilotRequest req =
            new PolicyRagComplianceCopilotService.CopilotRequest();
        req.question = 'Should we allow this candidate?';
        req.candidateId = candidate.Id;
        req.jurisdiction = 'US';
        req.retrievedChunks = buildChunks('chunk_25');

        Test.setMock(HttpCalloutMock.class, new BaseMock(aiJson));

        Test.startTest();
        PolicyRagComplianceCopilotService.CopilotResponse res =
            PolicyRagComplianceCopilotService.evaluate(req);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals('MANUAL_REVIEW', res.decision);
        System.assertEquals(0, res.citations.size());
        System.assert(res.missing_information.contains('No valid policy citations returned.'));
        System.assertEquals(1.000, res.confidence);
    }

    @IsTest
    static void testCodeFenceOutputParses() {
        Candidate__c candidate = createCandidate('fence');

        String aiJson =
            '```json\n' +
            '{"decision":"BLOCK","answer":"Do not proceed.",' +
            '"reasoning":"Critical requirement failed.",' +
            '"citations":["chunk_77"],"missing_information":["Latest license upload"],' +
            '"confidence":0.25}' +
            '\n```';

        PolicyRagComplianceCopilotService.CopilotRequest req =
            new PolicyRagComplianceCopilotService.CopilotRequest();
        req.question = 'Can we proceed?';
        req.candidateId = candidate.Id;
        req.jurisdiction = 'US';
        req.retrievedChunks = buildChunks('chunk_77');

        Test.setMock(HttpCalloutMock.class, new BaseMock(aiJson));

        Test.startTest();
        PolicyRagComplianceCopilotService.CopilotResponse res =
            PolicyRagComplianceCopilotService.evaluate(req);
        Test.stopTest();

        System.assertEquals(true, res.success, res.message);
        System.assertEquals('BLOCK', res.decision, res.message);
        System.assertEquals(1, res.citations.size());
        System.assertEquals('chunk_77', res.citations[0]);
    }

    @IsTest
    static void testBadJsonFallsBackToManualReview() {
        Candidate__c candidate = createCandidate('badjson');

        PolicyRagComplianceCopilotService.CopilotRequest req =
            new PolicyRagComplianceCopilotService.CopilotRequest();
        req.question = 'Can we proceed?';
        req.candidateId = candidate.Id;
        req.retrievedChunks = buildChunks('chunk_x');

        Test.setMock(HttpCalloutMock.class, new BadJsonMock());

        Test.startTest();
        PolicyRagComplianceCopilotService.CopilotResponse res =
            PolicyRagComplianceCopilotService.evaluate(req);
        Test.stopTest();

        System.assertEquals(true, res.success);
        System.assertEquals('MANUAL_REVIEW', res.decision);
    }

    @IsTest
    static void testInvocableAndChunkJsonParser() {
        Candidate__c candidate = createCandidate('flow');

        String aiJson =
            '{"decision":"ALLOW","answer":"Proceed.",' +
            '"reasoning":"Policy supports proceed.",' +
            '"citations":["chunk_12"],"missing_information":[],"confidence":0.9}';

        PolicyRagComplianceCopilotService.FlowInput input =
            new PolicyRagComplianceCopilotService.FlowInput();
        input.question = 'Can this candidate proceed?';
        input.candidateId = candidate.Id;
        input.jurisdiction = 'US';
        input.retrievedChunksJson = '[{"chunkId":"chunk_12","source":"policy","content":"HIPAA completed."}]';

        Test.setMock(HttpCalloutMock.class, new BaseMock(aiJson));

        Test.startTest();
        List<PolicyRagComplianceCopilotService.FlowOutput> out =
            PolicyRagComplianceCopilotService.runForFlow(
                new List<PolicyRagComplianceCopilotService.FlowInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, out.size());
        System.assertEquals(true, out[0].success, out[0].message);
        System.assertEquals('ALLOW', out[0].decision, out[0].message);
        System.assert(out[0].citationsJson.contains('chunk_12'));
    }

    @IsTest
    static void testResolveCandidateContextForCandidateRecord() {
        Candidate__c candidate = createCandidate('resolve');

        Test.startTest();
        PolicyRagComplianceCopilotService.ResolveCandidateResult res =
            PolicyRagComplianceCopilotService.resolveCandidateContext(candidate.Id);
        Test.stopTest();

        System.assertEquals(candidate.Id, res.candidateId);
        System.assertEquals('RECORD_SELF', res.source);
        System.assert(!String.isBlank(res.candidateName));
    }

    @IsTest
    static void testSearchCandidatesReturnsMatch() {
        Candidate__c candidate = createCandidate('search');

        Test.startTest();
        List<PolicyRagComplianceCopilotService.CandidateOption> results =
            PolicyRagComplianceCopilotService.searchCandidates('RAG Candidate search', 5);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Expected at least one candidate suggestion');

        Boolean found = false;
        for (PolicyRagComplianceCopilotService.CandidateOption opt : results) {
            if (opt.id == candidate.Id) {
                found = true;
                break;
            }
        }
        System.assertEquals(true, found, 'Created candidate should be returned in search results');
    }

    @IsTest
    static void testEvaluateUsingStoredEvidence() {
        Candidate__c candidate = createCandidate('stored');

        Policy_Document__c doc = new Policy_Document__c(
            Title__c = 'HIPAA Policy',
            Jurisdiction__c = 'US',
            Policy_Type__c = 'Compliance',
            Version__c = 'v1',
            Status__c = 'Active',
            Is_Current__c = true
        );
        insert doc;

        insert new Policy_Chunk__c(
            Policy_Document__c = doc.Id,
            Chunk_Id__c = 'chunk_store_1',
            Source_Ref__c = 'policy/hipaa.md#L1',
            Content__c = 'HIPAA training completion is mandatory before PHI access.',
            Keywords__c = 'hipaa, training, phi',
            Jurisdiction__c = 'US',
            Is_Active__c = true
        );

        String aiJson =
            '{"decision":"BLOCK","answer":"Do not proceed.",' +
            '"reasoning":"Policy requires completed HIPAA training.",' +
            '"citations":["chunk_store_1"],"missing_information":[],"confidence":0.92}';

        Test.setMock(HttpCalloutMock.class, new BaseMock(aiJson));

        Test.startTest();
        PolicyRagComplianceCopilotService.CopilotResponse res =
            PolicyRagComplianceCopilotService.evaluateUsingStoredEvidence(
                'Can candidate proceed if HIPAA is pending?',
                candidate.Id,
                'US',
                'Compliance',
                5
            );
        Test.stopTest();

        System.assertEquals('STORED_RETRIEVAL', res.retrievalMode);
        System.assertEquals('BLOCK', res.decision);
        System.assert(res.retrievedChunksJson.contains('chunk_store_1'));
    }
}
