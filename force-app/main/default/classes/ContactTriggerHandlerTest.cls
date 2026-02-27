@IsTest
private class ContactTriggerHandlerTest {
    private static Account createAccount(String name) {
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static Contact createContact(Id accountId, String suffix) {
        Contact c = new Contact(
            FirstName = 'First' + suffix,
            LastName = 'Last' + suffix,
            Email = 'contact.' + suffix + '@example.com',
            Phone = '555000' + suffix,
            AccountId = accountId
        );
        insert c;
        return c;
    }

    @IsTest
    static void testHandleAfterInsert_CreatesCandidateForCandidatesAccount() {
        Account candidatesAccount = createAccount('Candidates');
        Contact contact = createContact(candidatesAccount.Id, '1');

        Test.startTest();
        ContactTriggerHandler.handleAfterInsert(new List<Contact>{ contact });
        Test.stopTest();

        List<Candidate__c> created = [
            SELECT Full_Name__c, Email__c, Phone__c, Contact__c
            FROM Candidate__c
            WHERE Contact__c = :contact.Id
        ];
        System.assertEquals(1, created.size(), 'A Candidate__c should be created');
        System.assertEquals('First1 Last1', created[0].Full_Name__c);
        System.assertEquals('contact.1@example.com', created[0].Email__c);
        System.assertEquals('5550001', created[0].Phone__c);
    }

    @IsTest
    static void testHandleAfterInsert_NoCreateForOtherAccountAndNoDuplicate() {
        Account other = createAccount('Other');
        Contact otherContact = createContact(other.Id, '2');

        Account candidatesAccount = createAccount('Candidates');
        Contact existingContact = createContact(candidatesAccount.Id, '3');

        Integer beforeCount = [
            SELECT Count()
            FROM Candidate__c
            WHERE Contact__c = :existingContact.Id
        ];

        Test.startTest();
        ContactTriggerHandler.handleAfterInsert(new List<Contact>{ otherContact, existingContact });
        Test.stopTest();

        Integer countOther = [SELECT Count() FROM Candidate__c WHERE Contact__c = :otherContact.Id];
        Integer countExisting = [SELECT Count() FROM Candidate__c WHERE Contact__c = :existingContact.Id];
        System.assertEquals(0, countOther, 'Should not create for non-Candidates account');
        System.assertEquals(beforeCount, countExisting, 'Should not create duplicate Candidate__c');
    }
}
