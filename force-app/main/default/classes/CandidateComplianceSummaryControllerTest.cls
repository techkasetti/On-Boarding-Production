@IsTest
private class CandidateComplianceSummaryControllerTest {
    @IsTest
    static void testGetCandidateComplianceSummary_NullCandidateId() {
        try {
            Test.startTest();
            CandidateComplianceSummaryController.getCandidateComplianceSummary(null);
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException for null candidateId');
        } catch (Exception ex) {
            System.assertNotEquals(null, ex);
        }
    }

    @IsTest
    static void testGetCandidateComplianceSummary_NoRelatedRecords() {
        Candidate__c candidate = new Candidate__c(
            Full_Name__c = 'Compliance Test',
            Email__c = 'compliance.test@example.com'
        );
        insert candidate;

        Test.startTest();
        CandidateComplianceSummaryController.CandidateComplianceSummary summary =
            CandidateComplianceSummaryController.getCandidateComplianceSummary(candidate.Id);
        Test.stopTest();

        System.assertNotEquals(null, summary, 'Summary should be returned');
        System.assertEquals(candidate.Id, summary.candidateId, 'Candidate id should match');
        System.assertEquals(6, summary.totalDomains, 'All six compliance domains should be present');
        System.assertNotEquals(null, summary.domains, 'Domain summaries should be initialized');
        System.assertEquals(6, summary.domains.size(), 'Domain list should contain six entries');
    }
}
