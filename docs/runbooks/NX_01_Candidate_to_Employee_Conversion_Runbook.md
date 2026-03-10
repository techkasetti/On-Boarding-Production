# NX-01 Candidate to Employee Conversion Runbook

## Purpose
Idempotent conversion from offer accepted candidate to employee and contract.

## Preconditions
1. Flow Convert_Candidate_To_Employee active
2. Employee and contract objects deployed
3. Offer Accepted status path enabled

## Step-by-Step Operation
1. Set Job_Application__c status to Offer Accepted.
2. Flow invokes EmployeeConversionService.
3. Verify employee create/reuse behavior.
4. Verify contract create/reuse behavior.

## Validation Checklist
1. No duplicate employee/contract on rerun
2. Candidate back-links updated
3. Status transition correct

## Failure Handling and Recovery
1. Review conversion logs on failure
2. Retry safely due to idempotency
3. Route unresolved records to admin queue

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
