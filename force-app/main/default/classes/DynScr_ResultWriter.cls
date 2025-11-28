public with sharing class DynScr_ResultWriter {

    public static Id persist(
        Id tenantId,
        Map<String,Object> payload,
        DynScr_RuleResult ruleResult,
        String jurisdiction,
        String path,
        Map<String,Object> score
    ) {

        Onboarding_run__c rec = new Onboarding_run__c();
        rec.Tenant__c = tenantId;
        rec.RawInput__c = JSON.serialize(payload);
        rec.TriggeredRules__c = String.join(ruleResult.triggeredRules, ';');
        rec.Jurisdiction__c = jurisdiction;
        rec.PathChosen__c = path;
        rec.ScoreJSON__c = JSON.serialize(score);

        insert rec;
        return rec.Id;
    }
}
