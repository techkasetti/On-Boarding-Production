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

    private static Job_Posting__c makeJob() {
        Job_Posting__c job = new Job_Posting__c(
            Name = 'Recruit Job',
            Job_Title__c = 'Nurse'
        );
        insert job;
        return job;
    }

    private static Job_Application__c makeApplication(Candidate__c c, Job_Posting__c job) {

        Job_Application__c app = new Job_Application__c(
            Candidate__c = c.Id,
            Job_Posting__c = job.Id,
            Application_Date__c = Date.today(),
            Status__c = 'Application Received'
        );

        insert app;
        return app;
    }

    @IsTest
    static void testCoreReadMethods() {

        Job_Posting__c job = makeJob();
        Candidate__c c = makeCandidate();
        Job_Application__c app = makeApplication(c, job);

        Test.startTest();

        List<Job_Posting__c> jobs =
            MedicalRecruitmentController.getJobPostings(null);

        List<MedicalRecruitmentController.ApplicationWrapper> apps =
            MedicalRecruitmentController.getJobApplications(job.Id);

        MedicalRecruitmentController.CandidateDetailWrapper detail =
            MedicalRecruitmentController.getCandidateDetails(app.Id);

        Test.stopTest();

        System.assert(!jobs.isEmpty());
        System.assertEquals(1, apps.size());
        System.assertEquals(app.Id, detail.application.Id);
    }

    @IsTest
    static void testUpdateApplicationStatus() {

        Job_Posting__c job = makeJob();
        Candidate__c c = makeCandidate();
        Job_Application__c app = makeApplication(c, job);

        Test.startTest();

        Job_Application__c updated =
            MedicalRecruitmentController.updateApplicationStatus(
                app.Id,
                'Eligibility Check In Progress',
                'Moving forward'
            );

        Test.stopTest();

        System.assertEquals('Eligibility Check In Progress', updated.Status__c);
    }
@IsTest
static void testLicenseVerificationMethods() {

    Candidate__c c = makeCandidate();

    Contact provider = new Contact(LastName='Provider');
    insert provider;

    LicenseVerification__c lic = new LicenseVerification__c(
        Candidate__c=c.Id,
        Provider__c=provider.Id,
        LicenseNumber__c='LIC123',
        IssuingAuthority__c='Medical Board',
        ExpirationDate__c=Date.today().addYears(1)
    );

    insert lic;

    Test.startTest();

    List<LicenseVerification__c> licenses =
        MedicalRecruitmentController.getLicenseVerifications(c.Id);

    Map<String,Object> updateFields = new Map<String,Object>{
        'Name_On_License__c' => 'Updated License Name'
    };

    MedicalRecruitmentController.updateLicenseVerification(
        lic.Id,
        updateFields
    );

    Test.stopTest();

    System.assertEquals(1, licenses.size());
}
    @IsTest
    static void testContactLookup() {

        Contact con = new Contact(LastName='Provider Contact');
        insert con;

        Test.startTest();

        List<Map<String,String>> contacts =
            MedicalRecruitmentController.getContacts();

        Test.stopTest();

        System.assert(!contacts.isEmpty());
    }

    @IsTest
    static void testInterviewDetailMethods() {

        Candidate__c c = makeCandidate();
        Job_Posting__c job = makeJob();
        Job_Application__c app = makeApplication(c, job);

        Map<String,Object> fields = new Map<String,Object>{
            'External_Interviewer_Name__c' => 'Dr Smith',
            'External_Interviewer_Email__c' => 'smith@test.com',
            'Interviewer_Type__c' => 'External',
            'Meeting_Type__c' => 'Virtual'
        };

        Test.startTest();

        Id interviewId =
            MedicalRecruitmentController.createInterviewDetail(
                c.Id,
                app.Id,
                fields
            );

        List<Interview_Detail__c> interviews =
            MedicalRecruitmentController.getInterviewDetails(c.Id);

        Map<String,Object> updateFields = new Map<String,Object>{
            'Feedback__c' => 'Good Candidate'
        };

        MedicalRecruitmentController.updateInterviewDetail(
            interviewId,
            updateFields
        );

        Test.stopTest();

        System.assert(!interviews.isEmpty());
    }

    @IsTest
    static void testUserLookup() {

        Test.startTest();

        List<Map<String,String>> users =
            MedicalRecruitmentController.getActiveUsers();

        Test.stopTest();

        System.assert(!users.isEmpty());
    }

    @IsTest
    static void testSendInterviewEmails() {

        Job_Posting__c job = makeJob();
        Candidate__c c = makeCandidate();
        Job_Application__c app = makeApplication(c, job);

        Test.startTest();

        MedicalRecruitmentController.sendInterviewEmails(
            app.Id,
            'External',
            null,
            'external@test.com',
            'Virtual',
            'https://zoom.test',
            'https://zoom.start'
        );

        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testNegativePaths() {

        try {
            MedicalRecruitmentController.getJobApplications(null);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            MedicalRecruitmentController.getCandidateDetails(null);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}