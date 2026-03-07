String key = String.valueOf(Datetime.now().getTime());

Account acc = new Account(Name='Candidates E2E ' + key);
insert acc;

Contact con = new Contact(
    LastName='E2E ' + key,
    Email='e2e.' + key + '@example.com',
    Phone='9000000000',
    AccountId=acc.Id
);
insert con;

Candidate__c cand = new Candidate__c(
    Full_Name__c='E2E Candidate ' + key,
    Email__c='candidate.' + key + '@example.com',
    Phone__c='9111111111',
    Role__c='Nurse',
    Contact__c=con.Id,
    Related_Account__c=acc.Id
);
insert cand;

Job_Posting__c jp = new Job_Posting__c(Name='E2E Posting ' + key);
insert jp;

Job_Application__c app = new Job_Application__c(
    Candidate__c=cand.Id,
    Job_Posting__c=jp.Id,
    Status__c='Application Received',
    Applied_From__c='Experience Cloud'
);
insert app;

// Trigger record-triggered flow.
app.Status__c = 'Offer Accepted';
update app;

List<Employee__c> emps = [
    SELECT Id, Name, Candidate__c, Contact__c, Employer_Account__c, Work_Email__c, Work_Phone__c, Employment_Status__c
    FROM Employee__c
    WHERE Candidate__c = :cand.Id
];
List<Employment_Contract__c> ctrs = [
    SELECT Id, Employee__c, Candidate__c, Job_Application__c, Contract_Status__c
    FROM Employment_Contract__c
    WHERE Job_Application__c = :app.Id
];
Candidate__c candAfter = [
    SELECT Id, Employee__c, Identity_Phase__c, Converted_To_Employee_On__c, Status__c
    FROM Candidate__c
    WHERE Id = :cand.Id
];

System.debug(
    'E2E_RESULT:: employees=' + emps.size() +
    ', contracts=' + ctrs.size() +
    ', candidateEmployee=' + candAfter.Employee__c +
    ', identityPhase=' + candAfter.Identity_Phase__c +
    ', candStatus=' + candAfter.Status__c
);
if (!emps.isEmpty()) {
    System.debug('E2E_EMP:: ' + JSON.serialize(emps[0]));
}
if (!ctrs.isEmpty()) {
    System.debug('E2E_CONTRACT:: ' + JSON.serialize(ctrs[0]));
}

// Re-trigger check: should not create duplicate employee/contract.
app.Status__c = 'Offer Released';
update app;
app.Status__c = 'Offer Accepted';
update app;

Integer empCountAfterRerun = [
    SELECT Count()
    FROM Employee__c
    WHERE Candidate__c = :cand.Id
];
Integer contractCountAfterRerun = [
    SELECT Count()
    FROM Employment_Contract__c
    WHERE Job_Application__c = :app.Id
];
System.debug(
    'E2E_IDEMPOTENCY:: employeeCountAfterRerun=' + empCountAfterRerun +
    ', contractCountAfterRerun=' + contractCountAfterRerun
);
