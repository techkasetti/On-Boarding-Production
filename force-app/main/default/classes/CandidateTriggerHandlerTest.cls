@IsTest
private class CandidateTriggerHandlerTest {
    private static Candidate__c createCandidate(Boolean resumeStatus, Boolean resumeAi) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Trigger Candidate',
            Email__c = 'trigger.candidate@example.com',
            Resume_Status__c = resumeStatus,
            Resume_parsing_using_ai__c = resumeAi
        );
        insert c;
        return c;
    }

    @IsTest
    static void testHandleAfterUpdate_EnqueuesQueueable() {
        Candidate__c oldCand = createCandidate(false, false);
        Candidate__c newCand = oldCand.clone(false, true, false, false);
        newCand.Id = oldCand.Id;
        newCand.Resume_Status__c = true;
        newCand.Resume_parsing_using_ai__c = true;

        Test.startTest();
        CandidateTriggerHandler.handleAfterUpdate(
            new List<Candidate__c>{ newCand },
            new Map<Id, Candidate__c>{ oldCand.Id => oldCand }
        );
        Test.stopTest();

        Integer queueJobs = [
            SELECT Count()
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
              AND ApexClass.Name = 'S3UploadQueueable'
        ];
        System.assert(queueJobs > 0, 'Queueable job should be enqueued');
    }

    @IsTest
    static void testHandleAfterUpdate_NoEnqueueWhenConditionsFail() {
        Candidate__c oldCand = createCandidate(false, false);
        Candidate__c newCand = oldCand.clone(false, true, false, false);
        newCand.Id = oldCand.Id;
        newCand.Resume_Status__c = false;
        newCand.Resume_parsing_using_ai__c = true;

        Test.startTest();
        CandidateTriggerHandler.handleAfterUpdate(
            new List<Candidate__c>{ newCand },
            new Map<Id, Candidate__c>{ oldCand.Id => oldCand }
        );
        System.assertEquals(0, Limits.getQueueableJobs(), 'No queueable should be enqueued');
        Test.stopTest();
    }
}
