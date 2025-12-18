public with sharing class ScreeningQueueable implements Queueable {
    private Map<Id, Id> candidateToJobMap;

    public ScreeningQueueable(Map<Id, Id> candToJobMap) {
        this.candidateToJobMap = candToJobMap;
    }

    public void execute(QueueableContext qc) {
        if (candidateToJobMap == null | candidateToJobMap.isEmpty()) {
            return;
        }

        Set<Id> candidateIds = candidateToJobMap.keySet();
        Set<Id> jobPostingIds = new Set<Id>(candidateToJobMap.values());

        // CRITICAL FIX: This SOQL query now ONLY fetches rules where the Applied_Role__c
        // lookup matches the Job Posting IDs of the candidates in this batch.
        List<Screening_Rule__c> relevantRules = [
            SELECT Name, Applied_Role__c, Target_Object__c, Field_API_Name__c, Operator__c, Expected_Value__c, Action__c, Failure_Message__c
            FROM Screening_Rule__c
            WHERE Active__c = true AND Applied_Role__c IN :jobPostingIds
        ];

        // Group the fetched rules by their associated Job ID for efficient processing.
        Map<Id, List<Screening_Rule__c>> rulesByJobId = new Map<Id, List<Screening_Rule__c>>();
        for (Screening_Rule__c rule : relevantRules) {
            if (!rulesByJobId.containsKey(rule.Applied_Role__c)) {
                rulesByJobId.put(rule.Applied_Role__c, new List<Screening_Rule__c>());
            }
            rulesByJobId.get(rule.Applied_Role__c).add(rule);
        }

        // Fetch candidate data
        List<Candidate__c> candidates = [
            SELECT Id, Name, Years_of_Experience__c, Location__c,
                   (SELECT Id, Name, Type__c FROM License_Certifications__r),
                   (SELECT Id, Organization__c, Role__c FROM Work_Experiences__r)
            FROM Candidate__c WHERE Id IN :candidateIds
        ];

        List<Screening_Result__c> resultsToInsert = new List<Screening_Result__c>();
        String correlationId = 'RUN-' + Datetime.now().getTime();

        // Process each candidate
        for (Candidate__c candidate : candidates) {
            Id jobPostingId = candidateToJobMap.get(candidate.Id);
            List<Screening_Rule__c> rulesForThisJob = rulesByJobId.get(jobPostingId);

            // If no rules exist for this specific job, skip evaluation for this candidate.
            if (rulesForThisJob == null | rulesForThisJob.isEmpty()) {
                continue;
            }

            // Evaluate ONLY the correct, job-specific rules
            List<ScreeningRuleService.EvalResult> evaluationResults = ScreeningRuleService.evaluateRules(rulesForThisJob, candidate);

            for (ScreeningRuleService.EvalResult eval : evaluationResults) {
                Screening_Result__c result = new Screening_Result__c();
                result.Candidate__c = candidate.Id;
                result.Screening_Rule__c = eval.rule.Id;
                result.Outcome__c = eval.outcome;
                result.Details__c = eval.details;
                result.Action__c = eval.rule.Action__c;
                result.Correlation_Id__c = correlationId;
                resultsToInsert.add(result);
            }
        }

        if (!resultsToInsert.isEmpty()) {
            insert resultsToInsert;
        }
    }
}
