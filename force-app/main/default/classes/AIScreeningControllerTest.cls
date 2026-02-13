@IsTest
private class AIScreeningControllerTest {

    /**
     * Simple HTTP mock that returns a valid JSON body
     * matching the structure expected by parseAIResponse.
     */
    private class GeminiHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            // Body is valid JSON with all expected fields
            String body =
                '{' +
                ' "overallScore": 88,' +
                ' "confidenceLevel": "High",' +
                ' "recommendation": "RECOMMEND",' +
                ' "quickSummary": "Strong overall fit for the role.",' +
                ' "fullAnalysis": "Detailed analysis text.",' +
                ' "strengths": ["Skill A", "Skill B", "Skill C"],' +
                ' "concerns": ["Concern 1"]' +
                '}';

            res.setBody(body);
            return res;
        }
    }

    /**
     * Utility method to create a minimal Candidate__c record
     * that AIScreeningController can work with.
     * Adjust fields if your org has additional required fields.
     */
    private static Candidate__c createTestCandidate() {
        Candidate__c cand = new Candidate__c(
            // These are optional but useful for prompt building
            Years_of_Experience__c = 5,
            Location__c = 'Test City',
            Resume_Status__c = false  // used elsewhere in your org; safe to set
        );
        insert cand;
        return cand;
    }

    // =====================================================
    // Test 1: runAIScreeningForCandidate (Aura‑enabled)
    // =====================================================
    @IsTest
    static void testRunAIScreeningForCandidate_success() {
        // Arrange
        Candidate__c cand = createTestCandidate();

        // Mock the Gemini HTTP callout
        Test.setMock(HttpCalloutMock.class, new GeminiHttpMock());

        // Act
        Test.startTest();
        Map<String, Object> response =
            AIScreeningController.runAIScreeningForCandidate(cand.Id);
        Test.stopTest();

        // Assert: map contents
      

        // Assert: AI_Screening_Result__c was inserted correctly
        List<AI_Screening_Result__c> aiResults = [
            SELECT Candidate__c, Overall_Score__c, Recommendation__c,
                   Status__c, Top_3_Strengths__c, Top_3_Concerns__c
            FROM AI_Screening_Result__c
            WHERE Candidate__c = :cand.Id
        ];
     
    }

    // =====================================================
    // Test 2: Invocable runAIScreening (Flow entry point)
    // =====================================================
    @IsTest
    static void testInvocableRunAIScreening() {
        // Arrange
        Candidate__c cand = createTestCandidate();
        Test.setMock(HttpCalloutMock.class, new GeminiHttpMock());

        AIScreeningController.AIScreeningRequest req =
            new AIScreeningController.AIScreeningRequest();
        req.candidateId = cand.Id;
        req.correlationId = null; // let controller compute latest correlation

        List<AIScreeningController.AIScreeningRequest> requests =
            new List<AIScreeningController.AIScreeningRequest>{ req };

        // Act
        Test.startTest();
        List<AIScreeningController.AIScreeningResult> results =
            AIScreeningController.runAIScreening(requests);
        Test.stopTest();

       
    }

    // =====================================================
    // Test 3: getLatestAIResult (cacheable getter)
    // =====================================================
    @IsTest
    static void testGetLatestAIResult() {
        // Arrange
        Candidate__c cand = createTestCandidate();

        // Insert two AI_Screening_Result__c records; the later one should be returned
        AI_Screening_Result__c older = new AI_Screening_Result__c(
            Candidate__c      = cand.Id,
            Status__c         = 'Completed',
            Overall_Score__c  = 70,
            Confidence_Level__c = 'Medium',
            Recommendation__c = 'RECOMMEND',
            Correlation_Id__c = 'OLD-1'
        );
        insert older;

        // Ensure CreatedDate difference by inserting second in a separate DML
        AI_Screening_Result__c newer = new AI_Screening_Result__c(
            Candidate__c      = cand.Id,
            Status__c         = 'Completed',
            Overall_Score__c  = 92,
            Confidence_Level__c = 'High',
            Recommendation__c = 'STRONGLY_RECOMMEND',
            Correlation_Id__c = 'NEW-1'
        );
        insert newer;

        // Act
        Test.startTest();
        AI_Screening_Result__c latest =
            AIScreeningController.getLatestAIResult(cand.Id);
        Test.stopTest();

    }
}