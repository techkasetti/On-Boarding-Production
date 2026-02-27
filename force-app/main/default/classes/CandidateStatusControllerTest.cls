@IsTest
private class CandidateStatusControllerTest {
    private static Candidate__c makeCandidate(Id jobId) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Status Candidate',
            Email__c = 'status.candidate@example.com',
            Interested_In_Job__c = jobId
        );
        insert c;
        return c;
    }

    @IsTest
    static void testGetJobApplicationsAndStatus() {
        Job_Posting__c job = new Job_Posting__c(Name = 'Status Job');
        insert job;
        Candidate__c c = makeCandidate(job.Id);
        Job_Application__c app = new Job_Application__c(
            Candidate__c = c.Id,
            Job_Posting__c = job.Id,
            Application_Date__c = Date.today()
        );
        insert app;

        Test.startTest();
        List<CandidateStatusController.JobApplicationWrapper> apps =
            CandidateStatusController.getJobApplicationsForCandidate(c.Id);
        CandidateStatusController.CandidateStatusDto dto =
            CandidateStatusController.getCandidateStatus(c.Id, null);
        Test.stopTest();

        System.assertEquals(1, apps.size());
        System.assertEquals(c.Id, dto.candidateId);
    }

    @IsTest
    static void testNegativePaths() {
        try {
            CandidateStatusController.getJobApplicationsForCandidate(null);
            System.assert(false, 'Expected exception for null candidate id');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            CandidateStatusController.getCandidateStatus(null, null);
            System.assert(false, 'Expected exception for null candidate id');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
