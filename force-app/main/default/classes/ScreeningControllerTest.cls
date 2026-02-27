@IsTest
private class ScreeningControllerTest {
    private static Screening_Rule__c createRule(Id jobId) {
        Screening_Rule__c r = new Screening_Rule__c(
            Name = 'SC Rule',
            Rule_Key__c = 'SC_RULE_1',
            Applied_Role__c = jobId,
            Active__c = true,
            Is_Current_Version__c = true,
            Priority__c = 1,
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Full_Name__c',
            Operator__c = 'Contains',
            Expected_Value__c = 'Screen',
            Action__c = 'AutoFail',
            Rule_Category__c = 'Experience',
            Journey_Path__c = 'Doctor Path'
        );
        insert r;
        return r;
    }

    @IsTest
    static void testReadAndSaveBasics() {
        Job_Posting__c job = new Job_Posting__c(Name = 'SC Job', Job_Title__c = 'Screen Job');
        insert job;
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Screen Candidate',
            Email__c = 'screen.candidate@example.com'
        );
        insert c;
        Screening_Rule__c rule = createRule(job.Id);

        Test.startTest();
        List<ScreeningController.RuleWrapper> rules = ScreeningController.getRules();
        List<Job_Posting__c> jobs = ScreeningController.getJobPostings();
        List<Candidate__c> candidates = ScreeningController.getCandidates();
        String saveMsg = ScreeningController.saveRules(new List<Screening_Rule__c>{rule});
        List<ScreeningController.LabelValueOption> objs = ScreeningController.getAvailableObjects();
        List<ScreeningController.LabelValueOption> fields = ScreeningController.getFieldsForObject('Candidate__c');
        Test.stopTest();

        System.assert(!rules.isEmpty());
        System.assert(!jobs.isEmpty());
        System.assert(!candidates.isEmpty());
        System.assert(saveMsg.contains('Success'));
        System.assert(!objs.isEmpty());
        System.assert(!fields.isEmpty());
    }

    @IsTest
    static void testValidationPaths() {
        try {
            ScreeningController.saveNewRule(new Screening_Rule__c());
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            ScreeningController.getFieldsForObject('BadObject__c');
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
