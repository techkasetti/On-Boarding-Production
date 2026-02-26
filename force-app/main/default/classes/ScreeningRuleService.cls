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

    private static Map<String, List<SObject>> buildAllRelatedRecordsMap(Candidate__c cand) {
        Map<String, List<SObject>> recordMap = new Map<String, List<SObject>>();
        
        if (cand.License_Certifications__r != null) {
            recordMap.put('License_Certification__c', 
                         (List<SObject>) cand.License_Certifications__r);
        }
        
        if (cand.Clinical_Skills__r != null) {
            recordMap.put('Clinical_Skill__c', 
                         (List<SObject>) cand.Clinical_Skills__r);
        }
        
        if (cand.Work_Experiences__r != null) {
            recordMap.put('Work_Experience__c', 
                         (List<SObject>) cand.Work_Experiences__r);
        }
        
        if (cand.Internships__r != null) {
            recordMap.put('Internship__c', 
                         (List<SObject>) cand.Internships__r);
        }
        
        if (cand.Educations__r != null) {
            recordMap.put('Education__c', 
                         (List<SObject>) cand.Educations__r);
        }
        
        if (cand.Procedures__r != null) {
            recordMap.put('Procedure__c', 
                         (List<SObject>) cand.Procedures__r);
        }
        
        if (cand.Research_and_Publications__r != null) {
            recordMap.put('Research_Publication__c', 
                         (List<SObject>) cand.Research_and_Publications__r);
        }
        
        if (cand.Technical_Skills__r != null) {
            recordMap.put('Technical_Skill__c', 
                         (List<SObject>) cand.Technical_Skills__r);
        }
        
        if (cand.Memberships__r != null) {
            recordMap.put('Membership__c', 
                         (List<SObject>) cand.Memberships__r);
        }
        
        return recordMap;
    }

    private static EvalResult evaluateRuleAgainstMultipleRecords(
        Screening_Rule__c rule, 
        List<SObject> records, 
        Candidate__c candidate
    ) {
        if (records == null || records.isEmpty()) {
            String outcome = (rule.Action__c == 'FlagForReview') ? 'Review' : 'Fail';
            String details = '✗ No ' + getObjectLabel(rule.Target_Object__c) + ' records found for candidate';
            return new EvalResult(rule, outcome, details);
        }
        
        String matchType = String.isBlank(rule.Match_Type__c) ? 'Any' : rule.Match_Type__c;
        Boolean anyRecordPassed = false;
        Boolean allRecordsPassed = true;
        List<String> failedRecords = new List<String>();
        List<String> passedRecords = new List<String>();
        
        System.debug('=== Evaluating Rule: ' + rule.Name + ' ===');
        System.debug('Target Object: ' + rule.Target_Object__c);
        System.debug('Field: ' + rule.Field_API_Name__c);
        System.debug('Operator: ' + rule.Operator__c);
        System.debug('Expected Value: ' + rule.Expected_Value__c);
        System.debug('Number of records: ' + records.size());
        
        for (SObject record : records) {
            try {
                Object actualValue = record.get(rule.Field_API_Name__c);
                
                System.debug('  Checking record: ' + getRecordIdentifier(record));
                System.debug('    Actual value: ' + actualValue);
                
                Boolean isMet = compare(actualValue, rule.Operator__c, rule.Expected_Value__c);
                
                System.debug('    Match result: ' + isMet);
                
                if (isMet) {
                    anyRecordPassed = true;
                    passedRecords.add(getRecordIdentifier(record));
                } else {
                    allRecordsPassed = false;
                    failedRecords.add(getRecordIdentifier(record));
                }
            } catch (Exception e) {
                System.debug('    ERROR: ' + e.getMessage());
                allRecordsPassed = false;
                failedRecords.add(getRecordIdentifier(record) + ' (Error: ' + e.getMessage() + ')');
            }
        }
        
        String outcome;
        String details;
        
        if (matchType == 'All') {
            if (allRecordsPassed) {
                outcome = 'Pass';
                details = '✓ All ' + records.size() + ' ' + getObjectLabel(rule.Target_Object__c) + ' records met criteria';
            } else {
                outcome = (rule.Action__c == 'FlagForReview') ? 'Review' : 'Fail';
                details = '✗ Some records failed: ' + String.join(failedRecords, ', ');
            }
        } else {
            if (anyRecordPassed) {
                outcome = (rule.Action__c == 'FlagForReview') ? 'Review' : 'Pass';
                details = '✓ Found matching: ' + String.join(passedRecords, ', ');
            } else {
                outcome = (rule.Action__c == 'FlagForReview') ? 'Review' : 'Fail';
                details = '✗ No ' + getObjectLabel(rule.Target_Object__c) + ' records matched criteria. Checked ' + records.size() + ' record(s).';
            }
        }
        
        System.debug('Final outcome: ' + outcome);
        System.debug('Details: ' + details);
        
        return new EvalResult(rule, outcome, details);
    }

    private static String getObjectLabel(String objectApiName) {
        Map<String, String> labels = new Map<String, String>{
            'License_Certification__c' => 'License/Certification',
            'Clinical_Skill__c' => 'Clinical Skill',
            'Work_Experience__c' => 'Work Experience',
            'Education__c' => 'Education',
            'Procedure__c' => 'Procedure',
            'Research_Publication__c' => 'Research/Publication',
            'Technical_Skill__c' => 'Technical Skill',
            'Membership__c' => 'Membership',
            'Internship__c' => 'Internship'
        };
        return labels.containsKey(objectApiName) ? labels.get(objectApiName) : objectApiName;
    }

    // 🔥 FIXED: Object-specific field priorities for better display names
    private static String getRecordIdentifier(SObject record) {
        // Get the object type to determine which fields to check
        String objectType = String.valueOf(record.getSObjectType());
        
        // Object-specific field priorities
        Map<String, List<String>> fieldsByObject = new Map<String, List<String>>{
            'Education__c' => new List<String>{'Degree__c', 'Institution__c', 'Name'},
            'Work_Experience__c' => new List<String>{'Role__c', 'Organization__c', 'Name'},
            'License_Certification__c' => new List<String>{'Name', 'Type__c'},
            'Clinical_Skill__c' => new List<String>{'Name', 'Skill_Type__c'},
            'Research_Publication__c' => new List<String>{'Title__c', 'Name'},
            'Procedure__c' => new List<String>{'Name', 'Category__c'},
            'Technical_Skill__c' => new List<String>{'Name', 'Category__c'},
            'Membership__c' => new List<String>{'Organization_Name__c', 'Name'},
            'Internship__c' => new List<String>{'Organization__c', 'Name'}
        };
        
        // Try object-specific fields first
        if (fieldsByObject.containsKey(objectType)) {
            for (String field : fieldsByObject.get(objectType)) {
                try {
                    Object value = record.get(field);
                    if (value != null && String.valueOf(value).trim() != '') {
                        return String.valueOf(value);
                    }
                } catch (Exception e) { 
                    continue; 
                }
            }
        }
        
        // Fallback to generic fields
        List<String> genericFields = new List<String>{
            'Name',
            'Title__c',
            'Degree__c',
            'Organization__c',
            'Organization_Name__c',
            'Role__c',
            'Type__c'
        };
        
        for (String field : genericFields) {
            try {
                Object value = record.get(field);
                if (value != null && String.valueOf(value).trim() != '') {
                    return String.valueOf(value);
                }
            } catch (Exception e) { 
                continue; 
            }
        }
        
        // Last resort: return "Unknown [ObjectType]"
        return 'Unknown ' + getObjectLabel(objectType);
    }

    // 🔥 FIXED: Handle NULL values for ALL field types on Candidate
    private static EvalResult evaluateSingleRule(Screening_Rule__c rule, SObject record) {
        if (record == null) {
            return new EvalResult(rule, 'Review', 'Target record does not exist');
        }

        try {
            Object actualValue = record.get(rule.Field_API_Name__c);
            
            // 🔥 CRITICAL FIX: Check for null/blank values BEFORE any comparison
            if (actualValue == null || (actualValue instanceof String && String.isBlank((String)actualValue))) {
                String outcome = (rule.Action__c == 'FlagForReview') ? 'Review' : 'Fail';
                String details = 'Field: ' + rule.Field_API_Name__c + ' is null/empty (cannot evaluate rule)';
                
                System.debug('⚠️ NULL/BLANK field detected: ' + rule.Field_API_Name__c);
                System.debug('   Action: ' + rule.Action__c);
                System.debug('   Outcome: ' + outcome);
                
                EvalResult result = new EvalResult(rule, outcome, details);
                result.actualValue = null;
                return result;
            }
            
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

    // 🔥 FIXED: Comprehensive null/blank handling with case-insensitive operators
    private static Boolean compare(Object actual, String operator, String expected) {
        // 🔥 SAFETY CHECK: This should never happen due to evaluateSingleRule check, but just in case
        if (actual == null) {
            System.debug('    ⚠️ WARNING: compare() received null actual value');
            return false;
        }
        
        // 🔥 SAFETY CHECK: Handle blank strings
        if (actual instanceof String && String.isBlank((String)actual)) {
            System.debug('    ⚠️ WARNING: compare() received blank string');
            return false;
        }
        
        if (String.isBlank(expected)) {
            System.debug('    compare() -> expected is blank, returning false');
            return false;
        }

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

        // Clean and normalize strings
        String actualStr = String.valueOf(actual).trim().toLowerCase();
        String expectedStr = expected.trim().toLowerCase();
        String operatorLower = operator.trim().toLowerCase();
        
        System.debug('    Normalized actual: "' + actualStr + '"');
        System.debug('    Normalized expected: "' + expectedStr + '"');
        System.debug('    Normalized operator: "' + operatorLower + '"');

        if (operatorLower == 'equals') {
            Boolean result = actualStr.equals(expectedStr);
            System.debug('    Equals check: ' + result);
            return result;
        } 
        else if (operatorLower == 'not equals') {
            Boolean result = !actualStr.equals(expectedStr);
            System.debug('    Not Equals check: ' + result);
            return result;
        }
        else if (operatorLower == 'contains') {
            // 🔥 Handle OR logic with | separator
            if (expectedStr.contains('|')) {
                System.debug('    OR logic detected, splitting by |');
                List<String> keywords = expectedStr.split('\\|');
                System.debug('    Keywords: ' + keywords);
                
                for (String keyword : keywords) {
                    String cleanKeyword = keyword.trim();
                    System.debug('      Testing keyword: "' + cleanKeyword + '"');
                    
                    if (actualStr.contains(cleanKeyword)) {
                        System.debug('      ✓ MATCH FOUND!');
                        return true;
                    }
                }
                System.debug('      ✗ No matches found');
                return false;
            }
            
            Boolean result = actualStr.contains(expectedStr);
            System.debug('    Contains check: ' + result);
            return result;
        }
        else if (operatorLower == 'does not contain') {
            Boolean result = !actualStr.contains(expectedStr);
            System.debug('    Does Not Contain check: ' + result);
            return result;
        }
        else if (operatorLower == 'starts with') {
            Boolean result = actualStr.startsWith(expectedStr);
            System.debug('    Starts With check: ' + result);
            return result;
        }
        else if (operatorLower == 'ends with') {
            Boolean result = actualStr.endsWith(expectedStr);
            System.debug('    Ends With check: ' + result);
            return result;
        }
        else {
            System.debug('    Unknown operator: ' + operator);
            return false;
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
        
        String operatorLower = operator.trim().toLowerCase();
        
        if (operatorLower == 'equals') return actualDate == expectedDate;
        if (operatorLower == 'not equals') return actualDate != expectedDate;
        if (operatorLower == 'greater than') return actualDate > expectedDate;
        if (operatorLower == 'greater than or equal') return actualDate >= expectedDate;
        if (operatorLower == 'less than') return actualDate < expectedDate;
        if (operatorLower == 'less than or equal') return actualDate <= expectedDate;
        
        return false;
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
        
        String operatorLower = operator.trim().toLowerCase();
        
        if (operatorLower == 'greater than') return actualDateTime > expectedDateTime;
        if (operatorLower == 'less than') return actualDateTime < expectedDateTime;
        
        return false;
    }

    private static Boolean compareNumeric(Object actual, String operator, String expectedStr) {
        try {
            Decimal actualNum = Decimal.valueOf(String.valueOf(actual));
            Decimal expectedNum = Decimal.valueOf(expectedStr);
            
            String operatorLower = operator.trim().toLowerCase();
            
            if (operatorLower == 'equals') return actualNum == expectedNum;
            if (operatorLower == 'not equals') return actualNum != expectedNum;
            if (operatorLower == 'greater than') return actualNum > expectedNum;
            if (operatorLower == 'greater than or equal') return actualNum >= expectedNum;
            if (operatorLower == 'less than') return actualNum < expectedNum;
            if (operatorLower == 'less than or equal') return actualNum <= expectedNum;
            
            return false;
        } catch (Exception e) {
            System.debug('    compareNumeric() exception: ' + e.getMessage());
            return false;
        }
    }

    private static Boolean compareBoolean(Boolean actual, String operator, String expectedStr) {
        Boolean expected = Boolean.valueOf(expectedStr);
        String operatorLower = operator.trim().toLowerCase();
        
        if (operatorLower == 'equals') return actual == expected;
        if (operatorLower == 'not equals') return actual != expected;
        
        return false;
    }
}