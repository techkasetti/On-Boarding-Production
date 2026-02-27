@IsTest
private class DocumentGenerationControllerTest {
    @IsTest
    static void testBasicMethodsAndNegativePaths() {
        Test.startTest();
        List<DocumentTemplate__c> allTemplates = DocumentGenerationController.getDocumentTemplates();
        List<DocumentTemplate__c> activeTemplates = DocumentGenerationController.getActiveTemplatesForSelection();
        String clause = DocumentGenerationController.generateClauseWithAI('model', 'prompt', '{}');
        DocumentGenerationController.PreviewResult preview =
            DocumentGenerationController.previewDocument(null, null, null, String.valueOf(System.now()));
        Test.stopTest();

        System.assertNotEquals(null, allTemplates);
        System.assertNotEquals(null, activeTemplates);
        System.assert(String.isNotBlank(clause));
        System.assertEquals(false, preview.success);
    }

    @IsTest
    static void testRequiredValidationErrors() {
        try {
            DocumentGenerationController.createApprovalRequest(null, null);
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            DocumentGenerationController.createDocumentRequest('', '', '', '', '');
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
