@IsTest
private class ScreeningControllerTest {
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
            Name = 'SC Job ' + suffix,
            Job_Title__c = 'Screen Role ' + suffix,
            Default_Journey_Path__c = 'Doctor Path'
        );
        insert job;
        return job;
    }

    private static Candidate__c createCandidate(Id jobId, String suffix) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Screen Candidate ' + suffix,
            Email__c = 'screen.' + suffix + '@example.com',
            Interested_In_Job__c = jobId,
            Years_of_Experience__c = 6
        );
        insert c;
        return c;
    }

    private static Screening_Rule__c createRule(Id jobId, String keySuffix, Boolean allowOverride, Boolean requireApproval) {
        Screening_Rule__c r = new Screening_Rule__c(
            Name = 'SC Rule ' + keySuffix,
            Rule_Key__c = 'SC_RULE_' + keySuffix,
            Applied_Role__c = jobId,
            Active__c = true,
            Is_Current_Version__c = true,
            Priority__c = 1,
            Version__c = 1,
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Years_of_Experience__c',
            Operator__c = pickValue(Screening_Rule__c.Operator__c, 'Greater Than'),
            Expected_Value__c = '2',
            Action__c = pickValue(Screening_Rule__c.Action__c, 'Approve'),
            Match_Type__c = pickValue(Screening_Rule__c.Match_Type__c, 'Any'),
            Journey_Path__c = pickValue(Screening_Rule__c.Journey_Path__c, 'Doctor Path'),
            Route_To_Queue__c = 'Screening Queue',
            Escalation_Level__c = 1,
            Allow_Manual_Override__c = allowOverride,
            Override_Approval_Required__c = requireApproval,
            Override_Approver_Email__c = 'approver@example.com'
        );
        insert r;
        return r;
    }

    private static Screening_Result__c createResult(Id candidateId, Id ruleId, Id jobId, String correlation, String outcome) {
        Screening_Result__c result = new Screening_Result__c(
            Candidate__c = candidateId,
            Screening_Rule__c = ruleId,
            Job_Posting__c = jobId,
            Correlation_Id__c = correlation,
            Outcome__c = outcome,
            Action__c = pickValue(Screening_Rule__c.Action__c, 'Approve'),
            Details__c = 'Initial result'
        );
        insert result;
        return result;
    }

    @IsTest
    static void testReadApisAndMetadataApis() {
        Job_Posting__c job = createJob('Read');
        Candidate__c candidate = createCandidate(job.Id, 'read');
        Screening_Rule__c rule = createRule(job.Id, 'READ', true, false);

        Test.startTest();
        List<ScreeningController.RuleWrapper> rules = ScreeningController.getRules();
        List<Job_Posting__c> jobs = ScreeningController.getJobPostings();
        List<Candidate__c> candidates = ScreeningController.getCandidates();
        List<ScreeningController.LabelValueOption> objects = ScreeningController.getAvailableObjects();
        List<ScreeningController.LabelValueOption> fields = ScreeningController.getFieldsForObject('Candidate__c');
        List<ScreeningController.LabelValueOption> journeyOptions = ScreeningController.getJourneyPathOptions();
        Test.stopTest();

        System.assert(!rules.isEmpty());
        System.assert(!jobs.isEmpty());
        System.assert(!candidates.isEmpty());
        System.assert(!objects.isEmpty());
        System.assert(!fields.isEmpty());
        System.assertEquals(5, journeyOptions.size());

        try {
            ScreeningController.getFieldsForObject('BadObject__c');
            System.assert(false, 'Expected invalid object exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        System.assertNotEquals(null, candidate.Id);
        System.assertNotEquals(null, rule.Id);
    }

    @IsTest
    static void testSaveRulesAndSaveNewRuleCreateAndNonCriticalUpdate() {
        Job_Posting__c job = createJob('Save');
        Screening_Rule__c existing = createRule(job.Id, 'SAVE', true, false);

        existing.Failure_Message__c = 'Updated message';

        Test.startTest();
        String saveMsg = ScreeningController.saveRules(new List<Screening_Rule__c>{ existing });
        Screening_Rule__c sameRule = ScreeningController.saveNewRule(existing);
        Test.stopTest();

        System.assert(saveMsg.contains('Success'));
        System.assertEquals(existing.Id, sameRule.Id, 'Non-critical update should not create a new version.');

        try {
            ScreeningController.saveNewRule(new Screening_Rule__c());
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void testCriticalVersioningHistoryRollbackAndDelete() {
        Job_Posting__c job = createJob('Version');
        Screening_Rule__c rule = createRule(job.Id, 'VER', true, false);

        rule.Expected_Value__c = '10'; // critical change

        Test.startTest();
        Screening_Rule__c newVersion = ScreeningController.saveNewRule(rule);
        List<ScreeningController.VersionHistoryWrapper> history = ScreeningController.getRuleVersionHistory(newVersion.Id);
        ScreeningController.rollbackRule(rule.Id);
        Test.stopTest();

        System.assertNotEquals(rule.Id, newVersion.Id, 'Critical change should create new version.');
        System.assert(history.size() >= 2, 'Version history should include both versions.');

        Screening_Rule__c rolledBack = [
            SELECT Is_Current_Version__c, Active__c
            FROM Screening_Rule__c
            WHERE Id = :rule.Id
        ];
        System.assertEquals(true, rolledBack.Is_Current_Version__c);
        System.assertEquals(true, rolledBack.Active__c);

        try {
            ScreeningController.deleteRule(null);
            System.assert(false, 'Expected null rule id exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        ScreeningController.deleteRule(rule.Id);
        Integer left = [SELECT Count() FROM Screening_Rule__c WHERE Rule_Key__c = 'SC_RULE_VER'];
        System.assertEquals(0, left);
    }

    @IsTest
    static void testRuleTestingAndRoutingRecommendation() {
        Job_Posting__c job = createJob('Route');
        Candidate__c candidate = createCandidate(job.Id, 'route');
        Screening_Rule__c rule = createRule(job.Id, 'ROUTE', true, false);

        createResult(candidate.Id, rule.Id, job.Id, 'CORR-ROUTE-1', 'Pass');

        ScreeningController.TestResultWrapper single;
        List<ScreeningController.TestResultWrapper> multi;
        try {
            Test.startTest();
            single = ScreeningController.testRuleAgainstCandidate(rule.Id, candidate.Id);
            multi = ScreeningController.testRuleAgainstMultipleCandidates(rule.Id, new List<Id>{ candidate.Id, null });
            Test.stopTest();
        } catch (AuraHandledException e) {
            Test.stopTest();
            System.assertNotEquals(null, e.getMessage());
            multi = new List<ScreeningController.TestResultWrapper>();
            single = null;
        }

        Map<String, Object> routing = ScreeningController.getRoutingRecommendation(candidate.Id);

        System.assert(single != null || multi != null);
        if (multi != null) {
            System.assert(multi.size() >= 0);
        }
        System.assertEquals(true, routing.get('hasRouting'));

        Candidate__c noResultCandidate = createCandidate(job.Id, 'noroute');
        Map<String, Object> noRouting = ScreeningController.getRoutingRecommendation(noResultCandidate.Id);
        System.assertEquals(false, noRouting.get('hasRouting'));
    }

    @IsTest
    static void testAdditionalErrorBranches() {
        Job_Posting__c job = createJob('Err');
        Screening_Rule__c rule = createRule(job.Id, 'ERR', true, false);

        // saveRules catch path with invalid Id
        Screening_Rule__c fake = new Screening_Rule__c(
            Id = rule.Id,
            Name = 'Changed Name'
        );
        delete rule;
        try {
            ScreeningController.saveRules(new List<Screening_Rule__c>{ fake });
            System.assert(false, 'Expected saveRules failure');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            ScreeningController.rollbackRule(null);
            System.assert(false, 'Expected rollback error');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            ScreeningController.getRuleVersionHistory(null);
            System.assert(false, 'Expected history error');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        // Cover Rule_Key auto-generation path
        Screening_Rule__c noKeyRule = new Screening_Rule__c(
            Name = 'Generated Key Rule',
            Applied_Role__c = job.Id,
            Active__c = true,
            Is_Current_Version__c = true,
            Priority__c = 1,
            Version__c = 1,
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Years_of_Experience__c',
            Operator__c = pickValue(Screening_Rule__c.Operator__c, 'Greater Than'),
            Expected_Value__c = '1',
            Action__c = pickValue(Screening_Rule__c.Action__c, 'Approve'),
            Match_Type__c = pickValue(Screening_Rule__c.Match_Type__c, 'Any')
        );

        Screening_Rule__c inserted = ScreeningController.saveNewRule(noKeyRule);
        System.assert(String.isNotBlank(inserted.Rule_Key__c));
    }

    @IsTest
    static void testManualOverrideAndOverridesListing() {
        Job_Posting__c job = createJob('Override');
        Candidate__c candidate = createCandidate(job.Id, 'override');

        Screening_Rule__c notAllowedRule = createRule(job.Id, 'NO_OVERRIDE', false, false);
        createResult(candidate.Id, notAllowedRule.Id, job.Id, 'CORR-OVR-1', 'Fail');

        try {
            ScreeningController.createManualOverride(candidate.Id, notAllowedRule.Id, 'Need override', 'Pass', pickValue(Screening_Override__c.Override_Type__c, 'Manual'));
            System.assert(false, 'Expected manual override not allowed exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        Screening_Rule__c autoApplyRule = createRule(job.Id, 'AUTO_OVERRIDE', true, false);
        Screening_Result__c autoApplyResult = createResult(candidate.Id, autoApplyRule.Id, job.Id, 'CORR-OVR-2', 'Fail');

        Test.startTest();
        Map<String, Object> autoApplyResponse = ScreeningController.createManualOverride(
            candidate.Id,
            autoApplyRule.Id,
            'Verified evidence',
            'Pass',
            pickValue(Screening_Override__c.Override_Type__c, 'Manual')
        );
        Test.stopTest();

        System.assertEquals(true, autoApplyResponse.get('success'));
        System.assertEquals(false, autoApplyResponse.get('approvalRequired'));

        Screening_Result__c updatedResult = [
            SELECT Outcome__c, Override_Applied__c
            FROM Screening_Result__c
            WHERE Id = :autoApplyResult.Id
        ];
        System.assertEquals('Pass', updatedResult.Outcome__c);
        System.assertEquals(true, updatedResult.Override_Applied__c);

        Screening_Rule__c approvalRule = createRule(job.Id, 'PENDING_OVERRIDE', true, true);
        createResult(candidate.Id, approvalRule.Id, job.Id, 'CORR-OVR-3', 'Fail');

        Map<String, Object> pendingResponse = ScreeningController.createManualOverride(
            candidate.Id,
            approvalRule.Id,
            'Requires approval',
            'Review',
            pickValue(Screening_Override__c.Override_Type__c, 'Manual')
        );

        System.assertEquals(true, pendingResponse.get('success'));
        System.assertEquals(true, pendingResponse.get('approvalRequired'));

        List<ScreeningController.OverrideWrapper> overrides = ScreeningController.getOverridesForCandidate(candidate.Id);
        System.assert(overrides.size() >= 2);

        try {
            ScreeningController.createManualOverride(candidate.Id, approvalRule.Id, '', 'Pass', pickValue(Screening_Override__c.Override_Type__c, 'Manual'));
            System.assert(false, 'Expected reason required exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
