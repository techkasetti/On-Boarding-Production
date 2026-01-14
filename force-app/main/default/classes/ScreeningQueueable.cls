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

public class ScreeningQueueable implements Queueable {
    private Map<Id, Id> candidateToJobMap;

    public ScreeningQueueable(Map<Id, Id> candToJobMap) {
        this.candidateToJobMap = candToJobMap;
        System.debug('ScreeningQueueable initialized with ' + candToJobMap.size() + ' candidates');
    }

    public void execute(QueueableContext qc) {
        System.debug('=== QUEUEABLE EXECUTE STARTED ===');
        System.debug('Job ID: ' + qc.getJobId());
        
        if (candidateToJobMap == null || candidateToJobMap.isEmpty()) {
            System.debug('ERROR: candidateToJobMap is empty');
            return;
        }

        Set<Id> candidateIds = candidateToJobMap.keySet();
        Set<Id> jobPostingIds = new Set<Id>(candidateToJobMap.values());

        System.debug('Processing ' + candidateIds.size() + ' candidates');
        System.debug('For ' + jobPostingIds.size() + ' job postings');

        // Get all active rules for these job postings
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

        // Group rules by job ID
        Map<Id, List<Screening_Rule__c>> rulesByJobId = new Map<Id, List<Screening_Rule__c>>();
        for (Screening_Rule__c rule : relevantRules) {
            if (!rulesByJobId.containsKey(rule.Applied_Role__c)) {
                rulesByJobId.put(rule.Applied_Role__c, new List<Screening_Rule__c>());
            }
            rulesByJobId.get(rule.Applied_Role__c).add(rule);
            System.debug('Rule: ' + rule.Name + ' for Job: ' + rule.Applied_Role__c);
        }

        // Load candidates with all relations
        List<Candidate__c> candidates;
        try {
            candidates = ScreeningDataLoader.loadCandidatesWithAllRelations(candidateIds);
            System.debug('Loaded ' + candidates.size() + ' candidates with relations');
        } catch (Exception e) {
            System.debug('ERROR loading candidates: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return;
        }

        List<Screening_Result__c> resultsToInsert = new List<Screening_Result__c>();
        List<Screening_Run_Completed__e> eventsToPublish = new List<Screening_Run_Completed__e>();
        List<Routing_Decision__c> routingDecisions = new List<Routing_Decision__c>();
        
        String correlationId = 'RUN-' + Datetime.now().getTime();
        System.debug('Correlation ID: ' + correlationId);
        Long totalExecutionTime = 0;

        for (Candidate__c candidate : candidates) {
            System.debug('--- Processing Candidate: ' + candidate.Name + ' ---');
            
            Id jobPostingId = candidateToJobMap.get(candidate.Id);
            List<Screening_Rule__c> rulesForThisJob = rulesByJobId.get(jobPostingId);

            if (rulesForThisJob == null || rulesForThisJob.isEmpty()) {
                System.debug('No rules found for job: ' + jobPostingId);
                continue;
            }

            System.debug('Evaluating ' + rulesForThisJob.size() + ' rules for this candidate');
            Long candidateStartTime = System.currentTimeMillis();
            
            // Evaluate rules
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
            Boolean hasReviews = false;
            Integer passCount = 0;
            Integer failCount = 0;

            // Create result records
            for (ScreeningRuleService.EvalResult eval : evaluationResults) {
                System.debug('Rule: ' + eval.rule.Name + ' | Outcome: ' + eval.outcome);
                
                Screening_Result__c result = new Screening_Result__c();
                result.Candidate__c = candidate.Id;
                result.Screening_Rule__c = eval.rule.Id;
                result.Job_Posting__c = jobPostingId;
                result.Outcome__c = eval.outcome;
                result.Details__c = eval.details;
                result.Action__c = eval.rule.Action__c;
                result.Correlation_Id__c = correlationId;
                result.Execution_Time__c = eval.executionTimeMs;
                result.Executed_By__c = UserInfo.getUserId();
                result.Execution_Mode__c = 'Automatic';
                result.Rule_Version__c = eval.rule.Version__c;
                result.Actual_Value__c = eval.actualValue != null ? String.valueOf(eval.actualValue) : null;
                result.Expected_Value__c = eval.rule.Expected_Value__c;
                
                resultsToInsert.add(result);

                if (eval.outcome == 'Fail') {
                    hasFailures = true;
                    failCount++;
                }
                if (eval.outcome == 'Review') {
                    hasReviews = true;
                }
                if (eval.outcome == 'Pass') {
                    passCount++;
                }
            }
            
            String finalStatus = hasFailures ? 'Failed' : (hasReviews ? 'Manual Review' : 'Passed');
            System.debug('Final Status: ' + finalStatus + ' (Pass: ' + passCount + ', Fail: ' + failCount + ')');
            
            // Create routing decision
            try {
                WorkflowRoutingService.RoutingDecision routing = 
                    WorkflowRoutingService.determineRouting(candidate.Id, correlationId);
                
                System.debug('Routing Decision: Path=' + routing.journeyPath + ', Queue=' + routing.queueName);
                
                Routing_Decision__c routingRecord = new Routing_Decision__c();
                routingRecord.Candidate__c = candidate.Id;
                routingRecord.Job_Posting__c = jobPostingId;
                routingRecord.Journey_Path__c = routing.journeyPath;
                routingRecord.Assigned_Queue__c = routing.queueName;
                routingRecord.Escalation_Level__c = routing.escalationLevel;
                routingRecord.Requires_Manual_Review__c = routing.requiresManualReview;
                routingRecord.Decision_Reason__c = routing.reason;
                routingRecord.Required_Actions__c = String.join(routing.requiredActions, '\n');
                routingRecord.Correlation_Id__c = correlationId;
                routingRecord.Decision_Date__c = System.now();
                routingRecord.Decision_Made_By__c = UserInfo.getUserId();
                routingRecord.Status__c = 'Pending';
                
                routingDecisions.add(routingRecord);
            } catch (Exception e) {
                System.debug('ERROR creating routing decision: ' + e.getMessage());
            }
            
            // Create platform event
            eventsToPublish.add(new Screening_Run_Completed__e(
                Candidate_ID__c = candidate.Id,
                Final_Status__c = finalStatus,
                Correlation_ID__c = correlationId,
                Total_Rules__c = evaluationResults.size(),
                Rules_Passed__c = passCount,
                Rules_Failed__c = failCount,
                Execution_Time__c = candidateExecutionTime,
                Message__c = 'Screening completed for ' + candidate.Name
            ));
        }

        System.debug('--- INSERTING RECORDS ---');
        
        // Insert all results
        if (!resultsToInsert.isEmpty()) {
            try {
                insert resultsToInsert;
                System.debug('Inserted ' + resultsToInsert.size() + ' Screening_Result__c records');
            } catch (Exception e) {
                System.debug('ERROR inserting results: ' + e.getMessage());
            }
        }
        
        // Insert routing decisions
        if (!routingDecisions.isEmpty()) {
            try {
                insert routingDecisions;
                System.debug('Inserted ' + routingDecisions.size() + ' Routing_Decision__c records');
            } catch (Exception e) {
                System.debug('ERROR inserting routing decisions: ' + e.getMessage());
            }
        }

        // Publish events
        if (!eventsToPublish.isEmpty()) {
            try {
                List<Database.SaveResult> results = EventBus.publish(eventsToPublish);
                System.debug('Published ' + results.size() + ' platform events');
            } catch (Exception e) {
                System.debug('ERROR publishing events: ' + e.getMessage());
            }
        }
        
        // Update candidate statuses
        try {
            updateCandidateStatuses(candidateIds, correlationId);
            System.debug('Updated candidate statuses');
        } catch (Exception e) {
            System.debug('ERROR updating candidate statuses: ' + e.getMessage());
        }
        
        // Update rule statistics
        try {
            updateRuleStatistics(relevantRules, resultsToInsert);
            System.debug('Updated rule statistics');
        } catch (Exception e) {
            System.debug('ERROR updating rule statistics: ' + e.getMessage());
        }
        
        System.debug('=== QUEUEABLE EXECUTE COMPLETED ===');
    }
    
    private void updateCandidatesWithNoRules(Set<Id> candidateIds) {
        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();
        
        for (Id candId : candidateIds) {
            Candidate__c candidate = new Candidate__c(Id = candId);
            candidate.Screening_Status__c = 'Not Yet Screened';
            candidate.Last_Screening_Date__c = System.now();
            candidate.Last_Result_Summary__c = 'No active screening rules found for the selected job posting.';
            candidatesToUpdate.add(candidate);
        }
        
        if (!candidatesToUpdate.isEmpty()) {
            update candidatesToUpdate;
            System.debug('Updated ' + candidatesToUpdate.size() + ' candidates with "No Rules" status');
        }
    }
    
    private void updateCandidateStatuses(Set<Id> candidateIds, String correlationId) {
        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();
        
        for (Id candId : candidateIds) {
            List<Screening_Result__c> results = [
                SELECT Outcome__c
                FROM Screening_Result__c
                WHERE Candidate__c = :candId
                AND Correlation_Id__c = :correlationId
            ];
            
            Boolean hasFailures = false;
            Boolean hasReviews = false;
            Integer passCount = 0;
            Integer failCount = 0;
            Integer reviewCount = 0;
            
            for (Screening_Result__c result : results) {
                if (result.Outcome__c == 'Fail') {
                    hasFailures = true;
                    failCount++;
                }
                if (result.Outcome__c == 'Review') {
                    hasReviews = true;
                    reviewCount++;
                }
                if (result.Outcome__c == 'Pass') {
                    passCount++;
                }
            }
            
            Candidate__c candidate = new Candidate__c(Id = candId);
            candidate.Last_Screening_Date__c = System.now();
            candidate.Latest_Correlation_Id__c = correlationId;
            candidate.Total_Rules_Evaluated__c = results.size();
            
            if (results.size() > 0) {
                candidate.Pass_Rate__c = (Decimal.valueOf(passCount) / Decimal.valueOf(results.size())) * 100;
            }
            
            if (hasFailures) {
                candidate.Screening_Status__c = 'Failed';
                candidate.Last_Result_Summary__c = failCount + ' rule(s) failed. Review required.';
            } else if (hasReviews) {
                candidate.Screening_Status__c = 'Manual Review';
                candidate.Last_Result_Summary__c = reviewCount + ' rule(s) require manual review.';
            } else {
                candidate.Screening_Status__c = 'Passed';
                candidate.Last_Result_Summary__c = 'All ' + passCount + ' screening rules passed.';
            }
            
            candidatesToUpdate.add(candidate);
        }
        
        if (!candidatesToUpdate.isEmpty()) {
            update candidatesToUpdate;
        }
    }
    
    private void updateRuleStatistics(List<Screening_Rule__c> rules, List<Screening_Result__c> results) {
        Map<Id, Integer> passCountsByRule = new Map<Id, Integer>();
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
                rule.Execution_Count__c = (rule.Execution_Count__c != null ? rule.Execution_Count__c : 0) + 
                                         totalCountsByRule.get(rule.Id);
                
                Integer passed = passCountsByRule.get(rule.Id);
                Integer total = totalCountsByRule.get(rule.Id);
                rule.Pass_Rate__c = total > 0 ? (Decimal.valueOf(passed) / Decimal.valueOf(total)) * 100 : 0;
                
                rulesToUpdate.add(rule);
            }
        }
        
        if (!rulesToUpdate.isEmpty()) {
            update rulesToUpdate;
        }
    }
}
