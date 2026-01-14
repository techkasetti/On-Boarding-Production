// public with sharing class CandidateStatusController {
//     // DTO for the LWC payload
//     public class CandidateStatusDto {
//         @AuraEnabled public Id candidateId;
//         @AuraEnabled public String name;
//         @AuraEnabled public String status;
//         @AuraEnabled public List<EvalResultDto> results;
//         @AuraEnabled public Map<String, String> routingInfo;
//         public CandidateStatusDto() {
//             this.results = new List<EvalResultDto>();
//             this.routingInfo = null;
//         }
//     }

//     // DTO for a single result row
//     public class EvalResultDto {
//         @AuraEnabled public String ruleName;
//         @AuraEnabled public String outcome;
//         @AuraEnabled public String details;
//         @AuraEnabled public String action;
//         public EvalResultDto(String ruleName, String outcome, String details, String action) {
//             this.ruleName = ruleName;
//             this.outcome = outcome;
//             this.details = details;
//             this.action = action;
//         }
//     }

//     // Main method to get status
//     @AuraEnabled(cacheable=true)
//     public static CandidateStatusDto getCandidateStatus(Id candidateId) {
//         if (candidateId == null) { throw new AuraHandledException('Candidate ID is required.'); }
//         CandidateStatusDto dto = new CandidateStatusDto();
//         dto.candidateId = candidateId;

//         try {
//             Candidate__c c = [SELECT Id, Name FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
//             dto.name = c.Name;
//         } catch (Exception e) {
//             throw new AuraHandledException('Could not retrieve candidate information.');
//         }

//         List<Screening_Result__c> latestResults = [
//             SELECT Correlation_Id__c FROM Screening_Result__c
//             WHERE Candidate__c = :candidateId AND Correlation_Id__c != null
//             ORDER BY CreatedDate DESC LIMIT 1
//         ];

//         if (latestResults.isEmpty()) {
//             dto.status = 'Not Yet Screened';
//             return dto;
//         }
//         String latestCorrelationId = latestResults[0].Correlation_Id__c;

//         List<Screening_Result__c> screeningResults = [
//             SELECT Id, Outcome__c, Details__c, Action__c, Screening_Rule__r.Name
//             FROM Screening_Result__c
//             WHERE Candidate__c = :candidateId AND Correlation_Id__c = :latestCorrelationId
//             ORDER BY CreatedDate DESC
//         ];

//         boolean hasFailures = false;
//         for (Screening_Result__c res : screeningResults) {
//             dto.results.add(new EvalResultDto(
//                 res.Screening_Rule__r.Name, res.Outcome__c, res.Details__c, res.Action__c
//             ));
//             if (res.Outcome__c == 'Fail' | res.Outcome__c == 'Review') {
//                 hasFailures = true;
//             }
//             if (res.Action__c == 'RouteToJurisdiction' && (res.Outcome__c == 'Fail' || res.Outcome__c == 'Review')) {
//                 dto.routingInfo = new Map<String, String>{
//                     'queue' => 'Jurisdiction Review',
//                     'notes' => 'Candidate flagged for review based on rule: ' + res.Screening_Rule__r.Name
//                 };
//             }
//         }
//         dto.status = hasFailures ? 'Action Required' : 'Passed';
//         return dto;
//     }

//     // Method to trigger the screening
//     @AuraEnabled
//     public static void rerunScreening(Id candidateId) {
//         if (candidateId == null) { throw new AuraHandledException('Candidate ID is required.'); }

//         Candidate__c candidate;
//         try {
//             // Using the confirmed field name
//             candidate = [SELECT Id, Interested_In_Job__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
//         } catch (QueryException e) {
//             throw new AuraHandledException('Could not find the candidate record.');
//         }

//         if (candidate.Interested_In_Job__c == null) {
//             throw new AuraHandledException('Cannot run screening: This candidate is not associated with a job posting.');
//         }

//         try {
//             // This map correctly associates the candidate with their specific job
//             Map<Id, Id> candidateToJobMap = new Map<Id, Id>{ candidate.Id => candidate.Interested_In_Job__c };
//             System.enqueueJob(new ScreeningQueueable(candidateToJobMap));
//         } catch (Exception e) {
//             throw new AuraHandledException('Failed to start the screening process: ' + e.getMessage());
//         }
//     }
// }

// =====================================================
// CANDIDATE STATUS CONTROLLER
// For displaying screening results in LWC
// =====================================================

// =====================================================
// CANDIDATE STATUS CONTROLLER - FIXED VERSION
// Enhanced error handling and debugging
// =====================================================

public with sharing class CandidateStatusController {
    
    public class CandidateStatusDto {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public List<EvalResultDto> results;
        @AuraEnabled public Map<String, String> routingInfo;
        @AuraEnabled public List<OverrideDto> overrides;
        @AuraEnabled public String correlationId;
        @AuraEnabled public DateTime lastScreeningDate;
        @AuraEnabled public Integer totalRules;
        @AuraEnabled public Integer rulesPassed;
        @AuraEnabled public Integer rulesFailed;
        @AuraEnabled public Integer rulesReview;
        
        public CandidateStatusDto() {
            this.results = new List<EvalResultDto>();
            this.overrides = new List<OverrideDto>();
            this.routingInfo = null;
        }
    }
    
    public class EvalResultDto {
        @AuraEnabled public String ruleName;
        @AuraEnabled public String ruleCategory;
        @AuraEnabled public String outcome;
        @AuraEnabled public String details;
        @AuraEnabled public String action;
        @AuraEnabled public String actualValue;
        @AuraEnabled public String expectedValue;
        @AuraEnabled public Boolean overrideApplied;
        
        public EvalResultDto(Screening_Result__c result) {
            this.ruleName = result.Screening_Rule__r.Name;
            this.ruleCategory = result.Screening_Rule__r.Rule_Category__c;
            this.outcome = result.Outcome__c;
            this.details = result.Details__c;
            this.action = result.Action__c;
            this.actualValue = result.Actual_Value__c;
            this.expectedValue = result.Expected_Value__c;
            this.overrideApplied = result.Override_Applied__c;
        }
    }
    
    public class OverrideDto {
        @AuraEnabled public String ruleName;
        @AuraEnabled public String originalOutcome;
        @AuraEnabled public String newOutcome;
        @AuraEnabled public String reason;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public String overrideBy;
        @AuraEnabled public DateTime overrideDate;
        
        public OverrideDto(Screening_Override__c ov) {
            this.ruleName = ov.Screening_Rule__r.Name;
            this.originalOutcome = ov.Original_Outcome__c;
            this.newOutcome = ov.New_Outcome__c;
            this.reason = ov.Override_Reason__c;
            this.approvalStatus = ov.Approval_Status__c;
            this.overrideBy = ov.Override_By__r.Name;
            this.overrideDate = ov.Override_Date__c;
        }
    }
    @AuraEnabled(cacheable=true)
    public static CandidateStatusDto getCandidateStatus(Id candidateId) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID is required.');
        }
        
        CandidateStatusDto dto = new CandidateStatusDto();
        dto.candidateId = candidateId;
        
        // Get candidate info
        try {
            Candidate__c c = [
                SELECT Id, Name, Screening_Status__c, Last_Screening_Date__c, 
                       Latest_Correlation_Id__c, Routed_To_Queue__c, Current_Journey_Path__c
                FROM Candidate__c 
                WHERE Id = :candidateId 
                LIMIT 1
            ];
            
            dto.name = c.Name;
            dto.status = c.Screening_Status__c != null ? c.Screening_Status__c : 'Not Yet Screened';
            dto.lastScreeningDate = c.Last_Screening_Date__c;
            dto.correlationId = c.Latest_Correlation_Id__c;
        } catch (Exception e) {
            throw new AuraHandledException('Could not retrieve candidate information.');
        }
        
        // Get latest screening results
        List<Screening_Result__c> latestResults = [
            SELECT Correlation_Id__c 
            FROM Screening_Result__c
            WHERE Candidate__c = :candidateId 
            AND Correlation_Id__c != null
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        if (latestResults.isEmpty()) {
            return dto;
        }
        
        String latestCorrelationId = latestResults[0].Correlation_Id__c;
        dto.correlationId = latestCorrelationId;
        
        // Get all results for latest run
        List<Screening_Result__c> screeningResults = [
            SELECT Id, Outcome__c, Details__c, Action__c, Actual_Value__c, 
                   Expected_Value__c, Override_Applied__c,
                   Screening_Rule__r.Name, Screening_Rule__r.Rule_Category__c
            FROM Screening_Result__c
            WHERE Candidate__c = :candidateId 
            AND Correlation_Id__c = :latestCorrelationId
            ORDER BY Screening_Rule__r.Priority__c ASC
        ];
        
        dto.totalRules = screeningResults.size();
        dto.rulesPassed = 0;
        dto.rulesFailed = 0;
        dto.rulesReview = 0;
        
        for (Screening_Result__c res : screeningResults) {
            dto.results.add(new EvalResultDto(res));
            
            if (res.Outcome__c == 'Pass') dto.rulesPassed++;
            else if (res.Outcome__c == 'Fail') dto.rulesFailed++;
            else if (res.Outcome__c == 'Review') dto.rulesReview++;
        }
        
        // Get routing decision
        List<Routing_Decision__c> routingDecisions = [
            SELECT Journey_Path__c, Assigned_Queue__c, Decision_Reason__c,
                   Escalation_Level__c, Required_Actions__c
            FROM Routing_Decision__c
            WHERE Candidate__c = :candidateId
            AND Correlation_Id__c = :latestCorrelationId
            ORDER BY Decision_Date__c DESC
            LIMIT 1
        ];
        
        if (!routingDecisions.isEmpty()) {
            Routing_Decision__c routing = routingDecisions[0];
            dto.routingInfo = new Map<String, String>{
                'journeyPath' => routing.Journey_Path__c,
                'queue' => routing.Assigned_Queue__c,
                'reason' => routing.Decision_Reason__c,
                'escalationLevel' => String.valueOf(routing.Escalation_Level__c),
                'actions' => routing.Required_Actions__c
            };
        }
        
        // Get overrides
        List<Screening_Override__c> overrides = [
            SELECT Screening_Rule__r.Name, Original_Outcome__c, New_Outcome__c,
                   Override_Reason__c, Approval_Status__c, Override_By__r.Name, Override_Date__c
            FROM Screening_Override__c
            WHERE Candidate__c = :candidateId
            ORDER BY Override_Date__c DESC
        ];
        
        for (Screening_Override__c ov : overrides) {
            dto.overrides.add(new OverrideDto(ov));
        }
        
        return dto;
    }
    
    @AuraEnabled
    public static void rerunScreening(Id candidateId) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID is required.');
        }
        
        Candidate__c candidate;
        try {
            candidate = [
                SELECT Id, Interested_In_Job__c 
                FROM Candidate__c 
                WHERE Id = :candidateId 
                LIMIT 1
            ];
        } catch (QueryException e) {
            throw new AuraHandledException('Could not find the candidate record.');
        }
        
        if (candidate.Interested_In_Job__c == null) {
            throw new AuraHandledException('Cannot run screening: Candidate is not associated with a job posting.');
        }
        
        try {
            Map<Id, Id> candidateToJobMap = new Map<Id, Id>{ 
                candidate.Id => candidate.Interested_In_Job__c 
            };
            System.enqueueJob(new ScreeningQueueable(candidateToJobMap));
        } catch (Exception e) {
            throw new AuraHandledException('Failed to start the screening process: ' + e.getMessage());
        }
    }
}
