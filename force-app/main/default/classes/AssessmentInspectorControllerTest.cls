@IsTest
private class AssessmentInspectorControllerTest {
    @IsTest
    static void testFetchAssessment_NullIdReturnsNull() {
        Test.startTest();
        Onboarding_Run__c result = AssessmentInspectorController.fetchAssessment(null);
        Test.stopTest();

        System.assertEquals(null, result, 'Null Id should return null');
    }
}
