// =====================================================
// SCREENING CONTROLLER - AUTO VERSIONING ON EDIT
// Automatically creates new version when editing rules
// =====================================================

public with sharing class ScreeningController {

    // ==================== GET RULES - ONLY CURRENT VERSIONS ====================
    
    // @AuraEnabled(cacheable=true)
    // public static List<RuleWrapper> getRules() {
    //     List<Screening_Rule__c> rules = [
    //         SELECT Id, Name, Active__c, Priority__c, Applied_Role__c, Applied_Role__r.Name,
    //                Target_Object__c, Field_API_Name__c, Operator__c, Expected_Value__c,
    //                Action__c, Failure_Message__c, Rule_Key__c, Version__c, Is_Current_Version__c,
    //                Journey_Path__c, Route_To_Queue__c, Escalation_Level__c, Allow_Manual_Override__c,
    //                Is_Test_Rule__c, Group_Name__c, Match_Type__c, Rule_Category__c,
    //                Last_Execution_Date__c, Execution_Count__c, Pass_Rate__c,
    //                Override_Reason_Required__c, Override_Approval_Required__c, Auto_Route__c
    //         FROM Screening_Rule__c
    //         WHERE Is_Current_Version__c = true
    //         AND (Test_Mode_Only__c = false OR Test_Mode_Only__c = null)
    //         ORDER BY Priority__c ASC
    //     ];
        
    //     System.debug('Current version rules returned: ' + rules.size());
        
    //     List<RuleWrapper> wrappers = new List<RuleWrapper>();
    //     for (Screening_Rule__c rule : rules) {
    //         wrappers.add(new RuleWrapper(rule));
    //     }
    //     return wrappers;
    // }
    
@AuraEnabled(cacheable=true)
public static List<RuleWrapper> getRules() {
    List<Screening_Rule__c> rules = [
        SELECT Id, Name, Active__c, Priority__c, Applied_Role__c, Applied_Role__r.Name,
               Target_Object__c, Field_API_Name__c, Operator__c, Expected_Value__c,
               Action__c, Failure_Message__c, Rule_Key__c, Version__c, Is_Current_Version__c,
               Journey_Path__c, Route_To_Queue__c, Escalation_Level__c, Allow_Manual_Override__c, // ✅ INCLUDED
               Is_Test_Rule__c, Group_Name__c, Match_Type__c, Rule_Category__c,
               Last_Execution_Date__c, Execution_Count__c, Pass_Rate__c,
               Override_Reason_Required__c, Override_Approval_Required__c, Auto_Route__c
        FROM Screening_Rule__c
        WHERE Is_Current_Version__c = true
        AND (Test_Mode_Only__c = false OR Test_Mode_Only__c = null)
        ORDER BY Priority__c ASC
    ];
    
     System.debug('Current version rules returned: ' + rules.size());
        
        List<RuleWrapper> wrappers = new List<RuleWrapper>();
        for (Screening_Rule__c rule : rules) {
            wrappers.add(new RuleWrapper(rule));
        }
        return wrappers;
}
    
    @AuraEnabled(cacheable=true)
    public static List<Job_Posting__c> getJobPostings() {
        try {
            List<Job_Posting__c> jobs = [
                SELECT Id, Name, Enable_Screening__c, Default_Journey_Path__c
                FROM Job_Posting__c 
                ORDER BY Name ASC
                LIMIT 200
            ];
            return jobs;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching job postings: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Candidate__c> getCandidates() {
        return [
            SELECT Id, Name, Screening_Status__c, Last_Screening_Date__c
            FROM Candidate__c 
            ORDER BY Name ASC 
            LIMIT 200
        ];
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
    
   
     @AuraEnabled
    public static Screening_Rule__c saveNewRule(Screening_Rule__c newRule) {
        if (String.isBlank(newRule.Name) || newRule.Priority__c == null || 
            String.isBlank(newRule.Applied_Role__c)) {
            throw new AuraHandledException('Rule Name, Priority, and Applied Role are required.');
        }
        
        try {
            // Generate Rule_Key if blank
            if (String.isBlank(newRule.Rule_Key__c)) {
                newRule.Rule_Key__c = newRule.Name.replaceAll('[^a-zA-Z0-9]', '_').toUpperCase();
            }
            
            // ==================== STORAGE-OPTIMIZED VERSIONING ====================
            if (newRule.Id != null) {
                // EDIT MODE: Only version on SIGNIFICANT changes
                System.debug('EDIT MODE DETECTED - Checking for significant changes');
                
                // Get the existing rule to compare
                Screening_Rule__c existingRule = [
                    SELECT Id, Name, Version__c, Priority__c, Applied_Role__c,
                           Target_Object__c, Field_API_Name__c, Operator__c, Expected_Value__c,
                           Action__c, Failure_Message__c, Journey_Path__c, Route_To_Queue__c,
                           Escalation_Level__c, Allow_Manual_Override__c, Rule_Key__c,
                           Override_Reason_Required__c, Override_Approval_Required__c,
                           Group_Name__c, Rule_Category__c, Match_Type__c, Auto_Route__c
                    FROM Screening_Rule__c 
                    WHERE Id = :newRule.Id 
                    LIMIT 1
                ];
                
                // Check if any CRITICAL field has changed (not cosmetic changes)
                Boolean hasChanges = hasCriticalChanges(existingRule, newRule);
                
                if (hasChanges) {
                    System.debug('CRITICAL changes detected - creating new version');
                    
                    // STORAGE OPTIMIZATION: Delete old versions (keep only last 3)
                    deleteOldVersions(existingRule.Rule_Key__c, 3);
                    
                    // Deactivate current version
                    existingRule.Is_Current_Version__c = false;
                    existingRule.Active__c = false;
                    update existingRule;
                    
                    // Create new version
                    Screening_Rule__c newVersion = newRule.clone(false, true, false, false);
                    newVersion.Version__c = (existingRule.Version__c != null ? existingRule.Version__c : 1.0) + 1.0;
                    newVersion.Is_Current_Version__c = true;
                    newVersion.Parent_Rule_Version__c = existingRule.Id;
                    newVersion.Active__c = true;
                    newVersion.Rule_Key__c = existingRule.Rule_Key__c;
                    newVersion.Version_Notes__c = 'Auto-versioned - ' + System.now().format('yyyy-MM-dd HH:mm');
                    
                    // Reset statistics for new version
                    newVersion.Last_Execution_Date__c = null;
                    newVersion.Execution_Count__c = 0;
                    newVersion.Pass_Rate__c = null;
                    newVersion.Fail_Rate__c = null;
                    newVersion.Last_Tested_Date__c = null;
                    newVersion.Test_Pass_Count__c = 0;
                    newVersion.Test_Fail_Count__c = 0;
                    
                    insert newVersion;
                    
                    System.debug('New version created: ' + newVersion.Id + ' (Version ' + newVersion.Version__c + ')');
                    return newVersion;
                } else {
                    System.debug('No critical changes - updating existing version');
                    update newRule;
                    return newRule;
                }
                
            } else {
                // CREATE MODE: New rule
                System.debug('CREATE MODE - Creating new rule');
                newRule.Version__c = 1.0;
                newRule.Is_Current_Version__c = true;
                insert newRule;
                return newRule;
            }
            
        } catch (Exception e) {
            System.debug('ERROR in saveNewRule: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            // Better error message for storage limit
            if (e.getMessage().contains('STORAGE_LIMIT_EXCEEDED')) {
                throw new AuraHandledException('Storage limit exceeded. Please free up space by deleting old debug logs or unused data.');
            }
            throw new AuraHandledException('Error saving rule: ' + e.getMessage());
        }
    }

     // ==================== STORAGE OPTIMIZATION: DELETE OLD VERSIONS ====================
    
    private static void deleteOldVersions(String ruleKey, Integer keepCount) {
        try {
            List<Screening_Rule__c> allVersions = [
                SELECT Id, Version__c, Is_Current_Version__c
                FROM Screening_Rule__c
                WHERE Rule_Key__c = :ruleKey
                ORDER BY Version__c DESC
            ];
            
            if (allVersions.size() > keepCount) {
                List<Screening_Rule__c> versionsToDelete = new List<Screening_Rule__c>();
                Integer count = 0;
                
                for (Screening_Rule__c version : allVersions) {
                    if (!version.Is_Current_Version__c && count >= keepCount - 1) {
                        versionsToDelete.add(version);
                    }
                    if (!version.Is_Current_Version__c) {
                        count++;
                    }
                }
                
                if (!versionsToDelete.isEmpty()) {
                    delete versionsToDelete;
                    System.debug('Deleted ' + versionsToDelete.size() + ' old versions to save storage');
                }
            }
        } catch (Exception e) {
            System.debug('Warning: Could not delete old versions: ' + e.getMessage());
        }
    }
    
    
     
    // ==================== HELPER: CHECK FOR CRITICAL CHANGES ONLY ====================
    
    private static Boolean hasCriticalChanges(Screening_Rule__c oldRule, Screening_Rule__c newRule) {
        // Only version on CRITICAL changes that affect rule behavior
        Boolean changed = false;
        
        // Rule logic fields (CRITICAL)
        if (!equals(oldRule.Target_Object__c, newRule.Target_Object__c)) {
            System.debug('Changed: Target_Object__c');
            changed = true;
        }
        if (!equals(oldRule.Field_API_Name__c, newRule.Field_API_Name__c)) {
            System.debug('Changed: Field_API_Name__c');
            changed = true;
        }
        if (!equals(oldRule.Operator__c, newRule.Operator__c)) {
            System.debug('Changed: Operator__c');
            changed = true;
        }
        if (!equals(oldRule.Expected_Value__c, newRule.Expected_Value__c)) {
            System.debug('Changed: Expected_Value__c');
            changed = true;
        }
        if (!equals(oldRule.Action__c, newRule.Action__c)) {
            System.debug('Changed: Action__c');
            changed = true;
        }
        if (!equals(oldRule.Match_Type__c, newRule.Match_Type__c)) {
            System.debug('Changed: Match_Type__c');
            changed = true;
        }
        
        // Note: Priority, Name, Journey_Path, Route_To_Queue changes do NOT create new versions
        // to save storage
        
        return changed;
    }
    
    private static Boolean equals(String str1, String str2) {
        if (str1 == null && str2 == null) return true;
        if (str1 == null || str2 == null) return false;
        return str1.equals(str2);
    }
    
    // ==================== DELETE RULE ====================
    
    @AuraEnabled
    public static void deleteRule(Id ruleId) {
        if (ruleId == null) {
            throw new AuraHandledException('Rule ID is required.');
        }
        try {
            Screening_Rule__c ruleToDelete = [
                SELECT Rule_Key__c 
                FROM Screening_Rule__c 
                WHERE Id = :ruleId 
                LIMIT 1
            ];
            
            // Delete all versions of this rule
            if (String.isNotBlank(ruleToDelete.Rule_Key__c)) {
                List<Screening_Rule__c> allVersions = [
                    SELECT Id 
                    FROM Screening_Rule__c 
                    WHERE Rule_Key__c = :ruleToDelete.Rule_Key__c
                ];
                delete allVersions;
                System.debug('Deleted ' + allVersions.size() + ' versions of the rule');
            } else {
                delete new Screening_Rule__c(Id = ruleId);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting rule: ' + e.getMessage());
        }
    }
    
    // ==================== VERSIONING (MANUAL ROLLBACK ONLY) ====================
    
    @AuraEnabled
    public static void rollbackRule(Id targetVersionId) {
        try {
            RuleVersioningService.rollbackToVersion(targetVersionId);
        } catch (Exception e) {
            throw new AuraHandledException('Error rolling back: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<VersionHistoryWrapper> getRuleVersionHistory(Id ruleId) {
        List<VersionHistoryWrapper> history = new List<VersionHistoryWrapper>();
        try {
            List<Screening_Rule__c> versions = RuleVersioningService.getVersionHistory(ruleId);
            for (Screening_Rule__c ver : versions) {
                history.add(new VersionHistoryWrapper(ver));
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving history: ' + e.getMessage());
        }
        return history;
    }
    
    // ==================== TESTING SANDBOX ====================
    
    @AuraEnabled
    public static TestResultWrapper testRuleAgainstCandidate(Id ruleId, Id candidateId) {
        try {
            Screening_Rule__c rule = [
                SELECT Id, Name, Target_Object__c, Field_API_Name__c, Operator__c, 
                       Expected_Value__c, Action__c, Failure_Message__c, Match_Type__c
                FROM Screening_Rule__c 
                WHERE Id = :ruleId 
                LIMIT 1
            ];
            
            Candidate__c candidate = ScreeningDataLoader.loadCandidateWithAllRelations(candidateId);
            
            List<ScreeningRuleService.EvalResult> results = 
                ScreeningRuleService.evaluateRules(new List<Screening_Rule__c>{rule}, candidate);
            
            if (!results.isEmpty()) {
                ScreeningRuleService.EvalResult result = results[0];
                
                // Update test statistics (WITHOUT versioning)
                rule.Last_Tested_Date__c = System.now();
                if (result.outcome == 'Pass') {
                    rule.Test_Pass_Count__c = (rule.Test_Pass_Count__c != null ? rule.Test_Pass_Count__c : 0) + 1;
                } else {
                    rule.Test_Fail_Count__c = (rule.Test_Fail_Count__c != null ? rule.Test_Fail_Count__c : 0) + 1;
                }
                update rule;
                
                return new TestResultWrapper(result.outcome, result.details, rule.Name, candidate.Name);
            }
            
            return new TestResultWrapper('Error', 'No evaluation result', rule.Name, candidate.Name);
        } catch (Exception e) {
            throw new AuraHandledException('Test failed: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<TestResultWrapper> testRuleAgainstMultipleCandidates(Id ruleId, List<Id> candidateIds) {
        List<TestResultWrapper> results = new List<TestResultWrapper>();
        
        try {
            Screening_Rule__c rule = [
                SELECT Id, Name, Target_Object__c, Field_API_Name__c, Operator__c, 
                       Expected_Value__c, Action__c, Match_Type__c
                FROM Screening_Rule__c 
                WHERE Id = :ruleId 
                LIMIT 1
            ];
            
            for (Id candId : candidateIds) {
                try {
                    Candidate__c candidate = ScreeningDataLoader.loadCandidateWithAllRelations(candId);
                    List<ScreeningRuleService.EvalResult> evalResults = 
                        ScreeningRuleService.evaluateRules(new List<Screening_Rule__c>{rule}, candidate);
                    
                    if (!evalResults.isEmpty()) {
                        ScreeningRuleService.EvalResult result = evalResults[0];
                        results.add(new TestResultWrapper(result.outcome, result.details, rule.Name, candidate.Name));
                    }
                } catch (Exception e) {
                    results.add(new TestResultWrapper('Error', e.getMessage(), rule.Name, 'Unknown'));
                }
            }
            
            return results;
        } catch (Exception e) {
            throw new AuraHandledException('Batch test failed: ' + e.getMessage());
        }
    }
    
    // ==================== WORKFLOW ROUTING ====================
    
    @AuraEnabled(cacheable=true)
    public static List<LabelValueOption> getJourneyPathOptions() {
        return new List<LabelValueOption>{
            new LabelValueOption('Doctor Path', 'Doctor Path'),
            new LabelValueOption('Nurse Path', 'Nurse Path'),
            new LabelValueOption('Admin Path', 'Admin Path'),
            new LabelValueOption('Tech Path', 'Tech Path'),
            new LabelValueOption('Custom Path', 'Custom')
        };
    }
    
    @AuraEnabled
    public static Map<String, Object> getRoutingRecommendation(Id candidateId) {
        try {
            List<Screening_Result__c> results = [
                SELECT Id, Outcome__c, Action__c, Screening_Rule__r.Journey_Path__c,
                       Screening_Rule__r.Route_To_Queue__c, Screening_Rule__r.Escalation_Level__c
                FROM Screening_Result__c
                WHERE Candidate__c = :candidateId
                ORDER BY Screening_Rule__r.Escalation_Level__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 1
            ];
            
            if (results.isEmpty()) {
                return new Map<String, Object>{
                    'hasRouting' => false,
                    'message' => 'No screening results found'
                };
            }
            
            Screening_Result__c topResult = results[0];
            return new Map<String, Object>{
                'hasRouting' => true,
                'journeyPath' => topResult.Screening_Rule__r.Journey_Path__c,
                'queueName' => topResult.Screening_Rule__r.Route_To_Queue__c,
                'escalationLevel' => topResult.Screening_Rule__r.Escalation_Level__c,
                'outcome' => topResult.Outcome__c
            };
        } catch (Exception e) {
            throw new AuraHandledException('Error getting routing: ' + e.getMessage());
        }
    }
    
    // ==================== MANUAL OVERRIDE ====================
    
    // @AuraEnabled
    // public static void createManualOverride(Id candidateId, Id ruleId, String overrideReason, 
    //                                        String newOutcome, String overrideType) {
    //     if (String.isBlank(overrideReason)) {
    //         throw new AuraHandledException('Override reason is required.');
    //     }
        
    //     try {
    //         Screening_Rule__c rule = [
    //             SELECT Allow_Manual_Override__c, Override_Approval_Required__c, Override_Approver__c
    //             FROM Screening_Rule__c 
    //             WHERE Id = :ruleId 
    //             LIMIT 1
    //         ];
            
    //         if (!rule.Allow_Manual_Override__c) {
    //             throw new AuraHandledException('This rule does not allow manual overrides.');
    //         }
            
    //         List<Screening_Result__c> results = [
    //             SELECT Id, Outcome__c
    //             FROM Screening_Result__c
    //             WHERE Candidate__c = :candidateId AND Screening_Rule__c = :ruleId
    //             ORDER BY CreatedDate DESC
    //             LIMIT 1
    //         ];
            
    //         Screening_Override__c override1 = new Screening_Override__c();
    //         override1.Candidate__c = candidateId;
    //         override1.Screening_Rule__c = ruleId;
    //         override1.Screening_Result__c = !results.isEmpty() ? results[0].Id : null;
    //         override1.Original_Outcome__c = !results.isEmpty() ? results[0].Outcome__c : null;
    //         override1.New_Outcome__c = newOutcome;
    //         override1.Override_Reason__c = overrideReason;
    //         override1.Override_Type__c = overrideType;
    //         override1.Override_By__c = UserInfo.getUserId();
    //         override1.Override_Date__c = System.now();
    //         override1.Approval_Status__c = rule.Override_Approval_Required__c ? 'Pending' : 'Approved';
            
    //         insert override1;
            
    //         if (!rule.Override_Approval_Required__c) {
    //             ScreeningOverrideHandler.applyOverride(override1.Id);
    //         }
    //     } catch (Exception e) {
    //         throw new AuraHandledException('Error creating override: ' + e.getMessage());
    //     }
    // }

 // ==================== MANUAL OVERRIDE WITH APPROVAL ====================

    @AuraEnabled
    public static Map<String, Object> createManualOverride(
        Id candidateId, 
        Id ruleId, 
        String overrideReason, 
        String newOutcome, 
        String overrideType
    ) {
        if (String.isBlank(overrideReason)) {
            throw new AuraHandledException('Override reason is required.');
        }
        
        try {
            // Get rule details
            Screening_Rule__c rule = [
                SELECT Allow_Manual_Override__c, 
                       Override_Approval_Required__c, 
                       Override_Approver__c,
                       Override_Approver__r.Email,
                       Override_Approver__r.Name,
                       Name
                FROM Screening_Rule__c 
                WHERE Id = :ruleId 
                LIMIT 1
            ];
            
            if (!rule.Allow_Manual_Override__c) {
                throw new AuraHandledException('This rule does not allow manual overrides.');
            }
            
            // Get latest screening result
            List<Screening_Result__c> results = [
                SELECT Id, Outcome__c
                FROM Screening_Result__c
                WHERE Candidate__c = :candidateId 
                AND Screening_Rule__c = :ruleId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            // Create override record
            Screening_Override__c override1 = new Screening_Override__c();
            override1.Candidate__c = candidateId;
            override1.Screening_Rule__c = ruleId;
            override1.Screening_Result__c = !results.isEmpty() ? results[0].Id : null;
            override1.Original_Outcome__c = !results.isEmpty() ? results[0].Outcome__c : null;
            override1.New_Outcome__c = newOutcome;
            override1.Override_Reason__c = overrideReason;
            override1.Override_Type__c = overrideType;
            override1.Override_By__c = UserInfo.getUserId();
            override1.Override_Date__c = System.now();
            
            // 🔥 NEW: Set approval status based on rule configuration
            if (rule.Override_Approval_Required__c) {
                override1.Approval_Status__c = 'Pending';
            } else {
                override1.Approval_Status__c = 'Approved';
            }
            
            insert override1;
            
            // 🔥 NEW: Send approval email if required
            Boolean emailSent = false;
            if (rule.Override_Approval_Required__c && rule.Override_Approver__c != null) {
                try {
                    emailSent = sendApprovalEmail(override1.Id, rule);
                } catch (Exception emailError) {
                    System.debug('Email send failed: ' + emailError.getMessage());
                    // Don't fail the override creation if email fails
                }
            }
            
            // Apply override immediately if no approval required
            if (!rule.Override_Approval_Required__c) {
                ScreeningOverrideHandler.applyOverride(override1.Id);
            }
            
            // Return result with email status
            return new Map<String, Object>{
                'success' => true,
                'overrideId' => override1.Id,
                'approvalRequired' => rule.Override_Approval_Required__c,
                'emailSent' => emailSent,
                'approverName' => rule.Override_Approver__c != null ? rule.Override_Approver__r.Name : null
            };
            
        } catch (Exception e) {
            System.debug('ERROR in createManualOverride: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error creating override: ' + e.getMessage());
        }
    }
    
    // 🔥 NEW: Send approval email to manager
    private static Boolean sendApprovalEmail(Id overrideId, Screening_Rule__c rule) {
        if (rule.Override_Approver__c == null) {
            System.debug('No approver configured for rule: ' + rule.Name);
            return false;
        }
        
        try {
            // Get override details with candidate info
            Screening_Override__c override1 = [
                SELECT Id, Candidate__r.Name, Screening_Rule__r.Name,
                       Original_Outcome__c, New_Outcome__c, Override_Reason__c,
                       Override_Type__c, Override_By__r.Name, Override_Date__c
                FROM Screening_Override__c
                WHERE Id = :overrideId
                LIMIT 1
            ];
            
            // Get Salesforce base URL
          //  String baseUrl = URL.getSalesforceBaseUrl().toExternalForm();
          String baseUrl = URL.getOrgDomainUrl().toExternalForm();
          String overrideUrl = baseUrl + '/' + override1.Id;

            
            // Create email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Set recipient
            email.setTargetObjectId(rule.Override_Approver__c);
            email.setSaveAsActivity(false);
            
            // Set subject
            email.setSubject('Approval Required: Screening Override for ' + override1.Candidate__r.Name);
            
            // Create HTML body
            String htmlBody = '<html><body style="font-family: Arial, sans-serif;">';
            htmlBody += '<h2 style="color: #0176d3;">Screening Override Approval Request</h2>';
            htmlBody += '<p>A manual override has been requested for a candidate screening result and requires your approval.</p>';
            
            htmlBody += '<table border="1" cellpadding="10" style="border-collapse: collapse; margin: 20px 0; width: 100%; max-width: 600px;">';
            htmlBody += '<tr><td style="background-color: #f3f4f6;"><strong>Candidate Name:</strong></td><td>' + override1.Candidate__r.Name + '</td></tr>';
            htmlBody += '<tr><td style="background-color: #f3f4f6;"><strong>Rule Name:</strong></td><td>' + override1.Screening_Rule__r.Name + '</td></tr>';
            htmlBody += '<tr><td style="background-color: #f3f4f6;"><strong>Original Outcome:</strong></td><td><span style="padding: 4px 8px; border-radius: 3px; background-color: #fee2e2; color: #991b1b;">' + override1.Original_Outcome__c + '</span></td></tr>';
            htmlBody += '<tr><td style="background-color: #f3f4f6;"><strong>New Outcome:</strong></td><td><span style="padding: 4px 8px; border-radius: 3px; background-color: #d1fae5; color: #065f46;">' + override1.New_Outcome__c + '</span></td></tr>';
            htmlBody += '<tr><td style="background-color: #f3f4f6;"><strong>Override Type:</strong></td><td>' + override1.Override_Type__c + '</td></tr>';
            htmlBody += '<tr><td style="background-color: #f3f4f6;"><strong>Reason:</strong></td><td>' + override1.Override_Reason__c + '</td></tr>';
            htmlBody += '<tr><td style="background-color: #f3f4f6;"><strong>Requested By:</strong></td><td>' + override1.Override_By__r.Name + '</td></tr>';
            htmlBody += '<tr><td style="background-color: #f3f4f6;"><strong>Request Date:</strong></td><td>' + override1.Override_Date__c.format() + '</td></tr>';
            htmlBody += '</table>';
            
            htmlBody += '<p><strong style="color: #d97706;">Action Required:</strong> Please review and approve or reject this override request.</p>';
            
            htmlBody += '<p style="margin: 20px 0;">';
            htmlBody += '<a href="' + overrideUrl + '" style="background-color: #0176d3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">Review Override Request</a>';
            htmlBody += '</p>';
            
            htmlBody += '<hr style="margin: 30px 0; border: none; border-top: 1px solid #e5e7eb;">';
            htmlBody += '<p style="color: #6b7280; font-size: 12px;">This is an automated notification from the Candidate Screening System. To approve or reject this override, click the link above or navigate to the record in Salesforce.</p>';
            htmlBody += '</body></html>';
            
            email.setHtmlBody(htmlBody);
            
            // Send email
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            
            if (results[0].isSuccess()) {
                System.debug('✅ Approval email sent successfully to: ' + rule.Override_Approver__r.Email);
                return true;
            } else {
                System.debug('❌ Email send failed: ' + results[0].getErrors()[0].getMessage());
                return false;
            }
            
        } catch (Exception e) {
            System.debug('ERROR sending approval email: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return false;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<OverrideWrapper> getOverridesForCandidate(Id candidateId) {
        List<OverrideWrapper> wrappers = new List<OverrideWrapper>();
        
        List<Screening_Override__c> overrides = [
            SELECT Id, Screening_Rule__r.Name, Original_Outcome__c, New_Outcome__c,
                   Override_Reason__c, Override_Type__c, Approval_Status__c,
                   Override_By__r.Name, Override_Date__c
            FROM Screening_Override__c
            WHERE Candidate__c = :candidateId
            ORDER BY Override_Date__c DESC
        ];
        
        for (Screening_Override__c ov : overrides) {
            wrappers.add(new OverrideWrapper(ov));
        }
        
        return wrappers;
    }
    
    // ==================== OBJECT/FIELD METADATA ====================
    
    @AuraEnabled(cacheable=true)
    public static List<LabelValueOption> getAvailableObjects() {
        List<LabelValueOption> availableObjects = new List<LabelValueOption>();
        
        Map<String, String> objectMap = new Map<String, String>{
            'Candidate__c' => 'Candidate',
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
        
        for (String objectApiName : objectMap.keySet()) {
            SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
            if (objectType != null && objectType.getDescribe().isAccessible()) {
                availableObjects.add(new LabelValueOption(objectMap.get(objectApiName), objectApiName));
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
            throw new AuraHandledException('Invalid object specified.');
        }
        
        List<LabelValueOption> fieldOptions = new List<LabelValueOption>();
        Map<String, Schema.SObjectField> fieldMap = 
            Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        
        for (Schema.SObjectField field : fieldMap.values()) {
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            if (fieldDescribe.isAccessible() && !fieldDescribe.isCalculated()) {
                fieldOptions.add(new LabelValueOption(fieldDescribe.getLabel(), fieldDescribe.getName()));
            }
        }
        
        fieldOptions.sort();
        return fieldOptions;
    }
    
    // ==================== WRAPPER CLASSES ====================
    
    public class RuleWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Decimal priority;
        @AuraEnabled public String appliedRoleId;
        @AuraEnabled public String appliedRoleName;
        @AuraEnabled public String targetObject;
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String operator;
        @AuraEnabled public String expectedValue;
        @AuraEnabled public String action;
        @AuraEnabled public String failureMessage;
        @AuraEnabled public String ruleKey;
        @AuraEnabled public Decimal version;
        @AuraEnabled public Boolean isCurrentVersion;
        @AuraEnabled public String journeyPath;
        @AuraEnabled public String routeToQueue;
        @AuraEnabled public Decimal escalationLevel;
        @AuraEnabled public Boolean allowManualOverride;
        @AuraEnabled public Boolean isTestRule;
        @AuraEnabled public String groupName;
        @AuraEnabled public String matchType;
        @AuraEnabled public String ruleCategory;
        @AuraEnabled public DateTime lastExecutionDate;
        @AuraEnabled public Decimal executionCount;
        @AuraEnabled public Decimal passRate;
        @AuraEnabled public Boolean overrideReasonRequired;
        @AuraEnabled public Boolean overrideApprovalRequired;
        @AuraEnabled public Boolean autoRoute;
        
        public RuleWrapper(Screening_Rule__c rule) {
            this.Id = rule.Id;
            this.Name = rule.Name;
            this.active = rule.Active__c;
            this.priority = rule.Priority__c;
            this.appliedRoleId = rule.Applied_Role__c;
            this.appliedRoleName = rule.Applied_Role__r != null ? rule.Applied_Role__r.Name : '';
            this.targetObject = rule.Target_Object__c;
            this.fieldApiName = rule.Field_API_Name__c;
            this.operator = rule.Operator__c;
            this.expectedValue = rule.Expected_Value__c;
            this.action = rule.Action__c;
            this.failureMessage = rule.Failure_Message__c;
            this.ruleKey = rule.Rule_Key__c;
            this.version = rule.Version__c;
            this.isCurrentVersion = rule.Is_Current_Version__c;
            this.journeyPath = rule.Journey_Path__c;
            this.routeToQueue = rule.Route_To_Queue__c;
            this.escalationLevel = rule.Escalation_Level__c;
            this.allowManualOverride = rule.Allow_Manual_Override__c;
            this.isTestRule = rule.Is_Test_Rule__c;
            this.groupName = rule.Group_Name__c;
            this.matchType = rule.Match_Type__c;
            this.ruleCategory = rule.Rule_Category__c;
            this.lastExecutionDate = rule.Last_Execution_Date__c;
            this.executionCount = rule.Execution_Count__c;
            this.passRate = rule.Pass_Rate__c;
            this.overrideReasonRequired = rule.Override_Reason_Required__c;
            this.overrideApprovalRequired = rule.Override_Approval_Required__c;
            this.autoRoute = rule.Auto_Route__c;
        }
    }
    
    public class VersionHistoryWrapper {
        @AuraEnabled public Id ruleId;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal version;
        @AuraEnabled public String versionNotes;
        @AuraEnabled public Boolean isCurrent;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String createdBy;
        
        public VersionHistoryWrapper(Screening_Rule__c rule) {
            this.ruleId = rule.Id;
            this.name = rule.Name;
            this.version = rule.Version__c;
            this.versionNotes = rule.Version_Notes__c;
            this.isCurrent = rule.Is_Current_Version__c;
            this.createdDate = rule.CreatedDate;
            this.createdBy = rule.CreatedBy.Name;
        }
    }
    
    public class TestResultWrapper {
        @AuraEnabled public String outcome;
        @AuraEnabled public String details;
        @AuraEnabled public String ruleName;
        @AuraEnabled public String candidateName;
        
        public TestResultWrapper(String outcome, String details, String ruleName, String candidateName) {
            this.outcome = outcome;
            this.details = details;
            this.ruleName = ruleName;
            this.candidateName = candidateName;
        }
    }
    
    public class OverrideWrapper {
        @AuraEnabled public Id overrideId;
        @AuraEnabled public String ruleName;
        @AuraEnabled public String originalOutcome;
        @AuraEnabled public String newOutcome;
        @AuraEnabled public String overrideReason;
        @AuraEnabled public String overrideType;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public String overrideBy;
        @AuraEnabled public DateTime overrideDate;
        
        public OverrideWrapper(Screening_Override__c ov) {
            this.overrideId = ov.Id;
            this.ruleName = ov.Screening_Rule__r.Name;
            this.originalOutcome = ov.Original_Outcome__c;
            this.newOutcome = ov.New_Outcome__c;
            this.overrideReason = ov.Override_Reason__c;
            this.overrideType = ov.Override_Type__c;
            this.approvalStatus = ov.Approval_Status__c;
            this.overrideBy = ov.Override_By__r.Name;
            this.overrideDate = ov.Override_Date__c;
        }
    }
    
    public class LabelValueOption implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public LabelValueOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
        
        public Integer compareTo(Object compareTo) {
            return label.compareTo(((LabelValueOption)compareTo).label);
        }
    }
}