public with sharing class CandidateIntakeController {
    @AuraEnabled
    public static Id registerCandidate(String fullName, String phone, String email) {
        try {
            if (!Schema.getGlobalDescribe().containsKey('Candidate__c')) {
                throw new AuraHandledException('Candidate__c object is not available.');
            }

            String firstName;
            String lastName;

            if (String.isBlank(fullName)) {
                firstName = null;
                lastName = null;
            } else {
                List<String> parts = fullName.trim().split('\\s+');

                if (parts.size() == 1) {
                    firstName = parts[0];
                    lastName = null;
                } else {
                    firstName = parts[0];

                    // Build the "tail" (all parts after the first) manually
                    List<String> tail = new List<String>();
                    for (Integer i = 1; i < parts.size(); i++) {
                        tail.add(parts[i]);
                    }
                    lastName = String.join(tail, ' ');
                }
            }

            Candidate__c c = new Candidate__c();
            c.FirstName__c = firstName;
            c.LastName__c = lastName;
            c.Email__c = email;
            c.Phone__c = phone;
            c.Status__c = 'NEW';

            insert c;

            Onb_ActivationAuditWriter.write(
                'CANDIDATE_REGISTERED',
                'Chat-first registration',
                c.Id
            );

            return c.Id;
        } catch (Exception ex) {
            Onb_ErrorLogService.logError('CandidateIntakeController.registerCandidate', ex);
            throw new AuraHandledException('Failed to register candidate: ' + ex.getMessage());
        }
    }
}
