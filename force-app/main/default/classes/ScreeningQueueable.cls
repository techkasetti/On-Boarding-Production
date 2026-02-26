// public with sharing class ScreeningQueueable implements Queueable {
//     private Map<Id, Id> candidateToJobMap;

//     public ScreeningQueueable(Map<Id, Id> candToJobMap) {
//         this.candidateToJobMap = candToJobMap;
//     }

//     public void execute(QueueableContext qc) {
//         if (candidateToJobMap == null | candidateToJobMap.isEmpty()) {
//             return;
//         }

//         Set<Id> candidateIds = candidateToJobMap.keySet();
//         Set<Id> jobPostingIds = new Set<Id>(candidateToJobMap.values());

//         List<Screening_Rule__c> relevantRules = [
//             SELECT Name, Applied_Role__c, Target_Object__c, Field_API_Name__c, 
//                    Operator__c, Expected_Value__c, Action__c, Failure_Message__c
//             FROM Screening_Rule__c
//             WHERE Active__c = true AND Applied_Role__c IN :jobPostingIds
//         ];

//         Map<Id, List<Screening_Rule__c>> rulesByJobId = new Map<Id, List<Screening_Rule__c>>();
//         for (Screening_Rule__c rule : relevantRules) {
//             if (!rulesByJobId.containsKey(rule.Applied_Role__c)) {
//                 rulesByJobId.put(rule.Applied_Role__c, new List<Screening_Rule__c>());
//             }
//             rulesByJobId.get(rule.Applied_Role__c).add(rule);
//         }

//         List<Candidate__c> candidates = [
//             SELECT Id, Name, Years_of_Experience__c, Location__c,
//                    (SELECT Id, Name, Type__c FROM License_Certifications__r),
//                    (SELECT Id, Organization__c, Role__c FROM Work_Experiences__r)
//             FROM Candidate__c WHERE Id IN :candidateIds
//         ];

//         List<Screening_Result__c> resultsToInsert = new List<Screening_Result__c>();
//         // CORRECTED: Use your Platform Event's API name
//         List<Screening_Run_Completed__e> eventsToPublish = new List<Screening_Run_Completed__e>();
        
//         String correlationId = 'RUN-' + Datetime.now().getTime();

//         for (Candidate__c candidate : candidates) {
//             Id jobPostingId = candidateToJobMap.get(candidate.Id);
//             List<Screening_Rule__c> rulesForThisJob = rulesByJobId.get(jobPostingId);

//             if (rulesForThisJob == null | rulesForThisJob.isEmpty()) {
//                 continue;
//             }

//             List<ScreeningRuleService.EvalResult> evaluationResults = ScreeningRuleService.evaluateRules(rulesForThisJob, candidate);
//             boolean hasFailures = false;

//             for (ScreeningRuleService.EvalResult eval : evaluationResults) {
//                 Screening_Result__c result = new Screening_Result__c();
//                 result.Candidate__c = candidate.Id;
//                 result.Screening_Rule__c = eval.rule.Id;
//                 result.Outcome__c = eval.outcome;
//                 result.Details__c = eval.details;
//                 result.Action__c = eval.rule.Action__c;
//                 result.Correlation_Id__c = correlationId;
//                 resultsToInsert.add(result);

//                 if (eval.outcome == 'Fail' | eval.outcome == 'Review') {
//                     hasFailures = true;
//                 }
//             }
            
//             String finalStatus = hasFailures ? 'Action Required' : 'Passed';
            
//             // CORRECTED: Create an instance of your event and use your field API names
//             eventsToPublish.add(new Screening_Run_Completed__e(
//                 Candidate_ID__c = candidate.Id,
//                 Final_Status__c = finalStatus,
//                 Correlation_ID__c = correlationId
//             ));
//         }

//         if (!resultsToInsert.isEmpty()) {
//             insert resultsToInsert;
//         }

//         if (!eventsToPublish.isEmpty()) {
//             // This will now work because the list is of the correct type
//             EventBus.publish(eventsToPublish);
//         }
//     }
// }
// =====================================================
// SCREENING QUEUEABLE
// Asynchronous processing of screening rules
// =====================================================

// public class ScreeningQueueable implements Queueable {
//     private Map<Id, Id> candidateToJobMap;

//     public ScreeningQueueable(Map<Id, Id> candToJobMap) {
//         this.candidateToJobMap = candToJobMap;
//         System.debug('ScreeningQueueable initialized with ' + candToJobMap.size() + ' candidates');
//     }
public class ScreeningQueueable implements Queueable, Database.AllowsCallouts {
    private Map<Id, Id> candidateToJobMap;
    private Boolean aiEnabled; 
    private Map<Id, Id> candidateToJobAppMap;
    private Boolean aiOnlyMode;
    private Map<Id, Decimal> candidateToRuleScoreMap; // 🔥 NEW

    // AI-only constructor — chained after DML completes
    public ScreeningQueueable(Map<Id, Id> candidateToJobAppMap, Map<Id, Decimal> candidateToRuleScoreMap, String mode) {
        this.candidateToJobAppMap    = candidateToJobAppMap != null
                                       ? candidateToJobAppMap
                                       : new Map<Id, Id>();
        this.candidateToRuleScoreMap = candidateToRuleScoreMap != null
                                       ? candidateToRuleScoreMap
                                       : new Map<Id, Decimal>();
        this.candidateToJobMap       = new Map<Id, Id>();
        this.aiEnabled               = false;
        this.aiOnlyMode              = (mode == 'AI_ONLY');
        System.debug('ScreeningQueueable AI-ONLY mode initialized.');
    }

    public ScreeningQueueable(Map<Id, Id> candToJobMap, Boolean aiEnabled, Map<Id, Id> candidateToJobAppMap) {
        this.candidateToJobMap       = candToJobMap;
        this.aiEnabled               = (aiEnabled == true);
        this.candidateToJobAppMap    = candidateToJobAppMap != null 
                                       ? candidateToJobAppMap 
                                       : new Map<Id, Id>();
        this.candidateToRuleScoreMap = new Map<Id, Decimal>();
        this.aiOnlyMode              = false;
        System.debug('ScreeningQueueable initialized with ' + candToJobMap.size() + ' candidates');
        System.debug('AI Screening: ' + this.aiEnabled);
    }

    public ScreeningQueueable(Map<Id, Id> candToJobMap, Boolean aiEnabled) {
        this.candidateToJobMap       = candToJobMap;
        this.aiEnabled               = (aiEnabled == true);
        this.candidateToJobAppMap    = new Map<Id, Id>();
        this.candidateToRuleScoreMap = new Map<Id, Decimal>();
        this.aiOnlyMode              = false;
        System.debug('ScreeningQueueable initialized with ' + candToJobMap.size() + ' candidates');
        System.debug('AI Screening: ' + this.aiEnabled);
    }

    public ScreeningQueueable(Map<Id, Id> candToJobMap) {
        this.candidateToJobMap       = candToJobMap;
        this.aiEnabled               = false;
        this.candidateToJobAppMap    = new Map<Id, Id>();
        this.candidateToRuleScoreMap = new Map<Id, Decimal>();
        this.aiOnlyMode              = false;
        System.debug('ScreeningQueueable initialized with ' + candToJobMap.size() + ' candidates');
    }

    public void execute(QueueableContext qc) {
        System.debug('=== QUEUEABLE EXECUTE STARTED ===');
        System.debug('Job ID: ' + qc.getJobId());
        System.debug('AI Only Mode: ' + aiOnlyMode);

        // AI-only path — no DML, just callouts
        if (aiOnlyMode == true) {
            System.debug('Running in AI-ONLY mode...');
            for (Id candId : candidateToJobAppMap.keySet()) {
                Id jobAppId = candidateToJobAppMap.get(candId);
                try {
                    Map<String, Object> aiResult =
                        AIScreeningController.runAIScreeningForCandidate(candId, jobAppId);
                    System.debug('AI result for ' + candId + ': ' + aiResult);
                } catch (Exception e) {
                    System.debug('AI failed for ' + candId + ': ' + e.getMessage());
                }
            }

            // Update Job Application with combined score after AI completes
            try {
                updateJobApplicationsAfterAI(candidateToJobAppMap);
                System.debug('Updated job applications with AI combined score');
            } catch (Exception e) {
                System.debug('ERROR updating job applications after AI: ' + e.getMessage());
            }

            System.debug('=== AI-ONLY QUEUEABLE COMPLETED ===');
            return;
        }

        // ── Rule-based path ───────────────────────────────────────────────────
        if (candidateToJobMap == null || candidateToJobMap.isEmpty()) {
            System.debug('ERROR: candidateToJobMap is empty');
            return;
        }

        Set<Id> candidateIds  = candidateToJobMap.keySet();
        Set<Id> jobPostingIds = new Set<Id>(candidateToJobMap.values());

        System.debug('Processing ' + candidateIds.size() + ' candidates');
        System.debug('For ' + jobPostingIds.size() + ' job postings');

        List<Screening_Rule__c> relevantRules = [
            SELECT Name, Applied_Role__c, Target_Object__c, Field_API_Name__c, 
                   Operator__c, Expected_Value__c, Action__c, Failure_Message__c,
                   Journey_Path__c, Route_To_Queue__c, Escalation_Level__c,
                   Match_Type__c, Version__c, Id
            FROM Screening_Rule__c
            WHERE Active__c = true 
            AND Is_Current_Version__c = true
            AND Applied_Role__c IN :jobPostingIds
            AND (Test_Mode_Only__c = false OR Test_Mode_Only__c = null)
            ORDER BY Priority__c ASC
        ];

        System.debug('Found ' + relevantRules.size() + ' active screening rules');
        
        if (relevantRules.isEmpty()) {
            System.debug('WARNING: No active screening rules found for these job postings');
            updateCandidatesWithNoRules(candidateIds);
            return;
        }

        Map<Id, List<Screening_Rule__c>> rulesByJobId = new Map<Id, List<Screening_Rule__c>>();
        for (Screening_Rule__c rule : relevantRules) {
            if (!rulesByJobId.containsKey(rule.Applied_Role__c)) {
                rulesByJobId.put(rule.Applied_Role__c, new List<Screening_Rule__c>());
            }
            rulesByJobId.get(rule.Applied_Role__c).add(rule);
            System.debug('Rule: ' + rule.Name + ' for Job: ' + rule.Applied_Role__c);
        }

        List<Candidate__c> candidates;
        try {
            candidates = ScreeningDataLoader.loadCandidatesWithAllRelations(candidateIds);
            System.debug('Loaded ' + candidates.size() + ' candidates with relations');
        } catch (Exception e) {
            System.debug('ERROR loading candidates: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return;
        }

        Long timestamp = Datetime.now().getTime();
        Map<Id, String> jobToCorrelationMap = new Map<Id, String>();
        for (Id jobPostingId : jobPostingIds) {
            jobToCorrelationMap.put(jobPostingId, 'RUN-' + jobPostingId + '-' + timestamp);
        }
        System.debug('Correlation IDs built: ' + jobToCorrelationMap);

        List<Screening_Result__c>        resultsToInsert  = new List<Screening_Result__c>();
        List<Screening_Run_Completed__e> eventsToPublish  = new List<Screening_Run_Completed__e>();
        List<Routing_Decision__c>        routingDecisions = new List<Routing_Decision__c>();
        Long totalExecutionTime = 0;

        for (Candidate__c candidate : candidates) {
            System.debug('--- Processing Candidate: ' + candidate.Name + ' ---');
            
            Id     jobPostingId           = candidateToJobMap.get(candidate.Id);
            String candidateCorrelationId = jobToCorrelationMap.get(jobPostingId);
            List<Screening_Rule__c> rulesForThisJob = rulesByJobId.get(jobPostingId);

            if (rulesForThisJob == null || rulesForThisJob.isEmpty()) {
                System.debug('No rules found for job: ' + jobPostingId);
                continue;
            }

            System.debug('Evaluating ' + rulesForThisJob.size() + ' rules for this candidate');
            System.debug('Correlation ID: ' + candidateCorrelationId);

            Long candidateStartTime = System.currentTimeMillis();
            
            List<ScreeningRuleService.EvalResult> evaluationResults;
            try {
                evaluationResults = ScreeningRuleService.evaluateRules(rulesForThisJob, candidate);
                System.debug('Evaluation completed: ' + evaluationResults.size() + ' results');
            } catch (Exception e) {
                System.debug('ERROR during evaluation: ' + e.getMessage());
                continue;
            }
            
            Long candidateExecutionTime = System.currentTimeMillis() - candidateStartTime;
            totalExecutionTime += candidateExecutionTime;
            
            Boolean hasFailures = false;
            Boolean hasReviews  = false;
            Integer passCount   = 0;
            Integer failCount   = 0;

            for (ScreeningRuleService.EvalResult eval : evaluationResults) {
                System.debug('Rule: ' + eval.rule.Name + ' | Outcome: ' + eval.outcome);
                
                Screening_Result__c result = new Screening_Result__c();
                result.Candidate__c      = candidate.Id;
                result.Screening_Rule__c = eval.rule.Id;
                result.Job_Posting__c    = jobPostingId;
                result.Outcome__c        = eval.outcome;
                result.Details__c        = eval.details;
                result.Action__c         = eval.rule.Action__c;
                result.Correlation_Id__c = candidateCorrelationId;
                result.Execution_Time__c = eval.executionTimeMs;
                result.Executed_By__c    = UserInfo.getUserId();
                result.Execution_Mode__c = 'Automatic';
                result.Rule_Version__c   = eval.rule.Version__c;
                result.Actual_Value__c   = eval.actualValue != null 
                                          ? String.valueOf(eval.actualValue) : null;
                result.Expected_Value__c = eval.rule.Expected_Value__c;
                
                resultsToInsert.add(result);

                if (eval.outcome == 'Fail')   { hasFailures = true; failCount++; }
                if (eval.outcome == 'Review') { hasReviews  = true; }
                if (eval.outcome == 'Pass')   { passCount++; }
            }

            // 🔥 Build rule score map in-memory for use in AI-ONLY mode
            Decimal ruleScoreForThisCandidate = evaluationResults.size() > 0
                ? (Decimal.valueOf(passCount) / Decimal.valueOf(evaluationResults.size())) * 100
                : 0;
            candidateToRuleScoreMap.put(candidate.Id, ruleScoreForThisCandidate);
            System.debug('Rule score for ' + candidate.Id + ': ' + ruleScoreForThisCandidate);
            
            String finalStatus = hasFailures ? 'Failed' : (hasReviews ? 'Manual Review' : 'Passed');
            System.debug('Final Status: ' + finalStatus);
            
            try {
                WorkflowRoutingService.RoutingDecision routing = 
                    WorkflowRoutingService.determineRouting(candidate.Id, candidateCorrelationId);
                
                Routing_Decision__c routingRecord       = new Routing_Decision__c();
                routingRecord.Candidate__c              = candidate.Id;
                routingRecord.Job_Posting__c            = jobPostingId;
                routingRecord.Journey_Path__c           = routing.journeyPath;
                routingRecord.Assigned_Queue__c         = routing.queueName;
                routingRecord.Escalation_Level__c       = routing.escalationLevel;
                routingRecord.Requires_Manual_Review__c = routing.requiresManualReview;
                routingRecord.Decision_Reason__c        = routing.reason;
                routingRecord.Required_Actions__c       = String.join(routing.requiredActions, '\n');
                routingRecord.Correlation_Id__c         = candidateCorrelationId;
                routingRecord.Decision_Date__c          = System.now();
                routingRecord.Decision_Made_By__c       = UserInfo.getUserId();
                routingRecord.Status__c                 = 'Pending';
                routingDecisions.add(routingRecord);
            } catch (Exception e) {
                System.debug('ERROR creating routing decision: ' + e.getMessage());
            }
            
            eventsToPublish.add(new Screening_Run_Completed__e(
                Candidate_ID__c   = candidate.Id,
                Final_Status__c   = finalStatus,
                Correlation_ID__c = candidateCorrelationId,
                Total_Rules__c    = evaluationResults.size(),
                Rules_Passed__c   = passCount,
                Rules_Failed__c   = failCount,
                Execution_Time__c = candidateExecutionTime,
                Message__c        = 'Screening completed for ' + candidate.Name
            ));
        }

        System.debug('--- INSERTING RECORDS ---');
        
        if (!resultsToInsert.isEmpty()) {
            try {
                insert resultsToInsert;
                System.debug('Inserted ' + resultsToInsert.size() + ' Screening_Result__c records');
            } catch (Exception e) {
                System.debug('ERROR inserting results: ' + e.getMessage());
            }
        }
        
        if (!routingDecisions.isEmpty()) {
            try {
                insert routingDecisions;
                System.debug('Inserted ' + routingDecisions.size() + ' Routing_Decision__c records');
            } catch (Exception e) {
                System.debug('ERROR inserting routing decisions: ' + e.getMessage());
            }
        }

        if (!eventsToPublish.isEmpty()) {
            try {
                List<Database.SaveResult> results = EventBus.publish(eventsToPublish);
                System.debug('Published ' + results.size() + ' platform events');
            } catch (Exception e) {
                System.debug('ERROR publishing events: ' + e.getMessage());
            }
        }
        
        try {
            updateCandidateStatuses(candidateToJobMap, jobToCorrelationMap);
            System.debug('Updated candidate statuses');
        } catch (Exception e) {
            System.debug('ERROR updating candidate statuses: ' + e.getMessage());
        }
        
        try {
            updateRuleStatistics(relevantRules, resultsToInsert);
            System.debug('Updated rule statistics');
        } catch (Exception e) {
            System.debug('ERROR updating rule statistics: ' + e.getMessage());
        }

        // Update Job Application score + status after rule-based screening
        try {
            updateJobApplicationStatuses(
                candidateToJobMap,
                jobToCorrelationMap,
                candidateToJobAppMap,
                aiEnabled
            );
            System.debug('Updated job application statuses');
        } catch (Exception e) {
            System.debug('ERROR updating job application statuses: ' + e.getMessage());
        }

        // Chain AI-only mode in a fresh transaction — avoids callout after DML error
        if (aiEnabled == true && !candidateToJobAppMap.isEmpty()) {
            System.debug('AI Screening ENABLED → Chaining in AI-ONLY mode...');
            try {
                System.enqueueJob(new ScreeningQueueable(
                    candidateToJobAppMap,
                    candidateToRuleScoreMap, // 🔥 pass rule scores directly
                    'AI_ONLY'
                ));
                System.debug('AI-ONLY ScreeningQueueable enqueued successfully.');
            } catch (Exception e) {
                System.debug('Failed to enqueue AI-ONLY mode: ' + e.getMessage());
            }
        } else {
            System.debug('AI Screening DISABLED → Skipping.');
        }

        System.debug('=== QUEUEABLE EXECUTE COMPLETED ===');
    }
    
    private void updateCandidatesWithNoRules(Set<Id> candidateIds) {
        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();
        for (Id candId : candidateIds) {
            Candidate__c candidate            = new Candidate__c(Id = candId);
            candidate.Screening_Status__c     = 'Not Yet Screened';
            candidate.Last_Screening_Date__c  = System.now();
            candidate.Last_Result_Summary__c  = 'No active screening rules found for the selected job posting.';
            candidatesToUpdate.add(candidate);
        }
        if (!candidatesToUpdate.isEmpty()) {
            update candidatesToUpdate;
            System.debug('Updated ' + candidatesToUpdate.size() + ' candidates with "No Rules" status');
        }
    }
    
    private void updateCandidateStatuses(Map<Id, Id> candidateToJobMap, Map<Id, String> jobToCorrelationMap) {
        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();
        
        for (Id candId : candidateToJobMap.keySet()) {
            Id     jobPostingId  = candidateToJobMap.get(candId);
            String correlationId = jobToCorrelationMap.get(jobPostingId);

            List<Screening_Result__c> results = [
                SELECT Outcome__c
                FROM Screening_Result__c
                WHERE Candidate__c    = :candId
                AND Correlation_Id__c = :correlationId
            ];
            
            Boolean hasFailures = false;
            Boolean hasReviews  = false;
            Integer passCount   = 0;
            Integer failCount   = 0;
            Integer reviewCount = 0;
            
            for (Screening_Result__c result : results) {
                if (result.Outcome__c == 'Fail')   { hasFailures = true; failCount++;   }
                if (result.Outcome__c == 'Review') { hasReviews  = true; reviewCount++; }
                if (result.Outcome__c == 'Pass')   { passCount++; }
            }
            
            Candidate__c candidate             = new Candidate__c(Id = candId);
            candidate.Last_Screening_Date__c   = System.now();
            candidate.Latest_Correlation_Id__c = correlationId;
            candidate.Total_Rules_Evaluated__c = results.size();
            
            if (results.size() > 0) {
                candidate.Pass_Rate__c = (Decimal.valueOf(passCount) / Decimal.valueOf(results.size())) * 100;
            }
            
            if (hasFailures) {
                candidate.Screening_Status__c    = 'Failed';
                candidate.Last_Result_Summary__c = failCount + ' rule(s) failed. Review required.';
            } else if (hasReviews) {
                candidate.Screening_Status__c    = 'Manual Review';
                candidate.Last_Result_Summary__c = reviewCount + ' rule(s) require manual review.';
            } else {
                candidate.Screening_Status__c    = 'Passed';
                candidate.Last_Result_Summary__c = 'All ' + passCount + ' screening rules passed.';
            }
            
            candidatesToUpdate.add(candidate);
        }
        
        if (!candidatesToUpdate.isEmpty()) {
            update candidatesToUpdate;
        }
    }
    
    private void updateRuleStatistics(List<Screening_Rule__c> rules, List<Screening_Result__c> results) {
        Map<Id, Integer> passCountsByRule  = new Map<Id, Integer>();
        Map<Id, Integer> totalCountsByRule = new Map<Id, Integer>();
        
        for (Screening_Result__c result : results) {
            if (!totalCountsByRule.containsKey(result.Screening_Rule__c)) {
                totalCountsByRule.put(result.Screening_Rule__c, 0);
                passCountsByRule.put(result.Screening_Rule__c, 0);
            }
            totalCountsByRule.put(result.Screening_Rule__c, 
                                  totalCountsByRule.get(result.Screening_Rule__c) + 1);
            if (result.Outcome__c == 'Pass') {
                passCountsByRule.put(result.Screening_Rule__c, 
                                     passCountsByRule.get(result.Screening_Rule__c) + 1);
            }
        }
        
        List<Screening_Rule__c> rulesToUpdate = new List<Screening_Rule__c>();
        for (Screening_Rule__c rule : rules) {
            if (totalCountsByRule.containsKey(rule.Id)) {
                rule.Last_Execution_Date__c = System.now();
                rule.Execution_Count__c     = (rule.Execution_Count__c != null 
                                               ? rule.Execution_Count__c : 0) + 
                                               totalCountsByRule.get(rule.Id);
                Integer passed    = passCountsByRule.get(rule.Id);
                Integer total     = totalCountsByRule.get(rule.Id);
                rule.Pass_Rate__c = total > 0 
                                    ? (Decimal.valueOf(passed) / Decimal.valueOf(total)) * 100 
                                    : 0;
                rulesToUpdate.add(rule);
            }
        }
        
        if (!rulesToUpdate.isEmpty()) {
            update rulesToUpdate;
        }
    }

    // Called after rule-based screening completes
    private void updateJobApplicationStatuses(
        Map<Id, Id> candidateToJobMap,
        Map<Id, String> jobToCorrelationMap,
        Map<Id, Id> candidateToJobAppMap,
        Boolean aiEnabled
    ) {
        List<Job_Application__c> appsToUpdate = new List<Job_Application__c>();

        for (Id candId : candidateToJobMap.keySet()) {
            Id jobAppId = candidateToJobAppMap.get(candId);
            if (jobAppId == null) continue;

            Id     jobPostingId  = candidateToJobMap.get(candId);
            String correlationId = jobToCorrelationMap.get(jobPostingId);

            List<Screening_Result__c> results = [
                SELECT Outcome__c
                FROM Screening_Result__c
                WHERE Candidate__c    = :candId
                AND Correlation_Id__c = :correlationId
            ];

            Job_Application__c app = new Job_Application__c(Id = jobAppId);

            if (results.isEmpty()) {
                app.Status__c           = 'Pending';
                app.Screening_Result__c = 'Pending';
                app.Screening_Score__c  = 0;
                appsToUpdate.add(app);
                continue;
            }

            Integer total  = results.size();
            Integer passed = 0;
            for (Screening_Result__c res : results) {
                if (res.Outcome__c == 'Pass') passed++;
            }

            Decimal ruleScore      = (Decimal.valueOf(passed) / Decimal.valueOf(total)) * 100;
            app.Screening_Score__c = ruleScore;

            if (aiEnabled == true) {
                // AI will run next in AI-ONLY mode — set Pending until it finalises
                app.Status__c           = 'Pending';
                app.Screening_Result__c = 'Pending';
            } else {
                // No AI — finalise now
                if (ruleScore >= 70) {
                    app.Screening_Result__c = 'Pass';
                    app.Status__c           = 'Background Check Cleared';
                } else {
                    app.Screening_Result__c = 'Fail';
                    app.Status__c           = 'Background Check Failed';
                }
            }

            appsToUpdate.add(app);
        }

        if (!appsToUpdate.isEmpty()) {
            update appsToUpdate;
            System.debug('Job Applications updated after rule-based: ' + appsToUpdate.size());
        }
    }

    // Called after AI completes in AI-ONLY mode
    private void updateJobApplicationsAfterAI(Map<Id, Id> candidateToJobAppMap) {
        List<Job_Application__c> appsToUpdate = new List<Job_Application__c>();

        for (Id candId : candidateToJobAppMap.keySet()) {
            Id jobAppId = candidateToJobAppMap.get(candId);
            if (jobAppId == null) continue;

            // 🔥 Use passed rule score directly — no DB re-read needed
            Decimal ruleScore = candidateToRuleScoreMap.containsKey(candId)
                                ? candidateToRuleScoreMap.get(candId)
                                : 0;

            List<Job_Application__c> jobApps = [
                SELECT Job_Posting__c
                FROM Job_Application__c
                WHERE Id = :jobAppId
                LIMIT 1
            ];
            if (jobApps.isEmpty()) continue;

            Id jobPostingId = jobApps[0].Job_Posting__c;

            List<AI_Screening_Result__c> aiResults = [
                SELECT Overall_Score__c
                FROM AI_Screening_Result__c
                WHERE Candidate__c = :candId
                AND Job_Posting__c = :jobPostingId
                AND Status__c      = 'Completed'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            Job_Application__c app = new Job_Application__c(Id = jobAppId);

            if (aiResults.isEmpty()) {
                // AI failed — use rule score only
                app.Screening_Score__c = ruleScore;
                System.debug('AI result missing, using rule score: ' + ruleScore);
            } else {
                Decimal aiScore        = aiResults[0].Overall_Score__c != null
                                         ? aiResults[0].Overall_Score__c : 0;
                app.Screening_Score__c = (ruleScore + aiScore) / 2;
                System.debug('Rule: ' + ruleScore + ' | AI: ' + aiScore + 
                             ' | Combined: ' + app.Screening_Score__c);
            }

            if (app.Screening_Score__c >= 70) {
                app.Screening_Result__c = 'Pass';
                app.Status__c           = 'Background Check Cleared';
            } else {
                app.Screening_Result__c = 'Fail';
                app.Status__c           = 'Background Check Failed';
            }

            appsToUpdate.add(app);
        }

        if (!appsToUpdate.isEmpty()) {
            update appsToUpdate;
            System.debug('Job Applications updated after AI: ' + appsToUpdate.size());
        }
    }
}