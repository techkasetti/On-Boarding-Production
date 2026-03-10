# AI-02 Candidate Screening Runbook

## Purpose
Generate AI score/recommendation and combine with rule-based screening.

## Preconditions
1. Candidate record exists
2. Screening configuration available
3. AI feature toggle enabled

## Step-by-Step Operation
1. Open Candidate Screening UI.
2. Run AI screening for selected candidate/job application.
3. Wait for async processing.
4. Refresh result panel.

## Validation Checklist
1. AI_Screening_Result__c generated
2. Recommendation and confidence populated
3. Queueable completed without errors

## Failure Handling and Recovery
1. Retry failed queueable
2. Fallback to rule-only decision
3. Check AIScreeningController + ScreeningQueueable logs

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
