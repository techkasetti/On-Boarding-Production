# NA-03 Metadata-Driven Screening Rules Runbook

## Purpose
Run configurable rule engine for screening without code change.

## Preconditions
1. Screening rules configured
2. Rule engine metadata deployed
3. Screening admin access provided

## Step-by-Step Operation
1. Create or update screening rule metadata.
2. Trigger candidate screening execution.
3. Inspect rule-by-rule output.
4. Confirm final decision.

## Validation Checklist
1. Rule evaluation traces available
2. Outcome matches configured logic
3. No hardcoded override mismatch

## Failure Handling and Recovery
1. Rollback problematic rule version
2. Disable bad rule quickly
3. Re-run affected candidates

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
