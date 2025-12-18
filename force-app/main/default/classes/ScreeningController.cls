public with sharing class ScreeningController {

    //=================================================================//
    //======= METHODS FOR THE SCREENING RULE ADMIN LWC ================//
    //=================================================================//

    @AuraEnabled(cacheable=true)
    public static List<RuleWrapper> getRules() {
        List<Screening_Rule__c> rules = [
            SELECT Id, Name, Active__c, Priority__c, Applied_Role__c, Applied_Role__r.Name,
                   Target_Object__c, Field_API_Name__c, Operator__c, Expected_Value__c,
                   Action__c, Failure_Message__c, Rule_Key__c
            FROM Screening_Rule__c
            ORDER BY Priority__c ASC
        ];
        List<RuleWrapper> wrappers = new List<RuleWrapper>();
        for (Screening_Rule__c rule : rules) {
            wrappers.add(new RuleWrapper(rule));
        }
        return wrappers;
    }

    @AuraEnabled(cacheable=true)
    public static List<Job_Posting__c> getJobPostings() {
        return [SELECT Id, Name FROM Job_Posting__c ORDER BY Name ASC];
    }
    
    // NEW: Fetches candidates for the "View Results" dropdown
    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> getCandidates() {
        return [SELECT Id, Name FROM Candidate__c ORDER BY Name ASC LIMIT 200];
    }

    @AuraEnabled
    public static String saveRules(Object data) {
        List<Screening_Rule__c> rulesToUpdate = (List<Screening_Rule__c>) JSON.deserialize(
            JSON.serialize(data),
            List<Screening_Rule__c>.class
        );
        try {
            update rulesToUpdate;
            return 'Success: Rules saved successfully.';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // UPDATED: Now uses 'upsert' to handle both create and edit
    @AuraEnabled
    public static Screening_Rule__c saveNewRule(Screening_Rule__c newRule) {
        if (String.isBlank(newRule.Name) || newRule.Priority__c == null || String.isBlank(newRule.Applied_Role__c)) {
            throw new AuraHandledException('Rule Name, Priority, and Applied to Job Posting are required.');
        }
        try {
            if (String.isBlank(newRule.Rule_Key__c) && String.isNotBlank(newRule.Name)) {
                newRule.Rule_Key__c = newRule.Name.replaceAll('[^a-zA-Z0-9]', '_').toUpperCase();
            }
            upsert newRule; // Upsert handles both insert and update
            return newRule;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving new rule: ' + e.getMessage());
        }
    }

    // NEW: Method to delete a rule record
    @AuraEnabled
    public static void deleteRule(Id ruleId) {
        if (ruleId == null) {
            throw new AuraHandledException('Rule ID is required for deletion.');
        }
        try {
            Screening_Rule__c ruleToDelete = new Screening_Rule__c(Id = ruleId);
            delete ruleToDelete;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting rule: ' + e.getMessage());
        }
    }

    //=======================================================================//
    //======= METHODS FOR DYNAMIC OBJECT/FIELD LOOKUP =======================//
    //=======================================================================//

    public class LabelValueOption implements Comparable {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        public LabelValueOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
        public Integer compareTo(Object compareTo) {
            return label.compareTo(((LabelValueOption)compareTo).label);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<LabelValueOption> getAvailableObjects() {
        List<LabelValueOption> availableObjects = new List<LabelValueOption>();
        Map<String, String> childObjectsToCheck = new Map<String, String>{
            'License_Certification__c' => 'License/Certification',
            'Clinical_Skill__c' => 'Clinical Skill',
            'Work_Experience__c' => 'Work Experience',
            'Education__c' => 'Education',
            'Procedure__c' => 'Procedure',
            'Research_Publication__c' => 'Research/Publication',
            'Technical_Skill__c' => 'Technical Skill',
            'Membership__c' => 'Membership'
        };
        if (Schema.sObjectType.Candidate__c.isAccessible()) {
            availableObjects.add(new LabelValueOption('Candidate', 'Candidate__c'));
        }
        for (String objectApiName : childObjectsToCheck.keySet()) {
            SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
            if (objectType != null && objectType.getDescribe().isAccessible()) {
                availableObjects.add(new LabelValueOption(childObjectsToCheck.get(objectApiName), objectApiName));
            }
        }
        availableObjects.sort();
        return availableObjects;
    }

    @AuraEnabled(cacheable=true)
    public static List<LabelValueOption> getFieldsForObject(String objectApiName) {
        Set<String> allowedObjects = new Set<String>{
            'Candidate__c', 'License_Certification__c', 'Clinical_Skill__c',
            'Work_Experience__c', 'Internship__c', 'Education__c', 'Procedure__c',
            'Research_Publication__c', 'Technical_Skill__c', 'Membership__c'
        };
        if (String.isBlank(objectApiName) || !allowedObjects.contains(objectApiName)) {
            throw new AuraHandledException('Invalid or unauthorized object specified.');
        }
        List<LabelValueOption> fieldOptions = new List<LabelValueOption>();
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        for (Schema.SObjectField field : fieldMap.values()) {
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            if (fieldDescribe.isAccessible() && !fieldDescribe.isCalculated()) {
                fieldOptions.add(new LabelValueOption(fieldDescribe.getLabel(), fieldDescribe.getName()));
            }
        }
        fieldOptions.sort();
        return fieldOptions;
    }

    //=======================================================================//
    //======= WRAPPER CLASS =================================================//
    //=======================================================================//

    public class RuleWrapper {
        @AuraEnabled public Id Id { get; set; }
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public Boolean active { get; set; }
        @AuraEnabled public Decimal priority { get; set; }
        @AuraEnabled public String appliedRoleId { get; set; }
        @AuraEnabled public String appliedRoleName { get; set; }
        @AuraEnabled public String targetObject { get; set; }
        @AuraEnabled public String fieldApiName { get; set; }
        @AuraEnabled public String operator { get; set; }
        @AuraEnabled public String expectedValue { get; set; }
        @AuraEnabled public String action { get; set; }
        @AuraEnabled public String failureMessage { get; set; }
        @AuraEnabled public String ruleKey { get; set; }
        
        public RuleWrapper(Screening_Rule__c rule) {
            this.Id = rule.Id;
            this.Name = rule.Name;
            this.active = rule.Active__c;
            this.priority = rule.Priority__c;
            this.appliedRoleId = rule.Applied_Role__c;
            this.appliedRoleName = (rule.Applied_Role__r != null) ? rule.Applied_Role__r.Name : '';
            this.targetObject = rule.Target_Object__c;
            this.fieldApiName = rule.Field_API_Name__c;
            this.operator = rule.Operator__c;
            this.expectedValue = rule.Expected_Value__c;
            this.action = rule.Action__c;
            this.failureMessage = rule.Failure_Message__c;
            this.ruleKey = rule.Rule_Key__c;
        }
    }
}
