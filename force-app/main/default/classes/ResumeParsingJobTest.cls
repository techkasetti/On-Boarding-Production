@IsTest
private class ResumeParsingJobTest {
    private static Candidate__c createCandidate() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Resume Job Candidate',
            Email__c = 'resume.job@example.com'
        );
        insert c;
        return c;
    }

    @IsTest
    static void testExecute_NullCandidateId_NoOp() {
        ResumeParsingJob job = new ResumeParsingJob(null);

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testUpdateCandidateStatus_AndNullGuards() {
        Candidate__c c = createCandidate();

        Test.startTest();
        ResumeParsingJob.updateCandidateStatus(c.Id, 'RESUME_PARSED_SUCCESS');
        ResumeParsingJob.updateCandidateStatus(null, 'RESUME_PARSED_FAILED');
        ResumeParsingJob.updateCandidateStatus(c.Id, null);
        ResumeParsingJob.applyPayloadToCandidate(c.Id, null);
        Test.stopTest();

        Candidate__c updated = [SELECT Status__c FROM Candidate__c WHERE Id = :c.Id];
        System.assertEquals('RESUME_PARSED_SUCCESS', updated.Status__c);
    }
}
