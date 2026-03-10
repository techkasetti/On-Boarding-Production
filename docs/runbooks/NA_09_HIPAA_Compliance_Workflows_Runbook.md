# NA-09 HIPAA Compliance Workflows Runbook

## Purpose
Enforce PHI gating and compliance progression.

## Preconditions
1. HIPAA flows active
2. Candidate status field values deployed
3. Compliance checklist operational

## Step-by-Step Operation
1. Initialize HIPAA compliance state.
2. Track completion artifacts.
3. Update PHI access gating.
4. Promote candidate when gate conditions met.

## Validation Checklist
1. PHI access blocked until compliant
2. Status progression valid
3. Audit entries created

## Failure Handling and Recovery
1. Do not auto-promote on incomplete evidence
2. Send manual compliance review task
3. Escalate overdue compliance cases

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
