@IsTest
private class EvaluateScreeningRulesTest {
    private static final String BACKGROUND_VERIFICATION_FEATURE = 'Background Verification';

    private static void upsertBackgroundVerificationFeature(Boolean isActive) {
        List<AIFeature__c> existing = [
            SELECT Id
            FROM AIFeature__c
            WHERE Name__c = :BACKGROUND_VERIFICATION_FEATURE
            LIMIT 1
        ];

        if (existing.isEmpty()) {
            insert new AIFeature__c(
                Name__c = BACKGROUND_VERIFICATION_FEATURE,
                Description__c = 'Controls AI in screening flow',
                IsActive__c = isActive
            );
        } else {
            update new AIFeature__c(
                Id = existing[0].Id,
                IsActive__c = isActive
            );
        }
    }

    private static Candidate__c createCandidate() {
        Candidate__c candidate = new Candidate__c(
            Full_Name__c = 'Screening Candidate',
            Email__c = 'screening.' + String.valueOf(DateTime.now().getTime()) + '@example.com'
        );
        insert candidate;
        return candidate;
    }

    private static Job_Posting__c createJobPosting() {
        Job_Posting__c posting = new Job_Posting__c(
            Name = 'Screening Posting'
        );
        insert posting;
        return posting;
    }

    private static Job_Application__c createJobApplication(Id candidateId, Id jobPostingId) {
        Job_Application__c jobApp = new Job_Application__c(
            Candidate__c = candidateId,
            Job_Posting__c = jobPostingId
        );
        insert jobApp;
        return jobApp;
    }

    private static EvaluateScreeningRules.Request buildRequest(Id jobApplicationId) {
        EvaluateScreeningRules.Request req = new EvaluateScreeningRules.Request();
        req.jobApplicationId = jobApplicationId;
        return req;
    }

    @IsTest
    static void testRun_WhenBackgroundVerificationDisabled() {
        upsertBackgroundVerificationFeature(false);
        Candidate__c candidate = createCandidate();
        Job_Posting__c posting = createJobPosting();
        Job_Application__c jobApp = createJobApplication(candidate.Id, posting.Id);

        List<EvaluateScreeningRules.Response> responses = EvaluateScreeningRules.run(
            new List<EvaluateScreeningRules.Request>{ buildRequest(jobApp.Id) }
        );

        System.assertEquals(1, responses.size(), 'Expected one response.');
        System.assertEquals('Queued', responses[0].status, 'Expected queued response.');
        System.assert(responses[0].message.contains('AI: Disabled'), 'Expected AI disabled message.');
    }

    @IsTest
    static void testRun_WhenBackgroundVerificationEnabled() {
        upsertBackgroundVerificationFeature(true);
        Candidate__c candidate = createCandidate();
        Job_Posting__c posting = createJobPosting();
        Job_Application__c jobApp = createJobApplication(candidate.Id, posting.Id);

        List<EvaluateScreeningRules.Response> responses = EvaluateScreeningRules.run(
            new List<EvaluateScreeningRules.Request>{ buildRequest(jobApp.Id) }
        );

        System.assertEquals(1, responses.size(), 'Expected one response.');
        System.assertEquals('Queued', responses[0].status, 'Expected queued response.');
        System.assert(responses[0].message.contains('AI: Enabled'), 'Expected AI enabled message.');
    }

    @IsTest
    static void testRun_WhenRequestHasNullJobApplicationId() {
        EvaluateScreeningRules.Request req = new EvaluateScreeningRules.Request();
        req.jobApplicationId = null;

        List<EvaluateScreeningRules.Response> responses = EvaluateScreeningRules.run(
            new List<EvaluateScreeningRules.Request>{ req }
        );

        System.assertEquals(0, responses.size(), 'Expected empty response for null request id.');
    }

    @IsTest
    static void testRun_WhenJobApplicationNotFound() {
        String keyPrefix = Job_Application__c.SObjectType.getDescribe().getKeyPrefix();
        Id missingJobAppId = (Id) (keyPrefix + '000000000000AAA');

        List<EvaluateScreeningRules.Response> responses = EvaluateScreeningRules.run(
            new List<EvaluateScreeningRules.Request>{ buildRequest(missingJobAppId) }
        );

        System.assertEquals(0, responses.size(), 'Expected empty response when job application does not exist.');
    }
}
