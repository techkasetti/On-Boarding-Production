public with sharing class CandidateComplianceSummaryController {

    public class DomainSummary {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer completedCount;
        @AuraEnabled public Integer blockedCount;
        @AuraEnabled public Integer atRiskCount;
        @AuraEnabled public Date nearestExpiration;
    }

    public class CandidateComplianceSummary {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String candidateName;
        @AuraEnabled public String overallStatus;
        @AuraEnabled public Integer totalDomains;
        @AuraEnabled public Integer compliantDomains;
        @AuraEnabled public Integer atRiskDomains;
        @AuraEnabled public Integer blockedDomains;
        @AuraEnabled public Date nearestExpiration;
        @AuraEnabled public List<DomainSummary> domains;
    }

    @AuraEnabled(cacheable=true)
    public static CandidateComplianceSummary getCandidateComplianceSummary(Id candidateId) {
        if (candidateId == null) {
            throw new AuraHandledException('candidateId is required');
        }

        if (!Schema.sObjectType.Candidate__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Candidate__c');
        }
        if (!Schema.sObjectType.LicenseVerification__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to LicenseVerification__c');
        }
        if (!Schema.sObjectType.CMERecord__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to CMERecord__c');
        }
        if (!Schema.sObjectType.HIPAACompliance__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to HIPAACompliance__c');
        }
        if (!Schema.sObjectType.ProviderCredential__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to ProviderCredential__c');
        }
        if (!Schema.sObjectType.ClinicalTrialRequirement__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to ClinicalTrialRequirement__c');
        }
        if (!Schema.sObjectType.Device_Training__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Device_Training__c');
        }

        List<Candidate__c> candidateList = [
            SELECT Id, Name
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];

        if (candidateList.isEmpty()) {
            throw new AuraHandledException('Candidate not found or not accessible');
        }

        Candidate__c candidate = candidateList[0];
        Date today = Date.today();

        List<LicenseVerification__c> licenseList = [
            SELECT Id, Status__c, ExpirationDate__c
            FROM LicenseVerification__c
            WHERE Candidate__c = :candidate.Id
        ];
        List<CMERecord__c> cmeList = [
            SELECT Id, Expiration_Date__c
            FROM CMERecord__c
            WHERE Candidate__c = :candidate.Id
        ];
        List<HIPAACompliance__c> hipaaList = [
            SELECT Id, Status__c
            FROM HIPAACompliance__c
            WHERE Candidate__c = :candidate.Id
        ];
        List<ProviderCredential__c> credentialList = [
            SELECT Id, Credentialing_Status__c, Malpractice_Expiration_Date__c
            FROM ProviderCredential__c
            WHERE Provider__c = :candidate.Id
        ];
        List<ClinicalTrialRequirement__c> trialList = [
            SELECT Id, Status__c, Expiration_Date__c
            FROM ClinicalTrialRequirement__c
            WHERE Provider__c = :candidate.Id
        ];
        List<Device_Training__c> deviceList = [
            SELECT Id, Training_Completed__c, Expiration_Date__c
            FROM Device_Training__c
            WHERE Provider__c = :candidate.Id
        ];

        List<DomainSummary> domains = new List<DomainSummary>();
        domains.add(buildLicenseSummary(licenseList, today));
        domains.add(buildCmeSummary(cmeList, today));
        domains.add(buildHipaaSummary(hipaaList));
        domains.add(buildCredentialSummary(credentialList, today));
        domains.add(buildTrialSummary(trialList, today));
        domains.add(buildDeviceSummary(deviceList, today));

        Integer compliantDomains = 0;
        Integer atRiskDomains = 0;
        Integer blockedDomains = 0;
        Date nearestExpiration = null;

        for (DomainSummary d : domains) {
            if (d.status == 'Compliant') {
                compliantDomains++;
            } else if (d.status == 'At Risk') {
                atRiskDomains++;
            } else if (d.status == 'Blocked') {
                blockedDomains++;
            }

            if (d.nearestExpiration != null) {
                if (nearestExpiration == null || d.nearestExpiration < nearestExpiration) {
                    nearestExpiration = d.nearestExpiration;
                }
            }
        }

        String overallStatus;
        if (blockedDomains > 0) {
            overallStatus = 'Blocked';
        } else if (atRiskDomains > 0) {
            overallStatus = 'At Risk';
        } else {
            overallStatus = 'Compliant';
        }

        CandidateComplianceSummary summary = new CandidateComplianceSummary();
        summary.candidateId = candidate.Id;
        summary.candidateName = candidate.Name;
        summary.overallStatus = overallStatus;
        summary.totalDomains = domains.size();
        summary.compliantDomains = compliantDomains;
        summary.atRiskDomains = atRiskDomains;
        summary.blockedDomains = blockedDomains;
        summary.nearestExpiration = nearestExpiration;
        summary.domains = domains;

        return summary;
    }

    private static DomainSummary buildLicenseSummary(List<LicenseVerification__c> licenseList, Date today) {
        DomainSummary summary = new DomainSummary();
        summary.apiName = 'LICENSING';
        summary.label = 'Licenses & Certifications';
        summary.totalCount = licenseList.size();
        summary.completedCount = 0;
        summary.blockedCount = 0;
        summary.atRiskCount = 0;
        summary.nearestExpiration = null;

        if (licenseList.isEmpty()) {
            summary.status = 'Not Started';
            return summary;
        }

        for (LicenseVerification__c lic : licenseList) {
            Boolean isValid = lic.Status__c == 'Valid';
            Boolean isExpired = lic.Status__c == 'Expired';
            Boolean isSuspended = lic.Status__c == 'Suspended';
            Boolean isNotFound = lic.Status__c == 'Not Found';
            Boolean isError = lic.Status__c == 'Error';

            if (isValid) {
                summary.completedCount++;
                if (lic.ExpirationDate__c != null) {
                    if (summary.nearestExpiration == null || lic.ExpirationDate__c < summary.nearestExpiration) {
                        summary.nearestExpiration = lic.ExpirationDate__c;
                    }
                    Integer daysToExpiry = today.daysBetween(lic.ExpirationDate__c);
                    if (daysToExpiry >= 0 && daysToExpiry <= 30) {
                        summary.atRiskCount++;
                    }
                }
            }

            if (isExpired || isSuspended || isNotFound || isError) {
                summary.blockedCount++;
            }
        }

        if (summary.blockedCount > 0) {
            summary.status = 'Blocked';
        } else if (summary.atRiskCount > 0) {
            summary.status = 'At Risk';
        } else {
            summary.status = 'Compliant';
        }
        return summary;
    }

    private static DomainSummary buildCmeSummary(List<CMERecord__c> cmeList, Date today) {
        DomainSummary summary = new DomainSummary();
        summary.apiName = 'CME';
        summary.label = 'CME / CEU';
        summary.totalCount = cmeList.size();
        summary.completedCount = 0;
        summary.blockedCount = 0;
        summary.atRiskCount = 0;
        summary.nearestExpiration = null;

        if (cmeList.isEmpty()) {
            summary.status = 'Not Started';
            return summary;
        }

        for (CMERecord__c cme : cmeList) {
            if (cme.Expiration_Date__c != null) {
                if (summary.nearestExpiration == null || cme.Expiration_Date__c < summary.nearestExpiration) {
                    summary.nearestExpiration = cme.Expiration_Date__c;
                }
                Integer daysToExpiry = today.daysBetween(cme.Expiration_Date__c);

                if (daysToExpiry < 0) {
                    summary.blockedCount++;
                } else if (daysToExpiry <= 60) {
                    summary.atRiskCount++;
                } else {
                    summary.completedCount++;
                }
            } else {
                summary.completedCount++;
            }
        }

        if (summary.blockedCount > 0) {
            summary.status = 'Blocked';
        } else if (summary.atRiskCount > 0) {
            summary.status = 'At Risk';
        } else {
            summary.status = 'Compliant';
        }
        return summary;
    }

    private static DomainSummary buildHipaaSummary(List<HIPAACompliance__c> hipaaList) {
        DomainSummary summary = new DomainSummary();
        summary.apiName = 'HIPAA';
        summary.label = 'HIPAA & Privacy';
        summary.totalCount = hipaaList.size();
        summary.completedCount = 0;
        summary.blockedCount = 0;
        summary.atRiskCount = 0;
        summary.nearestExpiration = null;

        if (hipaaList.isEmpty()) {
            summary.status = 'Not Started';
            summary.blockedCount = 1;
            return summary;
        }

        for (HIPAACompliance__c h : hipaaList) {
            if (h.Status__c == 'Completed') {
                summary.completedCount++;
            } else {
                summary.blockedCount++;
            }
        }

        if (summary.totalCount > 0 && summary.completedCount == summary.totalCount) {
            summary.status = 'Compliant';
        } else if (summary.blockedCount > 0) {
            summary.status = 'Blocked';
        } else if (summary.completedCount > 0) {
            summary.status = 'At Risk';
        } else {
            summary.status = 'Blocked';
        }
        return summary;
    }

    private static DomainSummary buildCredentialSummary(List<ProviderCredential__c> credentialList, Date today) {
        DomainSummary summary = new DomainSummary();
        summary.apiName = 'CREDENTIALING';
        summary.label = 'Credentialing & Privileges';
        summary.totalCount = credentialList.size();
        summary.completedCount = 0;
        summary.blockedCount = 0;
        summary.atRiskCount = 0;
        summary.nearestExpiration = null;

        if (credentialList.isEmpty()) {
            summary.status = 'Not Started';
            return summary;
        }

        for (ProviderCredential__c cred : credentialList) {
            Boolean isCompleted = cred.Credentialing_Status__c == 'Completed';
            if (isCompleted) {
                summary.completedCount++;
            } else {
                summary.atRiskCount++;
            }

            if (cred.Malpractice_Expiration_Date__c != null) {
                if (summary.nearestExpiration == null || cred.Malpractice_Expiration_Date__c < summary.nearestExpiration) {
                    summary.nearestExpiration = cred.Malpractice_Expiration_Date__c;
                }
                Integer daysToExpiry = today.daysBetween(cred.Malpractice_Expiration_Date__c);

                if (daysToExpiry < 0) {
                    summary.blockedCount++;
                } else if (daysToExpiry <= 60) {
                    summary.atRiskCount++;
                }
            }
        }

        if (summary.blockedCount > 0) {
            summary.status = 'Blocked';
        } else if (summary.atRiskCount > 0) {
            summary.status = 'At Risk';
        } else {
            summary.status = 'Compliant';
        }
        return summary;
    }

    private static DomainSummary buildTrialSummary(List<ClinicalTrialRequirement__c> trialList, Date today) {
        DomainSummary summary = new DomainSummary();
        summary.apiName = 'TRIALS';
        summary.label = 'Clinical Trial Compliance';
        summary.totalCount = trialList.size();
        summary.completedCount = 0;
        summary.blockedCount = 0;
        summary.atRiskCount = 0;
        summary.nearestExpiration = null;

        if (trialList.isEmpty()) {
            summary.status = 'Not Started';
            return summary;
        }

        for (ClinicalTrialRequirement__c req : trialList) {
            Boolean isCompleted = req.Status__c == 'Completed';
            Boolean isNonCompliant = req.Status__c == 'Non Compliant';

            if (isCompleted) {
                summary.completedCount++;
            }

            if (isNonCompliant) {
                summary.blockedCount++;
            }

            if (req.Expiration_Date__c != null) {
                if (summary.nearestExpiration == null || req.Expiration_Date__c < summary.nearestExpiration) {
                    summary.nearestExpiration = req.Expiration_Date__c;
                }
                Integer daysToExpiry = today.daysBetween(req.Expiration_Date__c);

                if (daysToExpiry < 0) {
                    summary.blockedCount++;
                } else if (daysToExpiry <= 60) {
                    summary.atRiskCount++;
                }
            }
        }

        if (summary.blockedCount > 0) {
            summary.status = 'Blocked';
        } else if (summary.atRiskCount > 0) {
            summary.status = 'At Risk';
        } else {
            summary.status = 'Compliant';
        }
        return summary;
    }

    private static DomainSummary buildDeviceSummary(List<Device_Training__c> deviceList, Date today) {
        DomainSummary summary = new DomainSummary();
        summary.apiName = 'DEVICE_TRAINING';
        summary.label = 'Medical Device Training';
        summary.totalCount = deviceList.size();
        summary.completedCount = 0;
        summary.blockedCount = 0;
        summary.atRiskCount = 0;
        summary.nearestExpiration = null;

        if (deviceList.isEmpty()) {
            summary.status = 'Not Started';
            return summary;
        }

        for (Device_Training__c dt : deviceList) {
            Boolean completed = dt.Training_Completed__c;
            if (completed) {
                summary.completedCount++;
            } else {
                summary.blockedCount++;
            }

            if (dt.Expiration_Date__c != null) {
                if (summary.nearestExpiration == null || dt.Expiration_Date__c < summary.nearestExpiration) {
                    summary.nearestExpiration = dt.Expiration_Date__c;
                }
                Integer daysToExpiry = today.daysBetween(dt.Expiration_Date__c);

                if (daysToExpiry < 0) {
                    summary.blockedCount++;
                } else if (daysToExpiry <= 60) {
                    summary.atRiskCount++;
                }
            }
        }

        if (summary.blockedCount > 0) {
            summary.status = 'Blocked';
        } else if (summary.atRiskCount > 0) {
            summary.status = 'At Risk';
        } else {
            summary.status = 'Compliant';
        }
        return summary;
    }
}