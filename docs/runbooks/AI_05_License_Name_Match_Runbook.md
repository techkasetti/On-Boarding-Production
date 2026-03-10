# AI-05 License Name Match Runbook

## Purpose
Compare candidate identity name vs license name using AI decisioning.

## Preconditions
1. LicenseVerification__c records present
2. Candidate linkage valid
3. AI service configured

## Step-by-Step Operation
1. Submit license verification process.
2. Trigger AI name-match evaluation.
3. Review match/review/mismatch output.
4. Route manual review cases.

## Validation Checklist
1. Name match decision persisted
2. Review-required cases are flagged
3. No unhandled exceptions

## Failure Handling and Recovery
1. Force Manual Review on uncertain confidence
2. Audit AI response payload
3. Check LicenseNameAIService logs

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
