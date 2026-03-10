# NX-04 Shift Admin Console Runbook

## Purpose
Create/manage shift templates, assignments, and guided conflict checks.

## Preconditions
1. Shift objects/fields deployed
2. ShiftAdminController deployed
3. Employer accounts available

## Step-by-Step Operation
1. Open Shift Admin Console.
2. Select employer account.
3. Create template with times/recurrence/days.
4. Create assignment and run conflict check before save.

## Validation Checklist
1. Template appears in recent list
2. Assignment appears with correct times
3. Conflict detection prevents overlaps

## Failure Handling and Recovery
1. Fix required-field validation failures
2. Verify picklist values align with metadata
3. Recheck controller errors for missing fields

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
