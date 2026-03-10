# NA-13 Referral Tracking and Rewards Runbook

## Purpose
Track referral shares, conversions, and reward points.

## Preconditions
1. Referral labels configured
2. Referral object permissions assigned
3. Referral UI exposed

## Step-by-Step Operation
1. Generate referral link.
2. Track share activity.
3. Record referred candidate conversion.
4. Validate points and counters.

## Validation Checklist
1. Referral_Conversion__c created
2. Referrer counters increment correctly
3. Referral link resolves as expected

## Failure Handling and Recovery
1. Fix label configuration issues
2. Prevent duplicate conversion credit
3. Audit reward adjustments

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
