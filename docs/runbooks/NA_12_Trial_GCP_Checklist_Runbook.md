# NA-12 Trial and GCP Checklist Automation Runbook

## Purpose
Automate clinical trial onboarding checklist and GCP compliance.

## Preconditions
1. Trial and GCP flows active
2. Required task templates configured
3. Trial assignment object deployed

## Step-by-Step Operation
1. Create trial assignment record.
2. Verify automatic checklist/task generation.
3. Update GCP expiry dates.
4. Confirm expiring/expired actions trigger.

## Validation Checklist
1. Checklist completeness visible
2. GCP flags update correctly
3. Compliance tasks generated

## Failure Handling and Recovery
1. Handle late GCP renewals via escalation
2. Correct assignment mapping
3. Re-run checklist creation after data fixes

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
