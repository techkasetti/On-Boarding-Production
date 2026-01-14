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
        
        @InvocableVariable(label='Error Details')
        public String errorDetails;
    }
    
    @InvocableMethod(
        label='Evaluate Screening Rules (Job-Aware)' 
        description='Runs the job-specific screening rule engine for candidates.'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> responses = new List<Response>();
        Map<Id, Id> candidateToJobMap = new Map<Id, Id>();
        Set<Id> candidatesToQueryForJob = new Set<Id>();
        
        System.debug('=== INVOCABLE METHOD CALLED ===');
        System.debug('Timestamp: ' + System.now());
        System.debug('Number of requests: ' + requests.size());
        System.debug('Running User: ' + UserInfo.getUserName());
        
        // Build candidate to job mapping
        for (Request req : requests) {
            System.debug('Processing request for candidateId: ' + req.candidateId);
            System.debug('Job Posting ID provided: ' + req.jobPostingId);
            
            if (req.jobPostingId != null) {
                candidateToJobMap.put(req.candidateId, req.jobPostingId);
            } else {
                candidatesToQueryForJob.add(req.candidateId);
            }
        }
        
        // Query for candidates without job mapping
        if (!candidatesToQueryForJob.isEmpty()) {
            System.debug('Querying candidates without job mapping: ' + candidatesToQueryForJob.size());
            
            for (Candidate__c c : [
                SELECT Id, Name, Interested_In_Job__c 
                FROM Candidate__c 
                WHERE Id IN :candidatesToQueryForJob
            ]) {
                System.debug('Candidate: ' + c.Name + ', Interested_In_Job__c: ' + c.Interested_In_Job__c);
                
                if (c.Interested_In_Job__c != null) {
                    candidateToJobMap.put(c.Id, c.Interested_In_Job__c);
                } else {
                    System.debug('WARNING: Candidate ' + c.Name + ' has no job posting!');
                }
            }
        }
        
        System.debug('Final candidateToJobMap size: ' + candidateToJobMap.size());
        System.debug('Candidate to Job Mapping: ' + candidateToJobMap);
        
        // Enqueue screening job
        if (!candidateToJobMap.isEmpty()) {
            try {
                // Check if there are active rules for these jobs
                Set<Id> jobPostingIds = new Set<Id>(candidateToJobMap.values());
                System.debug('Checking for active rules for jobs: ' + jobPostingIds);
                
                List<Screening_Rule__c> activeRules = [
                    SELECT Id, Name, Applied_Role__c 
                    FROM Screening_Rule__c 
                    WHERE Active__c = true 
                    AND Is_Current_Version__c = true
                    AND Applied_Role__c IN :jobPostingIds
                    AND (Test_Mode_Only__c = false OR Test_Mode_Only__c = null)
                ];
                
                Integer activeRulesCount = activeRules.size();
                System.debug('Active rules found: ' + activeRulesCount);
                
                for (Screening_Rule__c rule : activeRules) {
                    System.debug('Active Rule: ' + rule.Name + ' for Job: ' + rule.Applied_Role__c);
                }
                
                if (activeRulesCount == 0) {
                    System.debug('WARNING: No active screening rules found!');
                    
                    // Still enqueue but with warning
                    for (Id candId : candidateToJobMap.keySet()) {
                        Response warningRes = new Response();
                        warningRes.candidateId = candId;
                        warningRes.status = 'Warning';
                        warningRes.message = 'No active screening rules found for the selected job posting. Candidate status will be updated.';
                        responses.add(warningRes);
                    }
                }
                
                // Enqueue the job
                System.debug('Enqueueing ScreeningQueueable job...');
                Id jobId = System.enqueueJob(new ScreeningQueueable(candidateToJobMap));
                System.debug('Screening job enqueued successfully with Job ID: ' + jobId);
                
                for (Id candId : candidateToJobMap.keySet()) {
                    Response res = new Response();
                    res.candidateId = candId;
                    res.status = 'Success';
                    res.message = 'Screening process started. Found ' + activeRulesCount + ' active rules. Job ID: ' + jobId;
                    responses.add(res);
                }
            } catch (Exception e) {
                System.debug('ERROR: Failed to enqueue screening job');
                System.debug('Error Type: ' + e.getTypeName());
                System.debug('Error message: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
                System.debug('Line number: ' + e.getLineNumber());
                
                for (Request req : requests) {
                    Response errorRes = new Response();
                    errorRes.candidateId = req.candidateId;
                    errorRes.status = 'Error';
                    errorRes.message = 'Failed to start screening';
                    errorRes.errorDetails = e.getMessage() + ' | Line: ' + e.getLineNumber();
                    responses.add(errorRes);
                }
                return responses;
            }
        }
        
        // Handle candidates without job postings
        for (Request req : requests) {
            if (!candidateToJobMap.containsKey(req.candidateId)) {
                System.debug('WARNING: Candidate ' + req.candidateId + ' not processed - no job posting');
                
                Response warningRes = new Response();
                warningRes.candidateId = req.candidateId;
                warningRes.status = 'Warning';
                warningRes.message = 'Candidate is not associated with a job posting. Please set Interested In Job field.';
                responses.add(warningRes);
            }
        }
        
        System.debug('=== INVOCABLE METHOD COMPLETED ===');
        System.debug('Total responses: ' + responses.size());
        
        for (Response resp : responses) {
            System.debug('Response - Candidate: ' + resp.candidateId + ', Status: ' + resp.status + ', Message: ' + resp.message);
        }
        
        return responses;
    }
}