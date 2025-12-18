public with sharing class ScreeningRuleService {

    // Inner class to hold the result of a single rule evaluation
    public class EvalResult {
        public Screening_Rule__c rule;
        public String outcome; // 'Pass', 'Fail', 'Review'
        public String details;

        public EvalResult(Screening_Rule__c r, String out, String det) {
            this.rule = r;
            this.outcome = out;
            this.details = det;
        }
    }

    // Main evaluation method
    public static List<EvalResult> evaluateRules(List<Screening_Rule__c> rules, Candidate__c candidate) {
        List<EvalResult> results = new List<EvalResult>();
        Map<String, SObject> relatedRecordMap = buildRelatedRecordMap(candidate);

        for (Screening_Rule__c rule : rules) {
            SObject targetRecord = candidate; // Default to the Candidate object itself

            // If the rule targets a related object, get it from the map
            if (String.isNotBlank(rule.Target_Object__c) && !rule.Target_Object__c.equalsIgnoreCase('Candidate__c')) {
                targetRecord = relatedRecordMap.get(rule.Target_Object__c);
            }

            // Evaluate the rule against the target record
            results.add(evaluateSingleRule(rule, targetRecord));
        }
        return results;
    }

    // Helper to evaluate one rule
    private static EvalResult evaluateSingleRule(Screening_Rule__c rule, SObject record) {
        if (record == null) {
            return new EvalResult(rule, 'Review', 'Rule could not be evaluated because the related record (' + rule.Target_Object__c + ') does not exist for this candidate.');
        }

        try {
            Object actualValue = record.get(rule.Field_API_Name__c);
            boolean isMet = compare(actualValue, rule.Operator__c, rule.Expected_Value__c);
            
            String outcome = isMet ? 'Pass' : 'Fail';
            String details = 'Evaluation of rule: ' + rule.Name;

            // Invert logic for certain actions e.g. "Flag for Review" should fail if condition is met
            if (rule.Action__c == 'FlagForReview' || rule.Action__c == 'RouteToJurisdiction') {
                outcome = isMet ? 'Review' : 'Pass';
            }

            return new EvalResult(rule, outcome, details);
        } catch (Exception e) {
            return new EvalResult(rule, 'Review', 'Error evaluating rule: ' + e.getMessage());
        }
    }

    // Comparison logic
    private static boolean compare(Object actual, String operator, String expected) {
        if (actual == null) return false;

        // Simplified comparison logic for demonstration
        String actualStr = String.valueOf(actual).toLowerCase();
        String expectedStr = expected.toLowerCase();

        switch on operator {
            when 'Equals' { return actualStr.equals(expectedStr); }
            when 'Contains' { return actualStr.contains(expectedStr); }
            when 'Greater Than' {
                try {
                    return Decimal.valueOf(actualStr) > Decimal.valueOf(expectedStr);
                } catch (Exception e) { return false; }
            }
            when 'Less Than' {
                 try {
                    return Decimal.valueOf(actualStr) < Decimal.valueOf(expectedStr);
                } catch (Exception e) { return false; }
            }
            when else { return false; }
        }
    }
    
    // Pre-fetches the FIRST related record for each relationship type for simplicity
    private static Map<String, SObject> buildRelatedRecordMap(Candidate__c cand) {
        Map<String, SObject> recordMap = new Map<String, SObject>();
        if (cand.License_Certifications__r != null && !cand.License_Certifications__r.isEmpty()) {
            recordMap.put('License_Certification__c', cand.License_Certifications__r[0]);
        }
        if (cand.Work_Experiences__r != null && !cand.Work_Experiences__r.isEmpty()) {
            recordMap.put('Work_Experience__c', cand.Work_Experiences__r[0]);
        }
        // Add other related objects here as needed
        return recordMap;
    }
}
