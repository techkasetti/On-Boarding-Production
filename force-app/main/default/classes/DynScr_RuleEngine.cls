public with sharing class DynScr_RuleEngine {

    public static DynScr_RuleResult evaluateRules(
        Id tenantId,
        Map<String, Object> payload,
        List<DynScr_Rule__mdt> rules
    ) {
        DynScr_RuleResult result = new DynScr_RuleResult();
        result.tenantId = tenantId;
        result.rawInput = payload;
        result.triggeredRules = new List<String>();

        for (DynScr_Rule__mdt r : rules) {
            Boolean matched = DynScr_RuleInterpreter.evaluate(r, payload);
            if (matched == true) {
                result.triggeredRules.add(r.DeveloperName);
            }
        }
        return result;
    }
}
