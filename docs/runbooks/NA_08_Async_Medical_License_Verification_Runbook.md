# NA-08 Async Medical License Verification Runbook

## Purpose
Run external verification and updates asynchronously.

## Preconditions
1. Queueable enabled
2. Named credential configured
3. Invoker flow active

## Step-by-Step Operation
1. Submit license verification for processing.
2. Queue job executes callout.
3. Persist verification status.
4. Trigger AI name match if configured.

## Validation Checklist
1. Queue completes successfully
2. Status transitions correct
3. Manual review path available

## Failure Handling and Recovery
1. Retry failed job
2. Fallback to manual verification
3. Capture endpoint downtime incident

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
