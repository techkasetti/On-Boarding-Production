# NA-07 License Verification API Runbook

## Purpose
Accept external license verification events into Salesforce.

## Preconditions
1. API endpoint enabled
2. Integration auth configured
3. Field mappings agreed

## Step-by-Step Operation
1. Send payload to API endpoint.
2. Validate request and persist record.
3. Return success/error response.
4. Trigger downstream verification flow.

## Validation Checklist
1. Record created for valid payload
2. Error returned for invalid payload
3. Idempotency respected

## Failure Handling and Recovery
1. Inspect request logs and payload
2. Retry transient failures
3. Quarantine malformed events

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
