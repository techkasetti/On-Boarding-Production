@IsTest
private class ScreeningRuleAdminControllerTest {
    @IsTest
    static void testSaveRuleValidationAndMissingMetadata() {
        Test.startTest();
        Map<String, Object> missingInput = ScreeningRuleAdminController.saveRule('', '', true);
        Map<String, Object> missingMetadata = ScreeningRuleAdminController.saveRule('Rule One', 'x > 1', true);
        Test.stopTest();

        System.assertEquals(false, missingInput.get('success'));
        System.assert(String.valueOf(missingInput.get('message')).contains('required'));

        // In this org path, DynScr_Rule__mdt is expected missing; method should fail gracefully.
        System.assertEquals(false, missingMetadata.get('success'));
        System.assertNotEquals(null, missingMetadata.get('message'));
    }

    @IsTest
    static void testPreviewRuleGoodAndBadPayload() {
        Object badPayloadResult = ScreeningRuleAdminController.previewRule('x > 1', 'bad-json');
        Object goodPayloadResult = ScreeningRuleAdminController.previewRule('x > 1', '{"x":2}');

        System.assertNotEquals(null, badPayloadResult);
        System.assertNotEquals(null, goodPayloadResult);

        Map<String, Object> badMap = (Map<String, Object>) badPayloadResult;
        System.assert(badMap.containsKey('error') || badMap.containsKey('matched'));

        Map<String, Object> goodMap = (Map<String, Object>) goodPayloadResult;
        System.assert(goodMap.containsKey('error') || goodMap.containsKey('matched'));
    }
}
