# Workforce Shift Operations Runbook

## 1. Purpose
This runbook defines how admins and operations users manage and monitor Workforce Shift Operations using:
- `Shift Admin Console` (Templates, Assignments, Guided Scheduling)
- `Workforce Monitor` (KPIs and operational queues)

It is intended for day-to-day operations, incident handling, and release-safe administration.

## 2. Scope
In scope:
- Shift template setup and recurring day selection
- Shift assignment creation and conflict prevention
- Guided conflict checks before scheduling
- Workforce KPI monitoring and queue review

Out of scope:
- Employee provisioning and identity onboarding
- Payroll or time-sheet downstream integrations
- External mobile check-in apps

## 3. Key Artifacts
Core Apex:
- `ShiftAdminController`
- `WorkforceAdminMonitorController`

Core LWC:
- `shiftAdminConsole`
- `workforceAdminMonitor`

Primary objects:
- `Shift_Template__c`
- `Shift_Assignment__c`
- `Attendance__c`
- `Leave_Request__c`
- `Case_Assignment__c`
- `Employee__c`

## 4. Role Model
- Workforce Admin / Ops:
  - Create and maintain shift templates
  - Assign shifts and resolve conflicts
  - Review Workforce Monitor KPIs and exception queues
- Compliance/Admin Reviewer:
  - Monitor anomalies and pending leave queue
  - Escalate unresolved scheduling exceptions

## 5. Entry Conditions
Before using this feature:
1. At least one non-reserved employer account exists.
2. Employee records exist and are linked via `Employee__c.Employer_Account__c`.
3. Users have read/write access to shift objects and LWC visibility.
4. `Candidates` account is intentionally excluded from employer dropdown.

## 6. Shift Admin Console Operations

### 6.1 Employer Selection (Required)
1. Open `KT Onboarding` app.
2. Open `Shift Admin Console`.
3. Select `Employer Account`.
4. Confirm templates and assignments load for that account only.

Expected behavior:
- No account is preselected automatically.
- Refresh button remains disabled until an account is selected.

### 6.2 Create Shift Template
1. Go to `Templates` tab.
2. Enter required fields:
   - `Template Name`
   - `Status`
   - `Shift Type`
   - `Start Time`
   - `End Time`
3. Set optional fields:
   - `Break Minutes`
   - `Recurrence`
   - `Days Of Week` (chip selector)
   - `Max Headcount`
   - `Required Skill`
   - `Compliance Required`
   - `Notes`
4. Click `Save Template`.

Expected behavior:
- Success toast appears.
- Template list refreshes in-component (no browser refresh).
- New template appears in `Recent Templates`.

### 6.3 Days Of Week Selection UX
Use quick actions for speed:
- `Weekdays` -> Mon-Fri
- `All Days` -> Mon-Sun
- `Clear` -> remove selection

Manual selection:
- Click day chips to toggle each day.
- Summary line shows current selection.

### 6.4 Create Shift Assignment
1. Go to `Assignments` tab.
2. Select:
   - `Employee`
   - `Template` (optional but recommended)
3. Set:
   - `Shift Date`
   - `Start Time`
   - `End Time`
   - `Status`
4. Optionally set `Location` and `Notes`.
5. Click `Save Assignment`.

Expected behavior:
- Success toast appears.
- Assignment grid refreshes in-component.
- Conflict banner updates as data changes.

### 6.5 Guided Scheduling (Pre-check)
1. Go to `Guided Scheduling`.
2. Provide employee, date, and time window.
3. Click `Check Conflicts`.

Expected behavior:
- `No Conflicts` if safe
- `Conflict Found` with overlapping shifts listed
- Overnight overlap detection is supported

## 7. Workforce Monitor Operations

### 7.1 KPI Monitoring
Monitor:
- Active Templates
- Scheduled Shifts
- Upcoming 7 Days
- Attendance Anomalies
- Late Check-ins (7d)
- Leave Submitted / Approved / Rejected
- Open Case Assignments

### 7.2 Queue Review
Review datatables:
- Scheduled Shifts
- Attendance Exceptions
- Pending Leave Approvals

### 7.3 Refresh Behavior
- Manual refresh icon supported
- Auto-refresh runs at interval (component-side)
- `Last refreshed` timestamp confirms recency

## 8. Validation Checklist (Post Deployment)
1. Open `Shift Admin Console`, confirm version text appears (`Shift Console v5`).
2. Select employer account and verify recent templates load.
3. Create template and verify immediate appearance in list.
4. Create assignment and verify immediate appearance in assignment list.
5. Validate conflict check with overlapping window.
6. Validate overnight conflict scenario.
7. Open `Workforce Monitor` and verify KPIs and queues populate.
8. Confirm refresh icon updates timestamp and data.

## 9. Known Error Conditions and Responses

`Template name is required`
- Cause: empty input or stale UI state.
- Response: ensure template name is entered and retry; component now syncs before save.

`Employer Account is required`
- Cause: account not selected.
- Response: select employer first; refresh and load remain scoped by account.

No records in recent tables
- Cause: no data for selected account, or wrong account selected.
- Response: verify account selection, then click refresh icon.

Raw numeric time values seen
- Cause: old metadata/UI cache.
- Response: hard reload and verify latest version banner.

## 10. Guardrails and AppExchange Readiness
- Explicit account selection avoids accidental cross-account actions.
- Reserved `Candidates` account excluded from scheduling context.
- Server-side validations protect core integrity:
  - required identifiers
  - required time fields
  - disallow identical start/end time
- Conflict engine checks adjacent-day windows for overnight safety.
- In-component refresh avoids dependency on browser reload.

## 11. Operational Cadence
- Shift Admin Console:
  - Use during template/assignment creation windows.
  - Run Guided Scheduling for high-risk coverage periods.
- Workforce Monitor:
  - Review at least 2-3 times/day.
  - Escalate anomaly or leave backlog based on KPI thresholds.

## 12. Escalation Path
If behavior deviates:
1. Capture employer account, template/assignment ids, and timestamp.
2. Capture screenshot of visible toast/error.
3. Run manual refresh in component and confirm reproducibility.
4. Escalate with exact error message and impacted record ids.

