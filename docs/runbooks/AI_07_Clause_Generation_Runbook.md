# AI-07 Clause Generation Runbook

## Purpose
Generate policy/legal clause text for document assembly.

## Preconditions
1. Document generation module active
2. Clause generator config available
3. Clause placement template present

## Step-by-Step Operation
1. Start document creation.
2. Invoke clause generation step.
3. Review generated clause text.
4. Finalize and persist document.

## Validation Checklist
1. Clause inserted into final document
2. Audit captures AI vs fallback path
3. Generated text meets expected structure

## Failure Handling and Recovery
1. Fallback to deterministic clause
2. Log generation failure with correlation ID
3. Require legal review on low confidence

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
