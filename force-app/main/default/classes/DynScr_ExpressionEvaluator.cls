public with sharing class DynScr_ExpressionEvaluator {

    public static Boolean evaluate(String expr) {

        if (String.isBlank(expr)) return false;

        // Allow only safe operators
        String safeExpr = expr.toLowerCase();

        List<String> allowedTokens = new List<String>{
            'and','or','>','<','>=','<=','==','!=','(',')','true','false'
        };

        // Validate operators
        for (String token : safeExpr.split(' ')) {
            if (token.isNumeric()) continue;
            Boolean allowed = false;
            for (String a : allowedTokens) {
                if (token.contains(a)) allowed = true;
            }
            if (!allowed && token.contains('\'')) allowed = true;
            if (!allowed) return false;
        }

        // Apex does not allow dynamic expression evaluation.
        // We use a lightweight recursive evaluator.
        try {
            return DynScr_SafeEval.execute(expr);
        } catch (Exception ex) {
            DynScr_Log.error('ExpressionEval', ex.getMessage());
            return false;
        }
    }
}
