# NA-11 CME and License Expiry Alerts Runbook

## Purpose
Generate proactive alerts for expiring credentials.

## Preconditions
1. Scheduled or record-triggered flows active
2. Task assignment defaults set
3. Owners have task visibility

## Step-by-Step Operation
1. Create/update records near expiry window.
2. Run scheduled alert cycle.
3. Verify task/notification creation.
4. Track acknowledgement and closure.

## Validation Checklist
1. Alerts created only in threshold window
2. Owner assignment correct
3. Duplicate alert suppression works

## Failure Handling and Recovery
1. Tune thresholds if noisy
2. Close false alerts with reason
3. Escalate unacknowledged critical expiries

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
