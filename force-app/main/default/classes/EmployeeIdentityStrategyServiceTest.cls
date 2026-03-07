@IsTest
private class EmployeeIdentityStrategyServiceTest {

    @IsTest
    static void testApplyIdentityModeWithoutUser() {
        Candidate__c candidate = new Candidate__c(
            Full_Name__c = 'Identity Candidate',
            Email__c = 'identity@example.com'
        );
        insert candidate;

        Employee__c employee = new Employee__c(
            Candidate__c = candidate.Id,
            Identity_Mode__c = 'Experience Only',
            Employment_Status__c = 'Pending Activation'
        );
        insert employee;

        Test.startTest();
        EmployeeIdentityStrategyService.StrategyResult result =
            EmployeeIdentityStrategyService.applyIdentityMode(employee.Id, 'Internal Only');
        Test.stopTest();

        System.assertEquals(true, result.success, result.message);

        Employee__c updatedEmployee = [
            SELECT Identity_Mode__c, Is_External_Login_Only__c
            FROM Employee__c
            WHERE Id = :employee.Id
        ];
        System.assertEquals('Internal Only', updatedEmployee.Identity_Mode__c);
        System.assertEquals(false, updatedEmployee.Is_External_Login_Only__c);

        Candidate__c updatedCandidate = [
            SELECT Identity_Phase__c
            FROM Candidate__c
            WHERE Id = :candidate.Id
        ];
        System.assertEquals('Employee Internal', updatedCandidate.Identity_Phase__c);
    }
}
