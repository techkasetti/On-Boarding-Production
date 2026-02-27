@IsTest
private class ScreeningRunViewerControllerTest {
    private static Candidate__c createCandidate(String suffix) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Run Candidate ' + suffix,
            Email__c = 'run.' + suffix + '@example.com'
        );
        insert c;
        return c;
    }

    private static Onboarding_Run__c createRun(Id candidateId) {
        Onboarding_Run__c run = new Onboarding_Run__c(
            Candidate__c = candidateId
        );
        insert run;
        return run;
    }

    @IsTest
    static void testFetchRecentRunsAndFetchRunById() {
        Candidate__c candidate = createCandidate('a');
        Onboarding_Run__c run1 = createRun(candidate.Id);
        Onboarding_Run__c run2 = createRun(candidate.Id);

        Test.startTest();
        List<Onboarding_Run__c> recent = ScreeningRunViewerController.fetchRecentRuns();
        Onboarding_Run__c fetched = ScreeningRunViewerController.fetchRunById(run1.Id);
        Test.stopTest();

        System.assert(recent.size() >= 2, 'Should return inserted runs');
        System.assertEquals(run1.Id, fetched.Id, 'Should fetch by id');
    }

    @IsTest
    static void testFetchRunByIdNull() {
        Test.startTest();
        Onboarding_Run__c fetched = ScreeningRunViewerController.fetchRunById(null);
        Test.stopTest();

        System.assertEquals(null, fetched, 'Null id should return null');
    }
}
