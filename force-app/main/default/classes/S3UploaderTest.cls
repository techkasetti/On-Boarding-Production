@IsTest
private class S3UploaderTest {
    private class S3SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('ok');
            return res;
        }
    }

    private class S3FailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('failed');
            return res;
        }
    }

    private static Candidate__c createCandidate(String suffix) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'S3 Candidate ' + suffix,
            Email__c = 's3.' + suffix + '@example.com'
        );
        insert c;
        return c;
    }

    private static ContentVersion createVersion(String title) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.pdf',
            VersionData = Blob.valueOf('dummy data')
        );
        insert cv;
        return [
            SELECT Id, Title, FileExtension
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];
    }

    @IsTest
    static void testUploadToS3_Success() {
        Candidate__c candidate = createCandidate('ok');
        ContentVersion cv = createVersion('Resume (1)');

        Test.setMock(HttpCalloutMock.class, new S3SuccessMock());
        Test.startTest();
        S3Uploader.uploadToS3(new Map<Id, Id>{ cv.Id => candidate.Id });
        Test.stopTest();

        Candidate__c updated = [
            SELECT S3_Resume_URL__c
            FROM Candidate__c
            WHERE Id = :candidate.Id
        ];
        System.assertNotEquals(null, updated.S3_Resume_URL__c, 'S3 URL should be set after successful upload');
        System.assert(updated.S3_Resume_URL__c.contains(String.valueOf(candidate.Id)));
    }

    @IsTest
    static void testUploadToS3_FailureAndEmptyMap() {
        Candidate__c candidate = createCandidate('fail');
        ContentVersion cv = createVersion('Resume');

        Test.setMock(HttpCalloutMock.class, new S3FailureMock());
        Test.startTest();
        S3Uploader.uploadToS3(new Map<Id, Id>{ cv.Id => candidate.Id });
        S3Uploader.uploadToS3(new Map<Id, Id>());
        S3Uploader.uploadToS3(null);
        Test.stopTest();

        Candidate__c updated = [
            SELECT S3_Resume_URL__c
            FROM Candidate__c
            WHERE Id = :candidate.Id
        ];
        System.assertEquals(null, updated.S3_Resume_URL__c, 'Failed upload should not set URL');
    }
}
