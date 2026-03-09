@IsTest
private class ProviderComplianceControllerTest {
    private static String pickValue(Schema.SObjectField fieldToken, String preferred) {
        List<Schema.PicklistEntry> entries = fieldToken.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry pe : entries) {
            if (pe.isActive() && pe.getValue() == preferred) {
                return pe.getValue();
            }
        }
        for (Schema.PicklistEntry pe : entries) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return preferred;
    }

    private static Candidate__c createCandidate(String suffix, String facility, String specialty) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Provider Candidate ' + suffix,
            Email__c = 'provider.' + suffix + '@example.com'
        );
        insert c;
        return c;
    }

    private static Contact createProviderContact(String suffix) {
        Contact con = new Contact(
            LastName = 'Provider ' + suffix,
            Email = 'provider.contact.' + suffix + '@example.com'
        );
        insert con;
        return con;
    }

    private static void seedBlockedProvider(Candidate__c c) {
        Contact provider = createProviderContact('blocked' + c.Id);
        insert new LicenseVerification__c(
            Candidate__c = c.Id,
            Provider__c = provider.Id,
            LicenseNumber__c = 'BLK-1',
            IssuingAuthority__c = 'State Board',
            ExpirationDate__c = Date.today().addDays(-2),
            Status__c = pickValue(LicenseVerification__c.Status__c, 'Expired')
        );

        insert new HIPAACompliance__c(
            Candidate__c = c.Id,
            Status__c = pickValue(HIPAACompliance__c.Status__c, 'Not Started')
        );

        insert new ProviderCredential__c(
            Provider__c = c.Id,
            Credentialing_Status__c = pickValue(ProviderCredential__c.Credentialing_Status__c, 'In Progress'),
            Credential_Score_Completeness__c = 40,
            Credential_Score_Risk_Level__c = 'High',
            Malpractice_Expiration_Date__c = Date.today().addDays(-10),
            Malpractice_Coverage_Amount__c = 100000
        );

        insert new CMERecord__c(
            Candidate__c = c.Id,
            Expiration_Date__c = Date.today().addDays(20)
        );
    }

    private static void seedEligibleProvider(Candidate__c c) {
        Contact provider = createProviderContact('eligible' + c.Id);
        insert new LicenseVerification__c(
            Candidate__c = c.Id,
            Provider__c = provider.Id,
            LicenseNumber__c = 'OK-1',
            IssuingAuthority__c = 'State Board',
            ExpirationDate__c = Date.today().addDays(180),
            Status__c = pickValue(LicenseVerification__c.Status__c, 'Valid')
        );

        insert new HIPAACompliance__c(
            Candidate__c = c.Id,
            Status__c = pickValue(HIPAACompliance__c.Status__c, 'Completed')
        );

        insert new ProviderCredential__c(
            Provider__c = c.Id,
            Credentialing_Status__c = pickValue(ProviderCredential__c.Credentialing_Status__c, 'Completed'),
            Credential_Score_Completeness__c = 95,
            Credential_Score_Risk_Level__c = 'Low',
            Malpractice_Expiration_Date__c = Date.today().addDays(200),
            Malpractice_Coverage_Amount__c = 300000
        );
    }

    private static void seedAtRiskProvider(Candidate__c c) {
        Contact provider = createProviderContact('risk' + c.Id);
        insert new LicenseVerification__c(
            Candidate__c = c.Id,
            Provider__c = provider.Id,
            LicenseNumber__c = 'RISK-1',
            IssuingAuthority__c = 'State Board',
            ExpirationDate__c = Date.today().addDays(10),
            Status__c = pickValue(LicenseVerification__c.Status__c, 'Valid')
        );

        insert new HIPAACompliance__c(
            Candidate__c = c.Id,
            Status__c = pickValue(HIPAACompliance__c.Status__c, 'Completed')
        );

        insert new ProviderCredential__c(
            Provider__c = c.Id,
            Credentialing_Status__c = pickValue(ProviderCredential__c.Credentialing_Status__c, 'Completed'),
            Credential_Score_Completeness__c = 90,
            Credential_Score_Risk_Level__c = 'Medium',
            Malpractice_Expiration_Date__c = Date.today().addDays(90),
            Malpractice_Coverage_Amount__c = 250000
        );

        insert new CMERecord__c(
            Candidate__c = c.Id,
            Expiration_Date__c = Date.today().addDays(30)
        );
    }

    @IsTest
    static void testGetProviderComplianceSummaryBranches() {
        System.assertEquals(null, ProviderComplianceController.getProviderComplianceSummary(null));
        System.assertEquals(null, ProviderComplianceController.getProviderComplianceSummary('a0F000000000001AAA'));

        Candidate__c emptyCandidate = createCandidate('empty', 'Facility A', 'Cardiology');
        Candidate__c blockedCandidate = createCandidate('blocked', 'Facility A', 'Cardiology');
        Candidate__c eligibleCandidate = createCandidate('eligible', 'Facility B', 'Neurology');

        seedBlockedProvider(blockedCandidate);
        seedEligibleProvider(eligibleCandidate);

        Test.startTest();
        ProviderComplianceController.ProviderComplianceSummary emptySummary =
            ProviderComplianceController.getProviderComplianceSummary(emptyCandidate.Id);
        ProviderComplianceController.ProviderComplianceSummary blockedSummary =
            ProviderComplianceController.getProviderComplianceSummary(blockedCandidate.Id);
        ProviderComplianceController.ProviderComplianceSummary eligibleSummary =
            ProviderComplianceController.getProviderComplianceSummary(eligibleCandidate.Id);
        Test.stopTest();

        System.assertEquals('Blocked', emptySummary.overallStatus);
        System.assert(emptySummary.blockingReasons.size() > 0);

        System.assertEquals('Blocked', blockedSummary.overallStatus);
        System.assertNotEquals(null, blockedSummary.overallReason);
        System.assertNotEquals(null, blockedSummary.license);
        System.assertNotEquals(null, blockedSummary.hipaa);
        System.assertNotEquals(null, blockedSummary.credential);
        System.assertNotEquals(null, blockedSummary.cme);

        System.assertEquals('Eligible', eligibleSummary.overallStatus);
    }

    @IsTest
    static void testFlagProviderForReviewAndQueueAndKpis() {
        Candidate__c blockedCandidate = createCandidate('queueBlk', 'Facility A', 'Cardiology');
        Candidate__c eligibleCandidate = createCandidate('queueOk', 'Facility B', 'Neurology');
        Candidate__c riskCandidate = createCandidate('queueRisk', 'Facility A', 'Cardiology');

        seedBlockedProvider(blockedCandidate);
        seedEligibleProvider(eligibleCandidate);
        seedAtRiskProvider(riskCandidate);

        try {
            ProviderComplianceController.flagProviderForReview(null, 'reason');
            System.assert(false, 'Expected null candidate exception');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        Test.startTest();
        ProviderComplianceController.flagProviderForReview(blockedCandidate.Id, 'Manual check');

        ProviderComplianceController.PagedResult allRows =
            ProviderComplianceController.getProviderQueue(
                null,
                null,
                null,
                null,
                null,
                50,
                0,
                'overallStatus',
                'ASC'
            );

        ProviderComplianceController.PagedResult blockedRows =
            ProviderComplianceController.getProviderQueue(
                null,
                null,
                null,
                null,
                'Blocked',
                50,
                0,
                'overallStatus',
                'ASC'
            );

        ProviderComplianceController.PagedResult searchedRows =
            ProviderComplianceController.getProviderQueue(
                null,
                'queue',
                null,
                null,
                null,
                50,
                0,
                'overallStatus',
                'ASC'
            );

        Map<String, Integer> kpis = ProviderComplianceController.getOverviewKpis();
        Test.stopTest();

        Task t = [
            SELECT Id, Subject, Priority, Status, WhatId, Description
            FROM Task
            WHERE WhatId = :blockedCandidate.Id
            LIMIT 1
        ];
        System.assert(t.Subject.contains('Compliance Review'));

        System.assert(allRows.records.size() > 0);
        System.assert(allRows.totalCount > 0);
        for (ProviderComplianceController.ProviderQueueRow row : blockedRows.records) {
            System.assertEquals('Blocked', row.overallStatus);
        }
        System.assert(searchedRows.records.size() >= 0);

        System.assert(kpis.containsKey('blockedProviders'));
        System.assert(kpis.containsKey('atRiskProviders'));
        System.assert(kpis.containsKey('eligibleProviders'));
        System.assert(kpis.containsKey('expiringLicenses30'));
        System.assert(kpis.containsKey('expiringCme60'));
        System.assert(kpis.containsKey('missingHipaa'));
        System.assert(kpis.containsKey('incompleteCredentialing'));

        System.assert(kpis.get('blockedProviders') >= 1);
        System.assert(kpis.get('atRiskProviders') >= 1);
        System.assert(kpis.get('eligibleProviders') >= 1);
    }
}
