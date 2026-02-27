@IsTest
private class EligibilityAICallerTest {
    @IsTest
    static void testInvocableQueuesAsync() {
        EligibilityAICaller.FlowInput i = new EligibilityAICaller.FlowInput();
        i.jobApplicationId = 'a0B000000000001AAA';

        Test.startTest();
        List<EligibilityAICaller.FlowOutput> outList =
            EligibilityAICaller.callEligibilityAIFromFlow(new List<EligibilityAICaller.FlowInput>{ i });
        Test.stopTest();

        System.assertEquals(1, outList.size());
        System.assertEquals(true, outList[0].success);
        System.assert(outList[0].message.contains('queued'));
    }
}
