public with sharing class ScreeningRuleService {

    public class Rule {
        public String ruleKey;
        public Integer priority;
        public Boolean active;
        public String condition;
        public String action;
        public String jurisdiction;
        public String schemaVersion;
        public String severity;

        public Rule(String rk, Integer pr, Boolean ac, String cond, String act, String jur, String sv, String sev) {
            ruleKey = rk;
            priority = pr;
            active = ac;
            condition = cond;
            action = act;
            jurisdiction = jur;
            schemaVersion = sv;
            severity = sev;
        }
    }

    // Main method to get all active rules sorted by priority
    public static List<Rule> getActiveRules() {
        List<Rule> rules = new List<Rule>();

        try {
            List<Screening_Rule__mdt> mdts = [
                SELECT MasterLabel, Rule_Key__c, Priority__c, Active__c, Condition_Expression__c,
                       Action__c, Jurisdiction__c, Schema_Version__c, Severity__c
                FROM Screening_Rule__mdt
            ];

            for (Screening_Rule__mdt m : mdts) {
                Boolean ac = (m.Active__c == null) ? false : m.Active__c;
                Integer pr = (m.Priority__c == null) ? 1000 : Integer.valueOf(m.Priority__c);

                rules.add(new Rule(
                    m.Rule_Key__c,
                    pr,
                    ac,
                    m.Condition_Expression__c,
                    m.Action__c,
                    m.Jurisdiction__c,
                    m.Schema_Version__c,
                    m.Severity__c
                ));
            }
        } catch (Exception ex) {
            // during test context or no metadata
        }

        if (rules.isEmpty() && Test.isRunningTest()) {
            // fallback sample rules
            rules.add(new Rule('SAMPLE_RULE_FAIL_IF_EXP_LT_2', 10, true,
                'parsed_json.experience_years < 2', 'AutoReject', null, 'v1', 'Low'));

            rules.add(new Rule('SAMPLE_RULE_ROUTE_IN_IF_AADHAAR', 20, true,
                'candidate.locale == \'IN\' AND parsed_json.has_aadhaar == true', 'RouteToJurisdiction', 'IN', 'v1', 'Medium'));
        }

        // Keep only active
        List<Rule> activeRules = new List<Rule>();
        for (Rule r : rules) {
            if (r.active) activeRules.add(r);
        }

        // Sort using comparator
        activeRules.sort(new RulePriorityComparator());

        return activeRules;
    }

    // Comparator (cannot be static inside Apex outer class)
    private class RulePriorityComparator implements System.Comparator<ScreeningRuleService.Rule> {

        public Integer compare(ScreeningRuleService.Rule a, ScreeningRuleService.Rule b) {
            if (a == null && b == null) return 0;
            if (a == null) return 1;
            if (b == null) return -1;

            Integer pa = a.priority;
            Integer pb = b.priority;

            if (pa == pb) return 0;
            if (pa == null) return 1;
            if (pb == null) return -1;

            return (pa > pb) ? 1 : -1;
        }
    }

    // Evaluation results model
    public class EvalResult {
        public String ruleKey;
        public String action;
        public Decimal score;
        public String outcome;
        public String details;
        public String jurisdiction;

        public EvalResult(String rk, String a, Decimal s, String out, String d, String jur) {
            ruleKey = rk;
            action = a;
            score = s;
            outcome = out;
            details = d;
            jurisdiction = jur;
        }
    }

    public static List<EvalResult> evaluateAll(
        String candidateId,
        Map<String,Object> candidateMap,
        Map<String,Object> parsedJson
    ) {
        List<EvalResult> results = new List<EvalResult>();
        List<Rule> rules = getActiveRules();

        for (Rule r : rules) {
            try {
                Boolean pass = RuleExpressionEvaluator.evaluate(r.condition, candidateMap, parsedJson);
                results.add(new EvalResult(
                    r.ruleKey,
                    r.action,
                    pass ? 1.0 : 0.0,
                    pass ? 'Pass' : 'Fail',
                    'Evaluated expression: ' + r.condition,
                    r.jurisdiction
                ));
            } catch (Exception ex) {
                results.add(new EvalResult(
                    r.ruleKey,
                    r.action,
                    0,
                    'Error',
                    'Evaluator error: ' + ex.getMessage(),
                    r.jurisdiction
                ));
            }
        }

        return results;
    }
}
