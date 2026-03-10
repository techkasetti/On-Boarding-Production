# NA-01 Chat-First Registration Runbook

## Purpose
Capture candidate onboarding inputs through guided conversation.

## Preconditions
1. Chat registration flow active
2. Candidate object permissions set
3. Experience site access configured

## Step-by-Step Operation
1. Open external/experience registration entry point.
2. Complete chat-guided profile steps.
3. Submit and verify account creation.
4. Proceed to job interest selection.

## Validation Checklist
1. Candidate created with required fields
2. No abandoned mandatory step
3. Linked contact/user relationship valid

## Failure Handling and Recovery
1. Use manual registration fallback
2. Review Flow fault paths
3. Log and retry failed transactions

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
