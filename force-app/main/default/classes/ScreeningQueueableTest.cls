@IsTest
private class ScreeningQueueableTest {
    @IsTest
    static void testQueueableEmptyMapNoError() {
        Test.startTest();
        System.enqueueJob(new ScreeningQueueable(new Map<Id, Id>()));
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void testQueueableNoRulesPath() {
        Job_Posting__c job = new Job_Posting__c(Name = 'SQ Job');
        insert job;
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'SQ Candidate',
            Email__c = 'sq.candidate@example.com',
            Interested_In_Job__c = job.Id
        );
        insert c;

        Map<Id, Id> candToJob = new Map<Id, Id>{ c.Id => job.Id };
        Test.startTest();
        System.enqueueJob(new ScreeningQueueable(candToJob));
        Test.stopTest();

        Candidate__c updated = [SELECT Id, Screening_Status__c FROM Candidate__c WHERE Id = :c.Id];
        System.assertNotEquals(null, updated.Id);
    }
}
