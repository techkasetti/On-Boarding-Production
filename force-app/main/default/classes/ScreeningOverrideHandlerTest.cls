@IsTest
private class ScreeningOverrideHandlerTest {
    private static Candidate__c createCandidate(String suffix) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Override Candidate ' + suffix,
            Email__c = 'override.' + suffix + '@example.com'
        );
        insert c;
        return c;
    }

    private static Screening_Result__c createScreeningResult(Id candidateId, String outcome, String correlationId) {
        Screening_Result__c r = new Screening_Result__c(
            Candidate__c = candidateId,
            Outcome__c = outcome,
            Correlation_Id__c = correlationId,
            Details__c = 'Initial details'
        );
        insert r;
        return r;
    }

    @IsTest
    static void testApplyOverride_UpdatesResultAndCandidateStatus() {
        Candidate__c candidate = createCandidate('apply');
        Screening_Result__c result = createScreeningResult(candidate.Id, 'Fail', 'corr-1');

        Screening_Override__c overrideRec = new Screening_Override__c(
            Candidate__c = candidate.Id,
            Screening_Result__c = result.Id,
            New_Outcome__c = 'Pass',
            Override_Reason__c = 'Manual verification',
            Original_Outcome__c = 'Fail',
            Approval_Status__c = 'Approved'
        );
        insert overrideRec;

        Test.startTest();
        ScreeningOverrideHandler.applyOverride(overrideRec.Id);
        Test.stopTest();

        Screening_Result__c updatedResult = [
            SELECT Outcome__c, Details__c, Override_Applied__c, Override_Id__c
            FROM Screening_Result__c
            WHERE Id = :result.Id
        ];
        System.assertEquals('Pass', updatedResult.Outcome__c);
        System.assertEquals(true, updatedResult.Override_Applied__c);
        System.assertEquals(overrideRec.Id, updatedResult.Override_Id__c);
        System.assert(updatedResult.Details__c.contains('MANUAL OVERRIDE APPLIED'));

        Candidate__c updatedCandidate = [
            SELECT Screening_Status__c
            FROM Candidate__c
            WHERE Id = :candidate.Id
        ];
        System.assertEquals('Passed', updatedCandidate.Screening_Status__c);
    }

    @IsTest
    static void testHandleApprovedOverrides_NoApprovalNoChanges() {
        Candidate__c candidate = createCandidate('nochange');
        Screening_Result__c result = createScreeningResult(candidate.Id, 'Fail', 'corr-2');

        Screening_Override__c overrideRec = new Screening_Override__c(
            Candidate__c = candidate.Id,
            Screening_Result__c = result.Id,
            New_Outcome__c = 'Pass',
            Override_Reason__c = 'Pending review',
            Original_Outcome__c = 'Fail',
            Approval_Status__c = 'Pending'
        );
        insert overrideRec;

        Test.startTest();
        ScreeningOverrideHandler.handleApprovedOverrides(
            new List<Screening_Override__c>{ overrideRec },
            new Map<Id, Screening_Override__c>{ overrideRec.Id => new Screening_Override__c(Id = overrideRec.Id, Approval_Status__c = 'Pending') }
        );
        Test.stopTest();

        Screening_Result__c unchanged = [
            SELECT Outcome__c, Override_Applied__c
            FROM Screening_Result__c
            WHERE Id = :result.Id
        ];
        System.assertEquals('Fail', unchanged.Outcome__c);
        System.assert(unchanged.Override_Applied__c != true, 'Override flag should not be set');
    }
}
