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
// Called from Record-Triggered Flow 
// =====================================================
public with sharing class EvaluateScreeningRules {

    public class Request {
        @InvocableVariable(required=true label='Job Application ID')
        public Id jobApplicationId;
    }

    public class Response {
        @InvocableVariable public Id candidateId;
        @InvocableVariable public String status;
        @InvocableVariable public String message;
        @InvocableVariable public String errorDetails;
    }

    @InvocableMethod(
        label='Evaluate Screening Rules'
        description='Triggered when Job Application Status changes to Interview Cleared.'
    )
    public static List<Response> run(List<Request> requests) {
        List<Response> responses = new List<Response>();

        // ── Step 1: Collect Job Application IDs ──────────────────────────────
        Set<Id> jobAppIds = new Set<Id>();
        for (Request req : requests) {
            if (req.jobApplicationId != null) {
                jobAppIds.add(req.jobApplicationId);
            }
        }

        if (jobAppIds.isEmpty()) {
            return responses;
        }

        // ── Step 2: Fetch Candidate + Job Posting from Job Application ────────
        List<Job_Application__c> jobApps = [
            SELECT Id, Candidate__c, Job_Posting__c
            FROM Job_Application__c
            WHERE Id IN :jobAppIds
        ];

        // ── Step 3: Check AI_Features__c for AI Screening flag ─────────
        Boolean aiEnabled = checkAIFeature('Background Verification');
        System.debug('AI Screening Enabled: ' + aiEnabled);

        // ── Step 4: Build candidateToJobMap ──────────────
        Map<Id, Id> candidateToJobMap = new Map<Id, Id>();
        Map<Id, Id> candidateToJobAppMap = new Map<Id, Id>();

        for (Job_Application__c jobApp : jobApps) {
            Response res = new Response();

            if (jobApp.Candidate__c == null) {
                res.status  = 'Error';
                res.message = 'No Candidate on Job Application: ' + jobApp.Id;
                responses.add(res);
                continue;
            }
            if (jobApp.Job_Posting__c == null) {
                res.status  = 'Error';
                res.message = 'No Job Posting on Job Application: ' + jobApp.Id;
                responses.add(res);
                continue;
            }

            candidateToJobMap.put(jobApp.Candidate__c, jobApp.Job_Posting__c);
            candidateToJobAppMap.put(jobApp.Candidate__c, jobApp.Id);

            res.candidateId = jobApp.Candidate__c;
            res.status      = 'Queued';
            res.message     = 'Screening queued. AI: ' + (aiEnabled ? 'Enabled' : 'Disabled');
            responses.add(res);
        }

        // ── Step 5: Enqueue ScreeningQueueable with aiEnabled flag ────────────
        if (!candidateToJobMap.isEmpty()) {
            try {
                Set<Id> jobPostingIds = new Set<Id>(candidateToJobMap.values());

                List<Screening_Rule__c> activeRules = [
                    SELECT Id FROM Screening_Rule__c
                    WHERE Active__c = true
                    AND Is_Current_Version__c = true
                    AND Applied_Role__c IN :jobPostingIds
                    AND (Test_Mode_Only__c = false OR Test_Mode_Only__c = null)
                ];

                System.debug('Active rules found: ' + activeRules.size());

                System.enqueueJob(new ScreeningQueueable(candidateToJobMap, aiEnabled,candidateToJobAppMap));

            } catch (Exception e) {
                System.debug('Enqueue Error: ' + e.getMessage());
                for (Response res : responses) {
                    res.status       = 'Error';
                    res.message      = 'Enqueue failed: ' + e.getMessage();
                    res.errorDetails = e.getStackTraceString();
                }
            }
        }

        return responses;
    }

    // ── Query AI_Features__c ──────────────────────────────────────────────────
    private static Boolean checkAIFeature(String featureName) {
        try {
            List<AI_Features__c> features = [
                SELECT Is_EnableorDesable__c
                FROM AI_Features__c
                WHERE Name = :featureName
                LIMIT 1
            ];
            return (!features.isEmpty() && features[0].Is_EnableorDesable__c == true);
        } catch (Exception e) {
            System.debug('AI_Features__c query failed: ' + e.getMessage());
            return false;
        }
    }
}