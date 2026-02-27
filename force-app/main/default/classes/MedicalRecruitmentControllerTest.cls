@IsTest
private class MedicalRecruitmentControllerTest {
    private static Candidate__c makeCandidate() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Recruit Candidate',
            Email__c = 'recruit.candidate@example.com'
        );
        insert c;
        return c;
    }

    @IsTest
    static void testCoreReadMethods() {
        Job_Posting__c job = new Job_Posting__c(Name = 'Recruit Job', Job_Title__c = 'Nurse');
        insert job;
        Candidate__c c = makeCandidate();
        Job_Application__c app = new Job_Application__c(
            Candidate__c = c.Id,
            Job_Posting__c = job.Id,
            Application_Date__c = Date.today()
        );
        insert app;

        Test.startTest();
        List<Job_Posting__c> jobs = MedicalRecruitmentController.getJobPostings(null);
        List<MedicalRecruitmentController.ApplicationWrapper> apps = MedicalRecruitmentController.getJobApplications(job.Id);
        MedicalRecruitmentController.CandidateDetailWrapper detail = MedicalRecruitmentController.getCandidateDetails(app.Id);
        Test.stopTest();

        System.assert(!jobs.isEmpty());
        System.assertEquals(1, apps.size());
        System.assertEquals(app.Id, detail.application.Id);
    }

    @IsTest
    static void testNegativePaths() {
        try {
            MedicalRecruitmentController.getJobApplications(null);
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            MedicalRecruitmentController.getCandidateDetails(null);
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
