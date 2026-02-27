@IsTest
private class RuleExpressionEvaluatorTest {
    @IsTest
    static void testEvaluate_PositiveExpressions() {
        Map<String, Object> candidateMap = new Map<String, Object>{
            'years' => 6,
            'status' => 'Active'
        };
        Map<String, Object> parsedJson = new Map<String, Object>{
            'risk' => 'low',
            'skills' => new List<Object>{ 'BLS', 'ACLS' }
        };

        Boolean expr1 = RuleExpressionEvaluator.evaluate(
            'candidate.years >= 5 AND parsed_json.risk == \'low\'',
            candidateMap,
            parsedJson
        );
        Boolean expr2 = RuleExpressionEvaluator.evaluate(
            'parsed_json.skills CONTAINS \'bls\'',
            candidateMap,
            parsedJson
        );
        Boolean expr3 = RuleExpressionEvaluator.evaluate(
            'NOT (candidate.status == \'inactive\')',
            candidateMap,
            parsedJson
        );

        System.assertEquals(true, expr1);
        System.assertEquals(true, expr2);
        System.assertEquals(true, expr3);
    }

    @IsTest
    static void testEvaluate_NegativeAndInvalidExpressions() {
        Map<String, Object> candidateMap = new Map<String, Object>{ 'years' => 2 };
        Map<String, Object> parsedJson = new Map<String, Object>{ 'skills' => new List<Object>{ 'CPR' } };

        Boolean negative = RuleExpressionEvaluator.evaluate(
            'candidate.years > 5 OR parsed_json.skills CONTAINS \'acls\'',
            candidateMap,
            parsedJson
        );
        System.assertEquals(false, negative);

        try {
            RuleExpressionEvaluator.evaluate(
                '(candidate.years > 1',
                candidateMap,
                parsedJson
            );
            System.assert(false, 'Expected evaluator to throw for mismatched parentheses');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('Mismatched parentheses'));
        }
    }
}
