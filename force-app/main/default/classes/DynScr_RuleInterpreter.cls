public with sharing class DynScr_RuleInterpreter {

    public static Boolean evaluate(DynScr_Rule__mdt rule, Map<String, Object> payload) {

        if (rule == null || String.isBlank(rule.Expression__c)) return false;

        try {
            // Expression example:
            // payload.amount > 10000 AND payload.country == 'US'
            String expr = rule.Expression__c;

            // Replace tokens
            for (String key : payload.keySet()) {
                Object val = payload.get(key);
                String token = 'payload.' + key;
                String replaceWith =
                    (val instanceof String) ? '\'' + String.valueOf(val) + '\'' :
                    (val instanceof Decimal) ? String.valueOf(val) :
                    (val instanceof Integer) ? String.valueOf(val) :
                    String.valueOf(val);

                expr = expr.replace(token, replaceWith);
            }

            // Call Expression Evaluator
            return DynScr_ExpressionEvaluator.evaluate(expr);

        } catch (Exception ex) {
            DynScr_Log.error('RuleInterpreter', ex.getMessage());
            return false;
        }
    }
}
