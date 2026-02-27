// =====================================================
// SCREENING OVERRIDE HANDLER
// Processes manual overrides and updates results
// =====================================================

public class ScreeningOverrideHandler {
    
    public static void handleApprovedOverrides(
        List<Screening_Override__c> newOverrides, 
        Map<Id, Screening_Override__c> oldMap
    ) {
        Set<Id> approvedOverrideIds = new Set<Id>();
        
        for (Screening_Override__c override1 : newOverrides) {
            Boolean wasJustApproved = (
                override1.Approval_Status__c == 'Approved' &&
                (oldMap == null || oldMap.get(override1.Id).Approval_Status__c != 'Approved')
            );
            
            if (wasJustApproved) {
                approvedOverrideIds.add(override1.Id);
            }
        }
        
        if (!approvedOverrideIds.isEmpty()) {
            for (Id overrideId : approvedOverrideIds) {
                applyOverride(overrideId);
            }
        }
    }
    
    public static void applyOverride(Id overrideId) {
        Screening_Override__c override1 = [
            SELECT Id, Candidate__c, Screening_Rule__c, Screening_Result__c,
                   New_Outcome__c, Override_Reason__c, Original_Outcome__c
            FROM Screening_Override__c 
            WHERE Id = :overrideId
        ];
        
        if (override1.Screening_Result__c != null) {
            Screening_Result__c result = [
                SELECT Id, Outcome__c, Details__c
                FROM Screening_Result__c
                WHERE Id = :override1.Screening_Result__c
            ];
            
            String previousOutcome = result.Outcome__c;
            result.Outcome__c = override1.New_Outcome__c;
            result.Details__c = (result.Details__c != null ? result.Details__c + '\n\n' : '') +
                               '*** MANUAL OVERRIDE APPLIED ***\n' +
                               'Original: ' + previousOutcome + '\n' +
                               'New: ' + override1.New_Outcome__c + '\n' +
                               'Reason: ' + override1.Override_Reason__c;
            result.Override_Applied__c = true;
            result.Override_Id__c = overrideId;
            result.Override_Date__c = System.now();
            
            update result;
        }
        
        // Update candidate screening status if needed
        updateCandidateStatus(override1.Candidate__c);
    }
    
    private static void updateCandidateStatus(Id candidateId) {
        List<Screening_Result__c> latestResults = [
            SELECT Correlation_Id__c
            FROM Screening_Result__c
            WHERE Candidate__c = :candidateId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        if (latestResults.isEmpty()) return;
        
        String correlationId = latestResults[0].Correlation_Id__c;
        
        List<Screening_Result__c> allResults = [
            SELECT Outcome__c
            FROM Screening_Result__c
            WHERE Candidate__c = :candidateId
            AND Correlation_Id__c = :correlationId
        ];
        
        Boolean hasFailures = false;
        Boolean hasReviews = false;
        
        for (Screening_Result__c result : allResults) {
            if (result.Outcome__c == 'Fail') hasFailures = true;
            if (result.Outcome__c == 'Review') hasReviews = true;
        }
        
        Candidate__c candidate = new Candidate__c(Id = candidateId);
        if (hasFailures) {
            candidate.Screening_Status__c = 'Failed';
        } else if (hasReviews) {
            candidate.Screening_Status__c = 'Manual Review';
        } else {
            candidate.Screening_Status__c = 'Passed';
        }
        
        update candidate;
    }
}