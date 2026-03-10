# NX-02 Identity Phase Strategy Runbook

## Purpose
Manage identity lifecycle across candidate and employee phases.

## Preconditions
1. Identity phase field values deployed
2. Strategy service available
3. Profile/perm model finalized

## Step-by-Step Operation
1. Run conversion or strategy action.
2. Default phase set to Hybrid unless overridden.
3. Validate user/profile access expectations.
4. Confirm downstream flows respect identity phase.

## Validation Checklist
1. Identity_Phase__c updated correctly
2. No broken login/access path
3. Phase reflected in monitoring UI

## Failure Handling and Recovery
1. Reapply strategy if mismatch
2. Audit identity transitions
3. Escalate conflicting access model settings

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
