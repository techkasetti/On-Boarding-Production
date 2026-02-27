@IsTest
private class InterviewQuestionGeneratorTest {
    @IsTest
    static void testNullAndNoDataPaths() {
        Job_Posting__c job = new Job_Posting__c(Name = 'IQ Job');
        insert job;

        Candidate__c c = new Candidate__c(
            Full_Name__c = 'IQ Candidate',
            Email__c = 'iq.candidate@example.com'
        );
        insert c;

        Test.startTest();
        Map<String, Object> noJob = InterviewQuestionGenerator.generateQuestions(null);
        List<Interview_Question__c> q1 = InterviewQuestionGenerator.getQuestions(job.Id);
        Map<String, Object> del1 = InterviewQuestionGenerator.deleteAllQuestions(job.Id);

        Map<String, Object> noCandidate = InterviewQuestionGenerator.generateQuestionsForCandidate(null);
        List<Interview_Question__c> q2 = InterviewQuestionGenerator.getQuestionsForCandidate(c.Id);
        Map<String, Object> del2 = InterviewQuestionGenerator.deleteQuestionsForCandidate(c.Id);
        Test.stopTest();

        System.assertEquals(false, noJob.get('success'));
        System.assertNotEquals(null, q1);
        System.assertEquals(true, del1.get('success'));
        System.assertEquals(false, noCandidate.get('success'));
        System.assertNotEquals(null, q2);
        System.assertEquals(true, del2.get('success'));
    }
}
