@IsTest
private class ScreeningDataLoaderTest {
    @IsTest
    static void testLoadCandidateWithAllRelations_PositiveAndErrors() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Loader Candidate',
            Email__c = 'loader@example.com',
            Location__c = 'Austin',
            Years_of_Experience__c = 5
        );
        insert c;

        insert new License_Certification__c(
            Candidate__c = c.Id,
            Name = 'BLS',
            Type__c = 'License'
        );

        Test.startTest();
        Candidate__c loaded = ScreeningDataLoader.loadCandidateWithAllRelations(c.Id);
        Test.stopTest();

        System.assertEquals(c.Id, loaded.Id);
        System.assertNotEquals(null, loaded.License_Certifications__r);
        System.assertEquals(1, loaded.License_Certifications__r.size());

        try {
            ScreeningDataLoader.loadCandidateWithAllRelations(null);
            System.assert(false, 'Expected IllegalArgumentException for null id');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Candidate ID cannot be null'));
        }

        try {
            ScreeningDataLoader.loadCandidateWithAllRelations('003000000000000AAA');
            System.assert(false, 'Expected no data exception for unknown candidate');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Candidate not found'));
        }
    }

    @IsTest
    static void testLoadCandidatesWithAllRelations_AndBasic() {
        Candidate__c c1 = new Candidate__c(
            Full_Name__c = 'Loader One',
            Email__c = 'loader.one@example.com'
        );
        Candidate__c c2 = new Candidate__c(
            Full_Name__c = 'Loader Two',
            Email__c = 'loader.two@example.com'
        );
        insert new List<Candidate__c>{ c1, c2 };

        Test.startTest();
        List<Candidate__c> full = ScreeningDataLoader.loadCandidatesWithAllRelations(
            new Set<Id>{ c1.Id, c2.Id }
        );
        List<Candidate__c> basic = ScreeningDataLoader.loadCandidatesBasic(
            new Set<Id>{ c1.Id, c2.Id }
        );
        List<Candidate__c> empty = ScreeningDataLoader.loadCandidatesWithAllRelations(new Set<Id>());
        Test.stopTest();

        System.assertEquals(2, full.size());
        System.assertEquals(2, basic.size());
        System.assertEquals(0, empty.size());
    }
}
