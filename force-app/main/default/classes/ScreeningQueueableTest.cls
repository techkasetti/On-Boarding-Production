@IsTest
private class ScreeningQueueableTest {
    private static String firstPicklistValue(Schema.SObjectField fieldToken) {
        List<Schema.PicklistEntry> entries = fieldToken.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry pe : entries) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }

    private static Job_Posting__c createJobPosting(String suffix) {
        Job_Posting__c job = new Job_Posting__c(
            Name = 'SQ Job ' + suffix,
            Job_Title__c = 'Nurse ' + suffix
        );
        insert job;
        return job;
    }

    private static Candidate__c createCandidate(Id jobId, String suffix) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'SQ Candidate ' + suffix,
            Email__c = 'sq.' + suffix + '@example.com',
            Interested_In_Job__c = jobId,
            Years_of_Experience__c = 5
        );
        insert c;
        return c;
    }

    private static Screening_Rule__c createRule(Id jobId, String expectedVal) {
        Screening_Rule__c rule = new Screening_Rule__c(
            Name = 'Min Experience Rule',
            Rule_Key__c = 'SQ_RULE_' + String.valueOf(Crypto.getRandomInteger()),
            Applied_Role__c = jobId,
            Active__c = true,
            Is_Current_Version__c = true,
            Test_Mode_Only__c = false,
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Years_of_Experience__c',
            Operator__c = 'Greater Than',
            Expected_Value__c = expectedVal,
            Action__c = 'Approve',
            Match_Type__c = 'Any',
            Priority__c = 1,
            Version__c = 1
        );
        insert rule;
        return rule;
    }

    @IsTest
    static void testExecuteWithEmptyMap() {
        Test.startTest();
        System.enqueueJob(new ScreeningQueueable(new Map<Id, Id>()));
        Test.stopTest();

        System.assert(true, 'Queueable should safely return when map is empty.');
    }

    @IsTest
    static void testRuleBasedFlowAndJobApplicationUpdate() {
        Job_Posting__c job = createJobPosting('Rule');
        Candidate__c candidate = createCandidate(job.Id, 'rule');
        createRule(job.Id, '2');

        String appStatus = firstPicklistValue(Job_Application__c.Status__c);
        Job_Application__c app = new Job_Application__c(
            Candidate__c = candidate.Id,
            Job_Posting__c = job.Id,
            Application_Date__c = Date.today(),
            Status__c = appStatus
        );
        insert app;

        Map<Id, Id> candToJob = new Map<Id, Id>{ candidate.Id => job.Id };
        Map<Id, Id> candToApp = new Map<Id, Id>{ candidate.Id => app.Id };

        Test.startTest();
        System.enqueueJob(new ScreeningQueueable(candToJob, false, candToApp));
        Test.stopTest();

        List<Screening_Result__c> results = [
            SELECT Id, Outcome__c, Correlation_Id__c
            FROM Screening_Result__c
            WHERE Candidate__c = :candidate.Id
        ];
        System.assertEquals(1, results.size(), 'Expected one screening result.');
        System.assertEquals('Pass', results[0].Outcome__c, 'Rule should pass for 5 > 2.');

        Candidate__c updatedCandidate = [
            SELECT Screening_Status__c, Latest_Correlation_Id__c, Total_Rules_Evaluated__c
            FROM Candidate__c
            WHERE Id = :candidate.Id
        ];
        System.assertEquals('Passed', updatedCandidate.Screening_Status__c);
        System.assertNotEquals(null, updatedCandidate.Latest_Correlation_Id__c);
        System.assertEquals(1, Integer.valueOf(updatedCandidate.Total_Rules_Evaluated__c));

        Job_Application__c updatedApp = [
            SELECT Screening_Result__c, Screening_Score__c
            FROM Job_Application__c
            WHERE Id = :app.Id
        ];
        System.assertEquals('Pass', updatedApp.Screening_Result__c);
        System.assertEquals(100, updatedApp.Screening_Score__c);
    }

    @IsTest
    static void testAiOnlyModeUpdatesApplicationFromRuleScore() {
        Job_Posting__c job = createJobPosting('AIOnly');
        Candidate__c candidate = createCandidate(job.Id, 'aionly');

        String appStatus = firstPicklistValue(Job_Application__c.Status__c);
        Job_Application__c app = new Job_Application__c(
            Candidate__c = candidate.Id,
            Job_Posting__c = job.Id,
            Application_Date__c = Date.today(),
            Status__c = appStatus
        );
        insert app;

        Map<Id, Id> candToApp = new Map<Id, Id>{ candidate.Id => app.Id };
        Map<Id, Decimal> ruleScores = new Map<Id, Decimal>{ candidate.Id => 88 };

        Test.startTest();
        System.enqueueJob(new ScreeningQueueable(candToApp, ruleScores, 'AI_ONLY'));
        Test.stopTest();

        Job_Application__c updatedApp = [
            SELECT Screening_Result__c, Screening_Score__c
            FROM Job_Application__c
            WHERE Id = :app.Id
        ];

        System.assertEquals('Pass', updatedApp.Screening_Result__c, 'AI-only flow should finalize based on score.');
        System.assertEquals(88, updatedApp.Screening_Score__c);
    }

    @IsTest
    static void testNoRulesPathUpdatesCandidateAsNotScreened() {
        Job_Posting__c job = createJobPosting('NoRules');
        Candidate__c candidate = createCandidate(job.Id, 'norules');

        Map<Id, Id> candToJob = new Map<Id, Id>{ candidate.Id => job.Id };

        Test.startTest();
        System.enqueueJob(new ScreeningQueueable(candToJob));
        Test.stopTest();

        Candidate__c updated = [
            SELECT Screening_Status__c, Last_Result_Summary__c
            FROM Candidate__c
            WHERE Id = :candidate.Id
        ];
        System.assertEquals('Not Screened', updated.Screening_Status__c);
        System.assert(updated.Last_Result_Summary__c.contains('No active screening rules'));
    }
}
