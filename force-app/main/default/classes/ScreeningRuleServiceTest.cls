@IsTest
private class ScreeningRuleServiceTest {
    private static Candidate__c createCandidate() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Rule Candidate',
            Email__c = 'rule.candidate@example.com',
            Location__c = 'New York',
            Years_of_Experience__c = 6
        );
        insert c;

        insert new License_Certification__c(
            Candidate__c = c.Id,
            Name = 'ACLS',
            Type__c = 'Certification'
        );
        insert new Work_Experience__c(
            Candidate__c = c.Id,
            Name = 'Experience 1',
            Role__c = 'Nurse',
            Organization__c = 'City Hospital'
        );
        return c;
    }

    @IsTest
    static void testEvaluateRules_CandidateAndRelatedRecords() {
        Candidate__c base = createCandidate();
        Candidate__c candidate = ScreeningDataLoader.loadCandidateWithAllRelations(base.Id);

        Screening_Rule__c r1 = new Screening_Rule__c(
            Name = 'Location contains',
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Location__c',
            Operator__c = 'Contains',
            Expected_Value__c = 'new',
            Action__c = 'AutoPass'
        );
        Screening_Rule__c r2 = new Screening_Rule__c(
            Name = 'Experience greater than',
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Years_of_Experience__c',
            Operator__c = 'Greater Than',
            Expected_Value__c = '3',
            Action__c = 'AutoPass'
        );
        Screening_Rule__c r3 = new Screening_Rule__c(
            Name = 'License match',
            Target_Object__c = 'License_Certification__c',
            Field_API_Name__c = 'Name',
            Operator__c = 'Contains',
            Expected_Value__c = 'acls',
            Match_Type__c = 'Any',
            Action__c = 'FlagForReview'
        );
        Screening_Rule__c r4 = new Screening_Rule__c(
            Name = 'Tech skill absent',
            Target_Object__c = 'Technical_Skill__c',
            Field_API_Name__c = 'Name',
            Operator__c = 'Contains',
            Expected_Value__c = 'epic',
            Match_Type__c = 'Any',
            Action__c = 'AutoFail'
        );
        Screening_Rule__c r5 = new Screening_Rule__c(
            Name = 'Location starts with',
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Location__c',
            Operator__c = 'Starts With',
            Expected_Value__c = 'new',
            Action__c = 'AutoPass'
        );
        Screening_Rule__c r6 = new Screening_Rule__c(
            Name = 'Location ends with',
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Location__c',
            Operator__c = 'Ends With',
            Expected_Value__c = 'york',
            Action__c = 'AutoPass'
        );
        Screening_Rule__c r7 = new Screening_Rule__c(
            Name = 'Location not equals',
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Location__c',
            Operator__c = 'Not Equals',
            Expected_Value__c = 'Chicago',
            Action__c = 'AutoPass'
        );
        Screening_Rule__c r8 = new Screening_Rule__c(
            Name = 'Route to jurisdiction',
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Location__c',
            Operator__c = 'Contains',
            Expected_Value__c = 'new',
            Action__c = 'RouteToJurisdiction'
        );

        Test.startTest();
        List<ScreeningRuleService.EvalResult> results =
            ScreeningRuleService.evaluateRules(
                new List<Screening_Rule__c>{ r1, r2, r3, r4, r5, r6, r7, r8 },
                candidate
            );
        Test.stopTest();

        System.assertEquals(8, results.size());
        System.assertEquals('Pass', results[0].outcome);
        System.assertEquals('Pass', results[1].outcome);
        System.assertEquals('Review', results[2].outcome);
        System.assertEquals('Fail', results[3].outcome);
        System.assertEquals('Pass', results[4].outcome);
        System.assertEquals('Pass', results[5].outcome);
        System.assertEquals('Pass', results[6].outcome);
        System.assertEquals('Review', results[7].outcome);
        System.assert(results[0].executionTimeMs >= 0);
    }

    @IsTest
    static void testEvaluateRules_NullFieldHandled() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Null Field Candidate',
            Email__c = 'null.field@example.com'
        );
        insert c;
        Candidate__c loaded = ScreeningDataLoader.loadCandidateWithAllRelations(c.Id);

        Screening_Rule__c nullFieldRule = new Screening_Rule__c(
            Name = 'Blank location',
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Location__c',
            Operator__c = 'Equals',
            Expected_Value__c = 'Austin',
            Action__c = 'AutoFail'
        );

        Test.startTest();
        List<ScreeningRuleService.EvalResult> results =
            ScreeningRuleService.evaluateRules(new List<Screening_Rule__c>{ nullFieldRule }, loaded);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Fail', results[0].outcome);
        System.assert(results[0].details.contains('null/empty'));
    }
}
