# AI-06 Resume Parsing Runbook

## Purpose
Extract resume content into candidate profile fields.

## Preconditions
1. Resume source available
2. Parsing queue infrastructure enabled
3. Candidate context exists

## Step-by-Step Operation
1. Trigger ResumeParsingJob.
2. Monitor async execution.
3. Review parsed/mapped candidate fields.
4. Correct exceptions manually if needed.

## Validation Checklist
1. Candidate profile populated
2. Mapping coverage meets baseline
3. Parse errors captured to logs

## Failure Handling and Recovery
1. Retry with cleaned payload
2. Use manual intake fallback
3. Analyze parser output schema drift

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
