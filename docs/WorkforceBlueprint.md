# Workforce Foundation Blueprint (Finalized Metadata)

## Scope
Initial objects and automation for workforce management, now implemented as Salesforce metadata:
- Shift Template
- Shift Assignment
- Attendance
- Leave
- Case Assignment (medical domain)

This blueprint is metadata-focused: object model, fields, relationships, automation, and security model.

## Object Model Summary (Implemented)

1) `Shift_Template__c`
- Purpose: Define recurring shift patterns and rules.
- Key relationships:
  - `Employer_Account__c -> Account`
  - `Primary_Role__c -> Role/Skill (picklist)`

2) `Shift_Assignment__c`
- Purpose: Concrete scheduled shift for an employee.
- Key relationships:
  - `Employee__c -> Employee__c`
  - `Shift_Template__c -> Shift_Template__c` (optional)
  - `Location__c -> Location__c` (optional future)

3) `Attendance__c`
- Purpose: Check-in/check-out records, exceptions.
- Key relationships:
  - `Employee__c -> Employee__c`
  - `Shift_Assignment__c -> Shift_Assignment__c` (optional)

4) `Leave_Request__c`
- Purpose: Leave/absence requests and approval status.
- Key relationships:
  - `Employee__c -> Employee__c`

5) `Case_Assignment__c`
- Purpose: Assign patient/case workload to staff.
- Key relationships:
  - `Employee__c -> Employee__c`
  - `Case__c -> Case` (standard object)

## Field Matrix (Final Picklists + Routing)

### Shift_Template__c
- `Name` (Text, required)
- `Employer_Account__c` (Lookup -> Account, required)
- `Template_Status__c` (Picklist, restricted: Draft [default], Active, Archived)
- `Shift_Type__c` (Picklist, restricted: Day, Evening, Night, On-Call)
- `Start_Time__c` (Time, required)
- `End_Time__c` (Time, required)
- `Break_Minutes__c` (Number, 0-240)
- `Recurrence__c` (Picklist, restricted: None [default], Daily, Weekly, Biweekly)
- `Days_Of_Week__c` (Multiselect, restricted: Mon, Tue, Wed, Thu, Fri, Sat, Sun)
- `Max_Headcount__c` (Number, 1-500)
- `Required_Skill__c` (Picklist, restricted: Nurse, Physician, Medical Assistant, Billing)
- `Compliance_Required__c` (Checkbox)
- `Notes__c` (Long Text)

### Shift_Assignment__c
- `Name` (AutoNumber SA-{000000})
- `Employee__c` (Lookup -> Employee__c, required)
- `Shift_Template__c` (Lookup -> Shift_Template__c)
- `Shift_Date__c` (Date, required)
- `Start_Time__c` (Time, required)
- `End_Time__c` (Time, required)
- `Assignment_Status__c` (Picklist, restricted: Scheduled [default], Confirmed, Completed, Cancelled)
- `Assigned_By__c` (Lookup -> User)
- `Location_Name__c` (Text)
- `Notes__c` (Long Text)

### Attendance__c
- `Name` (AutoNumber AT-{000000})
- `Employee__c` (Lookup -> Employee__c, required)
- `Shift_Assignment__c` (Lookup -> Shift_Assignment__c)
- `Check_In__c` (DateTime)
- `Check_Out__c` (DateTime)
- `Check_In_Method__c` (Picklist, restricted: Web, Mobile, Kiosk, Offline Sync)
- `GPS_Lat__c` (Number 10,6)
- `GPS_Lng__c` (Number 10,6)
- `Verification_Status__c` (Picklist, restricted: Unverified [default], Verified, Failed)
- `Anomaly_Flag__c` (Checkbox)
- `Anomaly_Reason__c` (Text)
- `Notes__c` (Long Text)

### Leave_Request__c
- `Name` (AutoNumber LV-{000000})
- `Employee__c` (Lookup -> Employee__c, required)
- `Leave_Type__c` (Picklist, restricted: Sick, Vacation, Emergency, Unpaid, Other)
- `Start_Date__c` (Date, required)
- `End_Date__c` (Date, required)
- `Duration_Days__c` (Formula)
- `Status__c` (Picklist, restricted: Draft [default], Submitted, Approved, Rejected, Cancelled)
- `Approver__c` (Lookup -> User)
- `Reason__c` (Long Text)

### Case_Assignment__c
- `Name` (AutoNumber CA-{000000})
- `Employee__c` (Lookup -> Employee__c, required)
- `Case__c` (Lookup -> Case, required)
- `Assignment_Status__c` (Picklist, restricted: Assigned [default], In Progress, Completed, Escalated)
- `Assigned_On__c` (DateTime)
- `Notes__c` (Long Text)

## Relationships
- `Employee__c` is the anchor for workforce records.
- All workforce objects should include `Employer_Account__c` if multi-tenant or multi-facility is required later.
- `Shift_Assignment__c` optionally links to `Shift_Template__c` for templates.

## Automation Map (Implemented)

1) Shift Template Activation
- Trigger: `Shift_Template__c.Template_Status__c = Active`
- Action: Validate `Start_Time__c < End_Time__c`, `Days_Of_Week__c` set for recurring templates.
- Tool: Validation Rule or Record-Triggered Flow.

2) Shift Assignment Creation
- Trigger: On insert/update of `Shift_Assignment__c`
- Action: Auto-calc `Start_Time__c`/`End_Time__c` from template if provided.
- Tool: Record-Triggered Flow (`Shift_Assignment_Default_Times`).

3) Attendance Capture
- Trigger: Create/Update `Attendance__c` from mobile/web check-in.
- Action: Flag anomaly if outside time window or location.
- Tool: Apex (for rules) + Flow (for notifications).

4) Leave Approval (Routing)
- Trigger: `Leave_Request__c.Status__c = Submitted`
- Action: Create approval task assigned to `Approver__c` if set, else `OwnerId`.
- Tool: Record-Triggered Flow (`Leave_Request_Create_Approval_Task`).

5) Case Assignment
- Trigger: Case created/updated with certain criteria.
- Action: Assign to Employee using scheduling/skill match.
- Tool: Apex for scoring + Flow for assignment.

## Security Model
- Internal Ops:
  - Full CRUD on all workforce objects.
  - ViewAll on `Shift_Assignment__c`, `Attendance__c`.
- Employee (Experience):
  - Read on `Shift_Assignment__c`
  - Create/Edit own `Attendance__c` and `Leave_Request__c`
  - Read own `Case_Assignment__c`

## Reports/Dashboards (Initial)
- Pending Compliance vs Attendance Anomalies
- Unfilled Shifts (no assignments)
- Leave utilization by month
- Case load by employee

## Next Steps
1. Decide if `Location__c` should be a new object or standard `Location`.
2. Define anomaly rules for attendance.
3. Add permission sets, tabs, and layouts for workforce objects if needed.
