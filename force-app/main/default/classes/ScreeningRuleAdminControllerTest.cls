@IsTest
private class ScreeningRuleAdminControllerTest {
    @IsTest
    static void testSaveRuleValidationAndPreview() {
        Test.startTest();
        Map<String, Object> bad = ScreeningRuleAdminController.saveRule('', '', true);
        Object previewBad = ScreeningRuleAdminController.previewRule('x > 1', 'bad-json');
        Object previewOk = ScreeningRuleAdminController.previewRule('x > 1', '{"x":2}');
        Test.stopTest();

        System.assertEquals(false, bad.get('success'));
        System.assertNotEquals(null, previewBad);
        System.assertNotEquals(null, previewOk);
    }
}
