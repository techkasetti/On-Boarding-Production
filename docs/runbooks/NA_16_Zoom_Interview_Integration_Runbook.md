# NA-16 Zoom Interview Integration Runbook

## Purpose
Create and store interview meeting links from Salesforce.

## Preconditions
1. Zoom integration credentials configured
2. Interview scheduling context ready
3. User timezone settings verified

## Step-by-Step Operation
1. Trigger meeting creation action.
2. Call Zoom API via service.
3. Persist meeting details.
4. Notify interviewer/candidate.

## Validation Checklist
1. Meeting URL stored and valid
2. Timing/timezone correct
3. Failure responses handled gracefully

## Failure Handling and Recovery
1. Retry transient API failures
2. Fallback to manual meeting creation
3. Monitor credential/token expiration

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
