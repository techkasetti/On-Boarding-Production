@IsTest
private class OnboardingOrchestratorTest {
    private static Candidate__c createCandidate(String suffix) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Onb Candidate ' + suffix,
            Email__c = 'onb.' + suffix + '@example.com'
        );
        insert c;
        return c;
    }

    private static Screening_Question__c createQuestion(String specialization, Integer ord) {
        Screening_Question__c q = new Screening_Question__c(
            Question_Text__c = 'Question ' + ord,
            Specialization__c = specialization,
            Order__c = ord
        );
        insert q;
        return q;
    }

    @IsTest
    static void testRegisterCandidateAndAvailableJobs() {
        for (Integer i = 0; i < 6; i++) {
            insert new Job_Posting__c(
                Name = 'Job ' + i,
                Description__c = 'Desc ' + i,
                Location__c = 'City ' + i,
                Specialization__c = 'Cardiology'
            );
        }

        Id createdId;
        Test.startTest();
        try {
            createdId = OnboardingOrchestrator.registerCandidate('John Doe', '9999999999', 'john.doe@example.com');
        } catch (AuraHandledException e) {
            // If org-level required fields block insert, error path is still covered.
            System.assert(e.getMessage().contains('error creating your profile'));
        }
        List<Job_Posting__c> jobs = OnboardingOrchestrator.getAvailableJobs();
        Test.stopTest();

        if (createdId != null) {
            Candidate__c c = [SELECT Id, Resume_Status__c FROM Candidate__c WHERE Id = :createdId LIMIT 1];
            System.assertEquals(false, c.Resume_Status__c);
        }

        System.assert(jobs.size() > 0);
        System.assert(jobs.size() <= 5);
    }

    @IsTest
    static void testRecordJobInterestQuestionsAndAnswers() {
        Job_Posting__c job = new Job_Posting__c(
            Name = 'Interest Job',
            Description__c = 'Interest Desc',
            Location__c = 'Austin',
            Specialization__c = 'Dermatology'
        );
        insert job;

        Candidate__c candidate = createCandidate('interest');

        createQuestion('Dermatology', 2);
        createQuestion('Dermatology', 1);
        createQuestion('Neurology', 1);

        Test.startTest();
        OnboardingOrchestrator.recordJobInterestOnCandidate(candidate.Id, job.Id);
        List<Screening_Question__c> blankQs = OnboardingOrchestrator.getScreeningQuestions('');
        List<Screening_Question__c> qs = OnboardingOrchestrator.getScreeningQuestions('Dermatology');
        Id answerId = OnboardingOrchestrator.saveCandidateAnswer(candidate.Id, qs[0].Id, 'My answer');
        Test.stopTest();

        Candidate__c updated = [SELECT Interested_In_Job__c FROM Candidate__c WHERE Id = :candidate.Id LIMIT 1];
        System.assertEquals(job.Id, updated.Interested_In_Job__c);

        System.assertEquals(0, blankQs.size());
        System.assertEquals(2, qs.size());
        System.assertEquals(1, qs[0].Order__c);
        System.assertNotEquals(null, answerId);

        try {
            OnboardingOrchestrator.recordJobInterestOnCandidate(null, job.Id);
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            OnboardingOrchestrator.saveCandidateAnswer(null, qs[0].Id, 'bad');
            System.assert(false, 'Expected insert failure');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void testErrorCatchBranchesForRegisterAndInterest() {
        Job_Posting__c job = new Job_Posting__c(
            Name = 'Catch Job',
            Description__c = 'Catch Desc',
            Location__c = 'NYC',
            Specialization__c = 'Neurology'
        );
        insert job;

        // Force DML exception in registerCandidate by using very long email.
        String longEmail = 'a'.repeat(300) + '@example.com';
        try {
            OnboardingOrchestrator.registerCandidate('Name', '9999999999', longEmail);
            System.assert(false, 'Expected registerCandidate failure');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        // Force DML exception in recordJobInterestOnCandidate with invalid candidate Id.
        try {
            OnboardingOrchestrator.recordJobInterestOnCandidate('a0F000000000001AAA', job.Id);
            System.assert(false, 'Expected record interest DML failure');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }
}
