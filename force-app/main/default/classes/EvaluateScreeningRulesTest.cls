@IsTest
private class EvaluateScreeningRulesTest {
    private static String pickValue(Schema.SObjectField fieldToken, String preferred) {
        List<Schema.PicklistEntry> entries = fieldToken.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry pe : entries) {
            if (pe.isActive() && pe.getValue() == preferred) {
                return pe.getValue();
            }
        }
        for (Schema.PicklistEntry pe : entries) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return preferred;
    }

    private static Job_Posting__c createJob(String suffix) {
        Job_Posting__c job = new Job_Posting__c(
            Name = 'Eval Job ' + suffix,
            Job_Title__c = 'Eval Role ' + suffix
        );
        insert job;
        return job;
    }

    private static Candidate__c createCandidate(Id jobId, String suffix) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Eval Candidate ' + suffix,
            Email__c = 'eval.' + suffix + '@example.com',
            Interested_In_Job__c = jobId,
            Years_of_Experience__c = 5
        );
        insert c;
        return c;
    }

    private static void createActiveRule(Id jobPostingId, String suffix) {
        Screening_Rule__c rule = new Screening_Rule__c(
            Name = 'Eval Active Rule ' + suffix,
            Rule_Key__c = 'EVAL_ACTIVE_' + suffix,
            Applied_Role__c = jobPostingId,
            Active__c = true,
            Is_Current_Version__c = true,
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Years_of_Experience__c',
            Operator__c = pickValue(Screening_Rule__c.Operator__c, 'Greater Than'),
            Expected_Value__c = '2',
            Action__c = pickValue(Screening_Rule__c.Action__c, 'Approve'),
            Match_Type__c = pickValue(Screening_Rule__c.Match_Type__c, 'Any'),
            Priority__c = 1,
            Version__c = 1
        );
        insert rule;
    }

    @IsTest
    static void testRunEmptyAndNullRequests() {
        EvaluateScreeningRules.Request req = new EvaluateScreeningRules.Request();
        req.jobApplicationId = null;

        Test.startTest();
        List<EvaluateScreeningRules.Response> responses =
            EvaluateScreeningRules.run(new List<EvaluateScreeningRules.Request>{ req });
        Test.stopTest();

        System.assertEquals(0, responses.size());
    }

    @IsTest
    static void testRunQueuedRowsAiDisabled() {
        Job_Posting__c job = createJob('Disabled');
        Candidate__c candidate = createCandidate(job.Id, 'disabled');
        createActiveRule(job.Id, 'disabled');

        Job_Application__c validApp = new Job_Application__c(
            Candidate__c = candidate.Id,
            Job_Posting__c = job.Id,
            Application_Date__c = Date.today(),
            Status__c = 'Application Received'
        );
        insert validApp;

        List<EvaluateScreeningRules.Request> reqs = new List<EvaluateScreeningRules.Request>();
        for (Id appId : new List<Id>{ validApp.Id }) {
            EvaluateScreeningRules.Request r = new EvaluateScreeningRules.Request();
            r.jobApplicationId = appId;
            reqs.add(r);
        }

        Test.startTest();
        List<EvaluateScreeningRules.Response> responses = EvaluateScreeningRules.run(reqs);
        Test.stopTest();

        System.assertEquals(1, responses.size());

        Integer queuedCount = 0;
        for (EvaluateScreeningRules.Response res : responses) {
            if (res.status == 'Queued') {
                queuedCount++;
                System.assert(res.message.contains('AI: Disabled'));
            }
        }
        System.assertEquals(1, queuedCount);
    }

    @IsTest
    static void testRunQueuedWithAiEnabled() {
        insert new AI_Features__c(
            Name = 'Background Verification',
            Is_EnableorDesable__c = true
        );

        Job_Posting__c job = createJob('Enabled');
        Candidate__c candidate = createCandidate(job.Id, 'enabled');
        createActiveRule(job.Id, 'enabled');

        Job_Application__c app = new Job_Application__c(
            Candidate__c = candidate.Id,
            Job_Posting__c = job.Id,
            Application_Date__c = Date.today(),
            Status__c = 'Application Received'
        );
        insert app;

        EvaluateScreeningRules.Request req = new EvaluateScreeningRules.Request();
        req.jobApplicationId = app.Id;

        Test.startTest();
        List<EvaluateScreeningRules.Response> responses =
            EvaluateScreeningRules.run(new List<EvaluateScreeningRules.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals('Queued', responses[0].status);
        System.assert(responses[0].message.contains('AI: Enabled'));
    }

    @IsTest
    static void testRunWithUnknownJobApplicationId() {
        EvaluateScreeningRules.Request req = new EvaluateScreeningRules.Request();
        req.jobApplicationId = 'a0B000000000001AAA';

        Test.startTest();
        List<EvaluateScreeningRules.Response> responses =
            EvaluateScreeningRules.run(new List<EvaluateScreeningRules.Request>{ req });
        Test.stopTest();

        System.assertEquals(0, responses.size(), 'Unknown job app ids should produce no queued responses.');
    }
}
