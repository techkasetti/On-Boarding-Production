# AI-03 Eligibility Scoring Runbook

## Purpose
Calculate candidate-job fit score for automated pre-screening decisions.

## Preconditions
1. Job_Application__c data complete
2. Eligibility flows active
3. AI endpoint reachable

## Step-by-Step Operation
1. Set/create job application meeting trigger criteria.
2. Allow auto flow to invoke eligibility scoring.
3. Review score and recommendation fields.
4. Confirm downstream status/routing impact.

## Validation Checklist
1. Eligibility score persisted
2. Decision status updated as per thresholds
3. Audit entries present

## Failure Handling and Recovery
1. Use default safe status on model failure
2. Retry callout after payload validation
3. Inspect EligibilityAICaller errors

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
