# AI-11 Fraud/Anomaly Detection Runbook

## Purpose
Detect suspicious attendance/workforce behavior patterns.

## Preconditions
1. Behavior telemetry captured
2. Risk thresholds approved
3. Investigation queue configured

## Step-by-Step Operation
1. Aggregate attendance and interaction signals.
2. Run anomaly scoring process.
3. Create risk alerts for threshold breaches.
4. Route cases to ops for investigation.

## Validation Checklist
1. Anomaly score generated
2. Alert records created correctly
3. False positive rate within agreed bounds

## Failure Handling and Recovery
1. Tune thresholds periodically
2. Add suppressions for known benign patterns
3. Escalate unresolved high-risk alerts

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
