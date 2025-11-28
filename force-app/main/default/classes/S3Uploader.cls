public with sharing class S3Uploader {
    private static final String S3_NAMED_CREDENTIAL = 'S3_Upload';
    private static final String BUCKET_NAME = 'your-company-onboarding-resumes'; // <-- Replace with your bucket name

    @future(callout=true)
    public static void uploadToS3(Map<Id, Id> contentVersionIdToCandidateId) {
        Set<Id> contentVersionIds = contentVersionIdToCandidateId.keySet();

        // Query for the file content
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
            req.setHeader('Content-Length', String.valueOf(fileBody.size()));
            req.setBodyAsBlob(fileBody);

            try {
                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    // Success! Construct the S3 URL and prepare the candidate record for update
                    String s3Url = 'https://' + BUCKET_NAME + '.s3.' + getRegionFromNamedCredential() + '.amazonaws.com/' + EncodingUtil.urlEncode(filename, 'UTF-8');
                    Id candidateId = contentVersionIdToCandidateId.get(cv.Id);
                    candidatesToUpdate.add(new Candidate__c(
                        Id = candidateId,
                        S3_Resume_URL__c = s3Url
                    ));
                    Onb_ActivationAuditWriter.write('FILE_UPLOADED_TO_S3', 'File ' + filename + ' successfully moved to S3.', candidateId);
                } else {
                    // Handle non-200 responses
                    Onb_ErrorLogService.logError('S3Uploader.uploadToS3', 'S3 Upload Failed for file ' + filename + '. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody(), null);
                }
            } catch (Exception e) {
                Onb_ErrorLogService.logError('S3Uploader.uploadToS3', 'Callout Exception for file ' + filename + ': ' + e.getMessage(), e);
            }
        }

        if (!candidatesToUpdate.isEmpty()) {
            try {
                update candidatesToUpdate;
            } catch (Exception e) {
                Onb_ErrorLogService.logError('S3Uploader.uploadToS3.DML', 'Failed to update Candidate records with S3 URL: ' + e.getMessage(), e);
            }
        }
    }

    private static String getRegionFromNamedCredential() {
        try {
            // The API name for the 'Name' field is 'DeveloperName'
            NamedCredential nc = [
                SELECT Endpoint 
                FROM NamedCredential 
                WHERE DeveloperName = :S3_NAMED_CREDENTIAL 
                LIMIT 1
            ];
            String endpointUrl = nc.Endpoint;

            // Example: https://s3.us-east-1.amazonaws.com
            // Use a regular expression to reliably extract the region from the URL
            Pattern regionPattern = Pattern.compile('s3\\.([a-z0-9\\-]+)\\.amazonaws\\.com');
            Matcher regionMatcher = regionPattern.matcher(endpointUrl);

            if (regionMatcher.find()) {
                return regionMatcher.group(1); // Group 1 is the captured region string (e.g., "us-east-1")
            } else {
                // Log an error if the URL format is unexpected
                Onb_ErrorLogService.logError('S3Uploader.getRegion', 'Could not parse region from Named Credential URL: ' + endpointUrl, null);
                return 'us-east-1'; // Fallback
            }
        } catch (Exception e) {
            Onb_ErrorLogService.logError('S3Uploader.getRegion.Query', 'Could not query Named Credential: ' + e.getMessage(), e);
            return 'us-east-1'; // Fallback on query failure
        }
    }
}
