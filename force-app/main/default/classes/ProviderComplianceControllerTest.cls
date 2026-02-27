@IsTest
private class ProviderComplianceControllerTest {
    private static Candidate__c makeCandidate() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Compliance Candidate',
            Email__c = 'compliance.candidate@example.com'
        );
        insert c;
        return c;
    }

    @IsTest
    static void testSummaryQueueAndKpis() {
        Candidate__c c = makeCandidate();

        Test.startTest();
        ProviderComplianceController.ProviderComplianceSummary summary =
            ProviderComplianceController.getProviderComplianceSummary(c.Id);
        ProviderComplianceController.PagedResult queue =
            ProviderComplianceController.getProviderQueue(null, null, null, null, null, 20, 0, null, null);
        Map<String, Integer> kpis = ProviderComplianceController.getOverviewKpis();
        Test.stopTest();

        System.assertNotEquals(null, summary);
        System.assertNotEquals(null, queue);
        System.assertNotEquals(null, kpis);
    }

    @IsTest
    static void testFlagProviderForReview() {
        Candidate__c c = makeCandidate();
        Test.startTest();
        ProviderComplianceController.flagProviderForReview(c.Id, 'Review requested');
        Test.stopTest();

        List<Task> tasks = [SELECT Id, WhatId FROM Task WHERE WhatId = :c.Id];
        System.assertEquals(1, tasks.size());
    }
}
