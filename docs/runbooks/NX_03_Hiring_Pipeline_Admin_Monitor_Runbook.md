# NX-03 Hiring Pipeline Admin Monitor Runbook

## Purpose
Operational visibility for Offer Accepted -> Compliance Pending -> Hired lifecycle.

## Preconditions
1. candidateHiringMonitor component deployed
2. Relevant candidate status values available
3. Monitor accessible in app home

## Step-by-Step Operation
1. Open KT Onboarding home monitor panel.
2. Review KPI cards and aging buckets.
3. Drill into pending records.
4. Take remediation actions and refresh.

## Validation Checklist
1. KPI counts reconcile with candidate records
2. Aging values update correctly
3. Audit metrics visible

## Failure Handling and Recovery
1. Correct status mapping if counts off
2. Validate HIPAA gate transitions
3. Track repeated conversion failures

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
