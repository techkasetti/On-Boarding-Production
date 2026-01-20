
// public with sharing class S3Uploader {
//     private static final String S3_NAMED_CREDENTIAL = 'S3_Upload';
//     private static final String BUCKET_NAME = 'snowflake-onboarding-p';
//     private static final String REGION = 'ap-south-1';

//     @future(callout=true)
//     public static void uploadToS3(Map<Id, Id> contentVersionIdToCandidateId) {
//         System.debug('S3Uploader.uploadToS3 invoked with map: ' + contentVersionIdToCandidateId);
//         Set<Id> contentVersionIds = contentVersionIdToCandidateId.keySet();

//         List<ContentVersion> versions = [
//             SELECT Id, Title, VersionData
//             FROM ContentVersion
//             WHERE Id IN :contentVersionIds
//         ];
        
//         List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();

//         for (ContentVersion cv : versions) {
//             String filename = cv.Title;
//             Blob fileBody = cv.VersionData;
//             String endpoint = 'callout:' + S3_NAMED_CREDENTIAL + '/' + BUCKET_NAME + '/' + EncodingUtil.urlEncode(filename, 'UTF-8');
            
//             HttpRequest req = new HttpRequest();
//             req.setEndpoint(endpoint);
//             req.setMethod('PUT');
//             req.setHeader('Content-Type', 'application/octet-stream');
//             req.setBodyAsBlob(fileBody);
            
//             try {
//                 HttpResponse res = new Http().send(req);
//                 if (res.getStatusCode() == 200) {
//                     String s3Url = 'https://' + BUCKET_NAME + '.s3.' + REGION + '.amazonaws.com/' + EncodingUtil.urlEncode(filename, 'UTF-8');
//                     Id candidateId = contentVersionIdToCandidateId.get(cv.Id);

//                     // --- LOGIC CHANGE ---
//                     // We ONLY update the S3 URL. The status is already true.
//                     candidatesToUpdate.add(new Candidate__c(
//                         Id = candidateId,
//                         S3_Resume_URL__c = s3Url
//                     ));
                    
//                     Onb_ActivationAuditWriter.write('FILE_UPLOADED_TO_S3', 'File ' + filename + ' successfully moved to S3.', candidateId);
//                 } else {
//                     Onb_ErrorLogService.logError('S3Uploader.uploadToS3', 'S3 Upload Failed. Status: ' + res.getStatusCode(), null);
//                 }
//             } catch (Exception e) {
//                 Onb_ErrorLogService.logError('S3Uploader.uploadToS3', 'Callout Exception: ' + e.getMessage(), e);
//             }
//         }

//         if (!candidatesToUpdate.isEmpty()) {
//             try {
//                 update candidatesToUpdate;
//             } catch (Exception e) {
//                 Onb_ErrorLogService.logError('S3Uploader.uploadToS3.DML', 'Failed to update Candidate with S3 URL.', e);
//             }
//         }
//     }
// }
public with sharing class S3Uploader {
    private static final String S3_NAMED_CREDENTIAL = 'S3_Upload';
    private static final String BUCKET_NAME = 'snowflake-onboarding-p';
    private static final String REGION = 'ap-south-1';

    @future(callout=true)
    public static void uploadToS3(Map<Id, Id> contentVersionIdToCandidateId) {
        System.debug('S3Uploader.uploadToS3 invoked with map: ' + contentVersionIdToCandidateId);
        Set<Id> contentVersionIds = contentVersionIdToCandidateId.keySet();

        List<ContentVersion> versions = [
            SELECT Id, Title, VersionData, FileExtension
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
        ];
        
        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();

        for (ContentVersion cv : versions) {
            Id candidateId = contentVersionIdToCandidateId.get(cv.Id);
            
            // Construct filename with Candidate ID
            // Format: CandidateId_OriginalFileName.ext
            // Example: a015g000001AbCdEAK_JohnDoe_Resume.pdf
            String fileExtension = String.isNotBlank(cv.FileExtension) ? '.' + cv.FileExtension : '';
            String originalTitle = cv.Title;
            
            // Remove extension from title if it exists to avoid duplication
            if (originalTitle.endsWithIgnoreCase(fileExtension)) {
                originalTitle = originalTitle.substring(0, originalTitle.length() - fileExtension.length());
            }
            
            String filename = candidateId + '_' + originalTitle + fileExtension;
            
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

                    // Update the candidate with the S3 URL
                    candidatesToUpdate.add(new Candidate__c(
                        Id = candidateId,
                        S3_Resume_URL__c = s3Url
                    ));
                    
                    Onb_ActivationAuditWriter.write('FILE_UPLOADED_TO_S3', 'File ' + filename + ' successfully moved to S3.', candidateId);
                } else {
                    Onb_ErrorLogService.logError('S3Uploader.uploadToS3', 'S3 Upload Failed for Candidate ' + candidateId + '. Status: ' + res.getStatusCode() + ' Response: ' + res.getBody(), null);
                }
            } catch (Exception e) {
                Onb_ErrorLogService.logError('S3Uploader.uploadToS3', 'Callout Exception for Candidate ' + candidateId + ': ' + e.getMessage(), e);
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