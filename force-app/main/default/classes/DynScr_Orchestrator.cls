public with sharing class DynScr_Orchestrator {

    public static Id runScreening(Id tenantId, Map<String,Object> payload) {

        // 1. Load rules
        List<DynScr_Rule__mdt> rules = [
            SELECT DeveloperName, Expression__c FROM DynScr_Rule__mdt
        ];

        // 2. Evaluate rules
        DynScr_RuleResult result = DynScr_RuleEngine.evaluateRules(tenantId, payload, rules);

        // 3. Jurisdiction
        String jurisdiction = DynScr_JurisdictionResolver.resolve(payload);

        // 4. Path
        String path = DynScr_ConditionalPathEvaluator.determinePath(result, jurisdiction);

        // 5. Score via Snowflake
        Map<String,Object> score = DynScr_SnowflakeProxy.score(payload);

        // 6. Persist
        return DynScr_ResultWriter.persist(tenantId, payload, result, jurisdiction, path, score);
    }
}
