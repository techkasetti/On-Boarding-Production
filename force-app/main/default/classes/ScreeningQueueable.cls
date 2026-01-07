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
    }

    public void execute(QueueableContext qc) {
        if (candidateToJobMap == null || candidateToJobMap.isEmpty()) {
            return;
        }

        Set<Id> candidateIds = candidateToJobMap.keySet();
        Set<Id> jobPostingIds = new Set<Id>(candidateToJobMap.values());

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

        // Group rules by job ID
        Map<Id, List<Screening_Rule__c>> rulesByJobId = new Map<Id, List<Screening_Rule__c>>();
        for (Screening_Rule__c rule : relevantRules) {
            if (!rulesByJobId.containsKey(rule.Applied_Role__c)) {
                rulesByJobId.put(rule.Applied_Role__c, new List<Screening_Rule__c>());
            }
            rulesByJobId.get(rule.Applied_Role__c).add(rule);
        }

        // Load candidates with all relations
        List<Candidate__c> candidates = ScreeningDataLoader.loadCandidatesWithAllRelations(candidateIds);

        List<Screening_Result__c> resultsToInsert = new List<Screening_Result__c>();
        List<Screening_Run_Completed__e> eventsToPublish = new List<Screening_Run_Completed__e>();
        List<Routing_Decision__c> routingDecisions = new List<Routing_Decision__c>();
        
        String correlationId = 'RUN-' + Datetime.now().getTime();
        Long totalExecutionTime = 0;

        for (Candidate__c candidate : candidates) {
            Id jobPostingId = candidateToJobMap.get(candidate.Id);
            List<Screening_Rule__c> rulesForThisJob = rulesByJobId.get(jobPostingId);

            if (rulesForThisJob == null || rulesForThisJob.isEmpty()) {
                continue;
            }

            Long candidateStartTime = System.currentTimeMillis();
            
            // Evaluate rules
            List<ScreeningRuleService.EvalResult> evaluationResults = 
                ScreeningRuleService.evaluateRules(rulesForThisJob, candidate);
            
            Long candidateExecutionTime = System.currentTimeMillis() - candidateStartTime;
            totalExecutionTime += candidateExecutionTime;
            
            Boolean hasFailures = false;
            Boolean hasReviews = false;
            Integer passCount = 0;
            Integer failCount = 0;

            // Create result records
            for (ScreeningRuleService.EvalResult eval : evaluationResults) {
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
            
            // Create routing decision
            WorkflowRoutingService.RoutingDecision routing = 
                WorkflowRoutingService.determineRouting(candidate.Id, correlationId);
            
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

        // Insert all results
        if (!resultsToInsert.isEmpty()) {
            insert resultsToInsert;
        }
        
        // Insert routing decisions
        if (!routingDecisions.isEmpty()) {
            insert routingDecisions;
        }

        // Publish events
        if (!eventsToPublish.isEmpty()) {
            EventBus.publish(eventsToPublish);
        }
        
        // Update candidate statuses
        updateCandidateStatuses(candidateIds, correlationId);
        
        // Update rule statistics
        updateRuleStatistics(relevantRules, resultsToInsert);
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
            
            for (Screening_Result__c result : results) {
                if (result.Outcome__c == 'Fail') hasFailures = true;
                if (result.Outcome__c == 'Review') hasReviews = true;
            }
            
            Candidate__c candidate = new Candidate__c(Id = candId);
            candidate.Last_Screening_Date__c = System.now();
            candidate.Latest_Correlation_Id__c = correlationId;
            
            if (hasFailures) {
                candidate.Screening_Status__c = 'Failed';
            } else if (hasReviews) {
                candidate.Screening_Status__c = 'Manual Review';
            } else {
                candidate.Screening_Status__c = 'Passed';
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
