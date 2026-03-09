// public with sharing class CandidateStatusController {
    
//     public class CandidateStatusDto {
//         @AuraEnabled public Id candidateId;
//         @AuraEnabled public String name;
//         @AuraEnabled public String jobTitle; // 🔥 NEW: Add job title
//         @AuraEnabled public String status;
//         @AuraEnabled public List<EvalResultDto> results;
//         @AuraEnabled public Map<String, String> routingInfo;
//         @AuraEnabled public List<OverrideDto> overrides;
//         @AuraEnabled public String correlationId;
//         @AuraEnabled public DateTime lastScreeningDate;
//         @AuraEnabled public Integer totalRules;
//         @AuraEnabled public Integer rulesPassed;
//         @AuraEnabled public Integer rulesFailed;
//         @AuraEnabled public Integer rulesReview;
        
//         public CandidateStatusDto() {
//             this.results = new List<EvalResultDto>();
//             this.overrides = new List<OverrideDto>();
//             this.routingInfo = null;
//         }
//     }
    
//     public class EvalResultDto {
//         @AuraEnabled public String ruleName;
//         @AuraEnabled public String ruleCategory;
//         @AuraEnabled public String outcome;
//         @AuraEnabled public String details;
//         @AuraEnabled public String action;
//         @AuraEnabled public String actualValue;
//         @AuraEnabled public String expectedValue;
//         @AuraEnabled public Boolean overrideApplied;
        
//         public EvalResultDto(Screening_Result__c result) {
//             this.ruleName = result.Screening_Rule__r.Name;
//             this.ruleCategory = result.Screening_Rule__r.Rule_Category__c;
//             this.outcome = result.Outcome__c;
//             this.details = result.Details__c;
//             this.action = result.Action__c;
//             this.actualValue = result.Actual_Value__c;
//             this.expectedValue = result.Expected_Value__c;
//             this.overrideApplied = result.Override_Applied__c;
//         }
//     }
    
//     public class OverrideDto {
//         @AuraEnabled public String ruleName;
//         @AuraEnabled public String originalOutcome;
//         @AuraEnabled public String newOutcome;
//         @AuraEnabled public String reason;
//         @AuraEnabled public String approvalStatus;
//         @AuraEnabled public String overrideBy;
//         @AuraEnabled public DateTime overrideDate;
        
//         public OverrideDto(Screening_Override__c ov) {
//             this.ruleName = ov.Screening_Rule__r.Name;
//             this.originalOutcome = ov.Original_Outcome__c;
//             this.newOutcome = ov.New_Outcome__c;
//             this.reason = ov.Override_Reason__c;
//             this.approvalStatus = ov.Approval_Status__c;
//             this.overrideBy = ov.Override_By__r.Name;
//             this.overrideDate = ov.Override_Date__c;
//         }
//     }
    
//     @AuraEnabled(cacheable=true)
//     public static CandidateStatusDto getCandidateStatus(Id candidateId) {
//         if (candidateId == null) {
//             throw new AuraHandledException('Candidate ID is required.');
//         }
        
//         CandidateStatusDto dto = new CandidateStatusDto();
//         dto.candidateId = candidateId;
        
//         // Get candidate info
//         try {
//             Candidate__c c = [
//                 SELECT Id, Name, Screening_Status__c, Last_Screening_Date__c, 
//                        Latest_Correlation_Id__c, Routed_To_Queue__c, Current_Journey_Path__c,
//                        Interested_In_Job__c, Interested_In_Job__r.Name // 🔥 FIX: Fetch job posting name
//                 FROM Candidate__c 
//                 WHERE Id = :candidateId 
//                 LIMIT 1
//             ];
            
//             dto.candidateId = candidateId;
//             dto.name = c.Name;
//             dto.jobTitle = c.Interested_In_Job__c != null ? c.Interested_In_Job__r.Name : 'Not Assigned'; // 🔥 FIX: Set actual job title
//             dto.status = c.Screening_Status__c != null ? c.Screening_Status__c : 'Not Yet Screened';
//             dto.lastScreeningDate = c.Last_Screening_Date__c;
//             dto.correlationId = c.Latest_Correlation_Id__c;
//         } catch (Exception e) {
//             throw new AuraHandledException('Could not retrieve candidate information.');
//         }
        
//         // Get latest screening results
//         List<Screening_Result__c> latestResults = [
//             SELECT Correlation_Id__c 
//             FROM Screening_Result__c
//             WHERE Candidate__c = :candidateId 
//             AND Correlation_Id__c != null
//             ORDER BY CreatedDate DESC 
//             LIMIT 1
//         ];
        
//         if (latestResults.isEmpty()) {
//             return dto;
//         }
        
//         String latestCorrelationId = latestResults[0].Correlation_Id__c;
//         dto.correlationId = latestCorrelationId;
        
//         // Get all results for latest run
//         List<Screening_Result__c> screeningResults = [
//             SELECT Id, Outcome__c, Details__c, Action__c, Actual_Value__c, 
//                    Expected_Value__c, Override_Applied__c,
//                    Screening_Rule__r.Name, Screening_Rule__r.Rule_Category__c
//             FROM Screening_Result__c
//             WHERE Candidate__c = :candidateId 
//             AND Correlation_Id__c = :latestCorrelationId
//             ORDER BY Screening_Rule__r.Priority__c ASC
//         ];
        
//         dto.totalRules = screeningResults.size();
//         dto.rulesPassed = 0;
//         dto.rulesFailed = 0;
//         dto.rulesReview = 0;
        
//         for (Screening_Result__c res : screeningResults) {
//             dto.results.add(new EvalResultDto(res));
            
//             if (res.Outcome__c == 'Pass') dto.rulesPassed++;
//             else if (res.Outcome__c == 'Fail') dto.rulesFailed++;
//             else if (res.Outcome__c == 'Review') dto.rulesReview++;
//         }
        
//         // Get routing decision
//         List<Routing_Decision__c> routingDecisions = [
//             SELECT Journey_Path__c, Assigned_Queue__c, Decision_Reason__c,
//                    Escalation_Level__c, Required_Actions__c
//             FROM Routing_Decision__c
//             WHERE Candidate__c = :candidateId
//             AND Correlation_Id__c = :latestCorrelationId
//             ORDER BY Decision_Date__c DESC
//             LIMIT 1
//         ];
        
//         if (!routingDecisions.isEmpty()) {
//             Routing_Decision__c routing = routingDecisions[0];
//             dto.routingInfo = new Map<String, String>{
//                 'journeyPath' => routing.Journey_Path__c,
//                 'queue' => routing.Assigned_Queue__c,
//                 'reason' => routing.Decision_Reason__c,
//                 'escalationLevel' => String.valueOf(routing.Escalation_Level__c),
//                 'actions' => routing.Required_Actions__c
//             };
//         }
        
//         // Get overrides
//         List<Screening_Override__c> overrides = [
//             SELECT Screening_Rule__r.Name, Original_Outcome__c, New_Outcome__c,
//                    Override_Reason__c, Approval_Status__c, Override_By__r.Name, Override_Date__c
//             FROM Screening_Override__c
//             WHERE Candidate__c = :candidateId
//             ORDER BY Override_Date__c DESC
//         ];
        
//         for (Screening_Override__c ov : overrides) {
//             dto.overrides.add(new OverrideDto(ov));
//         }
        
//         return dto;
//     }
    
//     @AuraEnabled
//     public static void rerunScreening(Id candidateId) {
//         if (candidateId == null) {
//             throw new AuraHandledException('Candidate ID is required.');
//         }
        
//         Candidate__c candidate;
//         try {
//             candidate = [
//                 SELECT Id, Interested_In_Job__c 
//                 FROM Candidate__c 
//                 WHERE Id = :candidateId 
//                 LIMIT 1
//             ];
//         } catch (QueryException e) {
//             throw new AuraHandledException('Could not find the candidate record.');
//         }
        
//         if (candidate.Interested_In_Job__c == null) {
//             throw new AuraHandledException('Cannot run screening: Candidate is not associated with a job posting.');
//         }
        
//         try {
//             Map<Id, Id> candidateToJobMap = new Map<Id, Id>{ 
//                 candidate.Id => candidate.Interested_In_Job__c 
//             };
//             System.enqueueJob(new ScreeningQueueable(candidateToJobMap));
//         } catch (Exception e) {
//             throw new AuraHandledException('Failed to start the screening process: ' + e.getMessage());
//         }
//     }
// }

// =====================================================
// CANDIDATE STATUS CONTROLLER - UPDATED WITH RESULT IDs
// For displaying screening results in LWC with Manual Override support
// =====================================================
public with sharing class CandidateStatusController {
    
    public class CandidateStatusDto {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String name;
        @AuraEnabled public String jobTitle;
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
            this.results     = new List<EvalResultDto>();
            this.overrides   = new List<OverrideDto>();
            this.routingInfo = null;
        }
    }
    
    public class EvalResultDto {
        @AuraEnabled public Id resultId;
        @AuraEnabled public Id ruleId;
        @AuraEnabled public String ruleName;
        @AuraEnabled public String ruleCategory;
        @AuraEnabled public String outcome;
        @AuraEnabled public String details;
        @AuraEnabled public String action;
        @AuraEnabled public String actualValue;
        @AuraEnabled public String expectedValue;
        @AuraEnabled public Boolean overrideApplied;
        @AuraEnabled public Boolean allowManualOverride;

        public EvalResultDto(Screening_Result__c result) {
            this.resultId          = result.Id;
            this.ruleId            = result.Screening_Rule__c;
            this.ruleName          = result.Screening_Rule__r.Name;
            this.ruleCategory      = result.Screening_Rule__r.Rule_Category__c;
            this.outcome           = result.Outcome__c;
            this.details           = result.Details__c;
            this.action            = result.Action__c;
            this.actualValue       = result.Actual_Value__c;
            this.expectedValue     = result.Expected_Value__c;
            this.overrideApplied   = result.Override_Applied__c;
            this.allowManualOverride = result.Screening_Rule__r.Allow_Manual_Override__c;
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
            this.ruleName        = ov.Screening_Rule__r.Name;
            this.originalOutcome = ov.Original_Outcome__c;
            this.newOutcome      = ov.New_Outcome__c;
            this.reason          = ov.Override_Reason__c;
            this.approvalStatus  = ov.Approval_Status__c;
            this.overrideBy      = ov.Override_By__r.Name;
            this.overrideDate    = ov.Override_Date__c;
        }
    }

    public class JobApplicationWrapper {
        @AuraEnabled public Id jobApplicationId;
        @AuraEnabled public String jobApplicationName;
        @AuraEnabled public String jobTitle;
        @AuraEnabled public String status;
        @AuraEnabled public String screeningResult;
        @AuraEnabled public Decimal screeningScore;
        @AuraEnabled public Date applicationDate;
        @AuraEnabled public String eligibilitySummary;

        public JobApplicationWrapper(Job_Application__c jobApp) {
            this.jobApplicationId   = jobApp.Id;
            this.jobApplicationName = jobApp.Name;
            this.jobTitle           = jobApp.Job_Posting__r != null
                                      ? jobApp.Job_Posting__r.Job_Title__c : 'N/A';
            this.status             = jobApp.Status__c;
            this.screeningResult    = jobApp.Screening_Result__c;
            this.screeningScore     = jobApp.Screening_Score__c;
            this.applicationDate    = jobApp.Application_Date__c;
            this.eligibilitySummary = jobApp.Eligibility_Summary__c;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<JobApplicationWrapper> getJobApplicationsForCandidate(Id candidateId) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID is required.');
        }

        List<Job_Application__c> jobApps = [
            SELECT Id, Name, Status__c,
                   Application_Date__c,
                   Screening_Result__c,
                   Screening_Score__c,
                   Eligibility_Summary__c,
                   Job_Posting__c,
                   Job_Posting__r.Job_Title__c,
                   Job_Posting__r.Name
            FROM Job_Application__c
            WHERE Candidate__c = :candidateId
            ORDER BY Application_Date__c DESC
        ];

        List<JobApplicationWrapper> wrappers = new List<JobApplicationWrapper>();
        for (Job_Application__c jobApp : jobApps) {
            wrappers.add(new JobApplicationWrapper(jobApp));
        }
        return wrappers;
    }

    @AuraEnabled(cacheable=true)
    public static CandidateStatusDto getCandidateStatus(Id candidateId, Id jobApplicationId) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID is required.');
        }

        CandidateStatusDto dto = new CandidateStatusDto();
        dto.candidateId = candidateId;

        // ── Get Candidate Info ────────────────────────────────────────────────
        try {
            Candidate__c c = [
                SELECT Id, Name, Screening_Status__c, Last_Screening_Date__c,
                       Latest_Correlation_Id__c, Routed_To_Queue__c,
                       Current_Journey_Path__c,
                       Interested_In_Job__c, Interested_In_Job__r.Name
                FROM Candidate__c
                WHERE Id = :candidateId
                LIMIT 1
            ];

            dto.name              = c.Name;
            dto.jobTitle          = c.Interested_In_Job__c != null
                                    ? c.Interested_In_Job__r.Name : 'Not Assigned';
            dto.status            = c.Screening_Status__c != null
                                    ? c.Screening_Status__c : 'Not Yet Screened';
            dto.lastScreeningDate = c.Last_Screening_Date__c;
            dto.correlationId     = c.Latest_Correlation_Id__c;

        } catch (Exception e) {
            throw new AuraHandledException('Could not retrieve candidate information.');
        }

        // ── Require jobApplicationId — no cross-job fallback ─────────────────
        // 🔥 FIX: If no jobApplicationId provided, return empty dto immediately.
        //         We never fall back to "absolute latest" because that shows
        //         another job's results.
        if (jobApplicationId == null) {
            return dto;
        }

        // ── Get Job Posting ID from Job Application ───────────────────────────
        Id jobPostingId = null;
        List<Job_Application__c> jobApps = [
            SELECT Id, Job_Posting__c
            FROM Job_Application__c
            WHERE Id = :jobApplicationId
            LIMIT 1
        ];

        if (jobApps.isEmpty() || jobApps[0].Job_Posting__c == null) {
            // Job application has no linked job posting — return empty
            return dto;
        }

        jobPostingId = jobApps[0].Job_Posting__c;

        // ── Find Latest Correlation ID strictly for this Job Posting ──────────
        // 🔥 FIX: Only query by Job_Posting__c — NO fallback to other jobs
        List<Screening_Result__c> latestResults = [
            SELECT Correlation_Id__c
            FROM Screening_Result__c
            WHERE Candidate__c    = :candidateId
            AND Job_Posting__c    = :jobPostingId
            AND Correlation_Id__c != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        // No results for this specific job yet — return empty dto (don't show other job's data)
        if (latestResults.isEmpty()) {
            return dto;
        }

        String latestCorrelationId = latestResults[0].Correlation_Id__c;
        dto.correlationId          = latestCorrelationId;

        // ── Get Screening Results ─────────────────────────────────────────────
        // 🔥 FIX: Filter by BOTH correlationId AND Job_Posting__c to be 100% safe
        List<Screening_Result__c> screeningResults = [
            SELECT Id, Screening_Rule__c, Outcome__c, Details__c, Action__c,
                   Actual_Value__c, Expected_Value__c, Override_Applied__c,
                   Screening_Rule__r.Name, Screening_Rule__r.Rule_Category__c,
                   Screening_Rule__r.Priority__c,
                   Screening_Rule__r.Allow_Manual_Override__c
            FROM Screening_Result__c
            WHERE Candidate__c    = :candidateId
            AND Correlation_Id__c = :latestCorrelationId
            AND Job_Posting__c    = :jobPostingId
            ORDER BY Screening_Rule__r.Priority__c ASC NULLS LAST
        ];

        dto.totalRules  = screeningResults.size();
        dto.rulesPassed = 0;
        dto.rulesFailed = 0;
        dto.rulesReview = 0;

        for (Screening_Result__c res : screeningResults) {
            dto.results.add(new EvalResultDto(res));
            if      (res.Outcome__c == 'Pass')   dto.rulesPassed++;
            else if (res.Outcome__c == 'Fail')   dto.rulesFailed++;
            else if (res.Outcome__c == 'Review') dto.rulesReview++;
        }

        // ── Get Routing Decision ──────────────────────────────────────────────
        // 🔥 FIX: Filter by Job_Posting__c too
        List<Routing_Decision__c> routingDecisions = [
            SELECT Journey_Path__c, Assigned_Queue__c, Decision_Reason__c,
                   Escalation_Level__c, Required_Actions__c
            FROM Routing_Decision__c
            WHERE Candidate__c    = :candidateId
            AND Correlation_Id__c = :latestCorrelationId
            AND Job_Posting__c    = :jobPostingId
            ORDER BY Decision_Date__c DESC
            LIMIT 1
        ];

        if (!routingDecisions.isEmpty()) {
            Routing_Decision__c routing = routingDecisions[0];
            dto.routingInfo = new Map<String, String>{
                'journeyPath'     => routing.Journey_Path__c,
                'queue'           => routing.Assigned_Queue__c,
                'reason'          => routing.Decision_Reason__c,
                'escalationLevel' => String.valueOf(routing.Escalation_Level__c),
                'actions'         => routing.Required_Actions__c
            };
        }

        // ── Get Overrides (candidate-level, shown regardless of job) ──────────
        List<Screening_Override__c> overrides = [
            SELECT Screening_Rule__r.Name, Original_Outcome__c, New_Outcome__c,
                   Override_Reason__c, Approval_Status__c,
                   Override_By__r.Name, Override_Date__c
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
public static void rerunScreening(Id candidateId, Id jobApplicationId) {

    Id jobPostingId = null;

    if (jobApplicationId != null) {
        Job_Application__c jobApp = [
            SELECT Id, Candidate__c, Job_Posting__c
            FROM Job_Application__c
            WHERE Id = :jobApplicationId
            LIMIT 1
        ];
        if (jobApp.Job_Posting__c == null) {
            throw new AuraHandledException(
                'Cannot run screening: Job Application has no Job Posting linked.'
            );
        }
        candidateId  = jobApp.Candidate__c;
        jobPostingId = jobApp.Job_Posting__c;
    } else {
        Candidate__c candidate = [
            SELECT Id, Interested_In_Job__c
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];
        if (candidate.Interested_In_Job__c == null) {
            throw new AuraHandledException(
                'Cannot run screening: Candidate is not associated with a job posting.'
            );
        }
        jobPostingId = candidate.Interested_In_Job__c;
    }

    // 🔥 FIX: Check if active rules exist for this job BEFORE enqueuing
    List<Screening_Rule__c> activeRules = [
        SELECT Id 
        FROM Screening_Rule__c
        WHERE Applied_Role__c     = :jobPostingId
        AND Active__c             = true
        AND Is_Current_Version__c = true
        AND (Test_Mode_Only__c    = false OR Test_Mode_Only__c = null)
        LIMIT 1
    ];

    if (activeRules.isEmpty()) {
        throw new AuraHandledException(
            'No active screening rules are defined for this job posting. Please configure rules before running screening.'
        );
    }

    try {
        Map<Id, Id> candidateToJobMap = new Map<Id, Id>{ candidateId => jobPostingId };
        System.enqueueJob(new ScreeningQueueable(candidateToJobMap, false));
    } catch (Exception e) {
        throw new AuraHandledException('Failed to start screening: ' + e.getMessage());
    }
}
}