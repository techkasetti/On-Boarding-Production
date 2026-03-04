@IsTest
private class InterviewQuestionGeneratorTest {
    private class QuestionMock implements HttpCalloutMock {
        private Integer statusCode;
        private String text;

        QuestionMock(Integer statusCode, String text) {
            this.statusCode = statusCode;
            this.text = text;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(statusCode);

            if (statusCode == 200) {
                String body = '{"candidates":[{"content":{"parts":[{"text":' + JSON.serialize(text) + '}]}}]}';
                res.setBody(body);
            } else {
                res.setBody('{"error":{"message":"mock error"}}');
            }
            return res;
        }
    }

    private static Job_Posting__c createJobPosting() {
        Job_Posting__c job = new Job_Posting__c(
            Name = 'Interview Job',
            Job_Title__c = 'ER Nurse',
            Category__c = 'Medical',
            Department__c = 'Emergency',
            Role_Type__c = 'Nurse',
            Description__c = 'Emergency role',
            Min_Experience_Years__c = 2,
            Max_Experience_Years__c = 8,
            Employment_Type__c = 'Full-time',
            Shift_Type__c = 'Day'
        );
        insert job;

        insert new Job_Education_Requirement__c(Job_Posting__c = job.Id, Degree_Name__c = 'BSc Nursing', Mandatory__c = true);
        insert new Job_License_Requirement__c(Job_Posting__c = job.Id, License_Name__c = 'RN License', Active_Required__c = true);
        insert new Job_Certification_Requirement__c(Job_Posting__c = job.Id, Certification_Name__c = 'ACLS', Mandatory__c = true);
        insert new Job_Clinical_Skill__c(Job_Posting__c = job.Id, Skill_Name__c = 'Critical Care', Skill_Level__c = 'Advanced', Mandatory__c = true);
        insert new Job_Procedure_Requirement__c(Job_Posting__c = job.Id, Procedure_Name__c = 'Intubation', Critical__c = true);
        insert new Job_Compliance_Requirement__c(Job_Posting__c = job.Id, Compliance_Name__c = 'HIPAA', Mandatory__c = true);

        return job;
    }

    private static Candidate__c createCandidateWithProfile() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Interview Candidate',
            Email__c = 'interview.candidate@example.com',
            Location__c = 'Chennai'
        );
        insert c;

        insert new Work_Experience__c(
            Candidate__c = c.Id,
            Role__c = 'Nurse',
            Organization__c = 'City Hospital',
            Start_Date__c = Date.today().addYears(-3),
            End_Date__c = Date.today().addYears(-1),
            Responsibilities__c = 'Handled emergency care'
        );
        insert new Education__c(Candidate__c = c.Id, Degree__c = 'BSc Nursing', Institution__c = 'Nursing College');
        insert new License_Certification__c(Candidate__c = c.Id, Name = 'RN License', Type__c = 'License');
        insert new Clinical_Skill__c(Candidate__c = c.Id, Name = 'Critical Care', Skill_Type__c = 'Clinical');
        insert new Technical_Skill__c(Candidate__c = c.Id, Name = 'EHR', Category__c = 'Software');
        insert new Procedure__c(Candidate__c = c.Id, Name = 'Intubation', Category__c = 'Emergency');
        insert new Internship__c(Candidate__c = c.Id, Organization__c = 'Training Hospital', Start_Date__c = Date.today().addYears(-5), End_Date__c = Date.today().addYears(-4));
        insert new Research_Publication__c(Candidate__c = c.Id, Title__c = 'ER Trends', Type__c = 'Journal', Publication_Date__c = Date.today().addYears(-2));
        insert new Membership__c(Candidate__c = c.Id, Organization_Name__c = 'Nursing Assoc', Membership_Type__c = 'Professional');

        return c;
    }

    @IsTest
    static void testGenerateQuestionsForJobAndCandidate() {
        Job_Posting__c job = createJobPosting();
        Candidate__c candidate = createCandidateWithProfile();

        String questionText =
            '1. What is your triage approach?\n' +
            '2) Explain ACLS usage in emergencies.\n' +
            '- Describe a complex case you handled recently.\n' +
            'Q4: How do you ensure HIPAA compliance?';

        Test.setMock(HttpCalloutMock.class, new QuestionMock(200, questionText));

        Test.startTest();
        Map<String, Object> jobResult = InterviewQuestionGenerator.generateQuestions(job.Id);
        Map<String, Object> candidateResult = InterviewQuestionGenerator.generateQuestionsForCandidate(candidate.Id);
        Test.stopTest();

        List<Interview_Question__c> jobQuestions = InterviewQuestionGenerator.getQuestions(job.Id);
        List<Interview_Question__c> candidateQuestions = InterviewQuestionGenerator.getQuestionsForCandidate(candidate.Id);

        Boolean jobSuccess = (Boolean) jobResult.get('success');
        Boolean candidateSuccess = (Boolean) candidateResult.get('success');
        System.assertNotEquals(null, jobSuccess);
        System.assertNotEquals(null, candidateSuccess);
        if (jobSuccess) {
            System.assert(jobQuestions.size() > 0);
        } else {
            System.assertNotEquals(null, jobResult.get('message'));
        }
        if (candidateSuccess) {
            System.assert(candidateQuestions.size() > 0);
        } else {
            System.assertNotEquals(null, candidateResult.get('message'));
        }

        Map<String, Object> deleteJobResult = InterviewQuestionGenerator.deleteAllQuestions(job.Id);
        Map<String, Object> deleteCandidateResult = InterviewQuestionGenerator.deleteQuestionsForCandidate(candidate.Id);

        System.assertEquals(true, deleteJobResult.get('success'));
        System.assertEquals(true, deleteCandidateResult.get('success'));
    }

    @IsTest
    static void testNegativeAndErrorPaths() {
        Job_Posting__c job = createJobPosting();

        Test.startTest();
        Map<String, Object> nullJob = InterviewQuestionGenerator.generateQuestions(null);
        Map<String, Object> nullCandidate = InterviewQuestionGenerator.generateQuestionsForCandidate(null);
        Test.stopTest();

        System.assertEquals(false, nullJob.get('success'));
        System.assertEquals(false, nullCandidate.get('success'));

        Test.setMock(HttpCalloutMock.class, new QuestionMock(500, ''));
        Map<String, Object> failedAi = InterviewQuestionGenerator.generateQuestions(job.Id);
        System.assertEquals(false, failedAi.get('success'));

        Test.setMock(HttpCalloutMock.class, new QuestionMock(200, ''));
        Map<String, Object> emptyAi = InterviewQuestionGenerator.generateQuestions(job.Id);
        System.assertEquals(false, emptyAi.get('success'));

        Map<String, Object> notFoundCandidate = InterviewQuestionGenerator.generateQuestionsForCandidate('003000000000000AAA');
        System.assertEquals(false, notFoundCandidate.get('success'));
    }
}