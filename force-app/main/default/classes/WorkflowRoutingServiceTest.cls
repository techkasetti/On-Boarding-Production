@IsTest
private class WorkflowRoutingServiceTest {
    private static Candidate__c createCandidate(Id jobId) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Routing Candidate',
            Email__c = 'routing.candidate@example.com',
            Interested_In_Job__c = jobId
        );
        insert c;
        return c;
    }

    private static Screening_Rule__c createRule(Id jobId, String name, Integer esc, String journey, String queue) {
        Screening_Rule__c rule = new Screening_Rule__c(
            Name = name,
            Rule_Key__c = 'ROUTE-' + name.replace(' ', '-'),
            Applied_Role__c = jobId,
            Active__c = true,
            Is_Current_Version__c = true,
            Target_Object__c = 'Candidate__c',
            Field_API_Name__c = 'Full_Name__c',
            Operator__c = 'Contains',
            Expected_Value__c = 'Routing',
            Rule_Category__c = 'Experience',
            Journey_Path__c = journey,
            Route_To_Queue__c = queue,
            Escalation_Level__c = esc
        );
        insert rule;
        return rule;
    }

    @IsTest
    static void testDetermineRouting_NoResults_DefaultPath() {
        Job_Posting__c job = new Job_Posting__c(Name = 'Route Job', Default_Journey_Path__c = 'Standard Approval');
        insert job;
        Candidate__c c = createCandidate(job.Id);

        Test.startTest();
        WorkflowRoutingService.RoutingDecision decision =
            WorkflowRoutingService.determineRouting(c.Id, 'corr-none');
        Test.stopTest();

        System.assertEquals('Default Queue', decision.queueName);
        System.assertEquals('Not Defined', decision.journeyPath);
    }

    @IsTest
    static void testDetermineRouting_FailAndCreateRecord() {
        Job_Posting__c job = new Job_Posting__c(Name = 'Route Job 2', Default_Journey_Path__c = 'Standard Approval');
        insert job;
        Candidate__c c = createCandidate(job.Id);
        Screening_Rule__c rule = createRule(job.Id, 'Fail Rule', 3, 'Doctor Path', 'Failure Review Queue');

        insert new Screening_Result__c(
            Candidate__c = c.Id,
            Screening_Rule__c = rule.Id,
            Correlation_Id__c = 'corr-fail',
            Outcome__c = 'Fail',
            Action__c = 'AutoFail',
            Details__c = 'Failed criteria'
        );

        Test.startTest();
        WorkflowRoutingService.RoutingDecision decision =
            WorkflowRoutingService.determineRouting(c.Id, 'corr-fail');
        WorkflowRoutingService.createRoutingDecisionRecord(decision, c.Id);
        Test.stopTest();

        System.assertEquals('Doctor Path', decision.journeyPath);
        System.assertEquals('Failure Review Queue', decision.queueName);

        List<Routing_Decision__c> records = [
            SELECT Id, Candidate__c, Journey_Path__c
            FROM Routing_Decision__c
            WHERE Candidate__c = :c.Id
        ];
        System.assertEquals(1, records.size());
    }

    @IsTest
    static void testDetermineRouting_RouteToJurisdiction() {
        Job_Posting__c job = new Job_Posting__c(Name = 'Route Job 3', Default_Journey_Path__c = 'Standard Approval');
        insert job;
        Candidate__c c = createCandidate(job.Id);
        Screening_Rule__c rule = createRule(job.Id, 'Jurisdiction Rule', 5, 'Nurse Path', 'Jurisdiction Review Queue');

        insert new Screening_Result__c(
            Candidate__c = c.Id,
            Screening_Rule__c = rule.Id,
            Correlation_Id__c = 'corr-juris',
            Outcome__c = 'Review',
            Action__c = 'RouteToJurisdiction',
            Details__c = 'Jurisdiction requirement'
        );

        Test.startTest();
        WorkflowRoutingService.RoutingDecision decision =
            WorkflowRoutingService.determineRouting(c.Id, 'corr-juris');
        Test.stopTest();

        System.assertEquals('Jurisdiction Review Queue', decision.queueName);
        System.assertEquals('Jurisdiction Review', decision.journeyPath);
        System.assertEquals(5, decision.escalationLevel);
    }
}
