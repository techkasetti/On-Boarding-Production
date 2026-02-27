@IsTest
private class CandidateProfileReceiverTest {
    private static Candidate__c createCandidate() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Receiver Candidate',
            Email__c = 'receiver@example.com'
        );
        insert c;
        return c;
    }

    @IsTest
    static void testProcessCandidateData_InvalidJson() {
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf('{invalid_json');
        RestContext.request = req;

        Test.startTest();
        String response = CandidateProfileReceiver.processCandidateData();
        Test.stopTest();

        System.assert(response.contains('"400"') || response.contains('"code":"400"'));
    }

    @IsTest
    static void testProcessCandidateData_MissingRequiredFields() {
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf('{"serviceType":"Onboarding"}');
        RestContext.request = req;

        Test.startTest();
        String response = CandidateProfileReceiver.processCandidateData();
        Test.stopTest();

        System.assert(response.contains('Validation Failed'));
        System.assert(response.contains('Candidate_Id'));
    }

    @IsTest
    static void testPerformDatabaseOperations_CandidateNotFound() {
        Map<String, String> mapping = new Map<String, String>{
            'fullName' => 'Full_Name__c#Candidate__c'
        };
        Map<String, Object> input = new Map<String, Object>{
            'fullName' => 'Does Not Exist'
        };

        Test.startTest();
        String response = CandidateProfileReceiver.performDatabaseOperations(
            'a00fo0000000001AAA',
            mapping,
            input
        );
        Test.stopTest();

        System.assert(response.contains('"404"') || response.contains('not found'));
    }

    @IsTest
    static void testPerformDatabaseOperations_UpdatesCandidate() {
        Candidate__c c = createCandidate();
        Map<String, String> mapping = new Map<String, String>{
            'fullName' => 'Full_Name__c#Candidate__c'
        };
        Map<String, Object> input = new Map<String, Object>{
            'serviceType' => 'X',
            'Candidate_Id' => c.Id,
            'fullName' => 'Updated Receiver Candidate'
        };

        Test.startTest();
        String response = CandidateProfileReceiver.performDatabaseOperations(c.Id, mapping, input);
        Test.stopTest();

        Candidate__c updated = [SELECT Full_Name__c FROM Candidate__c WHERE Id = :c.Id];
        System.assert(response.contains('Processed Successfully'));
        System.assertEquals('Updated Receiver Candidate', updated.Full_Name__c);
    }
}
