# NA-14 Resume to S3 Upload Runbook

## Purpose
Upload candidate resume artifacts to S3 and store resulting URL.

## Preconditions
1. S3 named credential/config ready
2. Candidate trigger active
3. ContentVersion available

## Step-by-Step Operation
1. Upload resume to candidate context.
2. Trigger enqueue of S3 upload job.
3. Complete upload callout.
4. Store resulting S3 URL on candidate.

## Validation Checklist
1. Upload job completes
2. URL field populated
3. Error log recorded on failures

## Failure Handling and Recovery
1. Retry failed uploads
2. Validate bucket/key permissions
3. Fallback to native file storage if S3 unavailable

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
