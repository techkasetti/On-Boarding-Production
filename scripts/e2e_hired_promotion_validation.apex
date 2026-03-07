String key = String.valueOf(Datetime.now().getTime());

Account acc = new Account(Name='Candidates HIPAA E2E ' + key);
insert acc;

Contact con = new Contact(
    LastName='HIPAA E2E ' + key,
    Email='hipaa.' + key + '@example.com',
    Phone='9000000001',
    AccountId=acc.Id
);
insert con;

Candidate__c cand = new Candidate__c(
    Full_Name__c='HIPAA Candidate ' + key,
    Email__c='candidate.hipaa.' + key + '@example.com',
    Phone__c='9222222222',
    Role__c='Nurse',
    Contact__c=con.Id,
    Related_Account__c=acc.Id
);
insert cand;

Job_Posting__c jp = new Job_Posting__c(Name='HIPAA Posting ' + key);
insert jp;

Job_Application__c app = new Job_Application__c(
    Candidate__c=cand.Id,
    Job_Posting__c=jp.Id,
    Status__c='Application Received',
    Applied_From__c='Experience Cloud'
);
insert app;

app.Status__c = 'Offer Accepted';
update app;

Candidate__c afterConversion = [
    SELECT Id, Status__c, Employee__c, Identity_Phase__c
    FROM Candidate__c
    WHERE Id = :cand.Id
];

HIPAACompliance__c hip = new HIPAACompliance__c(
    Candidate__c = cand.Id,
    Status__c = 'Not Started'
);
insert hip;

hip.Status__c = 'Completed';
hip.HIPAA_Training_Completed_Date__c = Date.today();
hip.Acknowledgment_Signed_Date__c = Date.today();
update hip;

Candidate__c afterHipaaComplete = [
    SELECT Id, Status__c, Employee__c, Identity_Phase__c
    FROM Candidate__c
    WHERE Id = :cand.Id
];

System.debug(
    'E2E_HIRED_PROMOTION:: afterConversionStatus=' + afterConversion.Status__c +
    ', afterConversionEmployee=' + afterConversion.Employee__c +
    ', afterConversionIdentity=' + afterConversion.Identity_Phase__c +
    ', afterHipaaStatus=' + afterHipaaComplete.Status__c
);
