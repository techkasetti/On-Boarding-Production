@IsTest
private class CandidateTriggerHandlerTest {
    private static final String INTELLIGENT_RESUME_PARSING_FEATURE = 'Intelligent Resume Parsing';

    private static void upsertResumeParsingFeature(Boolean isActive) {
        List<AIFeature__c> existing = [
            SELECT Id
            FROM AIFeature__c
            WHERE Name__c = :INTELLIGENT_RESUME_PARSING_FEATURE
            LIMIT 1
        ];

        if (existing.isEmpty()) {
            insert new AIFeature__c(
                Name__c = INTELLIGENT_RESUME_PARSING_FEATURE,
                Description__c = 'Controls intelligent resume parsing',
                IsActive__c = isActive
            );
        } else {
            update new AIFeature__c(
                Id = existing[0].Id,
                IsActive__c = isActive
            );
        }
    }

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
        upsertResumeParsingFeature(true);

        Candidate__c oldCand = createCandidate(false, false);
        Candidate__c newCand = oldCand.clone(false, true, false, false);
        newCand.Id = oldCand.Id;
        newCand.Resume_Status__c = true;
        newCand.Resume_parsing_using_ai__c = false;

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
        upsertResumeParsingFeature(true);

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

    @IsTest
    static void testHandleAfterUpdate_NoEnqueueWhenFeatureInactive() {
        upsertResumeParsingFeature(false);

        Candidate__c oldCand = createCandidate(false, true);
        Candidate__c newCand = oldCand.clone(false, true, false, false);
        newCand.Id = oldCand.Id;
        newCand.Resume_Status__c = true;
        newCand.Resume_parsing_using_ai__c = true;

        Test.startTest();
        CandidateTriggerHandler.handleAfterUpdate(
            new List<Candidate__c>{ newCand },
            new Map<Id, Candidate__c>{ oldCand.Id => oldCand }
        );
        System.assertEquals(0, Limits.getQueueableJobs(), 'No queueable should be enqueued when feature is inactive');
        Test.stopTest();
    }
}
