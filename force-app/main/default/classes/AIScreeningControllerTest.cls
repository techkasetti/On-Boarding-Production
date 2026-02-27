@IsTest
private class AIScreeningControllerTest {

    /* =====================================================
       🔥 GEMINI SUCCESS MOCK
       ===================================================== */
    private class GeminiSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            res.setBody(
            '{' +
            ' "candidates": [' +
            '   {' +
            '     "content": {' +
            '       "parts": [' +
            '         {' +
            '           "text": "{ \\"overallScore\\": 88, \\"confidenceLevel\\": \\"High\\", \\"recommendation\\": \\"RECOMMEND\\", \\"quickSummary\\": \\"Strong\\", \\"fullAnalysis\\": \\"Detailed\\", \\"strengths\\": [\\"A\\",\\"B\\",\\"C\\"], \\"concerns\\": [\\"X\\",\\"Y\\"] }"' +
            '         }' +
            '       ]' +
            '     }' +
            '   }' +
            ' ],' +
            ' "usageMetadata": { "totalTokenCount": 30 }' +
            '}'
            );

            return res;
        }
    }

    /* =====================================================
       🔥 CODE FENCE MOCK
       ===================================================== */
    private class GeminiCodeFenceMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            res.setBody(
            '{' +
            ' "candidates": [' +
            '   {' +
            '     "content": {' +
            '       "parts": [' +
            '         {' +
            '           "text": "```json { \\"overallScore\\": 85, \\"confidenceLevel\\": \\"High\\", \\"recommendation\\": \\"RECOMMEND\\", \\"strengths\\": [\\"A\\"], \\"concerns\\": [\\"B\\"] } ```"' +
            '         }' +
            '       ]' +
            '     }' +
            '   }' +
            ' ],' +
            ' "usageMetadata": { "totalTokenCount": 10 }' +
            '}'
            );

            return res;
        }
    }

    /* =====================================================
       🔥 INVALID JSON MOCK (Catch block)
       ===================================================== */
    private class GeminiInvalidMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            res.setBody(
            '{' +
            ' "candidates": [' +
            '   {' +
            '     "content": {' +
            '       "parts": [{ "text": "INVALID JSON TEXT" }]' +
            '     }' +
            '   }' +
            ' ],' +
            ' "usageMetadata": { "totalTokenCount": 10 }' +
            '}'
            );

            return res;
        }
    }

    /* =====================================================
       🔥 API FAILURE MOCK
       ===================================================== */
    private class GeminiFailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server Error');
            return res;
        }
    }

    /* =====================================================
       🔥 TEST DATA
       ===================================================== */
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

        if (withJob) {
            insert new Work_Experience__c(
                Candidate__c = cand.Id,
                Organization__c = 'Test Org',
                Duration_Text__c = '3 years'
            );

            insert new Screening_Rule__c(
                Name = 'Rule',
                Target_Object__c = 'Candidate__c',
                Field_API_Name__c = 'Years_of_Experience__c',
                Operator__c = 'GREATER_THAN',
                Expected_Value__c = '3',
                Active__c = true,
                Rule_Category__c = 'Qualification',
                Priority__c = 1,
                Applied_Role__c = job.Id,
                Rule_Key__c = 'R1',
                Override_Approver_Email__c = 'test@test.com'
            );
        }

        return cand;
    }

    /* =====================================================
       🔥 TESTS
       ===================================================== */

    @IsTest
    static void testSuccessFlow() {
        Candidate__c cand = createCandidate(true);
        Test.setMock(HttpCalloutMock.class, new GeminiSuccessMock());

        Test.startTest();
        AIScreeningController.runAIScreeningForCandidate(cand.Id);
        Test.stopTest();
    }

    @IsTest
    static void testCodeFenceBranch() {
        Candidate__c cand = createCandidate(true);
        Test.setMock(HttpCalloutMock.class, new GeminiCodeFenceMock());

        Test.startTest();
        AIScreeningController.runAIScreeningForCandidate(cand.Id);
        Test.stopTest();
    }

    @IsTest
    static void testInvalidJsonBranch() {
        Candidate__c cand = createCandidate(true);
        Test.setMock(HttpCalloutMock.class, new GeminiInvalidMock());

        Test.startTest();
        AIScreeningController.runAIScreeningForCandidate(cand.Id);
        Test.stopTest();
    }

    @IsTest
    static void testApiFailureBranch() {
        Candidate__c cand = createCandidate(true);
        Test.setMock(HttpCalloutMock.class, new GeminiFailureMock());

        Test.startTest();
        AIScreeningController.runAIScreeningForCandidate(cand.Id);
        Test.stopTest();
    }

    /* 🔥 Cover getApplicableRules null job branch */
    @IsTest
    static void testNoJobBranch() {
        Candidate__c cand = createCandidate(false);
        Test.setMock(HttpCalloutMock.class, new GeminiSuccessMock());

        Test.startTest();
        AIScreeningController.runAIScreeningForCandidate(cand.Id);
        Test.stopTest();
    }

    /* 🔥 Cover normalizeConfidenceLevel moderate branch */
    @IsTest
    static void testConfidenceModerateBranch() {
        System.assertEquals(
            'Medium',
            AIScreeningController.normalizeConfidenceLevel('moderate confidence')
        );
    }

    /* 🔥 Cover normalizeRecommendation unknown branch */
    @IsTest
    static void testUnknownRecommendationBranch() {
        System.assertEquals(
            'NEUTRAL',
            AIScreeningController.normalizeRecommendation('something weird')
        );
    }

    @IsTest
    static void testInvocable() {
        Candidate__c cand = createCandidate(true);
        Test.setMock(HttpCalloutMock.class, new GeminiSuccessMock());

        AIScreeningController.AIScreeningRequest req =
            new AIScreeningController.AIScreeningRequest();
        req.candidateId = cand.Id;

        Test.startTest();
        AIScreeningController.runAIScreening(
            new List<AIScreeningController.AIScreeningRequest>{ req }
        );
        Test.stopTest();
    }

    @IsTest
    static void testGetLatest() {
        Candidate__c cand = createCandidate(true);

        insert new AI_Screening_Result__c(
            Candidate__c = cand.Id,
            Status__c = 'Completed',
            Overall_Score__c = 75,
            Recommendation__c = 'RECOMMEND'
        );

        Test.startTest();
        AIScreeningController.getLatestAIResult(cand.Id);
        Test.stopTest();
    }
}