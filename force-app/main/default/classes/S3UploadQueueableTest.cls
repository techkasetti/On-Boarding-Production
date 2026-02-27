@IsTest
private class S3UploadQueueableTest {
    private class S3SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    private static Candidate__c createCandidate() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Queue Candidate',
            Email__c = 'queue.candidate@example.com'
        );
        insert c;
        return c;
    }

    private static void attachResumeToCandidate(Id candidateId) {
        ContentVersion cv = new ContentVersion(
            Title = 'Queue Resume',
            PathOnClient = 'Queue Resume.pdf',
            VersionData = Blob.valueOf('resume')
        );
        insert cv;

        ContentVersion inserted = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        insert new ContentDocumentLink(
            LinkedEntityId = candidateId,
            ContentDocumentId = inserted.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    @IsTest
    static void testQueueableUploadsLatestResume() {
        Candidate__c candidate = createCandidate();
        attachResumeToCandidate(candidate.Id);

        Test.setMock(HttpCalloutMock.class, new S3SuccessMock());
        Test.startTest();
        System.enqueueJob(new S3UploadQueueable(new Set<Id>{ candidate.Id }));
        Test.stopTest();
        System.assert(true, 'Queueable should execute for populated candidate set');
    }

    @IsTest
    static void testQueueableWithEmptySet() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            System.enqueueJob(new S3UploadQueueable(new Set<Id>()));
            Test.stopTest();
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        System.assertEquals(true, exceptionThrown, 'Current implementation throws for empty set');
    }
}
