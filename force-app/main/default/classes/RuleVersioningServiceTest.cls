@IsTest
private class RuleVersioningServiceTest {
    private static Screening_Rule__c createRule(Id jobId) {
        Screening_Rule__c r = new Screening_Rule__c(
            Name = 'Version Rule',
            Rule_Key__c = 'VERSION_RULE',
            Applied_Role__c = jobId,
            Active__c = true,
            Is_Current_Version__c = true,
            Priority__c = 1,
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Full_Name__c',
            Operator__c = 'Contains',
            Expected_Value__c = 'A',
            Rule_Category__c = 'Experience',
            Journey_Path__c = 'Doctor Path'
        );
        insert r;
        return r;
    }

    @IsTest
    static void testVersioningFlow() {
        Job_Posting__c job = new Job_Posting__c(Name = 'Version Job');
        insert job;
        Screening_Rule__c base = createRule(job.Id);

        Test.startTest();
        Screening_Rule__c newV = RuleVersioningService.createNewVersion(base.Id, 'v2');
        List<Screening_Rule__c> history = RuleVersioningService.getVersionHistory(base.Id);
        RuleVersioningService.rollbackToVersion(newV.Id);
        RuleVersioningService.backfillRuleKeys();
        Test.stopTest();

        System.assertNotEquals(null, newV.Id);
        System.assert(!history.isEmpty());
    }

    @IsTest
    static void testNullGuards() {
        try {
            RuleVersioningService.createNewVersion(null, 'x');
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            RuleVersioningService.getVersionHistory(null);
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
