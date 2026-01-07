// public with sharing class ScreeningRuleService {

//     // Inner class to hold the result of a single rule evaluation
//     public class EvalResult {
//         public Screening_Rule__c rule;
//         public String outcome; // 'Pass', 'Fail', 'Review'
//         public String details;

//         public EvalResult(Screening_Rule__c r, String out, String det) {
//             this.rule = r;
//             this.outcome = out;
//             this.details = det;
//         }
//     }

//     // Main evaluation method
//     public static List<EvalResult> evaluateRules(List<Screening_Rule__c> rules, Candidate__c candidate) {
//         List<EvalResult> results = new List<EvalResult>();
//         Map<String, SObject> relatedRecordMap = buildRelatedRecordMap(candidate);

//         for (Screening_Rule__c rule : rules) {
//             SObject targetRecord = candidate; // Default to the Candidate object itself

//             // If the rule targets a related object, get it from the map
//             if (String.isNotBlank(rule.Target_Object__c) && !rule.Target_Object__c.equalsIgnoreCase('Candidate__c')) {
//                 targetRecord = relatedRecordMap.get(rule.Target_Object__c);
//             }

//             // Evaluate the rule against the target record
//             results.add(evaluateSingleRule(rule, targetRecord));
//         }
//         return results;
//     }

//     // Helper to evaluate one rule
//     private static EvalResult evaluateSingleRule(Screening_Rule__c rule, SObject record) {
//         if (record == null) {
//             return new EvalResult(rule, 'Review', 'Rule could not be evaluated because the related record (' + rule.Target_Object__c + ') does not exist for this candidate.');
//         }

//         try {
//             Object actualValue = record.get(rule.Field_API_Name__c);
//             boolean isMet = compare(actualValue, rule.Operator__c, rule.Expected_Value__c);
            
//             String outcome = isMet ? 'Pass' : 'Fail';
//             String details = 'Evaluation of rule: ' + rule.Name;

//             // Invert logic for certain actions e.g. "Flag for Review" should fail if condition is met
//             if (rule.Action__c == 'FlagForReview' || rule.Action__c == 'RouteToJurisdiction') {
//                 outcome = isMet ? 'Review' : 'Pass';
//             }

//             return new EvalResult(rule, outcome, details);
//         } catch (Exception e) {
//             return new EvalResult(rule, 'Review', 'Error evaluating rule: ' + e.getMessage());
//         }
//     }

//     // Comparison logic
//     private static boolean compare(Object actual, String operator, String expected) {
//         if (actual == null) return false;

//         // Simplified comparison logic for demonstration
//         String actualStr = String.valueOf(actual).toLowerCase();
//         String expectedStr = expected.toLowerCase();

//         switch on operator {
//             when 'Equals' { return actualStr.equals(expectedStr); }
//             when 'Contains' { return actualStr.contains(expectedStr); }
//             when 'Greater Than' {
//                 try {
//                     return Decimal.valueOf(actualStr) > Decimal.valueOf(expectedStr);
//                 } catch (Exception e) { return false; }
//             }
//             when 'Less Than' {
//                  try {
//                     return Decimal.valueOf(actualStr) < Decimal.valueOf(expectedStr);
//                 } catch (Exception e) { return false; }
//             }
//             when else { return false; }
//         }
//     }
    
//     // Pre-fetches the FIRST related record for each relationship type for simplicity
//     private static Map<String, SObject> buildRelatedRecordMap(Candidate__c cand) {
//         Map<String, SObject> recordMap = new Map<String, SObject>();
//         if (cand.License_Certifications__r != null && !cand.License_Certifications__r.isEmpty()) {
//             recordMap.put('License_Certification__c', cand.License_Certifications__r[0]);
//         }
//         if (cand.Work_Experiences__r != null && !cand.Work_Experiences__r.isEmpty()) {
//             recordMap.put('Work_Experience__c', cand.Work_Experiences__r[0]);
//         }
//         // Add other related objects here as needed
//         return recordMap;
//     }
// }
// =====================================================
// SCREENING RULE SERVICE
// Core rule evaluation engine with multi-record support
// Uses CORRECT single __r relationship names
// =====================================================

public with sharing class ScreeningRuleService {

    public class EvalResult {
        public Screening_Rule__c rule;
        public String outcome;
        public String details;
        public Object actualValue;
        public Long executionTimeMs;

        public EvalResult(Screening_Rule__c r, String out, String det) {
            this.rule = r;
            this.outcome = out;
            this.details = det;
            this.executionTimeMs = 0;
        }
    }

    public static List<EvalResult> evaluateRules(List<Screening_Rule__c> rules, Candidate__c candidate) {
        List<EvalResult> results = new List<EvalResult>();
        Map<String, List<SObject>> allRelatedRecords = buildAllRelatedRecordsMap(candidate);

        for (Screening_Rule__c rule : rules) {
            Long startTime = System.currentTimeMillis();
            EvalResult result;
            
            if (rule.Target_Object__c == 'Candidate__c' || String.isBlank(rule.Target_Object__c)) {
                result = evaluateSingleRule(rule, candidate);
            } else {
                List<SObject> targetRecords = allRelatedRecords.get(rule.Target_Object__c);
                result = evaluateRuleAgainstMultipleRecords(rule, targetRecords, candidate);
            }
            
            result.executionTimeMs = System.currentTimeMillis() - startTime;
            results.add(result);
        }
        
        return results;
    }

    // =====================================================
// REPLACE THIS METHOD IN ScreeningRuleService.cls
// Uses correct relationship name for Research_and_Publications__r
// =====================================================

private static Map<String, List<SObject>> buildAllRelatedRecordsMap(Candidate__c cand) {
    Map<String, List<SObject>> recordMap = new Map<String, List<SObject>>();
    
    // Store ALL license/certifications
    if (cand.License_Certifications__r != null) {
        recordMap.put('License_Certification__c', 
                     (List<SObject>) cand.License_Certifications__r);
    }
    
    // Store ALL clinical skills
    if (cand.Clinical_Skills__r != null) {
        recordMap.put('Clinical_Skill__c', 
                     (List<SObject>) cand.Clinical_Skills__r);
    }
    
    // Store ALL work experiences
    if (cand.Work_Experiences__r != null) {
        recordMap.put('Work_Experience__c', 
                     (List<SObject>) cand.Work_Experiences__r);
    }
    
    // Store ALL internships
    if (cand.Internships__r != null) {
        recordMap.put('Internship__c', 
                     (List<SObject>) cand.Internships__r);
    }
    
    // Store ALL education records
    if (cand.Educations__r != null) {
        recordMap.put('Education__c', 
                     (List<SObject>) cand.Educations__r);
    }
    
    // Store ALL procedures
    if (cand.Procedures__r != null) {
        recordMap.put('Procedure__c', 
                     (List<SObject>) cand.Procedures__r);
    }
    
    // CORRECTED: Research_and_Publications__r (with underscores)
    if (cand.Research_and_Publications__r != null) {
        recordMap.put('Research_Publication__c', 
                     (List<SObject>) cand.Research_and_Publications__r);
    }
    
    // Store ALL technical skills
    if (cand.Technical_Skills__r != null) {
        recordMap.put('Technical_Skill__c', 
                     (List<SObject>) cand.Technical_Skills__r);
    }
    
    // Store ALL memberships
    if (cand.Memberships__r != null) {
        recordMap.put('Membership__c', 
                     (List<SObject>) cand.Memberships__r);
    }
    
    return recordMap;
}

// =====================================================
// NOTE: Verify ALL other relationship names too!
// =====================================================

/*
Run the verification script to confirm these names are correct:
- License_Certifications__r ✓
- Clinical_Skills__r ✓
- Work_Experiences__r ✓
- Internships__r ✓
- Educations__r ✓
- Procedures__r ✓
- Research_and_Publications__r ✓ (CONFIRMED)
- Technical_Skills__r ✓
- Memberships__r ✓

If any fail, update them based on the script output!
*/
    private static EvalResult evaluateRuleAgainstMultipleRecords(
        Screening_Rule__c rule, 
        List<SObject> records, 
        Candidate__c candidate
    ) {
        if (records == null || records.isEmpty()) {
            return new EvalResult(
                rule, 
                'Review', 
                'No ' + rule.Target_Object__c + ' records found'
            );
        }
        
        String matchType = String.isBlank(rule.Match_Type__c) ? 'Any' : rule.Match_Type__c;
        Boolean anyRecordPassed = false;
        Boolean allRecordsPassed = true;
        List<String> failedRecords = new List<String>();
        List<String> passedRecords = new List<String>();
        
        for (SObject record : records) {
            try {
                Object actualValue = record.get(rule.Field_API_Name__c);
                Boolean isMet = compare(actualValue, rule.Operator__c, rule.Expected_Value__c);
                
                if (isMet) {
                    anyRecordPassed = true;
                    passedRecords.add(getRecordIdentifier(record));
                } else {
                    allRecordsPassed = false;
                    failedRecords.add(getRecordIdentifier(record));
                }
            } catch (Exception e) {
                allRecordsPassed = false;
                failedRecords.add(getRecordIdentifier(record) + ' (Error: ' + e.getMessage() + ')');
            }
        }
        
        String outcome;
        String details;
        
        if (matchType == 'All') {
            if (allRecordsPassed) {
                outcome = 'Pass';
                details = 'All ' + records.size() + ' records met criteria';
            } else {
                outcome = 'Fail';
                details = 'Failed: ' + String.join(failedRecords, ', ');
            }
        } else {
            if (anyRecordPassed) {
                outcome = 'Pass';
                details = 'Matching: ' + String.join(passedRecords, ', ');
            } else {
                outcome = 'Fail';
                details = 'No matching records found';
            }
        }
        
        if (rule.Action__c == 'FlagForReview' || rule.Action__c == 'RouteToJurisdiction') {
            outcome = anyRecordPassed ? 'Review' : 'Pass';
        }
        
        return new EvalResult(rule, outcome, details);
    }

    private static String getRecordIdentifier(SObject record) {
        try {
            Object nameValue = record.get('Name');
            if (nameValue != null) return String.valueOf(nameValue);
        } catch (Exception e) { }
        
        List<String> identifierFields = new List<String>{
            'Title__c', 'Organization__c', 'Degree__c', 'Type__c', 'Organization_Name__c'
        };
        
        for (String field : identifierFields) {
            try {
                Object value = record.get(field);
                if (value != null) return String.valueOf(value);
            } catch (Exception e) { continue; }
        }
        
        return 'Record';
    }

    private static EvalResult evaluateSingleRule(Screening_Rule__c rule, SObject record) {
        if (record == null) {
            return new EvalResult(rule, 'Review', 'Target record does not exist');
        }

        try {
            Object actualValue = record.get(rule.Field_API_Name__c);
            Boolean isMet = compare(actualValue, rule.Operator__c, rule.Expected_Value__c);
            
            String outcome = isMet ? 'Pass' : 'Fail';
            String details = 'Field: ' + rule.Field_API_Name__c + ', Value: ' + actualValue;

            if (rule.Action__c == 'FlagForReview' || rule.Action__c == 'RouteToJurisdiction') {
                outcome = isMet ? 'Review' : 'Pass';
            }

            EvalResult result = new EvalResult(rule, outcome, details);
            result.actualValue = actualValue;
            return result;
        } catch (Exception e) {
            return new EvalResult(rule, 'Review', 'Error: ' + e.getMessage());
        }
    }

    private static Boolean compare(Object actual, String operator, String expected) {
        if (actual == null) return false;

        if (actual instanceof Date) {
            return compareDate((Date) actual, operator, expected);
        }
        if (actual instanceof DateTime) {
            return compareDateTime((DateTime) actual, operator, expected);
        }
        if (actual instanceof Boolean) {
            return compareBoolean((Boolean) actual, operator, expected);
        }
        if (actual instanceof Decimal || actual instanceof Integer || actual instanceof Double) {
            return compareNumeric(actual, operator, expected);
        }

        String actualStr = String.valueOf(actual).toLowerCase();
        String expectedStr = expected.toLowerCase();

        switch on operator {
            when 'Equals' { return actualStr.equals(expectedStr); }
            when 'Not Equals' { return !actualStr.equals(expectedStr); }
            when 'Contains' { return actualStr.contains(expectedStr); }
            when 'Does Not Contain' { return !actualStr.contains(expectedStr); }
            when 'Starts With' { return actualStr.startsWith(expectedStr); }
            when 'Ends With' { return actualStr.endsWith(expectedStr); }
            when else { return false; }
        }
    }

    private static Boolean compareDate(Date actualDate, String operator, String expectedStr) {
        Date expectedDate;
        
        if (expectedStr.equalsIgnoreCase('TODAY')) {
            expectedDate = Date.today();
        } else if (expectedStr.equalsIgnoreCase('YESTERDAY')) {
            expectedDate = Date.today().addDays(-1);
        } else if (expectedStr.equalsIgnoreCase('TOMORROW')) {
            expectedDate = Date.today().addDays(1);
        } else {
            try {
                expectedDate = Date.valueOf(expectedStr);
            } catch (Exception e) {
                return false;
            }
        }
        
        switch on operator {
            when 'Equals' { return actualDate == expectedDate; }
            when 'Not Equals' { return actualDate != expectedDate; }
            when 'Greater Than' { return actualDate > expectedDate; }
            when 'Greater Than or Equal' { return actualDate >= expectedDate; }
            when 'Less Than' { return actualDate < expectedDate; }
            when 'Less Than or Equal' { return actualDate <= expectedDate; }
            when else { return false; }
        }
    }

    private static Boolean compareDateTime(DateTime actualDateTime, String operator, String expectedStr) {
        DateTime expectedDateTime;
        
        if (expectedStr.equalsIgnoreCase('NOW')) {
            expectedDateTime = DateTime.now();
        } else {
            try {
                expectedDateTime = DateTime.valueOf(expectedStr);
            } catch (Exception e) {
                return false;
            }
        }
        
        switch on operator {
            when 'Greater Than' { return actualDateTime > expectedDateTime; }
            when 'Less Than' { return actualDateTime < expectedDateTime; }
            when else { return false; }
        }
    }

    private static Boolean compareNumeric(Object actual, String operator, String expectedStr) {
        try {
            Decimal actualNum = Decimal.valueOf(String.valueOf(actual));
            Decimal expectedNum = Decimal.valueOf(expectedStr);
            
            switch on operator {
                when 'Equals' { return actualNum == expectedNum; }
                when 'Not Equals' { return actualNum != expectedNum; }
                when 'Greater Than' { return actualNum > expectedNum; }
                when 'Greater Than or Equal' { return actualNum >= expectedNum; }
                when 'Less Than' { return actualNum < expectedNum; }
                when 'Less Than or Equal' { return actualNum <= expectedNum; }
                when else { return false; }
            }
        } catch (Exception e) {
            return false;
        }
    }

    private static Boolean compareBoolean(Boolean actual, String operator, String expectedStr) {
        Boolean expected = Boolean.valueOf(expectedStr);
        
        switch on operator {
            when 'Equals' { return actual == expected; }
            when 'Not Equals' { return actual != expected; }
            when else { return false; }
        }
    }
}