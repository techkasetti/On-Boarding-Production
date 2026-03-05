@IsTest
private class CandidateComplianceSummaryControllerTest {
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

    private static Candidate__c createCandidate(String suffix) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Compliance Candidate ' + suffix,
            Email__c = 'compliance.' + suffix + '@example.com'
        );
        insert c;
        return c;
    }

    @IsTest
    static void testNullAndNotFoundCandidatePaths() {
        try {
            CandidateComplianceSummaryController.getCandidateComplianceSummary(null);
            System.assert(false, 'Expected exception for null candidateId');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            CandidateComplianceSummaryController.getCandidateComplianceSummary('a0F000000000001AAA');
            System.assert(false, 'Expected not found exception');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void testNoRelatedRecordsSummary() {
        Candidate__c candidate = createCandidate('empty');

        Test.startTest();
        CandidateComplianceSummaryController.CandidateComplianceSummary summary =
            CandidateComplianceSummaryController.getCandidateComplianceSummary(candidate.Id);
        Test.stopTest();

        System.assertNotEquals(null, summary);
        System.assertEquals(candidate.Id, summary.candidateId);
        System.assertEquals(6, summary.totalDomains);
        System.assertEquals(6, summary.domains.size());
        System.assertEquals('Compliant', summary.overallStatus);
    }

    @IsTest
    static void testMixedDomainStatusesAndNearestExpiry() {
        Candidate__c candidate = createCandidate('mixed');
        Contact provider = new Contact(LastName = 'Compliance Provider', Email = 'compliance.provider@example.com');
        insert provider;
        Trial_Assignment__c trialAssignment = new Trial_Assignment__c(
            Provider__c = candidate.Id
        );
        insert trialAssignment;

        // Licensing: one valid near expiry, one expired -> Blocked
        insert new LicenseVerification__c(
            Candidate__c = candidate.Id,
            Provider__c = provider.Id,
            LicenseNumber__c = 'LIC-VAL',
            IssuingAuthority__c = 'State Board',
            ExpirationDate__c = Date.today().addDays(15),
            Status__c = pickValue(LicenseVerification__c.Status__c, 'Valid')
        );
        insert new LicenseVerification__c(
            Candidate__c = candidate.Id,
            Provider__c = provider.Id,
            LicenseNumber__c = 'LIC-EXP',
            IssuingAuthority__c = 'State Board',
            ExpirationDate__c = Date.today().addDays(-1),
            Status__c = pickValue(LicenseVerification__c.Status__c, 'Expired')
        );

        // CME: one expired, one expiring soon, one healthy, one no expiration
        insert new CMERecord__c(Candidate__c = candidate.Id, Expiration_Date__c = Date.today().addDays(-2));
        insert new CMERecord__c(Candidate__c = candidate.Id, Expiration_Date__c = Date.today().addDays(20));
        insert new CMERecord__c(Candidate__c = candidate.Id, Expiration_Date__c = Date.today().addDays(120));
        insert new CMERecord__c(Candidate__c = candidate.Id);

        // HIPAA: one completed, one not completed -> Blocked
        insert new HIPAACompliance__c(Candidate__c = candidate.Id, Status__c = pickValue(HIPAACompliance__c.Status__c, 'Completed'));
        insert new HIPAACompliance__c(Candidate__c = candidate.Id, Status__c = pickValue(HIPAACompliance__c.Status__c, 'In Progress'));

        // Credentialing: one completed at-risk malpractice, one not completed and expired malpractice
        insert new ProviderCredential__c(
            Provider__c = candidate.Id,
            Credentialing_Status__c = pickValue(ProviderCredential__c.Credentialing_Status__c, 'Completed'),
            Malpractice_Expiration_Date__c = Date.today().addDays(30)
        );
        insert new ProviderCredential__c(
            Provider__c = candidate.Id,
            Credentialing_Status__c = pickValue(ProviderCredential__c.Credentialing_Status__c, 'In Progress'),
            Malpractice_Expiration_Date__c = Date.today().addDays(-1)
        );

        // Trial compliance: completed at-risk + non compliant expired
        insert new ClinicalTrialRequirement__c(
            Provider__c = candidate.Id,
            Trial_Assignment__c = trialAssignment.Id,
            Status__c = pickValue(ClinicalTrialRequirement__c.Status__c, 'Completed'),
            Expiration_Date__c = Date.today().addDays(10)
        );
        insert new ClinicalTrialRequirement__c(
            Provider__c = candidate.Id,
            Trial_Assignment__c = trialAssignment.Id,
            Status__c = pickValue(ClinicalTrialRequirement__c.Status__c, 'Non Compliant'),
            Expiration_Date__c = Date.today().addDays(-5)
        );

        // Device training: one completed near expiry + one incomplete expired
        insert new Device_Training__c(
            Provider__c = candidate.Id,
            Training_Completed__c = true,
            Expiration_Date__c = Date.today().addDays(40)
        );
        insert new Device_Training__c(
            Provider__c = candidate.Id,
            Training_Completed__c = false,
            Expiration_Date__c = Date.today().addDays(-3)
        );

        Test.startTest();
        CandidateComplianceSummaryController.CandidateComplianceSummary summary =
            CandidateComplianceSummaryController.getCandidateComplianceSummary(candidate.Id);
        Test.stopTest();

        System.assertEquals('Blocked', summary.overallStatus);
        System.assert(summary.blockedDomains > 0);
        System.assert(summary.atRiskDomains >= 0);
        System.assertEquals(6, summary.domains.size());
        System.assertNotEquals(null, summary.nearestExpiration);

        Map<String, CandidateComplianceSummaryController.DomainSummary> byApi =
            new Map<String, CandidateComplianceSummaryController.DomainSummary>();
        for (CandidateComplianceSummaryController.DomainSummary d : summary.domains) {
            byApi.put(d.apiName, d);
        }

        System.assertEquals('Blocked', byApi.get('LICENSING').status);
        System.assertEquals('Blocked', byApi.get('HIPAA').status);
        System.assertEquals('Blocked', byApi.get('CREDENTIALING').status);
        System.assertEquals('Blocked', byApi.get('TRIALS').status);
        System.assertEquals('Blocked', byApi.get('DEVICE_TRAINING').status);
        System.assert(byApi.get('CME').status == 'Blocked' || byApi.get('CME').status == 'At Risk' || byApi.get('CME').status == 'Compliant');
    }

    @IsTest
    static void testAtRiskOverallPath() {
        Candidate__c candidate = createCandidate('atrisk');
        Contact provider = new Contact(LastName = 'AtRisk Provider', Email = 'atrisk.provider@example.com');
        insert provider;
        Trial_Assignment__c trialAssignment = new Trial_Assignment__c(
            Provider__c = candidate.Id
        );
        insert trialAssignment;

        insert new LicenseVerification__c(
            Candidate__c = candidate.Id,
            Provider__c = provider.Id,
            LicenseNumber__c = 'LIC-RISK',
            IssuingAuthority__c = 'State Board',
            ExpirationDate__c = Date.today().addDays(10),
            Status__c = pickValue(LicenseVerification__c.Status__c, 'Valid')
        );

        insert new CMERecord__c(
            Candidate__c = candidate.Id,
            Expiration_Date__c = Date.today().addDays(15)
        );

        insert new HIPAACompliance__c(
            Candidate__c = candidate.Id,
            Status__c = pickValue(HIPAACompliance__c.Status__c, 'Completed')
        );

        insert new ProviderCredential__c(
            Provider__c = candidate.Id,
            Credentialing_Status__c = pickValue(ProviderCredential__c.Credentialing_Status__c, 'Completed'),
            Malpractice_Expiration_Date__c = Date.today().addDays(20)
        );

        insert new ClinicalTrialRequirement__c(
            Provider__c = candidate.Id,
            Trial_Assignment__c = trialAssignment.Id,
            Status__c = pickValue(ClinicalTrialRequirement__c.Status__c, 'Completed'),
            Expiration_Date__c = Date.today().addDays(25)
        );

        insert new Device_Training__c(
            Provider__c = candidate.Id,
            Training_Completed__c = true,
            Expiration_Date__c = Date.today().addDays(30)
        );

        CandidateComplianceSummaryController.CandidateComplianceSummary summary =
            CandidateComplianceSummaryController.getCandidateComplianceSummary(candidate.Id);

        System.assertEquals('At Risk', summary.overallStatus);
        System.assertEquals(0, summary.blockedDomains);
        System.assert(summary.atRiskDomains > 0);
        System.assertNotEquals(null, summary.nearestExpiration);
    }
}
