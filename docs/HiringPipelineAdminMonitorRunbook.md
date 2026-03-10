# Hiring Pipeline Admin Monitor Runbook

## Purpose
Monitor and control the candidate state machine:

`Offer Accepted -> Offer Accepted - Compliance Pending -> Hired`

## Home Page Setup (One Time)
1. Go to `Setup -> App Builder`.
2. Open `Home_Page_Default2` (the Home page used by `KT Onboarding`).
3. Drag component `candidateHiringMonitor` onto the page.
4. Set `Rows Per Queue` to `10` (or your preferred value).
5. Save and Activate:
   - Assign to App: `KT Onboarding`
   - Profile scope: admin/operations profiles.

## What the Monitor Shows
- `Pending Compliance`: candidates at `Offer Accepted - Compliance Pending`.
- `Ready But Pending`: HIPAA completed (status + training date + acknowledgment date) but candidate still not `Hired`.
- `Pending Missing Employee`: pending candidates without `Employee__c` link.
- `Aging > 3 Days`: pending candidates older than 3 days since `Converted_To_Employee_On__c`.
- `Converted Last 7 Days`
- `Conversion Success (7d)`: count of successful conversions logged in `Employee_Conversion_Audit__c`.
- `Conversion Fail (7d)`: count of failed conversions logged in `Employee_Conversion_Audit__c`.
- `Hired Last 7 Days`
- `Avg Pending Age (Days)`
- `Last Conversion Failure`: latest failure message + timestamp from audit log.

Queues:
- Ready to Promote But Still Pending
- Pending Missing Employee Link
- Oldest Pending Compliance

## Daily Admin SOP
1. Open `KT Onboarding -> Home`.
2. Click refresh icon in `Hiring Pipeline Monitor`.
3. Resolve `Ready But Pending` first:
   - Open candidate from table link.
   - Check related HIPAA record values and flow failures.
4. Resolve `Pending Missing Employee Link`:
   - Ensure conversion process created/linked `Employee__c`.
5. Work `Oldest Pending Compliance` by descending age priority.

## Escalation Checks (If Counts Don't Move)
1. `Setup -> Paused and Failed Flow Interviews`.
2. Check flow failures for:
   - `HIPAA Compliance - Promote Candidate To Hired`
   - `Convert Candidate To Employee`
3. Validate candidate fields:
   - `Status__c`
   - `Employee__c`
   - `Converted_To_Employee_On__c`
   - `PHI_Access_Granted__c`
4. Validate HIPAA fields:
   - `Status__c = Completed`
   - `HIPAA_Training_Completed_Date__c` populated
   - `Acknowledgment_Signed_Date__c` populated
5. Check audit log:
   - Object: `Employee_Conversion_Audit__c`
   - Filter: `Stage__c = Conversion` and `Status__c = Failed`
   - Review `Message__c` and `Occurred_At__c` for root cause.
