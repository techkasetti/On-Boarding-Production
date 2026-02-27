@IsTest
private class JobCandidateMatcherControllerTest {
    private static Candidate__c makeCandidate() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Matcher Candidate',
            Email__c = 'matcher.candidate@example.com',
            Years_of_Experience__c = 5
        );
        insert c;
        return c;
    }

    @IsTest
    static void testGetMatchedCandidates_PositiveAndHardFail() {
        Job_Posting__c job = new Job_Posting__c(
            Name = 'Matcher Job',
            Role_Type__c = 'Nurse',
            Min_Experience_Years__c = 2,
            Max_Experience_Years__c = 8
        );
        insert job;

        insert new Job_Clinical_Skill__c(Job_Posting__c = job.Id, Skill_Name__c = 'ECG');
        insert new Job_Procedure_Requirement__c(Job_Posting__c = job.Id, Procedure_Name__c = 'IV');

        Candidate__c good = makeCandidate();
        insert new Work_Experience__c(Candidate__c = good.Id, Role__c = 'Nurse', Organization__c = 'General');
        insert new Clinical_Skill__c(Candidate__c = good.Id, Name = 'ECG', Verified__c = true);
        insert new Procedure__c(Candidate__c = good.Id, Name = 'IV', Verified__c = true);

        Candidate__c bad = new Candidate__c(
            Full_Name__c = 'Matcher Candidate Bad',
            Email__c = 'matcher.candidate.bad@example.com',
            Years_of_Experience__c = 4
        );
        insert bad;
        insert new Work_Experience__c(Candidate__c = bad.Id, Role__c = 'Nurse', Organization__c = 'General');

        Test.startTest();
        List<CandidateMatchWrapper> rows = JobCandidateMatcherController.getMatchedCandidates(job.Id);
        Test.stopTest();

        System.assertEquals(2, rows.size());
        System.assertEquals(good.Id, rows[0].candidateId);
    }
}
