public with sharing class CandidateHiringMonitorController {
    public class CandidateRow {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String candidateName;
        @AuraEnabled public String status;
        @AuraEnabled public Id employeeId;
        @AuraEnabled public Datetime convertedOn;
        @AuraEnabled public Integer ageDays;
        @AuraEnabled public Boolean hipaaComplete;
        @AuraEnabled public Boolean phiAccessGranted;
        @AuraEnabled public String identityPhase;
    }

    public class Snapshot {
        @AuraEnabled public Datetime generatedAt;
        @AuraEnabled public Integer totalPendingCompliance;
        @AuraEnabled public Integer readyButStillPending;
        @AuraEnabled public Integer pendingMissingEmployee;
        @AuraEnabled public Integer agingPendingOver3Days;
        @AuraEnabled public Integer convertedLast7Days;
        @AuraEnabled public Integer hiredLast7Days;
        @AuraEnabled public Decimal averagePendingAgeDays;
        @AuraEnabled public List<CandidateRow> readyQueue;
        @AuraEnabled public List<CandidateRow> missingEmployeeQueue;
        @AuraEnabled public List<CandidateRow> oldestPendingQueue;
    }

    @AuraEnabled(cacheable=true)
    public static Snapshot getHomeSnapshot(Integer maxRows) {
        Integer rowLimit = 10;
        if (maxRows != null) {
            rowLimit = Math.max(1, Math.min(50, maxRows));
        }

        Snapshot out = new Snapshot();
        out.generatedAt = System.now();
        out.readyQueue = new List<CandidateRow>();
        out.missingEmployeeQueue = new List<CandidateRow>();
        out.oldestPendingQueue = new List<CandidateRow>();

        List<Candidate__c> pendingCandidates = [
            SELECT Id, Name, Status__c, Employee__c, Converted_To_Employee_On__c, PHI_Access_Granted__c, Identity_Phase__c
            FROM Candidate__c
            WHERE Status__c = 'Offer Accepted - Compliance Pending'
            ORDER BY Converted_To_Employee_On__c ASC NULLS LAST, LastModifiedDate DESC
            LIMIT 2000
        ];

        out.totalPendingCompliance = pendingCandidates.size();

        Set<Id> pendingCandidateIds = new Set<Id>();
        for (Candidate__c c : pendingCandidates) {
            pendingCandidateIds.add(c.Id);
        }

        Set<Id> candidatesWithCompletedHipaa = new Set<Id>();
        if (!pendingCandidateIds.isEmpty()) {
            for (HIPAACompliance__c hipaa : [
                SELECT Candidate__c
                FROM HIPAACompliance__c
                WHERE Candidate__c IN :pendingCandidateIds
                    AND Status__c = 'Completed'
                    AND HIPAA_Training_Completed_Date__c != null
                    AND Acknowledgment_Signed_Date__c != null
            ]) {
                candidatesWithCompletedHipaa.add(hipaa.Candidate__c);
            }
        }

        Integer pendingAgeSum = 0;
        Integer pendingAgeCount = 0;
        Integer readyCount = 0;
        Integer missingEmployeeCount = 0;
        Integer agingCount = 0;

        for (Candidate__c candidate : pendingCandidates) {
            CandidateRow row = toRow(candidate, candidatesWithCompletedHipaa.contains(candidate.Id));

            if (row.ageDays != null) {
                pendingAgeSum += row.ageDays;
                pendingAgeCount++;
                if (row.ageDays > 3) {
                    agingCount++;
                }
            }

            if (row.hipaaComplete == true && candidate.Employee__c != null) {
                readyCount++;
                if (out.readyQueue.size() < rowLimit) {
                    out.readyQueue.add(row);
                }
            }

            if (candidate.Employee__c == null) {
                missingEmployeeCount++;
                if (out.missingEmployeeQueue.size() < rowLimit) {
                    out.missingEmployeeQueue.add(row);
                }
            }

            if (out.oldestPendingQueue.size() < rowLimit) {
                out.oldestPendingQueue.add(row);
            }
        }

        out.readyButStillPending = readyCount;
        out.pendingMissingEmployee = missingEmployeeCount;
        out.agingPendingOver3Days = agingCount;
        out.averagePendingAgeDays = pendingAgeCount == 0
            ? 0
            : (
                Decimal.valueOf(String.valueOf(pendingAgeSum)) /
                Decimal.valueOf(String.valueOf(pendingAgeCount))
            ).setScale(1);

        out.convertedLast7Days = [
            SELECT COUNT()
            FROM Candidate__c
            WHERE Converted_To_Employee_On__c = LAST_N_DAYS:7
        ];
        out.hiredLast7Days = [
            SELECT COUNT()
            FROM Candidate__c
            WHERE Status__c = 'Hired'
                AND LastModifiedDate = LAST_N_DAYS:7
        ];

        return out;
    }

    private static CandidateRow toRow(Candidate__c candidate, Boolean hipaaComplete) {
        CandidateRow row = new CandidateRow();
        row.candidateId = candidate.Id;
        row.candidateName = candidate.Name;
        row.status = candidate.Status__c;
        row.employeeId = candidate.Employee__c;
        row.convertedOn = candidate.Converted_To_Employee_On__c;
        row.hipaaComplete = hipaaComplete;
        row.phiAccessGranted = candidate.PHI_Access_Granted__c;
        row.identityPhase = candidate.Identity_Phase__c;
        row.ageDays = candidate.Converted_To_Employee_On__c == null
            ? null
            : candidate.Converted_To_Employee_On__c.date().daysBetween(Date.today());
        return row;
    }
}
