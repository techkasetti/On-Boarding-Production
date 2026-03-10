# AI-10 Referral Scoring (Planned) Runbook

## Purpose
Predict referral quality to prioritize high-conversion referrals.

## Preconditions
1. Historical referral outcomes captured
2. Feature store definition finalized
3. Model hosting selected

## Step-by-Step Operation
1. Train referral quality model offline.
2. Publish inference endpoint.
3. Integrate prediction call during referral events.
4. Expose score in referral UI.

## Validation Checklist
1. Prediction field populated
2. Score correlates with conversion outcomes
3. No blocking decisions solely by AI

## Failure Handling and Recovery
1. Human review for low-confidence cases
2. Bias check by role/domain
3. Fallback to non-AI ranking if unavailable

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
