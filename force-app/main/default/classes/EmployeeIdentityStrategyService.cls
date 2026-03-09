public with sharing class EmployeeIdentityStrategyService {

    public class StrategyResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id employeeId;
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String identityMode;
    }

    @AuraEnabled
    public static StrategyResult applyIdentityMode(Id employeeId, String identityMode) {
        StrategyResult result = new StrategyResult();
        result.employeeId = employeeId;
        result.identityMode = identityMode;

        if (employeeId == null || String.isBlank(identityMode)) {
            result.success = false;
            result.message = 'employeeId and identityMode are required.';
            return result;
        }

        try {
            Employee__c employee = [
                SELECT Id, Candidate__c, User__c
                FROM Employee__c
                WHERE Id = :employeeId
                LIMIT 1
            ];

            String normalized = normalizeMode(identityMode);
            if (normalized == null) {
                result.success = false;
                result.message = 'Invalid identity mode. Use Experience Only, Internal Only, or Hybrid.';
                return result;
            }

            employee.Identity_Mode__c = normalized;
            employee.Is_External_Login_Only__c = (normalized == 'Experience Only');
            update employee;

            if (employee.Candidate__c != null) {
                Candidate__c cand = new Candidate__c(
                    Id = employee.Candidate__c,
                    Identity_Phase__c = normalized == 'Internal Only'
                        ? 'Employee Internal'
                        : (normalized == 'Hybrid' ? 'Hybrid' : 'Employee External')
                );
                update cand;
                result.candidateId = cand.Id;
            }

            assignPermissionSets(employee.User__c, normalized);

            result.success = true;
            result.message = 'Identity mode applied successfully.';
            return result;
        } catch (Exception ex) {
            result.success = false;
            result.message = 'Failed to apply identity mode: ' + ex.getMessage();
            return result;
        }
    }

    private static String normalizeMode(String mode) {
        String m = mode == null ? '' : mode.trim();
        if (m == 'Experience Only' || m == 'Internal Only' || m == 'Hybrid') {
            return m;
        }
        return null;
    }

    private static void assignPermissionSets(Id userId, String mode) {
        if (userId == null) {
            return;
        }

        Map<String, PermissionSet> psByName = new Map<String, PermissionSet>();
        for (PermissionSet ps : [
            SELECT Id, Name
            FROM PermissionSet
            WHERE Name IN ('Employee_Experience_User', 'Employee_Internal_Operations')
        ]) {
            psByName.put(ps.Name, ps);
        }

        List<PermissionSetAssignment> existing = [
            SELECT Id, PermissionSet.Name
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
            AND PermissionSet.Name IN ('Employee_Experience_User', 'Employee_Internal_Operations')
        ];

        Set<String> assigned = new Set<String>();
        for (PermissionSetAssignment psa : existing) {
            assigned.add(psa.PermissionSet.Name);
        }

        Boolean needsExperience = (mode == 'Experience Only' || mode == 'Hybrid');
        Boolean needsInternal = (mode == 'Internal Only' || mode == 'Hybrid');

        List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
        if (needsExperience && psByName.containsKey('Employee_Experience_User') && !assigned.contains('Employee_Experience_User')) {
            toInsert.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = psByName.get('Employee_Experience_User').Id));
        }
        if (needsInternal && psByName.containsKey('Employee_Internal_Operations') && !assigned.contains('Employee_Internal_Operations')) {
            toInsert.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = psByName.get('Employee_Internal_Operations').Id));
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }
}
