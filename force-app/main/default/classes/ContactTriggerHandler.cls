public without sharing class ContactTriggerHandler {

    public static void handleAfterInsert(List<Contact> newContacts) {

        if (newContacts.isEmpty()) {
            return;
        }

        /* ------------------------------------------------------
           Step 1: Collect Account Ids from new Contacts
        ------------------------------------------------------ */
        Set<Id> accountIds = new Set<Id>();
        for (Contact c : newContacts) {
            if (c.AccountId != null) {
                accountIds.add(c.AccountId);
            }
        }

        if (accountIds.isEmpty()) {
            return;
        }

        /* ------------------------------------------------------
           Step 2: Query Accounts named 'Candidates'
        ------------------------------------------------------ */
        Map<Id, Account> candidateAccounts = new Map<Id, Account>(
            [
                SELECT Id, Name
                FROM Account
                WHERE Id IN :accountIds
                  AND Name = 'Candidates'
            ]
        );

        if (candidateAccounts.isEmpty()) {
            return;
        }

        /* ------------------------------------------------------
           Step 3: Prevent duplicate Candidate__c creation
           (Contact -> Candidate__c already exists)
        ------------------------------------------------------ */
        Set<Id> contactIds = new Set<Id>();
        for (Contact c : newContacts) {
            contactIds.add(c.Id);
        }

        // Check if candidates already exist for these contacts
        Map<Id, Candidate__c> existingCandidatesByContact = new Map<Id, Candidate__c>();
        for (Candidate__c cand : [
            SELECT Id, Contact__c
            FROM Candidate__c
            WHERE Contact__c IN :contactIds
        ]) {
            existingCandidatesByContact.put(cand.Contact__c, cand);
        }

        /* ------------------------------------------------------
           Step 4: Create Candidate__c records
        ------------------------------------------------------ */
        List<Candidate__c> candidatesToInsert = new List<Candidate__c>();

        for (Contact c : newContacts) {

            // Ensure Contact belongs to 'Candidates' Account and doesn't already have a Candidate record
            if (
                c.AccountId != null &&
                candidateAccounts.containsKey(c.AccountId) &&
                !existingCandidatesByContact.containsKey(c.Id)
            ) {
                Candidate__c candidate = new Candidate__c();
                
                // MAPPING UPDATES BASED ON PDF MODEL:
                
                // 1. Name is Auto-Number (CAND-{0000}), so we map to Full_Name__c instead 
                candidate.Full_Name__c = (c.FirstName != null ? c.FirstName + ' ' : '') + c.LastName;
                
                // 2. Map Email to Email__c 
                candidate.Email__c = c.Email;
                
                // 3. Map Phone to Phone__c (New field in model) 
                candidate.Phone__c = c.Phone;
                
                // 4. Link back to Contact (Assumed field based on your original code)
                candidate.Contact__c = c.Id;

                candidatesToInsert.add(candidate);
            }
        }

        if (!candidatesToInsert.isEmpty()) {
            insert candidatesToInsert;
        }
    }
}