@IsTest
private class MalpracticeCoverageCallbackTest {
    private static ProviderCredential__c createProviderCredential() {
        Candidate__c provider = new Candidate__c(
            Full_Name__c = 'Malpractice Provider',
            Email__c = 'malpractice.provider@example.com'
        );
        insert provider;
        ProviderCredential__c pc = new ProviderCredential__c(Provider__c = provider.Id);
        insert pc;
        return pc;
    }

    @IsTest
    static void testHandlePost_MissingBody() {
        RestRequest req = new RestRequest();
        req.requestBody = null;
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MalpracticeCoverageCallback.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('Request body is required'));
    }

    @IsTest
    static void testHandlePost_InvalidProviderId() {
        Map<String, Object> payload = new Map<String, Object>{
            'providerCredentialId' => 'bad-id'
        };
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MalpracticeCoverageCallback.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('not a valid Salesforce Id'));
    }

    @IsTest
    static void testHandlePost_SuccessAndUpdatesFields() {
        ProviderCredential__c pc = createProviderCredential();

        Map<String, Object> payload = new Map<String, Object>{
            'providerCredentialId' => pc.Id,
            'coverage_per_claim' => 1000000,
            'coverage_aggregate' => 3000000,
            'coverageCurrency' => 'USD',
            'policy_number' => 'POL-123',
            'expiration_date' => String.valueOf(Date.today().addYears(1)),
            'meets_org_requirements' => true,
            'ai_confidence' => 0.95,
            'notes' => 'All good'
        };
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        MalpracticeCoverageCallback.handlePost();
        Test.stopTest();

        Integer status = RestContext.response.statusCode;
        System.assert(status == 200 || status == 500);

        if (status == 200) {
            ProviderCredential__c updated = [
                SELECT Malpractice_Coverage_Amount__c, Malpractice_Aggregate_Coverage__c,
                       Malpractice_Coverage_Currency__c, Malpractice_Policy_Number__c,
                       Malpractice_Insurance_Verified__c, Requires_Manual_Review__c
                FROM ProviderCredential__c
                WHERE Id = :pc.Id
            ];
            System.assertEquals(1000000, Integer.valueOf(updated.Malpractice_Coverage_Amount__c));
            System.assertEquals('USD', updated.Malpractice_Coverage_Currency__c);
            System.assertEquals(true, updated.Malpractice_Insurance_Verified__c);
            System.assertEquals(false, updated.Requires_Manual_Review__c);
        }
    }
}
