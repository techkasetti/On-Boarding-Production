# Employee Domain Foundation

## Scope
This document closes five immediate gaps before Workforce Management feature build:

1. `EmployeeConversionService` implementation for flow dependency
2. Explicit `Candidate -> Employee` conversion mapping
3. Employee permission model definition
4. Introduction of `Employee__c` and `Employment_Contract__c`
5. Single identity strategy across candidate and employee phases

## Implemented Artifacts

### Apex
- `EmployeeConversionService.cls`
- `EmployeeIdentityStrategyService.cls`
- `EmployeeConversionServiceTest.cls`
- `EmployeeIdentityStrategyServiceTest.cls`

### Objects
- `Employee__c`
- `Employment_Contract__c`

### Candidate extensions
- `Candidate__c.Employee__c`
- `Candidate__c.Identity_Phase__c`
- `Candidate__c.Converted_To_Employee_On__c`

### Permission Sets
- `Employee_Experience_User`
- `Employee_Internal_Operations`

## Flow Dependency
`Convert_Candidate_To_Employee` flow (triggered on `Job_Application__c.Status__c = Offer Accepted`) calls Apex action `EmployeeConversionService`.

`EmployeeConversionService` is implemented as invocable and idempotent:
- Reuses existing employee record when already converted.
- Reuses existing contract by job application.

## Candidate -> Employee Conversion Mapping

| Source | Target | Rule |
|---|---|---|
| `Job_Application__c.Id` | `Employee__c.Source_Job_Application__c` | direct |
| `Job_Application__c.Candidate__c` | `Employee__c.Candidate__c` | direct |
| `Candidate__c.Contact__c` | `Employee__c.Contact__c` | direct |
| `Candidate__c.User__c` | `Employee__c.User__c` | direct |
| `Candidate__c.Related_Account__c` or `Contact.AccountId` | `Employee__c.Employer_Account__c` | fallback to contact account |
| `Candidate__c.Email__c` or `Contact.Email` | `Employee__c.Work_Email__c` | fallback logic |
| `Candidate__c.Phone__c` or `Contact.Phone` | `Employee__c.Work_Phone__c` | fallback logic |
| `Candidate__c.Role__c` | `Employee__c.Role__c` | direct |
| system date | `Employee__c.Join_Date__c` | default |
| fixed | `Employee__c.Employment_Status__c` | `Pending Activation` |
| fixed | `Employee__c.Identity_Mode__c` | `Experience Only` |
| computed | `Employee__c.Identity_Key__c` | `USR:<UserId>` else `CON:<ContactId>` else `CAN:<CandidateId>` |

### Contract mapping
| Source | Target | Rule |
|---|---|---|
| Employee id | `Employment_Contract__c.Employee__c` | direct |
| Candidate id | `Employment_Contract__c.Candidate__c` | direct |
| Job application id | `Employment_Contract__c.Job_Application__c` | direct |
| Employer account | `Employment_Contract__c.Employer_Account__c` | from employee |
| `Job_Application__c.Application_Date__c` | `Employment_Contract__c.Offered_On__c` | direct |
| system date | `Employment_Contract__c.Offer_Accepted_On__c` | default |
| system date | `Employment_Contract__c.Effective_Start_Date__c` | default |
| `Job_Application__c.Applied_From__c` | `Employment_Contract__c.Source_Channel__c` | fallback `Experience Cloud` |
| fixed | `Employment_Contract__c.Contract_Type__c` | `Contract` |
| fixed | `Employment_Contract__c.Contract_Status__c` | `Active` |
| fixed | `Employment_Contract__c.Identity_Strategy__c` | `Reuse Existing Experience User` |

### Candidate updates after conversion
- `Candidate__c.Employee__c = Employee Id`
- `Candidate__c.Status__c = Hired`
- `Candidate__c.Identity_Phase__c = Employee External` (or internal/hybrid by mode)
- `Candidate__c.Converted_To_Employee_On__c = now()`

## Permission Model

### 1) Employee Experience User (external)
- Purpose: workforce self-service in Experience Cloud only
- Object access:
  - `Employee__c`: read + limited edit
  - `Employment_Contract__c`: read only
- No internal operations class access

### 2) Employee Internal Operations
- Purpose: HR/ops/admin conversion and lifecycle control
- Class access:
  - `EmployeeConversionService`
  - `EmployeeIdentityStrategyService`
- Object access:
  - `Employee__c`: create/read/edit
  - `Employment_Contract__c`: create/read/edit
  - `Candidate__c`: read/edit (conversion fields)
  - `Job_Application__c`: read

## Identity Strategy (single user continuity)

### Principle
Maintain one person identity across phases wherever possible:
- Candidate phase user identity is reused in employee phase.
- Do not create duplicate external users for same contact.

### Modes
- `Experience Only`: employee uses Experience Cloud only.
- `Internal Only`: employee operates through internal Salesforce app only.
- `Hybrid`: both channels are allowed.

### Runtime controls
`EmployeeIdentityStrategyService.applyIdentityMode(employeeId, mode)`:
- Updates `Employee__c.Identity_Mode__c`
- Updates `Employee__c.Is_External_Login_Only__c`
- Updates `Candidate__c.Identity_Phase__c`
- Assigns permission sets when user exists:
  - `Employee_Experience_User`
  - `Employee_Internal_Operations`

## Notes
- This phase establishes foundation only; Workforce scheduling/attendance/leave/case/medical operations are next-phase features.
- No destructive changes were made to existing candidate/job objects beyond additive candidate fields.
