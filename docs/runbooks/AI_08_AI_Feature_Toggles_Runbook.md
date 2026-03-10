# AI-08 AI Feature Toggles Runbook

## Purpose
Enable/disable AI pathways safely by feature.

## Preconditions
1. AI feature config object deployed
2. Admin access to toggle UI/object
3. Change governance process defined

## Step-by-Step Operation
1. Open AI Feature Console.
2. Toggle feature state.
3. Execute dependent process.
4. Validate behavior change.

## Validation Checklist
1. Disabled feature performs no AI callout
2. Enabled feature uses AI path
3. Toggle change is auditable

## Failure Handling and Recovery
1. Immediately disable on incident
2. Rollback to stable config
3. Document change window + owner

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
