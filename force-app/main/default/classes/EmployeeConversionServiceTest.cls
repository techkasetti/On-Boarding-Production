@IsTest
private class EmployeeConversionServiceTest {

    private static Candidate__c createCandidateWithContact() {
        Account acc = new Account(Name = 'Candidates');
        insert acc;

        Contact c = new Contact(
            LastName = 'Candidate Contact',
            Email = 'candidate.contact@example.com',
            Phone = '9999999999',
            AccountId = acc.Id
        );
        insert c;

        Candidate__c candidate = new Candidate__c(
            Full_Name__c = 'Test Candidate',
            Email__c = 'test.candidate@example.com',
            Phone__c = '8888888888',
            Role__c = 'Nurse',
            Contact__c = c.Id,
            Related_Account__c = acc.Id
        );
        insert candidate;
        return candidate;
    }

    @IsTest
    static void testConvertSingleCreatesEmployeeAndContract() {
        Candidate__c candidate = createCandidateWithContact();
        Job_Posting__c posting = new Job_Posting__c(Name = 'Nurse Posting');
        insert posting;

        Job_Application__c app = new Job_Application__c(
            Candidate__c = candidate.Id,
            Job_Posting__c = posting.Id,
            Status__c = 'Offer Accepted',
            Applied_From__c = 'Experience Cloud'
        );
        insert app;

        Test.startTest();
        EmployeeConversionService.ConversionOutput out = EmployeeConversionService.convertSingle(app.Id);
        Test.stopTest();

        System.assertEquals(true, out.success, out.message);
        System.assertNotEquals(null, out.employeeId);
        System.assertNotEquals(null, out.contractId);

        Employee__c employee = [
            SELECT Candidate__c, Contact__c, Employer_Account__c, Identity_Mode__c, Employment_Status__c
            FROM Employee__c
            WHERE Id = :out.employeeId
        ];
        System.assertEquals(candidate.Id, employee.Candidate__c);
        System.assertEquals('Hybrid', employee.Identity_Mode__c);
        System.assertEquals('Pending Activation', employee.Employment_Status__c);

        Employment_Contract__c contract = [
            SELECT Employee__c, Candidate__c, Job_Application__c, Contract_Status__c
            FROM Employment_Contract__c
            WHERE Id = :out.contractId
        ];
        System.assertEquals(out.employeeId, contract.Employee__c);
        System.assertEquals(candidate.Id, contract.Candidate__c);
        System.assertEquals(app.Id, contract.Job_Application__c);
        System.assertEquals('Active', contract.Contract_Status__c);

        Candidate__c afterCandidate = [
            SELECT Status__c, Employee__c, Identity_Phase__c, Converted_To_Employee_On__c
            FROM Candidate__c
            WHERE Id = :candidate.Id
        ];
        System.assertEquals(out.employeeId, afterCandidate.Employee__c);
        System.assertEquals('Hybrid', afterCandidate.Identity_Phase__c);
        System.assertNotEquals(null, afterCandidate.Converted_To_Employee_On__c);
        System.assertEquals('Offer Accepted - Compliance Pending', afterCandidate.Status__c);
    }

    @IsTest
    static void testInvocableBatchPath() {
        Candidate__c candidate = createCandidateWithContact();
        Job_Posting__c posting = new Job_Posting__c(Name = 'Doctor Posting');
        insert posting;

        Job_Application__c app = new Job_Application__c(
            Candidate__c = candidate.Id,
            Job_Posting__c = posting.Id,
            Status__c = 'Offer Accepted'
        );
        insert app;

        EmployeeConversionService.ConversionInput input = new EmployeeConversionService.ConversionInput();
        input.jobApplicationId = app.Id;

        Test.startTest();
        List<EmployeeConversionService.ConversionOutput> outputs =
            EmployeeConversionService.convertCandidates(new List<EmployeeConversionService.ConversionInput>{ input });
        Test.stopTest();

        System.assertEquals(1, outputs.size());
        System.assertEquals(true, outputs[0].success, outputs[0].message);
    }
}
