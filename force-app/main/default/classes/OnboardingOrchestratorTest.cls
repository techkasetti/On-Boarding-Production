@IsTest
private class OnboardingOrchestratorTest {
    @IsTest
    static void testRegisterJobsAndInterest() {
        Job_Posting__c job = new Job_Posting__c(Name = 'Onboard Job', Specialization__c = 'Cardiology');
        insert job;

        Test.startTest();
        Id candidateId = OnboardingOrchestrator.registerCandidate('Onboard User', '123', 'onboard.user@example.com');
        List<Job_Posting__c> jobs = OnboardingOrchestrator.getAvailableJobs();
        OnboardingOrchestrator.recordJobInterestOnCandidate(candidateId, job.Id);
        List<Screening_Question__c> emptyQuestions = OnboardingOrchestrator.getScreeningQuestions('');
        Test.stopTest();

        Candidate__c c = [SELECT Id, Interested_In_Job__c FROM Candidate__c WHERE Id = :candidateId];
        System.assertEquals(job.Id, c.Interested_In_Job__c);
        System.assert(!jobs.isEmpty());
        System.assertEquals(0, emptyQuestions.size());
    }

    @IsTest
    static void testSaveCandidateAnswerAndValidation() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Answer Candidate',
            Email__c = 'answer.candidate@example.com'
        );
        insert c;
        Screening_Question__c q = new Screening_Question__c(
            Question_Text__c = 'Why this role?',
            Specialization__c = 'General',
            Order__c = 1
        );
        insert q;

        Test.startTest();
        Id answerId = OnboardingOrchestrator.saveCandidateAnswer(c.Id, q.Id, 'Because I care.');
        Test.stopTest();
        System.assertNotEquals(null, answerId);

        try {
            OnboardingOrchestrator.recordJobInterestOnCandidate(null, null);
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
