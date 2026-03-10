# NX-05 Workforce Admin Monitor Runbook

## Purpose
Monitor workforce KPIs and operational queues.

## Preconditions
1. Workforce monitor component deployed
2. Shift/attendance/leave data available
3. User has read access to workforce objects

## Step-by-Step Operation
1. Open Workforce Monitor panel.
2. Review KPI cards.
3. Inspect scheduled shifts/attendance exceptions/leave queues.
4. Use component refresh or auto-refresh.

## Validation Checklist
1. Metrics match current record set
2. Datatable drilldown links open records
3. Auto-refresh updates snapshot

## Failure Handling and Recovery
1. If zero data, verify status filters and seed records
2. Check object field API alignment
3. Inspect controller query filters

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
