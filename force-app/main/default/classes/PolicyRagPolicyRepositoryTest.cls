@IsTest
private class PolicyRagPolicyRepositoryTest {

    @IsTest
    static void testRetrieveChunksWithScoring() {
        Policy_Document__c doc = new Policy_Document__c(
            Title__c = 'Credentialing Policy',
            Jurisdiction__c = 'US',
            Policy_Type__c = 'Credentialing',
            Version__c = '2026.01',
            Status__c = 'Active',
            Is_Current__c = true
        );
        insert doc;

        insert new List<Policy_Chunk__c>{
            new Policy_Chunk__c(
                Policy_Document__c = doc.Id,
                Chunk_Id__c = 'cred_1',
                Source_Ref__c = 'policy/cred.md#L10',
                Content__c = 'License verification is required before final onboarding.',
                Keywords__c = 'license,verification,onboarding',
                Jurisdiction__c = 'US',
                Is_Active__c = true
            ),
            new Policy_Chunk__c(
                Policy_Document__c = doc.Id,
                Chunk_Id__c = 'cred_2',
                Source_Ref__c = 'policy/cred.md#L20',
                Content__c = 'Badge printing process after activation.',
                Keywords__c = 'badge,activation',
                Jurisdiction__c = 'US',
                Is_Active__c = true
            )
        };

        Test.startTest();
        List<PolicyRagComplianceCopilotService.PolicyChunkInput> chunks =
            PolicyRagPolicyRepository.retrieveChunks(
                'Is license verification required before onboarding?',
                'US',
                'Credentialing',
                3
            );
        Test.stopTest();

        System.assert(!chunks.isEmpty(), 'Expected retrieved chunks');
        System.assertEquals('cred_1', chunks[0].chunkId, 'Most relevant chunk should rank first');
    }
}
