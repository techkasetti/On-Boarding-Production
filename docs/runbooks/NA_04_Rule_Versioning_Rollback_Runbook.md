# NA-04 Rule Versioning and Rollback Runbook

## Purpose
Control screening rule lifecycle safely.

## Preconditions
1. Versioning service deployed
2. Rule ownership process defined
3. Change window established

## Step-by-Step Operation
1. Publish new rule version.
2. Validate with test dataset.
3. Promote or rollback based on outcome.
4. Document change record.

## Validation Checklist
1. Version history retained
2. Rollback restores expected behavior
3. Audit trail complete

## Failure Handling and Recovery
1. Immediate rollback on regressions
2. Lock edits during incident
3. Revalidate after rollback

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
