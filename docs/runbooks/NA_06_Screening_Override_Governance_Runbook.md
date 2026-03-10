# NA-06 Screening Override Governance Runbook

## Purpose
Allow controlled override with accountability.

## Preconditions
1. Override object and permissions in place
2. Approver workflow active
3. Audit fields visible

## Step-by-Step Operation
1. Create override request with reason.
2. Obtain required approval.
3. Apply override action.
4. Verify updated screening outcome.

## Validation Checklist
1. Override record stores actor/time/reason
2. Status updated correctly
3. No bypass without authorization

## Failure Handling and Recovery
1. Revoke unauthorized overrides
2. Audit override frequency
3. Require second-level approval for high-risk overrides

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
