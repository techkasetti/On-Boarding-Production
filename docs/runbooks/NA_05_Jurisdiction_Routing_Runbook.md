# NA-05 Jurisdiction Routing Runbook

## Purpose
Route candidates/work items based on jurisdiction and policy.

## Preconditions
1. Routing rules configured
2. Jurisdiction data present on records
3. Destination queues/users configured

## Step-by-Step Operation
1. Trigger workflow requiring routing.
2. Evaluate routing decision output.
3. Assign to target queue/user.
4. Track SLA until closure.

## Validation Checklist
1. Correct route selected
2. Routing reason stored
3. Escalation path available

## Failure Handling and Recovery
1. Fallback to default queue
2. Adjust routing rules for edge jurisdictions
3. Add monitoring for unrouted items

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
