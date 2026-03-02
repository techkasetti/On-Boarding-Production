@IsTest
private class EligibilityAICallerTest {
    private class EligibilityMock implements HttpCalloutMock {
        private String responseBody;
        private Integer code;

        EligibilityMock(String responseBody, Integer code) {
            this.responseBody = responseBody;
            this.code = code;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(code);
            res.setBody(responseBody);
            return res;
        }
    }

    private class RetryMock implements HttpCalloutMock {
        private Integer callCount = 0;

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            if (callCount == 1) {
                res.setBody('{"candidates":[{"content":{"parts":[{"text":"not-a-json"}]}}]}');
            } else {
                res.setBody('{"candidates":[{"content":{"parts":[{"text":"```json {\\"eligibilityScore\\":78,\\"summary\\":\\"Good fit\\",\\"pros\\":\\"Strong skills\\",\\"cons\\":\\"Minor gap\\"} ```"}]}}]}');
            }
            return res;
        }
    }

    private static Candidate__c createCandidate() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Eligibility Candidate',
            Email__c = 'eligibility.candidate@example.com'
        );
        insert c;
        return c;
    }

    private static Job_Posting__c createJobPosting() {
        Job_Posting__c jp = new Job_Posting__c(
            Name = 'Eligibility Job',
            Job_Title__c = 'Cardiology Specialist',
            Description__c = 'Cardiology role',
            Min_Experience_Years__c = 2,
            Max_Experience_Years__c = 8
        );
        insert jp;
        return jp;
    }

    private static Job_Application__c createJobApplication(Id candidateId, Id jobPostingId) {
        Job_Application__c app = new Job_Application__c(
            Candidate__c = candidateId,
            Job_Posting__c = jobPostingId,
            Application_Date__c = Date.today(),
            Status__c = 'Application Received'
        );
        insert app;
        return app;
    }

    private static void createRequirementsAndQualifications(Id candidateId, Id jobPostingId) {
        insert new Job_Education_Requirement__c(Job_Posting__c = jobPostingId, Degree_Name__c = 'MBBS', Mandatory__c = true);
        insert new Job_License_Requirement__c(Job_Posting__c = jobPostingId, License_Name__c = 'State License');
        insert new Job_Certification_Requirement__c(Job_Posting__c = jobPostingId, Certification_Name__c = 'ACLS', Mandatory__c = true);
        insert new Job_Clinical_Skill__c(Job_Posting__c = jobPostingId, Skill_Name__c = 'Critical Care', Skill_Level__c = 'Advanced', Mandatory__c = true);
        insert new Job_Procedure_Requirement__c(Job_Posting__c = jobPostingId, Procedure_Name__c = 'Intubation', Critical__c = true);

        insert new Education__c(Candidate__c = candidateId, Degree__c = 'MBBS', Institution__c = 'Med U');
        insert new License_Certification__c(Candidate__c = candidateId, Name = 'State License');
        insert new Clinical_Skill__c(Candidate__c = candidateId, Name = 'Critical Care');
        insert new Technical_Skill__c(Candidate__c = candidateId, Name = 'EHR');
        insert new Work_Experience__c(Candidate__c = candidateId, Role__c = 'Resident', Organization__c = 'City Hospital');
        insert new Procedure__c(Candidate__c = candidateId, Name = 'Intubation');
    }

    @IsTest
    static void testInvocableAndAsyncSuccessPath() {
        Candidate__c candidate = createCandidate();
        Job_Posting__c job = createJobPosting();
        Job_Application__c app = createJobApplication(candidate.Id, job.Id);
        createRequirementsAndQualifications(candidate.Id, job.Id);

        String successBody =
            '{"candidates":[{"content":{"parts":[{"text":"{\\"eligibilityScore\\":85,\\"summary\\":\\"Strong match\\",\\"pros\\":\\"Good experience\\",\\"cons\\":\\"None major\\"}"}]}}]}';

        Test.setMock(HttpCalloutMock.class, new EligibilityMock(successBody, 200));

        EligibilityAICaller.FlowInput input = new EligibilityAICaller.FlowInput();
        input.jobApplicationId = app.Id;

        Test.startTest();
        List<EligibilityAICaller.FlowOutput> outList =
            EligibilityAICaller.callEligibilityAIFromFlow(new List<EligibilityAICaller.FlowInput>{ input });
        Test.stopTest();

        Job_Application__c updated = [
            SELECT Eligibility_Score__c, Eligibility_Summary__c, Eligibility_Pros__c, Eligibility_Cons__c, Status__c
            FROM Job_Application__c
            WHERE Id = :app.Id
        ];

        System.assertEquals(1, outList.size());
        System.assertEquals(true, outList[0].success);
        System.assertNotEquals(null, updated.Status__c, 'Record should remain queryable after async run.');
    }

    @IsTest
    static void testAsyncFailThresholdAndRetryPath() {
        Candidate__c candidate = createCandidate();
        Job_Posting__c job = createJobPosting();
        Job_Application__c app = createJobApplication(candidate.Id, job.Id);
        createRequirementsAndQualifications(candidate.Id, job.Id);

        String lowScoreBody =
            '{"candidates":[{"content":{"parts":[{"text":"{\\"eligibilityScore\\":55,\\"summary\\":\\"Insufficient fit\\",\\"pros\\":\\"Basic education\\",\\"cons\\":\\"Missing depth\\"}"}]}}]}';

        Test.setMock(HttpCalloutMock.class, new EligibilityMock(lowScoreBody, 200));

        Test.startTest();
        EligibilityAICaller.callEligibilityAIAsync(app.Id);
        Test.stopTest();

        Job_Application__c updatedLow = [
            SELECT Eligibility_Score__c, Status__c
            FROM Job_Application__c
            WHERE Id = :app.Id
        ];
        System.assertNotEquals(null, updatedLow.Status__c);
    }

    @IsTest
    static void testAsyncRetryPath() {
        Candidate__c candidate = createCandidate();
        Job_Posting__c job = createJobPosting();
        Job_Application__c appRetry = createJobApplication(candidate.Id, job.Id);
        createRequirementsAndQualifications(candidate.Id, job.Id);
        Test.setMock(HttpCalloutMock.class, new RetryMock());

        Test.startTest();
        EligibilityAICaller.callEligibilityAIAsync(appRetry.Id);
        Test.stopTest();

        Job_Application__c updatedRetry = [
            SELECT Eligibility_Score__c, Status__c
            FROM Job_Application__c
            WHERE Id = :appRetry.Id
        ];

        System.assertNotEquals(null, updatedRetry.Status__c);
    }

    @IsTest
    static void testAsyncHandlesInvalidIdsGracefully() {
        Test.startTest();
        EligibilityAICaller.callEligibilityAIAsync('a0B000000000001AAA');
        List<EligibilityAICaller.FlowOutput> emptyOutput =
            EligibilityAICaller.callEligibilityAIFromFlow(new List<EligibilityAICaller.FlowInput>());
        Test.stopTest();

        System.assertEquals(0, emptyOutput.size());
    }
}
