
public with sharing class S3Uploader {
    private static final String S3_NAMED_CREDENTIAL = 'S3_Upload';
    private static final String BUCKET_NAME = 'snowflake-onboarding-p';
    private static final String REGION = 'ap-south-1';

    @future(callout=true)
    public static void uploadToS3(Map<Id, Id> contentVersionIdToCandidateId) {
        System.debug('S3Uploader.uploadToS3 invoked with map: ' + contentVersionIdToCandidateId);
        Set<Id> contentVersionIds = contentVersionIdToCandidateId.keySet();

        List<ContentVersion> versions = [
            SELECT Id, Title, VersionData
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
        ];
        
        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();

        for (ContentVersion cv : versions) {
            String filename = cv.Title;
            Blob fileBody = cv.VersionData;
            String endpoint = 'callout:' + S3_NAMED_CREDENTIAL + '/' + BUCKET_NAME + '/' + EncodingUtil.urlEncode(filename, 'UTF-8');
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('PUT');
            req.setHeader('Content-Type', 'application/octet-stream');
            req.setBodyAsBlob(fileBody);
            
            try {
                HttpResponse res = new Http().send(req);
                if (res.getStatusCode() == 200) {
                    String s3Url = 'https://' + BUCKET_NAME + '.s3.' + REGION + '.amazonaws.com/' + EncodingUtil.urlEncode(filename, 'UTF-8');
                    Id candidateId = contentVersionIdToCandidateId.get(cv.Id);

                    // --- LOGIC CHANGE ---
                    // We ONLY update the S3 URL. The status is already true.
                    candidatesToUpdate.add(new Candidate__c(
                        Id = candidateId,
                        S3_Resume_URL__c = s3Url
                    ));
                    
                    Onb_ActivationAuditWriter.write('FILE_UPLOADED_TO_S3', 'File ' + filename + ' successfully moved to S3.', candidateId);
                } else {
                    Onb_ErrorLogService.logError('S3Uploader.uploadToS3', 'S3 Upload Failed. Status: ' + res.getStatusCode(), null);
                }
            } catch (Exception e) {
                Onb_ErrorLogService.logError('S3Uploader.uploadToS3', 'Callout Exception: ' + e.getMessage(), e);
            }
        }

        if (!candidatesToUpdate.isEmpty()) {
            try {
                update candidatesToUpdate;
            } catch (Exception e) {
                Onb_ErrorLogService.logError('S3Uploader.uploadToS3.DML', 'Failed to update Candidate with S3 URL.', e);
            }
        }
    }
}
