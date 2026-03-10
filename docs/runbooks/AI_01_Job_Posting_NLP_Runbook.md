# AI-01 Job Posting NLP Runbook

## Purpose
Parse recruiter natural-language requirements into structured job posting metadata.

## Preconditions
1. Gemini named credential configured
2. Job Posting admin access
3. Required Job_* objects deployed

## Step-by-Step Operation
1. Open Job Posting Admin UI.
2. Enter free-text job requirement input.
3. Trigger AI parse and inspect extracted fields.
4. Save to create Job Posting and dependent records.

## Validation Checklist
1. Job Posting record created successfully
2. Extracted fields match input intent
3. No parsing exceptions in logs

## Failure Handling and Recovery
1. Fallback to manual form entry
2. Review AIJobPostingService logs
3. Disable AI toggle if endpoint unstable

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
