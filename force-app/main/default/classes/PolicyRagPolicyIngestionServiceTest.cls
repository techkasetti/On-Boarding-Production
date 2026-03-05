@IsTest
private class PolicyRagPolicyIngestionServiceTest {

    @IsTest
    static void testUpsertDocumentAndChunks() {
        PolicyRagPolicyIngestionService.IngestionRequest req =
            new PolicyRagPolicyIngestionService.IngestionRequest();
        req.title = 'HIPAA Core Policy';
        req.version = 'v2';
        req.jurisdiction = 'US';
        req.policyType = 'Compliance';
        req.sourceRef = 'policy/hipaa-core.md';
        req.activateDocument = true;
        req.chunkSize = 500;
        req.overlap = 80;
        req.plainText =
            'HIPAA training completion is mandatory before PHI access. ' +
            'Candidate must acknowledge policy and complete all required modules. ' +
            'Any pending HIPAA requirement should block PHI onboarding until completion.';

        Test.startTest();
        PolicyRagPolicyIngestionService.IngestionResult res =
            PolicyRagPolicyIngestionService.upsertDocumentAndChunks(req);
        Test.stopTest();

        System.assertNotEquals(null, res.policyDocumentId);
        System.assert(res.chunksUpserted > 0, 'Expected chunks to be inserted/upserted');

        List<Policy_Chunk__c> rows = [
            SELECT Id, Chunk_Id__c
            FROM Policy_Chunk__c
            WHERE Policy_Document__c = :res.policyDocumentId
        ];
        System.assert(!rows.isEmpty(), 'Expected chunks linked to document');
    }
}
