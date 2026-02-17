// force-app/main/default/classes/ProviderComplianceController.cls
public with sharing class ProviderComplianceController {

    // ===== Existing DTOs for provider-level detail =====
    public class LicenseSummary {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String status;
        @AuraEnabled public Date expirationDate;
        @AuraEnabled public Integer daysToExpiry;
    }

    public class HipaaSummary {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean phiAccess;
    }

    public class CredentialSummary {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal completenessScore;
        @AuraEnabled public String riskScore;
        @AuraEnabled public Date malpracticeExpiry;
        @AuraEnabled public Decimal malpracticeCoverageAmount;
    }

    public class CmeSummary {
        @AuraEnabled public String complianceStatus;
        @AuraEnabled public Decimal requiredCredits;
        @AuraEnabled public Decimal earnedCredits;
        @AuraEnabled public Integer expiringCount;
    }

    public class ProviderComplianceSummary {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String candidateName;
        @AuraEnabled public String overallStatus;
        @AuraEnabled public String overallReason;
        @AuraEnabled public List<String> blockingReasons;
        @AuraEnabled public LicenseSummary license;
        @AuraEnabled public HipaaSummary hipaa;
        @AuraEnabled public CredentialSummary credential;
        @AuraEnabled public CmeSummary cme;
    }

    // ===== NEW DTOs for queue & KPIs =====
    public class ProviderQueueRow {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String candidateName;
        @AuraEnabled public String overallStatus;
        @AuraEnabled public String overallStatusClass;
        @AuraEnabled public String overallStatusIcon;

        @AuraEnabled public String licenseSummary;
        @AuraEnabled public String licenseClass;

        @AuraEnabled public String credentialSummary;
        @AuraEnabled public String credentialClass;

        @AuraEnabled public String hipaaStatus;
        @AuraEnabled public String hipaaClass;

        @AuraEnabled public String cmeSummary;
        @AuraEnabled public String cmeClass;

        @AuraEnabled public String nextTriggerLabel;
    }

    public class PagedResult {
        @AuraEnabled public List<ProviderQueueRow> records;
        @AuraEnabled public Integer totalCount;
    }

    // ===== Existing: provider-level summary (used for drill-down) =====
    @AuraEnabled(cacheable=true)
    public static ProviderComplianceSummary getProviderComplianceSummary(Id candidateId) {
        if (candidateId == null) {
            return null;
        }

        ProviderComplianceSummary summary = new ProviderComplianceSummary();
        summary.blockingReasons = new List<String>();

        // Candidate
        Candidate__c candidate;
        try {
            candidate = [
                SELECT Id, Name,
                       CME_Compliance_Status__c,
                       Required_CME_Credits__c,
                       Total_CME_Credits_Earned__c
                FROM Candidate__c
                WHERE Id = :candidateId
                LIMIT 1
            ];
        } catch (Exception e) {
            return null;
        }

        summary.candidateId = candidate.Id;
        summary.candidateName = candidate.Name;

        // License (latest)
        LicenseSummary licenseSummary = new LicenseSummary();
        List<LicenseVerification__c> licList = [
            SELECT Id, Status__c, ExpirationDate__c
            FROM LicenseVerification__c
            WHERE Candidate__c = :candidateId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!licList.isEmpty()) {
            LicenseVerification__c lic = licList[0];
            licenseSummary.recordId = lic.Id;
            licenseSummary.status = lic.Status__c;
            licenseSummary.expirationDate = lic.ExpirationDate__c;
            if (lic.ExpirationDate__c != null) {
                licenseSummary.daysToExpiry =
                    Date.today().daysBetween(lic.ExpirationDate__c);
            }
        } else {
            licenseSummary.status = 'Not Found';
            summary.blockingReasons.add('No license verification record found.');
        }
        summary.license = licenseSummary;

        // HIPAA
        HipaaSummary hipaaSummary = new HipaaSummary();
        List<HIPAACompliance__c> hipaaList = [
            SELECT Id, Status__c
            FROM HIPAACompliance__c
            WHERE Candidate__c = :candidateId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!hipaaList.isEmpty()) {
            HIPAACompliance__c h = hipaaList[0];
            hipaaSummary.recordId = h.Id;
            hipaaSummary.status = h.Status__c;
        } else {
            hipaaSummary.status = 'Not Started';
            summary.blockingReasons.add('HIPAA compliance not started.');
        }
        summary.hipaa = hipaaSummary;

        // Provider Credentialing
        CredentialSummary credSummary = new CredentialSummary();
        List<ProviderCredential__c> credList = [
            SELECT Id,
                   Credentialing_Status__c,
                   Credential_Score_Completeness__c,
                   Credential_Score_Risk_Level__c,
                   Malpractice_Expiration_Date__c,
                   Malpractice_Coverage_Amount__c
            FROM ProviderCredential__c
            WHERE Provider__c = :candidateId
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!credList.isEmpty()) {
            ProviderCredential__c pc = credList[0];
            credSummary.recordId = pc.Id;
            credSummary.status = pc.Credentialing_Status__c;
            credSummary.completenessScore = pc.Credential_Score_Completeness__c;
            credSummary.riskScore = pc.Credential_Score_Risk_Level__c;
            credSummary.malpracticeExpiry = pc.Malpractice_Expiration_Date__c;
            credSummary.malpracticeCoverageAmount =
                pc.Malpractice_Coverage_Amount__c;
        } else {
            credSummary.status = 'Not Started';
            summary.blockingReasons.add('No provider credentialing record found.');
        }
        summary.credential = credSummary;

        // CME
        CmeSummary cmeSummary = new CmeSummary();
        cmeSummary.requiredCredits = candidate.Required_CME_Credits__c;
        cmeSummary.earnedCredits = candidate.Total_CME_Credits_Earned__c;
        cmeSummary.complianceStatus = candidate.CME_Compliance_Status__c;

        Date today = Date.today();
        Date sixtyDaysFromNow = today.addDays(60);
        AggregateResult[] cmeAgg = [
            SELECT COUNT(Id) expiringCount
            FROM CMERecord__c
            WHERE Candidate__c = :candidateId
                  AND Expiration_Date__c != null
                  AND Expiration_Date__c >= :today
                  AND Expiration_Date__c <= :sixtyDaysFromNow
        ];
        if (!cmeAgg.isEmpty()) {
            cmeSummary.expiringCount =
                (Integer)cmeAgg[0].get('expiringCount');
        } else {
            cmeSummary.expiringCount = 0;
        }
        summary.cme = cmeSummary;

        // Overall Status
        summary.overallStatus = 'Eligible';
        summary.overallReason =
            'All required compliance domains are in acceptable state.';

        if (summary.license == null
            || 'Not Found'.equals(summary.license.status)
            || 'Expired'.equals(summary.license.status)
            || 'Suspended'.equals(summary.license.status)
            || (summary.license.expirationDate != null
                && summary.license.expirationDate < Date.today())) {
            summary.overallStatus = 'Blocked';
            summary.overallReason = 'License issue.';
        }

        if (summary.hipaa == null
            || 'Not Started'.equals(summary.hipaa.status)
            || 'In Progress'.equals(summary.hipaa.status)) {
            summary.overallStatus = 'Blocked';
            summary.overallReason = 'HIPAA compliance incomplete.';
        }

        if (summary.credential == null
            || (summary.credential.status != null
                && summary.credential.status != 'Completed')) {
            summary.overallStatus = 'Blocked';
            summary.overallReason = 'Provider credentialing incomplete.';
        }

        if ('Eligible'.equals(summary.overallStatus)
            && cmeSummary.expiringCount != null
            && cmeSummary.expiringCount > 0) {
            summary.overallStatus = 'At Risk';
            summary.overallReason = 'CME requirements expiring soon.';
        }

        return summary;
    }

    // ===== Existing: audit-safe flagging =====
    @AuraEnabled
    public static void flagProviderForReview(Id candidateId, String reason) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate Id is required.');
        }
        if (!Schema.sObjectType.Task.isCreateable()) {
            throw new AuraHandledException(
                'You do not have permission to create review tasks.'
            );
        }

        Candidate__c candidate = [
            SELECT Id, Name
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];

        Task t = new Task();
        t.Subject = 'Compliance Review - Provider: ' + candidate.Name;
        t.Priority = 'High';
        t.Status = 'Not Started';
        t.WhatId = candidate.Id;
        t.OwnerId = UserInfo.getUserId();
        t.ActivityDate = Date.today().addDays(1);
        t.Description = String.isNotBlank(reason)
            ? reason
            : 'Flagged from Provider Compliance Overview console.';
        insert t;
    }

    // ===== NEW: queue data for admin landing =====
    @AuraEnabled(cacheable=true)
  public static PagedResult getProviderQueue(
    String queueName,
    String searchKey,
    String facility,
    String specialty,
    String statusFilter,
    Integer pageSize,
    Integer offset,
    String sortBy,
    String sortDirection
) {
    if (pageSize == null || pageSize <= 0) pageSize = 50;
    if (offset == null || offset < 0) offset = 0;

    // ---- Build dynamic SOQL on Candidate__c ----
    String query = 'SELECT Id, Name FROM Candidate__c WHERE Id != null';

    if (!String.isBlank(searchKey)) {
        String searchPattern = '%' + String.escapeSingleQuotes(searchKey) + '%';
        query += ' AND (Name LIKE :searchPattern)';
    }
    if (!String.isBlank(facility)) {
        query += ' AND Primary_Facility__c = :facility';
    }
    if (!String.isBlank(specialty)) {
        query += ' AND Specialty__c = :specialty';
    }

    // Basic sort – you can expand this mapping if needed
    String sortField = 'Name';
    if (sortBy == 'overallStatus') {
        // overallStatus is computed in Apex, so we just keep Name sort here
        sortField = 'Name';
    }
    query += ' ORDER BY ' + sortField + ' LIMIT :pageSize OFFSET :offset';

    // Execute dynamic query
    List<Candidate__c> candidates = Database.query(query);

    PagedResult result = new PagedResult();
    result.records = new List<ProviderQueueRow>();
    // For fully correct totalCount, you’d do a separate COUNT query;
    // for now we just use this page size.
    result.totalCount = candidates.size();

    Date today = Date.today();
    Date sixtyDaysFromNow = today.addDays(60);

    // Preload related data to avoid N+1
    Map<Id, LicenseVerification__c> licByCandidate = new Map<Id, LicenseVerification__c>();
    Map<Id, HIPAACompliance__c> hipaaByCandidate = new Map<Id, HIPAACompliance__c>();
    Map<Id, ProviderCredential__c> credByCandidate = new Map<Id, ProviderCredential__c>();
    Map<Id, AggregateResult> cmeExpiringByCandidate = new Map<Id, AggregateResult>();

    if (!candidates.isEmpty()) {
        Set<Id> candidateIds = new Map<Id, Candidate__c>(candidates).keySet();

        for (LicenseVerification__c lic : [
            SELECT Id, Candidate__c, Status__c, ExpirationDate__c
            FROM LicenseVerification__c
            WHERE Candidate__c IN :candidateIds
            ORDER BY LastModifiedDate DESC
        ]) {
            if (!licByCandidate.containsKey(lic.Candidate__c)) {
                licByCandidate.put(lic.Candidate__c, lic);
            }
        }

        for (HIPAACompliance__c hip : [
            SELECT Id, Candidate__c, Status__c
            FROM HIPAACompliance__c
            WHERE Candidate__c IN :candidateIds
            ORDER BY LastModifiedDate DESC
        ]) {
            if (!hipaaByCandidate.containsKey(hip.Candidate__c)) {
                hipaaByCandidate.put(hip.Candidate__c, hip);
            }
        }

        for (ProviderCredential__c pc : [
            SELECT Id, Provider__c, Credentialing_Status__c,
                   Credential_Score_Completeness__c,
                   Credential_Score_Risk_Level__c,
                   Malpractice_Expiration_Date__c
            FROM ProviderCredential__c
            WHERE Provider__c IN :candidateIds
            ORDER BY LastModifiedDate DESC
        ]) {
            if (!credByCandidate.containsKey(pc.Provider__c)) {
                credByCandidate.put(pc.Provider__c, pc);
            }
        }

        for (AggregateResult ar : [
            SELECT Candidate__c cId, COUNT(Id) expiringCount
            FROM CMERecord__c
            WHERE Candidate__c IN :candidateIds
                  AND Expiration_Date__c != null
                  AND Expiration_Date__c >= :today
                  AND Expiration_Date__c <= :sixtyDaysFromNow
            GROUP BY Candidate__c
        ]) {
            cmeExpiringByCandidate.put((Id) ar.get('cId'), ar);
        }
    }

    for (Candidate__c c : candidates) {
        ProviderQueueRow row = new ProviderQueueRow();
        row.candidateId = c.Id;
        row.candidateName = c.Name;

        // LICENSE
        LicenseVerification__c lic = licByCandidate.get(c.Id);
        String licenseStatus = (lic != null) ? lic.Status__c : 'Not Found';
        Date licExp = (lic != null) ? lic.ExpirationDate__c : null;

        if (lic == null) {
            row.licenseSummary = 'No license verification';
            row.licenseClass = 'slds-text-color_error';
        } else if (licExp != null && licExp < today) {
            row.licenseSummary = 'Expired on ' + String.valueOf(licExp);
            row.licenseClass = 'slds-text-color_error';
        } else if (licExp != null && licExp <= sixtyDaysFromNow) {
            row.licenseSummary = 'Expires ' + String.valueOf(licExp);
            row.licenseClass = 'slds-text-color_warning';
        } else {
            row.licenseSummary = 'Valid';
            if (licExp != null) {
                row.licenseSummary += ' • Expires ' + String.valueOf(licExp);
            }
            row.licenseClass = 'slds-text-color_success';
        }

        // HIPAA
        HIPAACompliance__c hip = hipaaByCandidate.get(c.Id);
        if (hip == null) {
            row.hipaaStatus = 'Not Started';
            row.hipaaClass = 'slds-text-color_error';
        } else {
            row.hipaaStatus = hip.Status__c;
            if ('Completed'.equalsIgnoreCase(hip.Status__c)) {
                row.hipaaClass = 'slds-text-color_success';
            } else {
                row.hipaaClass = 'slds-text-color_warning';
            }
        }

        // CREDENTIALING
        ProviderCredential__c pc = credByCandidate.get(c.Id);
        if (pc == null) {
            row.credentialSummary = 'Not Started';
            row.credentialClass = 'slds-text-color_error';
        } else {
            String completePct = (pc.Credential_Score_Completeness__c != null)
                ? String.valueOf(pc.Credential_Score_Completeness__c.setScale(0))
                : '0';
            row.credentialSummary =
                pc.Credentialing_Status__c + ' • ' + completePct + '% complete';

            if ('High'.equalsIgnoreCase(pc.Credential_Score_Risk_Level__c)) {
                row.credentialClass = 'slds-text-color_error';
            } else if ('Medium'.equalsIgnoreCase(pc.Credential_Score_Risk_Level__c)) {
                row.credentialClass = 'slds-text-color_warning';
            } else {
                row.credentialClass = 'slds-text-color_success';
            }
        }

        // CME
        AggregateResult ar = cmeExpiringByCandidate.get(c.Id);
        Integer expiringCount = (ar != null) ? (Integer) ar.get('expiringCount') : 0;
        if (expiringCount > 0) {
            row.cmeSummary = 'Expiring CME: ' + String.valueOf(expiringCount);
            row.cmeClass = 'slds-text-color_warning';
        } else {
            row.cmeSummary = 'No CME expirations in 60 days';
            row.cmeClass = 'slds-text-color_success';
        }

        // Overall status
        String overall = 'Eligible';
        String overallClass = 'slds-text-color_success';
        String overallIcon = 'utility:check';

        if ('Not Found'.equals(licenseStatus)
            || 'Expired'.equalsIgnoreCase(licenseStatus)
            || (licExp != null && licExp < today)
            || 'Not Started' == row.hipaaStatus
            || (pc != null
                && pc.Credentialing_Status__c != null
                && pc.Credentialing_Status__c != 'Completed')) {

            overall = 'Blocked';
            overallClass = 'slds-text-color_error';
            overallIcon = 'utility:error';
        } else if (expiringCount > 0
                   || (licExp != null && licExp <= sixtyDaysFromNow)) {
            overall = 'At Risk';
            overallClass = 'slds-text-color_warning';
            overallIcon = 'utility:warning';
        }

        row.overallStatus = overall;
        row.overallStatusClass = overallClass;
        row.overallStatusIcon = overallIcon;

        // Next trigger label
        row.nextTriggerLabel = 'None';
        if (licExp != null && licExp >= today) {
            row.nextTriggerLabel = 'License expires ' + String.valueOf(licExp);
        }
        if (expiringCount > 0 && row.nextTriggerLabel == 'None') {
            row.nextTriggerLabel = 'CME expiring within 60 days';
        }

        // Apply statusFilter in-memory (Blocked / At Risk / Eligible)
        if (!String.isBlank(statusFilter) && statusFilter != row.overallStatus) {
            continue;
        }

        result.records.add(row);
    }

    return result;
}

    // ===== NEW: KPIs for Overview tab =====
   @AuraEnabled(cacheable=true)
public static Map<String, Integer> getOverviewKpis() {

    // --- Counters for the dashboard tiles ---
    Integer blockedProviders        = 0;
    Integer atRiskProviders         = 0;
    Integer eligibleProviders       = 0;
    Integer expiringLicenses30      = 0;
    Integer expiringCme60           = 0;
    Integer missingHipaaTraining    = 0;
    Integer incompleteCredentialing = 0;

    Date today = Date.today();
    Date in30  = today.addDays(30);
    Date in60  = today.addDays(60);

    // ------------------------------------------------------
    // 1) Load all providers to include in the org‑wide view
    //    (add facility/specialty filters here if you need them)
    // ------------------------------------------------------
    List<Candidate__c> candidates = [
        SELECT Id
        FROM Candidate__c
    ];

    if (candidates.isEmpty()) {
        Map<String, Integer> empty = new Map<String, Integer>();
        empty.put('blockedProviders',        blockedProviders);
        empty.put('atRiskProviders',         atRiskProviders);
        empty.put('eligibleProviders',       eligibleProviders);
        empty.put('expiringLicenses30',      expiringLicenses30);
        empty.put('expiringCme60',           expiringCme60);
        empty.put('missingHipaa',            missingHipaaTraining);
        empty.put('incompleteCredentialing', incompleteCredentialing);
        return empty;
    }

    Set<Id> candidateIds = new Set<Id>();
    for (Candidate__c c : candidates) {
        candidateIds.add(c.Id);
    }

    // ------------------------------------------------------
    // 2) Preload related records in bulk (no SOQL-in-loop)
    //    We keep the *latest* record per provider.
    // ------------------------------------------------------

    // Latest LicenseVerification__c per candidate
    Map<Id, LicenseVerification__c> licenseByCandidate = new Map<Id, LicenseVerification__c>();
    for (LicenseVerification__c lv : [
        SELECT Id, Candidate__c, Status__c, ExpirationDate__c 
        FROM LicenseVerification__c
        WHERE Candidate__c IN :candidateIds
        ORDER BY ExpirationDate__c  DESC, CreatedDate DESC
    ]) {
        if (!licenseByCandidate.containsKey(lv.Candidate__c)) {
            licenseByCandidate.put(lv.Candidate__c, lv);
        }
    }

    // Latest HIPAACompliance__c per candidate
    Map<Id, HIPAACompliance__c> hipaaByCandidate = new Map<Id, HIPAACompliance__c>();
    for (HIPAACompliance__c hc : [
        SELECT Id, Candidate__c, Status__c
        FROM HIPAACompliance__c
        WHERE Candidate__c IN :candidateIds
        ORDER BY CreatedDate DESC
    ]) {
        if (!hipaaByCandidate.containsKey(hc.Candidate__c)) {
            hipaaByCandidate.put(hc.Candidate__c, hc);
        }
    }

    // Latest ProviderCredential__c per candidate
    Map<Id, ProviderCredential__c> credentialByCandidate = new Map<Id, ProviderCredential__c>();
    for (ProviderCredential__c pc : [
        SELECT Id, Provider__c, Credentialing_Status__c
        FROM ProviderCredential__c
        WHERE Provider__c IN :candidateIds
        ORDER BY CreatedDate DESC
    ]) {
        if (!credentialByCandidate.containsKey(pc.Provider__c)) {
            credentialByCandidate.put(pc.Provider__c, pc);
        }
    }

    // CME records expiring within 60 days per candidate
    // (Adjust object/field names if needed)
    Map<Id, Integer> cmeExpiringByCandidate = new Map<Id, Integer>();
    for (CMERecord__c cme : [
        SELECT Id, Candidate__c, Expiration_Date__c
        FROM CMERecord__c
        WHERE Candidate__c IN :candidateIds
        AND   Expiration_Date__c != NULL
        AND   Expiration_Date__c >= :today
        AND   Expiration_Date__c <= :in60
    ]) {
        Integer current = cmeExpiringByCandidate.containsKey(cme.Candidate__c)
            ? cmeExpiringByCandidate.get(cme.Candidate__c)
            : 0;
        cmeExpiringByCandidate.put(cme.Candidate__c, current + 1);
    }

    // ------------------------------------------------------
    // 3) Classify each provider using the *same rules*
    //    as your work‑queue (Blocked / At‑Risk / Eligible)
    // ------------------------------------------------------
    for (Candidate__c cand : candidates) {

        LicenseVerification__c lv = licenseByCandidate.get(cand.Id);
        HIPAACompliance__c    hc = hipaaByCandidate.get(cand.Id);
        ProviderCredential__c pc = credentialByCandidate.get(cand.Id);

        Integer cmeSoonCount = cmeExpiringByCandidate.containsKey(cand.Id)
            ? cmeExpiringByCandidate.get(cand.Id)
            : 0;

        Boolean isBlocked   = false;
        Boolean isAtRisk    = false;
        Boolean isEligible  = true; // assume eligible until proven otherwise

        // ---- License rules ----
        if (lv == null) {
            // No license verification at all
            isBlocked  = true;
            isEligible = false;
        } else {
            // invalid / expired license
            Boolean licenseExpired =
                (lv.ExpirationDate__c  != null && lv.ExpirationDate__c  < today);

            Boolean licenseBadStatus =
                (lv.Status__c == 'Expired' |
                 lv.Status__c == 'Suspended' ||
                 lv.Status__c == 'Not Found');

            if (licenseExpired | licenseBadStatus) {
                isBlocked  = true;
                isEligible = false;
            }

            // license expiring within next 30 days
            if (lv.ExpirationDate__c  != null &&
                lv.ExpirationDate__c  >= today &&
                lv.ExpirationDate__c  <= in30) {

                expiringLicenses30++;
                if (!isBlocked) {
                    isAtRisk  = true;
                    isEligible = false;
                }
            }
        }

        // ---- HIPAA rules ----
        // Adjust 'Status__c' values to whatever you use (Complete / Not Started / In Progress)
        if (hc == null || hc.Status__c == 'Not Started' || hc.Status__c == 'Expired') {
            missingHipaaTraining++;
            // In your design, missing HIPAA should block PHI access
            if (!isBlocked) {
                isBlocked  = true;
                isEligible = false;
            }
        }

        // ---- Credentialing rules ----
        // Adjust values for Credentialing_Status__c as in your org (Completed / Not Started / In Progress)
        if (pc == null || pc.Credentialing_Status__c != 'Completed') {
            incompleteCredentialing++;
            if (!isBlocked) {
                isBlocked  = true;
                isEligible = false;
            }
        }

        // ---- CME / CEU rules ----
        if (cmeSoonCount > 0 && !isBlocked) {
            // CME expiring soon makes the provider at‑risk but not blocked
            expiringCme60++;
            isAtRisk   = true;
            isEligible = false;
        }

        // ---- Final classification ----
        if (isBlocked) {
            blockedProviders++;
        } else if (isAtRisk) {
            atRiskProviders++;
        } else if (isEligible) {
            eligibleProviders++;
        }
    }

    // ------------------------------------------------------
    // 4) Build the map expected by your LWC
    // ------------------------------------------------------
    Map<String, Integer> kpis = new Map<String, Integer>();
    kpis.put('blockedProviders',        blockedProviders);
    kpis.put('atRiskProviders',         atRiskProviders);
    kpis.put('eligibleProviders',       eligibleProviders);
    kpis.put('expiringLicenses30',      expiringLicenses30);
    kpis.put('expiringCme60',           expiringCme60);
    kpis.put('missingHipaa',            missingHipaaTraining);
    kpis.put('incompleteCredentialing', incompleteCredentialing);

    return kpis;
}

}