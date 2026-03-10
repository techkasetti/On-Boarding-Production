# AI-09 AI Confidence Metadata Runbook

## Purpose
Persist confidence and rationale metadata for decision transparency.

## Preconditions
1. AI screening output schema includes metadata
2. Storage fields available
3. Reporting access enabled

## Step-by-Step Operation
1. Run AI-enabled workflow.
2. Inspect persisted result record.
3. Verify confidence and reasons displayed in UI.
4. Validate reporting compatibility.

## Validation Checklist
1. Confidence score non-null
2. Rationale/concerns present
3. Historical records queryable

## Failure Handling and Recovery
1. Set default confidence on parse issues
2. Capture malformed response
3. Open defect for schema mismatch

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
