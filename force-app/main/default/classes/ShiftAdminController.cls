public with sharing class ShiftAdminController {
    public class SelectOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class TemplateRow {
        @AuraEnabled public Id templateId;
        @AuraEnabled public String templateName;
        @AuraEnabled public String status;
        @AuraEnabled public String shiftType;
        @AuraEnabled public Time startTime;
        @AuraEnabled public Time endTime;
        @AuraEnabled public String startTimeValue;
        @AuraEnabled public String endTimeValue;
        @AuraEnabled public String startTimeDisplay;
        @AuraEnabled public String endTimeDisplay;
        @AuraEnabled public Integer maxHeadcount;
        @AuraEnabled public String recurrence;
        @AuraEnabled public String daysOfWeek;
    }

    public class AssignmentRow {
        @AuraEnabled public Id assignmentId;
        @AuraEnabled public String assignmentName;
        @AuraEnabled public Date shiftDate;
        @AuraEnabled public Time startTime;
        @AuraEnabled public Time endTime;
        @AuraEnabled public String startTimeValue;
        @AuraEnabled public String endTimeValue;
        @AuraEnabled public String startTimeDisplay;
        @AuraEnabled public String endTimeDisplay;
        @AuraEnabled public String status;
        @AuraEnabled public String employeeName;
        @AuraEnabled public String templateName;
    }

    public class TemplateInput {
        @AuraEnabled public String name;
        @AuraEnabled public String templateName;
        @AuraEnabled public Id employerAccountId;
        @AuraEnabled public String status;
        @AuraEnabled public String shiftType;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public Decimal breakMinutes;
        @AuraEnabled public String recurrence;
        @AuraEnabled public String daysOfWeek;
        @AuraEnabled public Decimal maxHeadcount;
        @AuraEnabled public String requiredSkill;
        @AuraEnabled public Boolean complianceRequired;
        @AuraEnabled public String notes;
    }

    public class AssignmentInput {
        @AuraEnabled public Id employeeId;
        @AuraEnabled public Id templateId;
        @AuraEnabled public Date shiftDate;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public String status;
        @AuraEnabled public String locationName;
        @AuraEnabled public String notes;
    }

    public class ConflictResult {
        @AuraEnabled public Boolean hasConflict;
        @AuraEnabled public String message;
        @AuraEnabled public List<AssignmentRow> conflicts;
    }

    @AuraEnabled(cacheable=true)
    public static List<SelectOption> getEmployerAccounts() {
        List<SelectOption> options = new List<SelectOption>();
        for (Account acct : [
            SELECT Id, Name
            FROM Account
            WHERE Name != 'Candidates'
            ORDER BY Name
            LIMIT 200
        ]) {
            SelectOption option = new SelectOption();
            option.label = acct.Name;
            option.value = acct.Id;
            options.add(option);
        }
        return options;
    }

    @AuraEnabled
    public static List<SelectOption> getEmployees(Id accountId) {
        List<SelectOption> options = new List<SelectOption>();
        List<Employee__c> employees;
        if (accountId != null) {
            employees = [
                SELECT Id, Name
                FROM Employee__c
                WHERE Employer_Account__c = :accountId
                ORDER BY Name
                LIMIT 200
            ];
        } else {
            employees = [
                SELECT Id, Name
                FROM Employee__c
                ORDER BY Name
                LIMIT 200
            ];
        }
        for (Employee__c emp : employees) {
            SelectOption option = new SelectOption();
            option.label = emp.Name;
            option.value = emp.Id;
            options.add(option);
        }
        return options;
    }

    @AuraEnabled
    public static List<SelectOption> getTemplates(Id accountId) {
        List<SelectOption> options = new List<SelectOption>();
        List<Shift_Template__c> templates;
        if (accountId != null) {
            templates = [
                SELECT Id, Name
                FROM Shift_Template__c
                WHERE Employer_Account__c = :accountId
                ORDER BY Name
                LIMIT 200
            ];
        } else {
            templates = [
                SELECT Id, Name
                FROM Shift_Template__c
                ORDER BY Name
                LIMIT 200
            ];
        }
        for (Shift_Template__c template : templates) {
            SelectOption option = new SelectOption();
            option.label = template.Name;
            option.value = template.Id;
            options.add(option);
        }
        return options;
    }

    @AuraEnabled
    public static List<TemplateRow> getTemplateRows(Id accountId) {
        List<TemplateRow> rows = new List<TemplateRow>();
        List<Shift_Template__c> templates;
        if (accountId != null) {
            templates = [
                SELECT Id, Name, Template_Status__c, Shift_Type__c, Start_Time__c, End_Time__c,
                       Max_Headcount__c, Recurrence__c, Days_Of_Week__c
                FROM Shift_Template__c
                WHERE Employer_Account__c = :accountId
                ORDER BY LastModifiedDate DESC
                LIMIT 200
            ];
        } else {
            templates = [
                SELECT Id, Name, Template_Status__c, Shift_Type__c, Start_Time__c, End_Time__c,
                       Max_Headcount__c, Recurrence__c, Days_Of_Week__c
                FROM Shift_Template__c
                ORDER BY LastModifiedDate DESC
                LIMIT 200
            ];
        }
        for (Shift_Template__c template : templates) {
            TemplateRow row = new TemplateRow();
            row.templateId = template.Id;
            row.templateName = template.Name;
            row.status = template.Template_Status__c;
            row.shiftType = template.Shift_Type__c;
            row.startTime = template.Start_Time__c;
            row.endTime = template.End_Time__c;
            row.startTimeValue = formatTime24(template.Start_Time__c);
            row.endTimeValue = formatTime24(template.End_Time__c);
            row.startTimeDisplay = formatTime(template.Start_Time__c);
            row.endTimeDisplay = formatTime(template.End_Time__c);
            row.maxHeadcount = template.Max_Headcount__c != null ? Integer.valueOf(template.Max_Headcount__c) : null;
            row.recurrence = template.Recurrence__c;
            row.daysOfWeek = template.Days_Of_Week__c;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled
    public static List<AssignmentRow> getAssignments(Id accountId, Date startDate, Date endDate) {
        List<AssignmentRow> rows = new List<AssignmentRow>();
        List<Shift_Assignment__c> assignments;
        if (accountId != null && startDate != null && endDate != null) {
            assignments = [
                SELECT Id, Name, Shift_Date__c, Start_Time__c, End_Time__c, Assignment_Status__c,
                       Employee__r.Name, Shift_Template__r.Name
                FROM Shift_Assignment__c
                WHERE Employee__r.Employer_Account__c = :accountId
                AND Shift_Date__c >= :startDate
                AND Shift_Date__c <= :endDate
                ORDER BY Shift_Date__c DESC, Start_Time__c DESC
                LIMIT 200
            ];
        } else if (accountId != null && startDate != null) {
            assignments = [
                SELECT Id, Name, Shift_Date__c, Start_Time__c, End_Time__c, Assignment_Status__c,
                       Employee__r.Name, Shift_Template__r.Name
                FROM Shift_Assignment__c
                WHERE Employee__r.Employer_Account__c = :accountId
                AND Shift_Date__c >= :startDate
                ORDER BY Shift_Date__c DESC, Start_Time__c DESC
                LIMIT 200
            ];
        } else if (accountId != null && endDate != null) {
            assignments = [
                SELECT Id, Name, Shift_Date__c, Start_Time__c, End_Time__c, Assignment_Status__c,
                       Employee__r.Name, Shift_Template__r.Name
                FROM Shift_Assignment__c
                WHERE Employee__r.Employer_Account__c = :accountId
                AND Shift_Date__c <= :endDate
                ORDER BY Shift_Date__c DESC, Start_Time__c DESC
                LIMIT 200
            ];
        } else if (accountId != null) {
            assignments = [
                SELECT Id, Name, Shift_Date__c, Start_Time__c, End_Time__c, Assignment_Status__c,
                       Employee__r.Name, Shift_Template__r.Name
                FROM Shift_Assignment__c
                WHERE Employee__r.Employer_Account__c = :accountId
                ORDER BY Shift_Date__c DESC, Start_Time__c DESC
                LIMIT 200
            ];
        } else if (startDate != null && endDate != null) {
            assignments = [
                SELECT Id, Name, Shift_Date__c, Start_Time__c, End_Time__c, Assignment_Status__c,
                       Employee__r.Name, Shift_Template__r.Name
                FROM Shift_Assignment__c
                WHERE Shift_Date__c >= :startDate
                AND Shift_Date__c <= :endDate
                ORDER BY Shift_Date__c DESC, Start_Time__c DESC
                LIMIT 200
            ];
        } else if (startDate != null) {
            assignments = [
                SELECT Id, Name, Shift_Date__c, Start_Time__c, End_Time__c, Assignment_Status__c,
                       Employee__r.Name, Shift_Template__r.Name
                FROM Shift_Assignment__c
                WHERE Shift_Date__c >= :startDate
                ORDER BY Shift_Date__c DESC, Start_Time__c DESC
                LIMIT 200
            ];
        } else if (endDate != null) {
            assignments = [
                SELECT Id, Name, Shift_Date__c, Start_Time__c, End_Time__c, Assignment_Status__c,
                       Employee__r.Name, Shift_Template__r.Name
                FROM Shift_Assignment__c
                WHERE Shift_Date__c <= :endDate
                ORDER BY Shift_Date__c DESC, Start_Time__c DESC
                LIMIT 200
            ];
        } else {
            assignments = [
                SELECT Id, Name, Shift_Date__c, Start_Time__c, End_Time__c, Assignment_Status__c,
                       Employee__r.Name, Shift_Template__r.Name
                FROM Shift_Assignment__c
                ORDER BY Shift_Date__c DESC, Start_Time__c DESC
                LIMIT 200
            ];
        }
        for (Shift_Assignment__c assignment : assignments) {
            AssignmentRow row = new AssignmentRow();
            row.assignmentId = assignment.Id;
            row.assignmentName = assignment.Name;
            row.shiftDate = assignment.Shift_Date__c;
            row.startTime = assignment.Start_Time__c;
            row.endTime = assignment.End_Time__c;
            row.startTimeValue = formatTime24(assignment.Start_Time__c);
            row.endTimeValue = formatTime24(assignment.End_Time__c);
            row.startTimeDisplay = formatTime(assignment.Start_Time__c);
            row.endTimeDisplay = formatTime(assignment.End_Time__c);
            row.status = assignment.Assignment_Status__c;
            row.employeeName = assignment.Employee__r != null ? assignment.Employee__r.Name : null;
            row.templateName = assignment.Shift_Template__r != null ? assignment.Shift_Template__r.Name : null;
            rows.add(row);
        }
        return rows;
    }

    @AuraEnabled
    public static Id createTemplateFromFields(
        String templateName,
        Id employerAccountId,
        String status,
        String shiftType,
        String startTime,
        String endTime,
        Decimal breakMinutes,
        String recurrence,
        String daysOfWeek,
        Decimal maxHeadcount,
        String requiredSkill,
        Boolean complianceRequired,
        String notes
    ) {
        String resolvedTemplateName = firstNonBlank(
            new List<String>{ templateName }
        );
        if (String.isBlank(resolvedTemplateName)) {
            throw new AuraHandledException('Template name is required.');
        }
        if (employerAccountId == null) {
            throw new AuraHandledException('Employer Account is required.');
        }
        Time parsedStartTime = parseTime(startTime, 'Start Time');
        Time parsedEndTime = parseTime(endTime, 'End Time');
        if (parsedStartTime == null || parsedEndTime == null) {
            throw new AuraHandledException('Start Time and End Time are required.');
        }
        if (parsedEndTime == parsedStartTime) {
            throw new AuraHandledException('Start Time and End Time cannot be the same.');
        }
        Shift_Template__c template = new Shift_Template__c();
        template.Name = resolvedTemplateName.trim();
        template.Employer_Account__c = employerAccountId;
        template.Template_Status__c = status;
        template.Shift_Type__c = shiftType;
        template.Start_Time__c = parsedStartTime;
        template.End_Time__c = parsedEndTime;
        template.Break_Minutes__c = breakMinutes;
        template.Recurrence__c = recurrence;
        template.Days_Of_Week__c = daysOfWeek;
        template.Max_Headcount__c = maxHeadcount;
        template.Required_Skill__c = requiredSkill;
        template.Compliance_Required__c = complianceRequired;
        template.Notes__c = notes;
        insert template;
        return template.Id;
    }

    @AuraEnabled
    public static Id createTemplate(TemplateInput input) {
        if (input == null) {
            throw new AuraHandledException('Template input is required.');
        }
        return createTemplateFromFields(
            firstNonBlank(new List<String>{ input.templateName, input.name }),
            input.employerAccountId,
            input.status,
            input.shiftType,
            input.startTime,
            input.endTime,
            input.breakMinutes,
            input.recurrence,
            input.daysOfWeek,
            input.maxHeadcount,
            input.requiredSkill,
            input.complianceRequired,
            input.notes
        );
    }

    private static String firstNonBlank(List<String> values) {
        if (values == null) {
            return null;
        }
        for (String value : values) {
            if (!String.isBlank(value)) {
                return value;
            }
        }
        return null;
    }

    @AuraEnabled
    public static Id createAssignment(AssignmentInput input) {
        if (input == null) {
            throw new AuraHandledException('Assignment input is required.');
        }
        if (input.employeeId == null) {
            throw new AuraHandledException('Employee is required.');
        }
        if (input.shiftDate == null) {
            throw new AuraHandledException('Shift Date is required.');
        }
        Time startTime = parseTime(input.startTime, 'Start Time');
        Time endTime = parseTime(input.endTime, 'End Time');
        if (startTime == null || endTime == null) {
            throw new AuraHandledException('Start Time and End Time are required.');
        }
        if (endTime == startTime) {
            throw new AuraHandledException('Start Time and End Time cannot be the same.');
        }
        Shift_Assignment__c assignment = new Shift_Assignment__c();
        assignment.Employee__c = input.employeeId;
        assignment.Shift_Template__c = input.templateId;
        assignment.Shift_Date__c = input.shiftDate;
        assignment.Start_Time__c = startTime;
        assignment.End_Time__c = endTime;
        assignment.Assignment_Status__c = input.status;
        assignment.Location_Name__c = input.locationName;
        assignment.Notes__c = input.notes;
        assignment.Assigned_By__c = UserInfo.getUserId();
        insert assignment;
        return assignment.Id;
    }

    @AuraEnabled
    public static void deleteTemplate(Id templateId) {
        if (templateId == null) {
            throw new AuraHandledException('Template Id is required.');
        }
        try {
            Shift_Template__c templateToDelete = [
                SELECT Id
                FROM Shift_Template__c
                WHERE Id = :templateId
                LIMIT 1
            ];
            delete templateToDelete;
        } catch (QueryException ex) {
            throw new AuraHandledException('Template record not found.');
        } catch (DmlException ex) {
            throw new AuraHandledException('Unable to delete template. Remove dependent records first.');
        }
    }

    private static Time parseTime(String timeValue, String label) {
        if (String.isBlank(timeValue)) {
            return null;
        }
        List<String> parts = timeValue.split(':');
        if (parts.size() < 2) {
            throw new AuraHandledException(label + ' must be in HH:MM format.');
        }
        Integer hours = Integer.valueOf(parts[0]);
        Integer minutes = Integer.valueOf(parts[1]);
        if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
            throw new AuraHandledException(label + ' must be a valid time.');
        }
        return Time.newInstance(hours, minutes, 0, 0);
    }

    private static String formatTime(Time value) {
        if (value == null) {
            return null;
        }
        Integer hour24 = value.hour();
        Integer minute = value.minute();
        String meridiem = hour24 >= 12 ? 'PM' : 'AM';
        Integer hour12 = Math.mod(hour24, 12);
        if (hour12 == 0) {
            hour12 = 12;
        }
        return String.valueOf(hour12) + ':' + String.valueOf(minute).leftPad(2, '0') + ' ' + meridiem;
    }

    private static String formatTime24(Time value) {
        if (value == null) {
            return null;
        }
        return String.valueOf(value.hour()).leftPad(2, '0') + ':' + String.valueOf(value.minute()).leftPad(2, '0');
    }

    private class TimeWindow {
        Datetime startAt;
        Datetime endAt;
    }

    private static TimeWindow buildWindow(Date dateValue, Time startTime, Time endTime) {
        TimeWindow window = new TimeWindow();
        window.startAt = Datetime.newInstance(dateValue, startTime);
        window.endAt = Datetime.newInstance(dateValue, endTime);
        if (endTime <= startTime) {
            window.endAt = window.endAt.addDays(1);
        }
        return window;
    }

    private static Boolean isOverlapping(TimeWindow left, TimeWindow right) {
        return left.startAt < right.endAt && left.endAt > right.startAt;
    }

    @AuraEnabled
    public static ConflictResult checkAssignmentConflicts(
        Id employeeId,
        Date shiftDate,
        String startTime,
        String endTime
    ) {
        ConflictResult result = new ConflictResult();
        result.conflicts = new List<AssignmentRow>();
        Time parsedStart = parseTime(startTime, 'Start Time');
        Time parsedEnd = parseTime(endTime, 'End Time');
        if (employeeId == null || shiftDate == null || parsedStart == null || parsedEnd == null) {
            result.hasConflict = false;
            result.message = 'Provide employee, date, start, and end time to check conflicts.';
            return result;
        }
        if (parsedEnd == parsedStart) {
            result.hasConflict = true;
            result.message = 'Start time and end time cannot be the same.';
            return result;
        }

        TimeWindow candidateWindow = buildWindow(shiftDate, parsedStart, parsedEnd);
        Date previousDate = shiftDate.addDays(-1);
        Date nextDate = shiftDate.addDays(1);

        List<Shift_Assignment__c> nearbyShifts = [
            SELECT Id, Name, Shift_Date__c, Start_Time__c, End_Time__c, Assignment_Status__c,
                   Employee__r.Name, Shift_Template__r.Name
            FROM Shift_Assignment__c
            WHERE Employee__c = :employeeId
            AND Shift_Date__c >= :previousDate
            AND Shift_Date__c <= :nextDate
            AND Assignment_Status__c != 'Cancelled'
            ORDER BY Shift_Date__c ASC, Start_Time__c ASC
            LIMIT 50
        ];

        List<Shift_Assignment__c> overlaps = new List<Shift_Assignment__c>();
        for (Shift_Assignment__c existingShift : nearbyShifts) {
            if (existingShift.Shift_Date__c == null || existingShift.Start_Time__c == null || existingShift.End_Time__c == null) {
                continue;
            }
            TimeWindow existingWindow = buildWindow(
                existingShift.Shift_Date__c,
                existingShift.Start_Time__c,
                existingShift.End_Time__c
            );
            if (isOverlapping(candidateWindow, existingWindow)) {
                overlaps.add(existingShift);
                if (overlaps.size() == 5) {
                    break;
                }
            }
        }

        if (!overlaps.isEmpty()) {
            result.hasConflict = true;
            result.message = 'This employee already has a shift that overlaps the selected time.';
            for (Shift_Assignment__c assignment : overlaps) {
                AssignmentRow row = new AssignmentRow();
                row.assignmentId = assignment.Id;
                row.assignmentName = assignment.Name;
                row.shiftDate = assignment.Shift_Date__c;
                row.startTime = assignment.Start_Time__c;
                row.endTime = assignment.End_Time__c;
                row.startTimeValue = formatTime24(assignment.Start_Time__c);
                row.endTimeValue = formatTime24(assignment.End_Time__c);
                row.startTimeDisplay = formatTime(assignment.Start_Time__c);
                row.endTimeDisplay = formatTime(assignment.End_Time__c);
                row.status = assignment.Assignment_Status__c;
                row.employeeName = assignment.Employee__r != null ? assignment.Employee__r.Name : null;
                row.templateName = assignment.Shift_Template__r != null ? assignment.Shift_Template__r.Name : null;
                result.conflicts.add(row);
            }
        } else {
            result.hasConflict = false;
            result.message = 'No conflicts detected.';
        }
        return result;
    }
}
