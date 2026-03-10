@IsTest
private class AIFeatureControllerTest {
    private static AIFeature__c createFeatureRecord(String suffix, Boolean isActive) {
        AIFeature__c feature = new AIFeature__c(
            Name__c = 'Feature ' + suffix,
            Description__c = 'Description ' + suffix,
            IsActive__c = isActive
        );
        insert feature;
        return feature;
    }

    @IsTest
    static void getFeaturesReturnsRecords() {
        createFeatureRecord('A', true);
        createFeatureRecord('B', false);

        Test.startTest();
        List<AIFeature__c> rows = AIFeatureController.getFeatures();
        Test.stopTest();

        System.assert(rows.size() >= 2, 'Expected at least two AI feature records.');
    }

    @IsTest
    static void createFeatureInsertsRecord() {
        Test.startTest();
        AIFeature__c created = AIFeatureController.createFeature('Screening', 'AI screening capability', true);
        Test.stopTest();

        AIFeature__c fromDb = [
            SELECT Id, Name__c, Description__c, IsActive__c
            FROM AIFeature__c
            WHERE Id = :created.Id
            LIMIT 1
        ];
        System.assertEquals('Screening', fromDb.Name__c);
        System.assertEquals('AI screening capability', fromDb.Description__c);
        System.assertEquals(true, fromDb.IsActive__c);
    }

    @IsTest
    static void updateFeatureModifiesRecord() {
        AIFeature__c seed = createFeatureRecord('Update', true);

        Test.startTest();
        AIFeature__c updated = AIFeatureController.updateFeature(seed.Id, 'Updated Name', 'Updated description', false);
        Test.stopTest();

        System.assertEquals(seed.Id, updated.Id);

        AIFeature__c fromDb = [
            SELECT Name__c, Description__c, IsActive__c
            FROM AIFeature__c
            WHERE Id = :seed.Id
            LIMIT 1
        ];
        System.assertEquals('Updated Name', fromDb.Name__c);
        System.assertEquals('Updated description', fromDb.Description__c);
        System.assertEquals(false, fromDb.IsActive__c);
    }

    @IsTest
    static void deleteFeatureRemovesRecord() {
        AIFeature__c seed = createFeatureRecord('Delete', true);

        Test.startTest();
        AIFeatureController.deleteFeature(seed.Id);
        Test.stopTest();

        Integer remaining = [SELECT COUNT() FROM AIFeature__c WHERE Id = :seed.Id];
        System.assertEquals(0, remaining);
    }

    @IsTest
    static void createFeatureValidatesName() {
        try {
            AIFeatureController.createFeature('  ', 'No name provided', true);
            System.assert(false, 'Expected an AuraHandledException for missing feature name.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Feature name is required.'));
        }
    }

    @IsTest
    static void updateFeatureValidatesFeatureId() {
        try {
            AIFeatureController.updateFeature(null, 'Valid Name', 'Description', true);
            System.assert(false, 'Expected an AuraHandledException for missing feature Id.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Feature Id is required.'));
        }
    }
}
