@IsTest
private class CandidateIntakeControllerTest {
    @IsTest
    static void testRegisterCandidate_MultiPartName() {
        Test.startTest();
        Id candidateId = CandidateIntakeController.registerCandidate(
            'John A Doe',
            '5551234567',
            'john.doe@example.com'
        );
        Test.stopTest();

        Candidate__c candidate = [
            SELECT FirstName__c, LastName__c, Email__c, Phone__c, Status__c
            FROM Candidate__c
            WHERE Id = :candidateId
        ];

        System.assertEquals('John', candidate.FirstName__c);
        System.assertEquals('A Doe', candidate.LastName__c);
        System.assertEquals('john.doe@example.com', candidate.Email__c);
        System.assertEquals('5551234567', candidate.Phone__c);
        System.assertEquals('NEW', String.valueOf(candidate.Status__c).toUpperCase());
    }

    @IsTest
    static void testRegisterCandidate_SingleName() {
        Test.startTest();
        Id candidateId = CandidateIntakeController.registerCandidate(
            'Prince',
            null,
            'prince@example.com'
        );
        Test.stopTest();

        Candidate__c candidate = [
            SELECT FirstName__c, LastName__c
            FROM Candidate__c
            WHERE Id = :candidateId
        ];

        System.assertEquals('Prince', candidate.FirstName__c);
        System.assertEquals(null, candidate.LastName__c);
    }

    @IsTest
    static void testRegisterCandidate_DmlFailureHandled() {
        String hugeName = '';
        for (Integer i = 0; i < 500; i++) {
            hugeName += 'X';
        }
        Boolean thrown = false;
        try {
            Test.startTest();
            CandidateIntakeController.registerCandidate(
                hugeName,
                '999',
                'error.path@example.com'
            );
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException for invalid first name length');
        } catch (Exception ex) {
            thrown = true;
            System.assert(!String.isBlank(ex.getMessage()), 'Expected handled exception message');
        }
        System.assertEquals(true, thrown, 'Expected handled exception to be thrown');
    }
}
