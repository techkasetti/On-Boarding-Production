# AI-12 Policy RAG Compliance Copilot Runbook

## Purpose
Answer compliance questions using grounded policy evidence and decision JSON.

## Preconditions
1. Policy documents and chunks ingested
2. Copilot permissions assigned
3. Candidate context available

## Step-by-Step Operation
1. Open Policy RAG Copilot Console.
2. Select candidate and jurisdiction.
3. Ask compliance question.
4. Review decision, citations, and confidence.

## Validation Checklist
1. JSON response contains decision + citations
2. No hallucinated policy references
3. Audit log captured for each run

## Failure Handling and Recovery
1. Return MANUAL_REVIEW on insufficient evidence
2. Re-ingest stale/missing policy chunks
3. Review PolicyRagAuditService logs

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
