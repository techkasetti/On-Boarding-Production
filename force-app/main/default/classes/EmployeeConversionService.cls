public with sharing class EmployeeConversionService {

    public class ConversionInput {
        @InvocableVariable(required=true label='Job Application Id')
        public Id jobApplicationId;
    }

    public class ConversionOutput {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
        @InvocableVariable public Id candidateId;
        @InvocableVariable public Id employeeId;
        @InvocableVariable public Id contractId;
    }

    @InvocableMethod(
        label='Convert Candidate To Employee'
        description='Converts an Offer Accepted job application candidate into Employee and Employment Contract records.'
        category='Workforce'
    )
    public static List<ConversionOutput> convertCandidates(List<ConversionInput> inputs) {
        List<ConversionOutput> outputs = new List<ConversionOutput>();
        if (inputs == null || inputs.isEmpty()) {
            return outputs;
        }

        for (ConversionInput input : inputs) {
            outputs.add(convertSingle(input == null ? null : input.jobApplicationId));
        }
        return outputs;
    }

    @AuraEnabled
    public static ConversionOutput convertSingle(Id jobApplicationId) {
        ConversionOutput out = new ConversionOutput();

        if (jobApplicationId == null) {
            out.success = false;
            out.message = 'jobApplicationId is required';
            logAudit(null, null, null, null, 'Conversion', 'Failed', out.message, 'MISSING_JOB_APPLICATION');
            return out;
        }

        try {
            Job_Application__c app = [
                SELECT Id, Candidate__c, Status__c, Application_Date__c, Applied_From__c
                FROM Job_Application__c
                WHERE Id = :jobApplicationId
                LIMIT 1
            ];

            if (app.Candidate__c == null) {
                out.success = false;
                out.message = 'Candidate is missing on job application.';
                logAudit(null, null, null, app.Id, 'Conversion', 'Failed', out.message, 'MISSING_CANDIDATE');
                return out;
            }

            Candidate__c candidate = [
                SELECT Id, Full_Name__c, Email__c, Phone__c, Role__c, Contact__c, User__c, Related_Account__c, Status__c
                FROM Candidate__c
                WHERE Id = :app.Candidate__c
                LIMIT 1
            ];

            Contact linkedContact;
            if (candidate.Contact__c != null) {
                List<Contact> contacts = [
                    SELECT Id, AccountId, Email, Phone
                    FROM Contact
                    WHERE Id = :candidate.Contact__c
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    linkedContact = contacts[0];
                }
            }

            Id employerAccountId = candidate.Related_Account__c;
            if (employerAccountId == null && linkedContact != null) {
                employerAccountId = linkedContact.AccountId;
            }

            Employee__c employee = upsertEmployee(candidate, app, employerAccountId, linkedContact);
            Employment_Contract__c contract = upsertEmploymentContract(candidate, app, employee, employerAccountId);

            String targetPhase = employee.Identity_Mode__c == 'Internal Only'
                ? 'Employee Internal'
                : (employee.Identity_Mode__c == 'Hybrid' ? 'Hybrid' : 'Employee External');
            updateCandidatePostConversion(candidate, employee.Id, targetPhase);

            out.success = true;
            out.message = 'Candidate converted to employee successfully.';
            out.candidateId = candidate.Id;
            out.employeeId = employee.Id;
            out.contractId = contract.Id;
            logAudit(candidate.Id, employee.Id, contract.Id, app.Id, 'Conversion', 'Success', out.message, null);
            return out;
        } catch (Exception ex) {
            out.success = false;
            out.message = 'Conversion failed: ' + ex.getMessage();
            logAudit(null, null, null, jobApplicationId, 'Conversion', 'Failed', out.message, ex.getTypeName());
            return out;
        }
    }

    private static Employee__c upsertEmployee(
        Candidate__c candidate,
        Job_Application__c app,
        Id employerAccountId,
        Contact linkedContact
    ) {
        List<Employee__c> existing = [
            SELECT Id, Identity_Mode__c
            FROM Employee__c
            WHERE Candidate__c = :candidate.Id
            LIMIT 1
        ];

        Employee__c employee = existing.isEmpty() ? new Employee__c() : existing[0];
        employee.Candidate__c = candidate.Id;
        employee.Contact__c = candidate.Contact__c;
        employee.User__c = candidate.User__c;
        employee.Employer_Account__c = employerAccountId;
        employee.Source_Job_Application__c = app.Id;
        employee.Work_Email__c = String.isBlank(candidate.Email__c)
            ? (linkedContact == null ? null : linkedContact.Email)
            : candidate.Email__c;
        employee.Work_Phone__c = String.isBlank(candidate.Phone__c)
            ? (linkedContact == null ? null : linkedContact.Phone)
            : candidate.Phone__c;
        employee.Role__c = candidate.Role__c;
        employee.Join_Date__c = Date.today();
        employee.Employment_Status__c = 'Pending Activation';
        employee.Is_External_Login_Only__c = true;
        if (String.isBlank(employee.Identity_Mode__c)) {
            employee.Identity_Mode__c = 'Hybrid';
        }
        employee.Identity_Key__c = buildIdentityKey(candidate, linkedContact);
        employee.Candidate_Converted_On__c = System.now();

        if (existing.isEmpty()) {
            insert employee;
        } else {
            update employee;
        }

        return employee;
    }

    private static Employment_Contract__c upsertEmploymentContract(
        Candidate__c candidate,
        Job_Application__c app,
        Employee__c employee,
        Id employerAccountId
    ) {
        List<Employment_Contract__c> existing = [
            SELECT Id
            FROM Employment_Contract__c
            WHERE Job_Application__c = :app.Id
            LIMIT 1
        ];

        Employment_Contract__c contract = existing.isEmpty() ? new Employment_Contract__c() : existing[0];
        contract.Employee__c = employee.Id;
        contract.Candidate__c = candidate.Id;
        contract.Job_Application__c = app.Id;
        contract.Employer_Account__c = employerAccountId;
        contract.Contract_Type__c = 'Contract';
        contract.Contract_Status__c = 'Active';
        contract.Effective_Start_Date__c = Date.today();
        contract.Offer_Accepted_On__c = Date.today();
        contract.Offered_On__c = app.Application_Date__c;
        contract.Source_Channel__c = String.isBlank(app.Applied_From__c) ? 'Experience Cloud' : app.Applied_From__c;
        contract.Identity_Strategy__c = 'Reuse Existing Experience User';

        if (existing.isEmpty()) {
            insert contract;
        } else {
            update contract;
        }

        return contract;
    }

    private static String buildIdentityKey(Candidate__c candidate, Contact linkedContact) {
        if (candidate.User__c != null) {
            return 'USR:' + candidate.User__c;
        }
        if (candidate.Contact__c != null) {
            return 'CON:' + candidate.Contact__c;
        }
        if (linkedContact != null) {
            return 'CON:' + linkedContact.Id;
        }
        return 'CAN:' + candidate.Id;
    }

    private static void updateCandidatePostConversion(Candidate__c candidate, Id employeeId, String identityPhase) {
        Candidate__c candidateUpdate = new Candidate__c(
            Id = candidate.Id,
            Employee__c = employeeId,
            Identity_Phase__c = identityPhase,
            Converted_To_Employee_On__c = System.now()
        );

        if (candidate.Status__c != 'Hired') {
            // Keep candidate in compliance-pending state until HIPAA completion flow promotes to Hired.
            candidateUpdate.Status__c = 'Offer Accepted - Compliance Pending';
        }

        try {
            update candidateUpdate;
        } catch (DmlException ex) {
            // Retain conversion link even if status transition is blocked by org-specific validations.
            candidateUpdate.Status__c = null;
            update candidateUpdate;
        }
    }

    private static void logAudit(
        Id candidateId,
        Id employeeId,
        Id contractId,
        Id jobApplicationId,
        String stage,
        String status,
        String message,
        String errorCode
    ) {
        try {
            Employee_Conversion_Audit__c audit = new Employee_Conversion_Audit__c();
            audit.Candidate__c = candidateId;
            audit.Employee__c = employeeId;
            audit.Employment_Contract__c = contractId;
            audit.Job_Application__c = jobApplicationId;
            audit.Stage__c = stage;
            audit.Status__c = status;
            audit.Message__c = message;
            audit.Error_Code__c = errorCode;
            audit.Occurred_At__c = System.now();
            audit.Source__c = 'EmployeeConversionService';
            audit.Actor__c = UserInfo.getUserId();
            insert audit;
        } catch (Exception ex) {
            // Never block conversion because audit logging failed.
        }
    }
}
