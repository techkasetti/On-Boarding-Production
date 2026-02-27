// // =====================================================
// // RULE VERSIONING SERVICE - FIXED VERSION
// // Handles version control and rollback for rules
// // =====================================================

// public class RuleVersioningService {
    
//     /**
//      * Creates a new version of an existing rule
//      * @param existingRuleId - ID of the rule to version
//      * @param versionNotes - Notes about what changed in this version
//      * @return The newly created rule version
//      */
//     public static Screening_Rule__c createNewVersion(Id existingRuleId, String versionNotes) {
//         if (existingRuleId == null) {
//             throw new AuraHandledException('Rule ID is required to create a new version.');
//         }
        
//         try {
//             // Query the existing rule with ALL fields we need to copy
//             Screening_Rule__c existingRule = [
//                 SELECT Id, Name, Version__c, Priority__c, Applied_Role__c,
//                        Target_Object__c, Field_API_Name__c, Operator__c, Expected_Value__c,
//                        Action__c, Failure_Message__c, Journey_Path__c, Route_To_Queue__c,
//                        Escalation_Level__c, Escalation_Owner__c, Allow_Manual_Override__c,
//                        Override_Reason_Required__c, Override_Approval_Required__c,
//                        Override_Approver__c, Group_Name__c, Rule_Category__c, Match_Type__c, 
//                        Condition_Logic__c, Rule_Key__c, Active__c, Is_Current_Version__c,
//                        Auto_Route__c
//                 FROM Screening_Rule__c 
//                 WHERE Id = :existingRuleId 
//                 LIMIT 1
//             ];
            
//             System.debug('Found existing rule: ' + existingRule.Name + ' (Version ' + existingRule.Version__c + ')');
            
//             // Deactivate current version
//             existingRule.Is_Current_Version__c = false;
//             existingRule.Active__c = false;
//             update existingRule;
            
//             System.debug('Deactivated existing version');
            
//             // Create new version by cloning
//             Screening_Rule__c newVersion = existingRule.clone(false, true, false, false);
            
//             // Set version-specific fields
//             Decimal currentVersion = existingRule.Version__c != null ? existingRule.Version__c : 1.0;
//             newVersion.Version__c = currentVersion + 1.0;
//             newVersion.Is_Current_Version__c = true;
//             newVersion.Parent_Rule_Version__c = existingRuleId;
//             newVersion.Version_Notes__c = versionNotes;
//             newVersion.Active__c = true;
            
//             // Reset execution statistics for new version
//             newVersion.Last_Execution_Date__c = null;
//             newVersion.Execution_Count__c = 0;
//             newVersion.Pass_Rate__c = null;
//             newVersion.Fail_Rate__c = null;
//             newVersion.Last_Tested_Date__c = null;
//             newVersion.Test_Pass_Count__c = 0;
//             newVersion.Test_Fail_Count__c = 0;
            
//             insert newVersion;
            
//             System.debug('Created new version: ' + newVersion.Id + ' (Version ' + newVersion.Version__c + ')');
            
//             return newVersion;
            
//         } catch (QueryException qe) {
//             System.debug('QueryException: ' + qe.getMessage());
//             throw new AuraHandledException('Rule not found: ' + qe.getMessage());
//         } catch (DmlException de) {
//             System.debug('DmlException: ' + de.getMessage());
//             throw new AuraHandledException('Failed to create new version: ' + de.getMessage());
//         } catch (Exception e) {
//             System.debug('Exception: ' + e.getMessage());
//             System.debug('Stack Trace: ' + e.getStackTraceString());
//             throw new AuraHandledException('Error creating new version: ' + e.getMessage());
//         }
//     }
    
//     /**
//      * Rolls back to a specific version of a rule
//      * @param targetVersionId - ID of the version to rollback to
//      */
//     public static void rollbackToVersion(Id targetVersionId) {
//         if (targetVersionId == null) {
//             throw new AuraHandledException('Version ID is required for rollback.');
//         }
        
//         try {
//             // Get the target version
//             Screening_Rule__c targetVersion = [
//                 SELECT Id, Name, Parent_Rule_Version__c, Rule_Key__c, Version__c
//                 FROM Screening_Rule__c 
//                 WHERE Id = :targetVersionId
//                 LIMIT 1
//             ];
            
//             System.debug('Rolling back to version: ' + targetVersion.Name + ' (Version ' + targetVersion.Version__c + ')');
            
//             // Find all versions with the same Rule_Key
//             List<Screening_Rule__c> allVersions = [
//                 SELECT Id, Is_Current_Version__c, Active__c, Version__c, Name
//                 FROM Screening_Rule__c 
//                 WHERE Rule_Key__c = :targetVersion.Rule_Key__c
//             ];
            
//             System.debug('Found ' + allVersions.size() + ' total versions');
            
//             // Deactivate all versions first
//             for (Screening_Rule__c ver : allVersions) {
//                 ver.Is_Current_Version__c = false;
//                 ver.Active__c = false;
//             }
//             update allVersions;
            
//             System.debug('Deactivated all versions');
            
//             // Activate only the target version
//             targetVersion.Is_Current_Version__c = true;
//             targetVersion.Active__c = true;
//             update targetVersion;
            
//             System.debug('Activated target version');
            
//         } catch (QueryException qe) {
//             System.debug('QueryException: ' + qe.getMessage());
//             throw new AuraHandledException('Version not found: ' + qe.getMessage());
//         } catch (DmlException de) {
//             System.debug('DmlException: ' + de.getMessage());
//             throw new AuraHandledException('Failed to rollback: ' + de.getMessage());
//         } catch (Exception e) {
//             System.debug('Exception: ' + e.getMessage());
//             System.debug('Stack Trace: ' + e.getStackTraceString());
//             throw new AuraHandledException('Error during rollback: ' + e.getMessage());
//         }
//     }
    
//     /**
//      * Gets the version history for a rule
//      * @param ruleId - ID of any version of the rule
//      * @return List of all versions ordered by version number descending
//      */
//     public static List<Screening_Rule__c> getVersionHistory(Id ruleId) {
//         if (ruleId == null) {
//             throw new AuraHandledException('Rule ID is required to get version history.');
//         }
        
//         try {
//             // Get the rule to find its Rule_Key
//             Screening_Rule__c rule = [
//                 SELECT Id, Parent_Rule_Version__c, Rule_Key__c, Name 
//                 FROM Screening_Rule__c 
//                 WHERE Id = :ruleId 
//                 LIMIT 1
//             ];
            
//             System.debug('Getting version history for: ' + rule.Name + ' (Key: ' + rule.Rule_Key__c + ')');
            
//             // If Rule_Key is blank, this rule doesn't have versions
//             if (String.isBlank(rule.Rule_Key__c)) {
//                 System.debug('WARNING: Rule has no Rule_Key, returning single version');
                
//                 // Generate Rule_Key and update the rule
//                 String generatedKey = rule.Name.replaceAll('[^a-zA-Z0-9]', '_').toUpperCase();
//                 rule.Rule_Key__c = generatedKey;
//                 update rule;
                
//                 // Return just this rule
//                 return [
//                     SELECT Id, Name, Version__c, Version_Notes__c, Is_Current_Version__c,
//                            Active__c, CreatedDate, CreatedBy.Name, LastModifiedDate
//                     FROM Screening_Rule__c 
//                     WHERE Id = :ruleId
//                 ];
//             }
            
//             // Get all versions with the same Rule_Key
//             List<Screening_Rule__c> versions = [
//                 SELECT Id, Name, Version__c, Version_Notes__c, Is_Current_Version__c,
//                        Active__c, CreatedDate, CreatedBy.Name, LastModifiedDate
//                 FROM Screening_Rule__c 
//                 WHERE Rule_Key__c = :rule.Rule_Key__c 
//                 ORDER BY Version__c DESC
//             ];
            
//             System.debug('Found ' + versions.size() + ' versions');
            
//             return versions;
            
//         } catch (QueryException qe) {
//             System.debug('QueryException: ' + qe.getMessage());
//             throw new AuraHandledException('Rule not found: ' + qe.getMessage());
//         } catch (Exception e) {
//             System.debug('Exception: ' + e.getMessage());
//             System.debug('Stack Trace: ' + e.getStackTraceString());
//             throw new AuraHandledException('Error retrieving version history: ' + e.getMessage());
//         }
//     }
// }
// =====================================================
// RULE VERSIONING SERVICE - COMPLETELY FIXED VERSION
// Handles version control and rollback for rules
// =====================================================
// =====================================================
// RULE VERSIONING SERVICE - COMPLETELY FIXED VERSION
// Handles version control and rollback for rules
// =====================================================

public class RuleVersioningService {
    
    /**
     * Creates a new version of an existing rule
     * @param existingRuleId - ID of the rule to version
     * @param versionNotes - Notes about what changed in this version
     * @return The newly created rule version
     */
    public static Screening_Rule__c createNewVersion(Id existingRuleId, String versionNotes) {
        if (existingRuleId == null) {
            throw new AuraHandledException('Rule ID is required to create a new version.');
        }
        
        try {
            // Query the existing rule with ALL fields we need to copy
            Screening_Rule__c existingRule = [
                SELECT Id, Name, Version__c, Priority__c, Applied_Role__c,
                       Target_Object__c, Field_API_Name__c, Operator__c, Expected_Value__c,
                       Action__c, Failure_Message__c, Journey_Path__c, Route_To_Queue__c,
                       Escalation_Level__c, Escalation_Owner__c, Allow_Manual_Override__c,
                       Override_Reason_Required__c, Override_Approval_Required__c,
                       Override_Approver__c, Group_Name__c, Rule_Category__c, Match_Type__c, 
                       Condition_Logic__c, Rule_Key__c, Active__c, Is_Current_Version__c,
                       Auto_Route__c
                FROM Screening_Rule__c 
                WHERE Id = :existingRuleId 
                LIMIT 1
            ];
            
            System.debug('Found existing rule: ' + existingRule.Name + ' (Version ' + existingRule.Version__c + ')');
            
            // CRITICAL FIX: Find the base Rule_Key
            String baseRuleKey = existingRule.Rule_Key__c;
            if (String.isBlank(baseRuleKey)) {
                baseRuleKey = existingRule.Name.replaceAll('[^a-zA-Z0-9]', '_').toUpperCase();
                existingRule.Rule_Key__c = baseRuleKey;
            }
            
            // Deactivate ALL versions with this Rule_Key first
            List<Screening_Rule__c> allVersions = [
                SELECT Id, Is_Current_Version__c, Active__c
                FROM Screening_Rule__c 
                WHERE Rule_Key__c = :baseRuleKey
            ];
            
            for (Screening_Rule__c ver : allVersions) {
                ver.Is_Current_Version__c = false;
                ver.Active__c = false;
            }
            update allVersions;
            
            System.debug('Deactivated ' + allVersions.size() + ' existing versions');
            
            // Create new version by cloning
            Screening_Rule__c newVersion = existingRule.clone(false, true, false, false);
            
            // Set version-specific fields
            Decimal currentVersion = existingRule.Version__c != null ? existingRule.Version__c : 1.0;
            newVersion.Version__c = currentVersion + 1.0;
            newVersion.Is_Current_Version__c = true;
            newVersion.Parent_Rule_Version__c = existingRuleId;
            newVersion.Version_Notes__c = versionNotes;
            newVersion.Active__c = true;
            newVersion.Rule_Key__c = baseRuleKey; // CRITICAL: Use same Rule_Key
            
            // Reset execution statistics for new version
            newVersion.Last_Execution_Date__c = null;
            newVersion.Execution_Count__c = 0;
            newVersion.Pass_Rate__c = null;
            newVersion.Fail_Rate__c = null;
            newVersion.Last_Tested_Date__c = null;
            newVersion.Test_Pass_Count__c = 0;
            newVersion.Test_Fail_Count__c = 0;
            
            insert newVersion;
            
            System.debug('Created new version: ' + newVersion.Id + ' (Version ' + newVersion.Version__c + ')');
            
            return newVersion;
            
        } catch (QueryException qe) {
            System.debug('QueryException: ' + qe.getMessage());
            throw new AuraHandledException('Rule not found: ' + qe.getMessage());
        } catch (DmlException de) {
            System.debug('DmlException: ' + de.getMessage());
            throw new AuraHandledException('Failed to create new version: ' + de.getMessage());
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error creating new version: ' + e.getMessage());
        }
    }
    
    /**
     * Rolls back to a specific version of a rule
     * @param targetVersionId - ID of the version to rollback to
     */
    public static void rollbackToVersion(Id targetVersionId) {
        if (targetVersionId == null) {
            throw new AuraHandledException('Version ID is required for rollback.');
        }
        
        try {
            // Get the target version
            Screening_Rule__c targetVersion = [
                SELECT Id, Name, Rule_Key__c, Version__c
                FROM Screening_Rule__c 
                WHERE Id = :targetVersionId
                LIMIT 1
            ];
            
            System.debug('Rolling back to version: ' + targetVersion.Name + ' (Version ' + targetVersion.Version__c + ')');
            
            // CRITICAL FIX: Find ALL versions with the same Rule_Key
            String baseRuleKey = targetVersion.Rule_Key__c;
            if (String.isBlank(baseRuleKey)) {
                throw new AuraHandledException('Cannot rollback: Rule has no Rule_Key');
            }
            
            List<Screening_Rule__c> allVersions = [
                SELECT Id, Is_Current_Version__c, Active__c, Version__c, Name
                FROM Screening_Rule__c 
                WHERE Rule_Key__c = :baseRuleKey
            ];
            
            System.debug('Found ' + allVersions.size() + ' total versions for rollback');
            
            // Deactivate ALL versions first
            for (Screening_Rule__c ver : allVersions) {
                ver.Is_Current_Version__c = false;
                ver.Active__c = false;
            }
            update allVersions;
            
            System.debug('Deactivated all versions');
            
            // Activate ONLY the target version
            Screening_Rule__c versionToActivate = new Screening_Rule__c(
                Id = targetVersionId,
                Is_Current_Version__c = true,
                Active__c = true
            );
            update versionToActivate;
            
            System.debug('Activated target version: ' + targetVersionId);
            
        } catch (QueryException qe) {
            System.debug('QueryException: ' + qe.getMessage());
            throw new AuraHandledException('Version not found: ' + qe.getMessage());
        } catch (DmlException de) {
            System.debug('DmlException: ' + de.getMessage());
            throw new AuraHandledException('Failed to rollback: ' + de.getMessage());
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error during rollback: ' + e.getMessage());
        }
    }
    
    /**
     * Gets the version history for a rule
     * @param ruleId - ID of any version of the rule
     * @return List of all versions ordered by version number descending
     */
    public static List<Screening_Rule__c> getVersionHistory(Id ruleId) {
        if (ruleId == null) {
            throw new AuraHandledException('Rule ID is required to get version history.');
        }
        
        try {
            // Get the rule to find its Rule_Key
            Screening_Rule__c rule = [
                SELECT Id, Rule_Key__c, Name 
                FROM Screening_Rule__c 
                WHERE Id = :ruleId 
                LIMIT 1
            ];
            
            System.debug('Getting version history for: ' + rule.Name + ' (Key: ' + rule.Rule_Key__c + ')');
            
            // If Rule_Key is blank, generate one and update
            String baseRuleKey = rule.Rule_Key__c;
            if (String.isBlank(baseRuleKey)) {
                System.debug('WARNING: Rule has no Rule_Key, generating one');
                baseRuleKey = rule.Name.replaceAll('[^a-zA-Z0-9]', '_').toUpperCase();
                rule.Rule_Key__c = baseRuleKey;
                update rule;
            }
            
            // Get ALL versions with the same Rule_Key
            List<Screening_Rule__c> versions = [
                SELECT Id, Name, Version__c, Version_Notes__c, Is_Current_Version__c,
                       Active__c, CreatedDate, CreatedBy.Name, LastModifiedDate, Rule_Key__c
                FROM Screening_Rule__c 
                WHERE Rule_Key__c = :baseRuleKey
                ORDER BY Version__c DESC
            ];
            
            System.debug('Found ' + versions.size() + ' versions with Rule_Key: ' + baseRuleKey);
            
            return versions;
            
        } catch (QueryException qe) {
            System.debug('QueryException: ' + qe.getMessage());
            throw new AuraHandledException('Rule not found: ' + qe.getMessage());
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error retrieving version history: ' + e.getMessage());
        }
    }
    
    /**
     * UTILITY: Ensures all rules have a Rule_Key for versioning
     * Call this once to fix existing rules
     */
    public static void backfillRuleKeys() {
        List<Screening_Rule__c> rulesWithoutKey = [
            SELECT Id, Name, Rule_Key__c
            FROM Screening_Rule__c
            WHERE Rule_Key__c = null
        ];
        
        for (Screening_Rule__c rule : rulesWithoutKey) {
            rule.Rule_Key__c = rule.Name.replaceAll('[^a-zA-Z0-9]', '_').toUpperCase();
        }
        
        if (!rulesWithoutKey.isEmpty()) {
            update rulesWithoutKey;
            System.debug('Backfilled Rule_Key for ' + rulesWithoutKey.size() + ' rules');
        }
    }
}