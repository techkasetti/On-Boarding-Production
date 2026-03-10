public with sharing class WorkforceAdminMonitorController {
    public class ShiftRow {
        @AuraEnabled public Id shiftId;
        @AuraEnabled public String shiftName;
        @AuraEnabled public Date shiftDate;
        @AuraEnabled public Time startTime;
        @AuraEnabled public Time endTime;
        @AuraEnabled public String startTimeDisplay;
        @AuraEnabled public String endTimeDisplay;
        @AuraEnabled public String status;
        @AuraEnabled public String employeeName;
    }

    public class AttendanceRow {
        @AuraEnabled public Id attendanceId;
        @AuraEnabled public String attendanceName;
        @AuraEnabled public Datetime checkIn;
        @AuraEnabled public String verificationStatus;
        @AuraEnabled public Boolean anomalyFlag;
        @AuraEnabled public String anomalyReason;
        @AuraEnabled public String employeeName;
    }

    public class LeaveRow {
        @AuraEnabled public Id leaveId;
        @AuraEnabled public String leaveName;
        @AuraEnabled public String employeeName;
        @AuraEnabled public String leaveType;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String status;
        @AuraEnabled public String approverName;
    }

    public class Snapshot {
        @AuraEnabled public Datetime generatedAt;
        @AuraEnabled public Integer activeTemplates;
        @AuraEnabled public Integer upcomingAssignments7Days;
        @AuraEnabled public Integer scheduledAssignments;
        @AuraEnabled public Integer attendanceAnomalies;
        @AuraEnabled public Integer lateCheckins7Days;
        @AuraEnabled public Integer leaveSubmitted;
        @AuraEnabled public Integer leaveApproved;
        @AuraEnabled public Integer leaveRejected;
        @AuraEnabled public Integer openCaseAssignments;
        @AuraEnabled public List<ShiftRow> scheduledShiftQueue;
        @AuraEnabled public List<AttendanceRow> attendanceExceptions;
        @AuraEnabled public List<LeaveRow> pendingLeaveQueue;
    }

    @AuraEnabled(cacheable=true)
    public static Snapshot getHomeSnapshot(Integer maxRows) {
        Integer limitSize = normalizeLimit(maxRows);
        Snapshot snapshot = new Snapshot();
        snapshot.generatedAt = System.now();
        snapshot.activeTemplates = (Integer)Database.countQuery(
            'SELECT COUNT() FROM Shift_Template__c WHERE Template_Status__c = \'Active\''
        );
        snapshot.upcomingAssignments7Days = (Integer)Database.countQuery(
            'SELECT COUNT() FROM Shift_Assignment__c WHERE Shift_Date__c = NEXT_N_DAYS:7'
        );
        snapshot.scheduledAssignments = (Integer)Database.countQuery(
            'SELECT COUNT() FROM Shift_Assignment__c WHERE Assignment_Status__c = \'Scheduled\''
        );
        snapshot.attendanceAnomalies = (Integer)Database.countQuery(
            'SELECT COUNT() FROM Attendance__c WHERE Anomaly_Flag__c = true'
        );
        snapshot.leaveSubmitted = (Integer)Database.countQuery(
            'SELECT COUNT() FROM Leave_Request__c WHERE Status__c = \'Submitted\''
        );
        snapshot.leaveApproved = (Integer)Database.countQuery(
            'SELECT COUNT() FROM Leave_Request__c WHERE Status__c = \'Approved\''
        );
        snapshot.leaveRejected = (Integer)Database.countQuery(
            'SELECT COUNT() FROM Leave_Request__c WHERE Status__c = \'Rejected\''
        );
        snapshot.openCaseAssignments = (Integer)Database.countQuery(
            'SELECT COUNT() FROM Case_Assignment__c WHERE Assignment_Status__c != \'Completed\''
        );
        snapshot.lateCheckins7Days = countLateCheckins();

        snapshot.scheduledShiftQueue = buildShiftQueue(limitSize);
        snapshot.attendanceExceptions = buildAttendanceQueue(limitSize);
        snapshot.pendingLeaveQueue = buildLeaveQueue(limitSize);
        return snapshot;
    }

    private static Integer normalizeLimit(Integer limitSize) {
        if (limitSize == null || limitSize <= 0) {
            return 10;
        }
        return Math.min(50, limitSize);
    }

    private static Integer countLateCheckins() {
        List<Attendance__c> recentAttendance = [
            SELECT Id, Check_In__c, Shift_Assignment__r.Shift_Date__c, Shift_Assignment__r.Start_Time__c
            FROM Attendance__c
            WHERE Check_In__c = LAST_N_DAYS:7
            AND Shift_Assignment__c != null
            AND Shift_Assignment__r.Start_Time__c != null
            AND Shift_Assignment__r.Shift_Date__c != null
        ];

        Integer lateCount = 0;
        for (Attendance__c attendance : recentAttendance) {
            Datetime shiftStart = Datetime.newInstance(
                attendance.Shift_Assignment__r.Shift_Date__c,
                attendance.Shift_Assignment__r.Start_Time__c
            );
            if (attendance.Check_In__c != null && attendance.Check_In__c > shiftStart.addMinutes(15)) {
                lateCount++;
            }
        }
        return lateCount;
    }

    private static List<ShiftRow> buildShiftQueue(Integer limitSize) {
        List<ShiftRow> rows = new List<ShiftRow>();
        for (Shift_Assignment__c shift : [
            SELECT Id, Name, Shift_Date__c, Start_Time__c, End_Time__c, Assignment_Status__c,
                   Employee__r.Name
            FROM Shift_Assignment__c
            WHERE Assignment_Status__c = 'Scheduled'
            ORDER BY Shift_Date__c ASC
            LIMIT :limitSize
        ]) {
            ShiftRow row = new ShiftRow();
            row.shiftId = shift.Id;
            row.shiftName = shift.Name;
            row.shiftDate = shift.Shift_Date__c;
            row.startTime = shift.Start_Time__c;
            row.endTime = shift.End_Time__c;
            row.startTimeDisplay = formatTime(shift.Start_Time__c);
            row.endTimeDisplay = formatTime(shift.End_Time__c);
            row.status = shift.Assignment_Status__c;
            row.employeeName = shift.Employee__r != null ? shift.Employee__r.Name : null;
            rows.add(row);
        }
        return rows;
    }

    private static List<AttendanceRow> buildAttendanceQueue(Integer limitSize) {
        List<AttendanceRow> rows = new List<AttendanceRow>();
        for (Attendance__c attendance : [
            SELECT Id, Name, Check_In__c, Verification_Status__c, Anomaly_Flag__c, Anomaly_Reason__c,
                   Employee__r.Name
            FROM Attendance__c
            WHERE Anomaly_Flag__c = true OR Verification_Status__c = 'Failed'
            ORDER BY Check_In__c DESC
            LIMIT :limitSize
        ]) {
            AttendanceRow row = new AttendanceRow();
            row.attendanceId = attendance.Id;
            row.attendanceName = attendance.Name;
            row.checkIn = attendance.Check_In__c;
            row.verificationStatus = attendance.Verification_Status__c;
            row.anomalyFlag = attendance.Anomaly_Flag__c;
            row.anomalyReason = attendance.Anomaly_Reason__c;
            row.employeeName = attendance.Employee__r != null ? attendance.Employee__r.Name : null;
            rows.add(row);
        }
        return rows;
    }

    private static List<LeaveRow> buildLeaveQueue(Integer limitSize) {
        List<LeaveRow> rows = new List<LeaveRow>();
        for (Leave_Request__c leaveRequest : [
            SELECT Id, Name, Leave_Type__c, Start_Date__c, End_Date__c, Status__c,
                   Employee__r.Name, Approver__r.Name
            FROM Leave_Request__c
            WHERE Status__c = 'Submitted'
            ORDER BY CreatedDate DESC
            LIMIT :limitSize
        ]) {
            LeaveRow row = new LeaveRow();
            row.leaveId = leaveRequest.Id;
            row.leaveName = leaveRequest.Name;
            row.employeeName = leaveRequest.Employee__r != null ? leaveRequest.Employee__r.Name : null;
            row.leaveType = leaveRequest.Leave_Type__c;
            row.startDate = leaveRequest.Start_Date__c;
            row.endDate = leaveRequest.End_Date__c;
            row.status = leaveRequest.Status__c;
            row.approverName = leaveRequest.Approver__r != null ? leaveRequest.Approver__r.Name : null;
            rows.add(row);
        }
        return rows;
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
}