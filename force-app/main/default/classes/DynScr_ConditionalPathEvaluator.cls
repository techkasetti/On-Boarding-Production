public with sharing class DynScr_ConditionalPathEvaluator {

    public static String determinePath(
        DynScr_RuleResult ruleResult,
        String jurisdiction
    ) {
        if (ruleResult.triggeredRules.isEmpty()) return 'NO_MATCH';

        List<DynScr_Path__mdt> paths =
            [SELECT DeveloperName, Rule__c, Jurisdiction__c FROM DynScr_Path__mdt];

        for (DynScr_Path__mdt p : paths) {
            if (
                (p.Jurisdiction__c == jurisdiction || p.Jurisdiction__c == 'ANY') &&
                ruleResult.triggeredRules.contains(p.Rule__c)
            ) {
                return p.DeveloperName;
            }
        }

        return 'NO_MATCH';
    }
}
