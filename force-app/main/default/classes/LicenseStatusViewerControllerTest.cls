@IsTest
private class LicenseStatusViewerControllerTest {
    private static void seedLicenses() {
        Contact provider = new Contact(LastName = 'Provider');
        insert provider;

        insert new LicenseVerification__c(
            Provider__c = provider.Id,
            LicenseNumber__c = 'L-VALID',
            IssuingAuthority__c = 'CA',
            ExpirationDate__c = Date.today().addDays(10),
            Status__c = 'Valid'
        );
        insert new LicenseVerification__c(
            Provider__c = provider.Id,
            LicenseNumber__c = 'L-PENDING',
            IssuingAuthority__c = 'CA',
            ExpirationDate__c = Date.today().addDays(60),
            Status__c = 'Pending Verification'
        );
    }

    @IsTest
    static void testGetLicenseVerifications_AllAndStatusFiltered() {
        seedLicenses();

        Test.startTest();
        List<LicenseStatusViewerController.LicenseRow> allRows =
            LicenseStatusViewerController.getLicenseVerifications(null, null);
        List<LicenseStatusViewerController.LicenseRow> validRows =
            LicenseStatusViewerController.getLicenseVerifications('Valid', null);
        Test.stopTest();

        System.assert(allRows.size() >= 2);
        System.assertEquals(1, validRows.size());
        System.assertEquals('Valid', validRows[0].status);
    }

    @IsTest
    static void testGetLicenseVerifications_ExpirationFilter() {
        seedLicenses();

        Test.startTest();
        List<LicenseStatusViewerController.LicenseRow> expiringSoon =
            LicenseStatusViewerController.getLicenseVerifications(null, Date.today().addDays(30));
        Test.stopTest();

        System.assertEquals(1, expiringSoon.size());
        System.assertEquals('L-VALID', expiringSoon[0].licenseNumber);
    }
}
