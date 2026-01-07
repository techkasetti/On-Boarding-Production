// public with sharing class EvaluateScreeningRules {
//     public class Request {
//         @InvocableVariable(required=true label='Candidate ID')
//         public Id candidateId;
//         @InvocableVariable(required=false label='Job Posting ID')
//         public Id jobPostingId;
//     }
    
//     public class Response {
//         @InvocableVariable(label='Candidate ID')
//         public Id candidateId;
//         @InvocableVariable(label='Status')
//         public String status;
//     }
    
//     @InvocableMethod(label='Evaluate Screening Rules (Job-Aware)' description='Runs the job-specific screening rule engine for a list of candidates.')
//     public static List<Response> run(List<Request> requests) {
//         List<Response> responses = new List<Response>();
//         Map<Id, Id> candidateToJobMap = new Map<Id, Id>();
//         Set<Id> candidatesToQueryForJob = new Set<Id>();
        
//         for (Request req : requests) {
//             if (req.jobPostingId != null) {
//                 candidateToJobMap.put(req.candidateId, req.jobPostingId);
//             } else {
//                 candidatesToQueryForJob.add(req.candidateId);
//             }
//         }
        
//         if (!candidatesToQueryForJob.isEmpty()) {
//             for (Candidate__c c : [SELECT Id, Interested_In_Job__c FROM Candidate__c WHERE Id IN :candidatesToQueryForJob]) {
//                 if (c.Interested_In_Job__c != null) {
//                     candidateToJobMap.put(c.Id, c.Interested_In_Job__c);
//                 }
//             }
//         }
        
//         if (!candidateToJobMap.isEmpty()) {
//             try {
//                 System.enqueueJob(new ScreeningQueueable(candidateToJobMap));
//                 for (Id candId : candidateToJobMap.keySet()) {
//                     Response res = new Response();
//                     res.candidateId = candId;
//                     res.status = 'Screening process started successfully.';
//                     responses.add(res);
//                 }
//             } catch (Exception e) {
//                 for (Request req : requests) {
//                     Response errorRes = new Response();
//                     errorRes.candidateId = req.candidateId;
//                     errorRes.status = 'Error: Failed to start screening job. ' + e.getMessage();
//                     responses.add(errorRes);
//                 }
//                 return responses;
//             }
//         }
        
//         // Final check for candidates who still don't have a job linked
//         for (Request req : requests) {
//             if (!candidateToJobMap.containsKey(req.candidateId)) {
//                 Response warningRes = new Response();
//                 warningRes.candidateId = req.candidateId;
//                 warningRes.status = 'Warning: Screening was not started because the candidate is not associated with a job posting.';
//                 responses.add(warningRes);
//             }
//         }
        
//         return responses;
//     }
// }
// =====================================================
// INVOCABLE METHOD FOR FLOW
// Called from Record-Triggered Flow on Candidate
// =====================================================

public with sharing class EvaluateScreeningRules {
    public class Request {
        @InvocableVariable(required=true label='Candidate ID')
        public Id candidateId;
        
        @InvocableVariable(required=false label='Job Posting ID')
        public Id jobPostingId;
    }
    
    public class Response {
        @InvocableVariable(label='Candidate ID')
        public Id candidateId;
        
        @InvocableVariable(label='Status')
        public String status;
        
        @InvocableVariable(label='Message')
        public String message;
    }
    
    @InvocableMethod(
        label='Evaluate Screening Rules (Job-Aware)' 
        description='Runs the job-specific screening rule engine for candidates.'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> responses = new List<Response>();
        Map<Id, Id> candidateToJobMap = new Map<Id, Id>();
        Set<Id> candidatesToQueryForJob = new Set<Id>();
        
        // Build candidate to job mapping
        for (Request req : requests) {
            if (req.jobPostingId != null) {
                candidateToJobMap.put(req.candidateId, req.jobPostingId);
            } else {
                candidatesToQueryForJob.add(req.candidateId);
            }
        }
        
        // Query for candidates without job mapping
        if (!candidatesToQueryForJob.isEmpty()) {
            for (Candidate__c c : [
                SELECT Id, Interested_In_Job__c 
                FROM Candidate__c 
                WHERE Id IN :candidatesToQueryForJob
            ]) {
                if (c.Interested_In_Job__c != null) {
                    candidateToJobMap.put(c.Id, c.Interested_In_Job__c);
                }
            }
        }
        
        // Enqueue screening job
        if (!candidateToJobMap.isEmpty()) {
            try {
                System.enqueueJob(new ScreeningQueueable(candidateToJobMap));
                
                for (Id candId : candidateToJobMap.keySet()) {
                    Response res = new Response();
                    res.candidateId = candId;
                    res.status = 'Success';
                    res.message = 'Screening process started successfully.';
                    responses.add(res);
                }
            } catch (Exception e) {
                for (Request req : requests) {
                    Response errorRes = new Response();
                    errorRes.candidateId = req.candidateId;
                    errorRes.status = 'Error';
                    errorRes.message = 'Failed to start screening: ' + e.getMessage();
                    responses.add(errorRes);
                }
                return responses;
            }
        }
        
        // Handle candidates without job postings
        for (Request req : requests) {
            if (!candidateToJobMap.containsKey(req.candidateId)) {
                Response warningRes = new Response();
                warningRes.candidateId = req.candidateId;
                warningRes.status = 'Warning';
                warningRes.message = 'Candidate is not associated with a job posting.';
                responses.add(warningRes);
            }
        }
        
        return responses;
    }
}