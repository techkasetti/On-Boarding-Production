@IsTest
private class CandidateStatusControllerTest {
    private static String firstPicklistValue(Schema.SObjectField fieldToken) {
        List<Schema.PicklistEntry> entries = fieldToken.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry pe : entries) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return null;
    }

    private static Job_Posting__c createJob(String suffix) {
        Job_Posting__c job = new Job_Posting__c(
            Name = 'Status Job ' + suffix,
            Job_Title__c = 'Doctor ' + suffix
        );
        insert job;
        return job;
    }

    private static Candidate__c createCandidate(Id jobId, String suffix) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Status Candidate ' + suffix,
            Email__c = 'status.' + suffix + '@example.com',
            Interested_In_Job__c = jobId,
            Screening_Status__c = 'Passed'
        );
        insert c;
        return c;
    }

    private static Screening_Rule__c createRule(Id jobId, String name, String action, Integer priority, Integer escalation) {
        String journey = firstPicklistValue(Screening_Rule__c.Journey_Path__c);
        Screening_Rule__c rule = new Screening_Rule__c(
            Name = name,
            Rule_Key__c = 'CS_RULE_' + String.valueOf(Crypto.getRandomInteger()),
            Applied_Role__c = jobId,
            Active__c = true,
            Is_Current_Version__c = true,
            Test_Mode_Only__c = false,
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Years_of_Experience__c',
            Operator__c = 'Greater Than',
            Expected_Value__c = '2',
            Action__c = action,
            Priority__c = priority,
            Version__c = 1,
            Journey_Path__c = journey,
            Route_To_Queue__c = 'Screening Queue',
            Escalation_Level__c = escalation,
            Allow_Manual_Override__c = true
        );
        insert rule;
        return rule;
    }

    @IsTest
    static void testGetJobApplicationsAndDetailedStatus() {
        String routingJourney = firstPicklistValue(Routing_Decision__c.Journey_Path__c);
        Job_Posting__c job = createJob('Main');
        Candidate__c candidate = createCandidate(job.Id, 'main');

        Job_Application__c app = new Job_Application__c(
            Candidate__c = candidate.Id,
            Job_Posting__c = job.Id,
            Application_Date__c = Date.today(),
            Status__c = 'Application Received',
            Screening_Result__c = 'Pass',
            Screening_Score__c = 92
        );
        insert app;

        Screening_Rule__c passRule = createRule(job.Id, 'Experience Rule', 'Approve', 1, 1);

        String correlation = 'CORR-001';
        insert new Screening_Result__c(
            Candidate__c = candidate.Id,
            Screening_Rule__c = passRule.Id,
            Job_Posting__c = job.Id,
            Outcome__c = 'Pass',
            Details__c = 'Pass detail',
            Action__c = 'Approve',
            Correlation_Id__c = correlation,
            Actual_Value__c = '5',
            Expected_Value__c = '2',
            Override_Applied__c = false
        );

        insert new Routing_Decision__c(
            Candidate__c = candidate.Id,
            Job_Posting__c = job.Id,
            Journey_Path__c = routingJourney,
            Assigned_Queue__c = 'Screening Queue',
            Escalation_Level__c = 1,
            Decision_Reason__c = 'All clear',
            Required_Actions__c = 'Proceed',
            Correlation_Id__c = correlation,
            Decision_Date__c = System.now(),
            Decision_Made_By__c = UserInfo.getUserId(),
            Status__c = 'Pending'
        );

        insert new Screening_Override__c(
            Candidate__c = candidate.Id,
            Screening_Rule__c = passRule.Id,
            Original_Outcome__c = 'Fail',
            New_Outcome__c = 'Pass',
            Override_Reason__c = 'Verified manually',
            Approval_Status__c = 'Approved',
            Override_By__c = UserInfo.getUserId(),
            Override_Date__c = System.now()
        );

        Test.startTest();
        List<CandidateStatusController.JobApplicationWrapper> wrappers =
            CandidateStatusController.getJobApplicationsForCandidate(candidate.Id);
        CandidateStatusController.CandidateStatusDto emptyDto =
            CandidateStatusController.getCandidateStatus(candidate.Id, null);
        CandidateStatusController.CandidateStatusDto dto =
            CandidateStatusController.getCandidateStatus(candidate.Id, app.Id);
        Test.stopTest();

        System.assertEquals(1, wrappers.size());
        System.assertEquals(app.Id, wrappers[0].jobApplicationId);

        System.assertEquals(candidate.Id, emptyDto.candidateId);
        System.assertEquals(0, emptyDto.results.size(), 'No job application id should return empty results.');

        System.assertEquals(1, dto.results.size());
        System.assertEquals(1, dto.totalRules);
        System.assertEquals(1, dto.rulesPassed);
        System.assertEquals(0, dto.rulesFailed);
        System.assertEquals(0, dto.rulesReview);
        System.assertNotEquals(null, dto.routingInfo);
        System.assertEquals(routingJourney, dto.routingInfo.get('journeyPath'));
        System.assertEquals(1, dto.overrides.size());
        System.assertEquals(passRule.Id, dto.results[0].ruleId);
        System.assertEquals(true, dto.results[0].allowManualOverride);
    }

    @IsTest
    static void testRerunScreeningPositiveAndNegativePaths() {
        Job_Posting__c jobWithRule = createJob('WithRule');
        Candidate__c candidateWithRule = createCandidate(jobWithRule.Id, 'withrule');
        candidateWithRule.Years_of_Experience__c = 6;
        update candidateWithRule;

        Job_Application__c appWithRule = new Job_Application__c(
            Candidate__c = candidateWithRule.Id,
            Job_Posting__c = jobWithRule.Id,
            Application_Date__c = Date.today(),
            Status__c = 'Application Received'
        );
        insert appWithRule;

        createRule(jobWithRule.Id, 'Rerun Rule', 'Approve', 1, 1);

        Job_Posting__c jobNoRule = createJob('NoRule');
        Candidate__c candidateNoRule = createCandidate(jobNoRule.Id, 'norule');

        Test.startTest();
        CandidateStatusController.rerunScreening(null, appWithRule.Id);
        CandidateStatusController.rerunScreening(candidateWithRule.Id, null);
        Test.stopTest();

        Integer runCount = [
            SELECT Count()
            FROM Screening_Result__c
            WHERE Candidate__c = :candidateWithRule.Id
        ];
        System.assert(runCount > 0, 'Rerun should generate screening results.');

        try {
            CandidateStatusController.rerunScreening(candidateNoRule.Id, null);
            System.assert(false, 'Expected no-rules validation exception');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            CandidateStatusController.getJobApplicationsForCandidate(null);
            System.assert(false, 'Expected candidateId required exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            CandidateStatusController.getCandidateStatus(null, null);
            System.assert(false, 'Expected candidateId required exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
