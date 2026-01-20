// public with sharing class S3UploadQueueable implements Queueable, Database.AllowsCallouts {
//     private Set<Id> candidateIds;

//     public S3UploadQueueable(Set<Id> candidateIds) {
//         this.candidateIds = candidateIds;
//     }

//     public void execute(QueueableContext context) {
//         // Find the latest ContentVersion for each candidate
//         Map<Id, Id> candidateIdToContentVersionId = new Map<Id, Id>();

//         // This query finds the most recently created file link for each candidate
//         for (ContentDocumentLink cdl : [
//             SELECT ContentDocument.LatestPublishedVersionId, LinkedEntityId
//             FROM ContentDocumentLink
//             WHERE LinkedEntityId IN :this.candidateIds
//             ORDER BY SystemModstamp DESC
//         ]) {
//             // Because of the ordering, we only map the first (most recent) one we find
//             if (!candidateIdToContentVersionId.containsKey(cdl.LinkedEntityId)) {
//                 candidateIdToContentVersionId.put(cdl.LinkedEntityId, cdl.ContentDocument.LatestPublishedVersionId);
//             }
//         }
        
//         // Invert the map to be ContentVersionId -> CandidateId for the S3Uploader
//         Map<Id, Id> versionIdToCandidateId = new Map<Id, Id>();
//         for(Id candId : candidateIdToContentVersionId.keySet()){
//             versionIdToCandidateId.put(candidateIdToContentVersionId.get(candId), candId);
//         }

//         // Call the S3Uploader future method if there are files to upload
//         if (!versionIdToCandidateId.isEmpty()) {
//             S3Uploader.uploadToS3(versionIdToCandidateId);
//         }
//     }
// }
public with sharing class S3UploadQueueable implements Queueable, Database.AllowsCallouts {
    private Set<Id> candidateIds;

    public S3UploadQueueable(Set<Id> candidateIds) {
        this.candidateIds = candidateIds;
    }

    public void execute(QueueableContext context) {
        // Find the latest ContentVersion for each candidate
        Map<Id, Id> candidateIdToContentVersionId = new Map<Id, Id>();

        // This query finds the most recently created file link for each candidate
        for (ContentDocumentLink cdl : [
            SELECT ContentDocument.LatestPublishedVersionId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :this.candidateIds
            ORDER BY SystemModstamp DESC
        ]) {
            // Because of the ordering, we only map the first (most recent) one we find
            if (!candidateIdToContentVersionId.containsKey(cdl.LinkedEntityId)) {
                candidateIdToContentVersionId.put(cdl.LinkedEntityId, cdl.ContentDocument.LatestPublishedVersionId);
            }
        }
        
        // Create a map of ContentVersionId -> CandidateId for the S3Uploader
        Map<Id, Id> versionIdToCandidateId = new Map<Id, Id>();
        for(Id candId : candidateIdToContentVersionId.keySet()){
            versionIdToCandidateId.put(candidateIdToContentVersionId.get(candId), candId);
        }

        // Call the S3Uploader future method if there are files to upload
        if (!versionIdToCandidateId.isEmpty()) {
            S3Uploader.uploadToS3(versionIdToCandidateId);
        }
    }
}