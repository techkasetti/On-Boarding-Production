public without sharing class CandidateTriggerHandler {

    public static void handleAfterUpdate(List<Candidate__c> newCandidates, Map<Id, Candidate__c> oldMap) {
        Set<Id> candidateIdsForS3Upload = new Set<Id>();

        for (Candidate__c newCand : newCandidates) {
            Candidate__c oldCand = oldMap.get(newCand.Id);

            // Check if the status changed from false to true
            if (newCand.Resume_Status__c == true && oldCand.Resume_Status__c == false) {
                candidateIdsForS3Upload.add(newCand.Id);
            }
        }

        // If candidates are ready for upload, enqueue the asynchronous job
        if (!candidateIdsForS3Upload.isEmpty()) {
            System.enqueueJob(new S3UploadQueueable(candidateIdsForS3Upload));
            System.debug('Enqueued ' + candidateIdsForS3Upload.size() + ' candidates for S3 upload.');
        }
    }
}
