# NA-10 Provider Credential Score and Status Runbook

## Purpose
Compute and display provider credential health.

## Preconditions
1. Provider credential objects populated
2. Compliance controller deployed
3. Dashboard visibility configured

## Step-by-Step Operation
1. Open provider compliance overview.
2. Review license/CME/credential summary.
3. Assess risk flags and required actions.
4. Assign remediation tasks.

## Validation Checklist
1. Score/status matches source records
2. Risk indicators accurate
3. Follow-up task creation works

## Failure Handling and Recovery
1. Correct stale source data
2. Recalculate score after updates
3. Audit score calculation logic

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
