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

// public without sharing class S3Uploader {
//     private static final String S3_NAMED_CREDENTIAL = 'S3_Upload';
//    // private static final String BUCKET_NAME = 'snowflake-onboarding-p';
//     private static final String BUCKET_NAME = 'mysalesforcetestdataabhay';
//    //  private static final String REGION = 'ap-south-1';
//     private static final String REGION = 'us-east-1';

//     @future(callout=true)
//     public static void uploadToS3(Map<Id, Id> contentVersionIdToCandidateId) {
//         System.debug('S3Uploader.uploadToS3 invoked with map: ' + contentVersionIdToCandidateId);
//         Set<Id> contentVersionIds = contentVersionIdToCandidateId.keySet();

//         List<ContentVersion> versions = [
//             SELECT Id, Title, VersionData, FileExtension
//             FROM ContentVersion
//             WHERE Id IN :contentVersionIds
//         ];
        
//         List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();

//         for (ContentVersion cv : versions) {
//             Id candidateId = contentVersionIdToCandidateId.get(cv.Id);
            
//             String fileExtension = String.isNotBlank(cv.FileExtension) ? '.' + cv.FileExtension : '';
//             String originalTitle = cv.Title;
            
//             // Remove extension from title if it exists to avoid duplication
//             if (originalTitle.endsWithIgnoreCase(fileExtension)) {
//                 originalTitle = originalTitle.substring(0, originalTitle.length() - fileExtension.length());
//             }
            
//             String filename = candidateId + '_' + originalTitle + fileExtension;
            
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

//                     // Update the candidate with the S3 URL
//                     candidatesToUpdate.add(new Candidate__c(
//                         Id = candidateId,
//                         S3_Resume_URL__c = s3Url
//                     ));
                    
//                     Onb_ActivationAuditWriter.write('FILE_UPLOADED_TO_S3', 'File ' + filename + ' successfully moved to S3.', candidateId);
//                 } else {
//                     Onb_ErrorLogService.logError('S3Uploader.uploadToS3', 'S3 Upload Failed for Candidate ' + candidateId + '. Status: ' + res.getStatusCode() + ' Response: ' + res.getBody(), null);
//                 }
//             } catch (Exception e) {
//                 Onb_ErrorLogService.logError('S3Uploader.uploadToS3', 'Callout Exception for Candidate ' + candidateId + ': ' + e.getMessage(), e);
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

    // Adjust these to match your org / bucket
    private static final String S3_NAMED_CREDENTIAL = 'S3_Upload';
    private static final String BUCKET_NAME = 'mysalesforcetestdataabhay';
    private static final String REGION = 'us-east-1';

    @future(callout=true)
    public static void uploadToS3(Map<Id, Id> contentVersionIdToCandidateId) {
        System.debug('S3Uploader.uploadToS3 invoked with map: ' + contentVersionIdToCandidateId);

        if (contentVersionIdToCandidateId == null || contentVersionIdToCandidateId.isEmpty()) {
            return;
        }

        Set<Id> contentVersionIds = contentVersionIdToCandidateId.keySet();

        List<ContentVersion> versions = [
            SELECT Id, Title, VersionData, FileExtension
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
        ];

        List<Candidate__c> candidatesToUpdate = new List<Candidate__c>();

        for (ContentVersion cv : versions) {
            Id candidateId = contentVersionIdToCandidateId.get(cv.Id);
            if (candidateId == null) {
                continue;
            }

            try {
                // ---------- Build logical key parts ----------
                String fileExtension = String.isNotBlank(cv.FileExtension)
                    ? '.' + cv.FileExtension
                    : '';

                String originalTitle = cv.Title;

                // Remove extension from title if already present to avoid duplication
                if (!String.isBlank(originalTitle)
                    && fileExtension != null
                    && fileExtension.length() > 0
                    && originalTitle.toLowerCase().endsWith(fileExtension.toLowerCase())) {

                    originalTitle = originalTitle.substring(
                        0,
                        originalTitle.length() - fileExtension.length()
                    );
                }

                // Logical object name: e.g. "Medical_Resume_Sample (1).pdf"
                String objectName = originalTitle + fileExtension;

                // Logical key for logging only
                String logicalKey = String.valueOf(candidateId) + '/' + objectName;
                System.debug('S3Uploader: Logical key = ' + logicalKey);

                Blob fileBody = cv.VersionData;

                // ---------- Encode each path segment separately ----------
                // This avoids encoding "/" as %2F while still encoding spaces, parentheses, etc.
                String encodedCandidateId = EncodingUtil.urlEncode(
                    String.valueOf(candidateId),
                    'UTF-8'
                ).replace('+', '%20');  // mostly no effect for Id but safe

                String encodedObjectName = EncodingUtil.urlEncode(
                    objectName,
                    'UTF-8'
                ).replace('+', '%20');   // spaces -> %20 instead of "+"

                // Final encoded key S3 expects in the URI:
                // a0Ffo000000ltSTEAY/Medical_Resume_Sample%20%281%29.pdf
                String encodedKey = encodedCandidateId + '/' + encodedObjectName;
                System.debug('S3Uploader: Encoded key = ' + encodedKey);

                // ---------- Build endpoint using encoded key ----------
                // Named Credential base URL: https://s3.us-east-1.amazonaws.com
                // Final URL: https://s3.us-east-1.amazonaws.com/<BUCKET_NAME>/<encodedKey>
                String endpoint =
                    'callout:' + S3_NAMED_CREDENTIAL + '/' + BUCKET_NAME + '/' + encodedKey;

                System.debug('S3Uploader: Endpoint = ' + endpoint);

                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint);
                req.setMethod('PUT');
                req.setHeader('Content-Type', 'application/octet-stream');
                req.setBodyAsBlob(fileBody);

                Http http = new Http();
                HttpResponse res = http.send(req);

                System.debug(
                    'S3Uploader response for candidate ' + candidateId +
                    ' | status: ' + res.getStatusCode() +
                    ' | body: ' + res.getBody()
                );

                if (res.getStatusCode() == 200) {
                    // ---------- Build public S3 URL for Candidate ----------
                    String s3Url =
                        'https://' + BUCKET_NAME + '.s3.' + REGION + '.amazonaws.com/' + encodedKey;

                    candidatesToUpdate.add(new Candidate__c(
                        Id = candidateId,
                        S3_Resume_URL__c = s3Url
                    ));

                    Onb_ActivationAuditWriter.write(
                        'FILE_UPLOADED_TO_S3',
                        'File ' + logicalKey + ' successfully moved to S3.',
                        candidateId
                    );
                } else {
                    Onb_ErrorLogService.logError(
                        'S3Uploader.uploadToS3',
                        'S3 Upload Failed for Candidate ' + candidateId +
                        '. Status: ' + res.getStatusCode() +
                        ' Response: ' + res.getBody(),
                        null
                    );
                }

            } catch (Exception e) {
                Onb_ErrorLogService.logError(
                    'S3Uploader.uploadToS3',
                    'Callout Exception for Candidate ' + candidateId + ': ' + e.getMessage(),
                    e
                );
            }
        }

        if (!candidatesToUpdate.isEmpty()) {
            try {
                update candidatesToUpdate;
            } catch (Exception e) {
                Onb_ErrorLogService.logError(
                    'S3Uploader.uploadToS3.DML',
                    'Failed to update Candidate with S3 URL.',
                    e
                );
            }
        }
    }
}
