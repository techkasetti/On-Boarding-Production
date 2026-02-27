@IsTest
private class AIScreeningControllerTest {
    private class GeminiSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{' +
                '"candidates":[{"content":{"parts":[{"text":"{ \\"overallScore\\": 88, \\"confidenceLevel\\": \\"High\\", \\"recommendation\\": \\"RECOMMEND\\", \\"quickSummary\\": \\"Strong\\", \\"fullAnalysis\\": \\"Detailed\\", \\"strengths\\": [\\"A\\",\\"B\\"], \\"concerns\\": [\\"X\\"] }"}]}}],' +
                '"usageMetadata":{"totalTokenCount":30}' +
                '}'
            );
            return res;
        }
    }

    private class GeminiFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server Error');
            return res;
        }
    }

    private class GeminiCodeFenceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{' +
                '"candidates":[{"content":{"parts":[{"text":"```json\\n{ ' +
                '\\\"overallScore\\\": \\\"91.5\\\", ' +
                '\\\"confidenceLevel\\\": \\\"excellent\\\", ' +
                '\\\"recommendation\\\": \\\"strongly recommend\\\", ' +
                '\\\"quickSummary\\\": \\\"Top candidate\\\", ' +
                '\\\"fullAnalysis\\\": \\\"Detailed review\\\", ' +
                '\\\"strengths\\\": [\\\"A\\\",\\\"B\\\",\\\"C\\\",\\\"D\\\"], ' +
                '\\\"concerns\\\": [\\\"X\\\",\\\"Y\\\",\\\"Z\\\"] ' +
                '}\\n```"}]}}],' +
                '"usageMetadata":{"totalTokenCount":42}' +
                '}'
            );
            return res;
        }
    }

    private class GeminiPlainTextMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{' +
                '"candidates":[{"content":{"parts":[{"text":"This is non-JSON analysis text to force fallback parsing."}]}}],' +
                '"usageMetadata":{"totalTokenCount":9}' +
                '}'
            );
            return res;
        }
    }

    private static Candidate__c createCandidate(Boolean withJob) {
        Job_Posting__c job;
        if (withJob) {
            job = new Job_Posting__c(Name = 'Developer');
            insert job;
        }

        Candidate__c cand = new Candidate__c(
            Years_of_Experience__c = 5,
            Location__c = 'Test City',
            Resume_Status__c = true,
            Interested_in_Job__c = withJob ? job.Id : null
        );
        insert cand;
        return cand;
    }

    private static Job_Posting__c createJobPosting(String suffix) {
        Job_Posting__c job = new Job_Posting__c(Name = 'Job ' + suffix);
        insert job;
        return job;
    }

    private static Job_Application__c createJobApplication(Id candidateId, Id jobPostingId) {
        Job_Application__c jobApp = new Job_Application__c(
            Candidate__c = candidateId,
            Job_Posting__c = jobPostingId
        );
        insert jobApp;
        return jobApp;
    }

    private static void createActiveRule(Id jobPostingId) {
        Screening_Rule__c rule = new Screening_Rule__c(
            Name = 'Rule 1',
            Rule_Key__c = 'RULE-1',
            Applied_Role__c = jobPostingId,
            Active__c = true,
            Is_Current_Version__c = true,
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Years_of_Experience__c',
            Operator__c = 'Greater Than or Equal',
            Expected_Value__c = '2',
            Rule_Category__c = 'Experience',
            Priority__c = 1
        );
        insert rule;
    }

    private static void createScreeningResults(Id candidateId, Id jobPostingId, String correlationId) {
        insert new Screening_Result__c(
            Name = 'SR-1',
            Candidate__c = candidateId,
            Job_Posting__c = jobPostingId,
            Correlation_Id__c = correlationId,
            Outcome__c = 'Pass'
        );
        insert new Screening_Result__c(
            Name = 'SR-2',
            Candidate__c = candidateId,
            Job_Posting__c = jobPostingId,
            Correlation_Id__c = correlationId,
            Outcome__c = 'Fail'
        );
    }

    private static void addRelatedProfileData(Id candidateId) {
        insert new License_Certification__c(
            Name = 'RN',
            Candidate__c = candidateId,
            Type__c = 'License',
            Expiry_Date__c = Date.today().addYears(1)
        );

        insert new Education__c(
            Name = 'BSN',
            Candidate__c = candidateId,
            Degree__c = 'BSN',
            Institution__c = 'Nursing School',
            End_Year__c = 2023
        );

        insert new Work_Experience__c(
            Name = 'Hospital Work',
            Candidate__c = candidateId,
            Role__c = 'Nurse',
            Organization__c = 'City Hospital',
            Duration_Text__c = '2 years'
        );

        insert new Clinical_Skill__c(
            Name = 'ICU',
            Candidate__c = candidateId,
            Skill_Type__c = 'Critical Care'
        );
    }

    @IsTest
    static void testRunAIScreeningForCandidate_Success() {
        Candidate__c cand = createCandidate(true);
        Test.setMock(HttpCalloutMock.class, new GeminiSuccessMock());

        Test.startTest();
        Map<String, Object> result = AIScreeningController.runAIScreeningForCandidate(cand.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.get('success'));
    }

    @IsTest
    static void testRunAIScreeningForCandidate_Failure() {
        Candidate__c cand = createCandidate(true);
        Test.setMock(HttpCalloutMock.class, new GeminiFailureMock());

        Test.startTest();
        Map<String, Object> result = AIScreeningController.runAIScreeningForCandidate(cand.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(false, result.get('success'));
    }

    @IsTest
    static void testInvocableRunAIScreening() {
        Candidate__c cand = createCandidate(false);
        Test.setMock(HttpCalloutMock.class, new GeminiSuccessMock());

        AIScreeningController.AIScreeningRequest req = new AIScreeningController.AIScreeningRequest();
        req.candidateId = cand.Id;

        Test.startTest();
        List<AIScreeningController.AIScreeningResult> results =
            AIScreeningController.runAIScreening(new List<AIScreeningController.AIScreeningRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
    }

    @IsTest
    static void testGetLatestResultSignature() {
        Candidate__c cand = createCandidate(false);
        insert new AI_Screening_Result__c(
            Candidate__c = cand.Id,
            Status__c = 'Completed',
            Overall_Score__c = 75,
            Recommendation__c = 'RECOMMEND'
        );

        Test.startTest();
        AI_Screening_Result__c latest = AIScreeningController.getLatestAIResult(cand.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, latest);
    }

    @IsTest
    static void testRunAIScreeningForCandidate_WithJobApp_NoActiveRules_Handled() {
        Job_Posting__c job = createJobPosting('NoRules');
        Candidate__c cand = new Candidate__c(
            Years_of_Experience__c = 6,
            Location__c = 'Austin',
            Resume_Status__c = true,
            Interested_in_Job__c = job.Id
        );
        insert cand;
        Job_Application__c jobApp = createJobApplication(cand.Id, job.Id);

        try {
            Test.startTest();
            AIScreeningController.runAIScreeningForCandidate(cand.Id, jobApp.Id);
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException when no active screening rules exist');
        } catch (AuraHandledException e) {
            System.assert(!String.isBlank(e.getMessage()), 'Expected handled message');
        }
    }

    @IsTest
    static void testRunAIScreeningForCandidate_WithJobApp_RichData_Success() {
        Job_Posting__c job = createJobPosting('Rich');
        Candidate__c cand = new Candidate__c(
            Years_of_Experience__c = 7,
            Location__c = 'Dallas',
            Resume_Status__c = true,
            Interested_in_Job__c = job.Id
        );
        insert cand;

        Job_Application__c jobApp = createJobApplication(cand.Id, job.Id);
        createActiveRule(job.Id);
        createScreeningResults(cand.Id, job.Id, 'corr-rich');
        addRelatedProfileData(cand.Id);
        Test.setMock(HttpCalloutMock.class, new GeminiCodeFenceMock());

        Test.startTest();
        Map<String, Object> runResult = AIScreeningController.runAIScreeningForCandidate(cand.Id, jobApp.Id);
        Test.stopTest();

        System.assertEquals(true, runResult.get('success'));
        Id aiResultId = (Id) runResult.get('resultId');
        System.assertNotEquals(null, aiResultId);

        AI_Screening_Result__c saved = [
            SELECT Job_Posting__c, Confidence_Level__c, Recommendation__c, Traditional_Score__c, Rules_Evaluated__c
            FROM AI_Screening_Result__c
            WHERE Id = :aiResultId
        ];
        System.assertEquals(job.Id, saved.Job_Posting__c);
        System.assertEquals('Very High', saved.Confidence_Level__c);
        System.assertEquals('STRONGLY_RECOMMEND', saved.Recommendation__c);
        System.assertEquals(50, Integer.valueOf(saved.Traditional_Score__c));
        System.assertEquals(1, saved.Rules_Evaluated__c);

        AI_Screening_Result__c latestByJobApp = AIScreeningController.getLatestAIResult(cand.Id, jobApp.Id);
        System.assertEquals(aiResultId, latestByJobApp.Id);
    }

    @IsTest
    static void testRunAIScreeningForCandidate_ParseFallback_UsesDefaults() {
        Candidate__c cand = createCandidate(false);
        Test.setMock(HttpCalloutMock.class, new GeminiPlainTextMock());

        Test.startTest();
        Map<String, Object> runResult = AIScreeningController.runAIScreeningForCandidate(cand.Id, null);
        Test.stopTest();

        System.assertEquals(true, runResult.get('success'));

        AI_Screening_Result__c saved = [
            SELECT Confidence_Level__c, Recommendation__c, Overall_Score__c
            FROM AI_Screening_Result__c
            WHERE Id = :((Id) runResult.get('resultId'))
        ];
        System.assertEquals('Low', saved.Confidence_Level__c);
        System.assertEquals('NEUTRAL', saved.Recommendation__c);
        System.assertEquals(50, Integer.valueOf(saved.Overall_Score__c));
    }
}
