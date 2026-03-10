@IsTest
public class WorkforceAdminMonitorControllerTest {
    @IsTest
    static void testSnapshotCounts() {
        Account employer = new Account(Name = 'Test Health Org');
        insert employer;

        Employee__c employee = new Employee__c(Employer_Account__c = employer.Id);
        insert employee;

        Shift_Template__c template = new Shift_Template__c(
            Name = 'Day Shift',
            Employer_Account__c = employer.Id,
            Template_Status__c = 'Active',
            Shift_Type__c = 'Day',
            Start_Time__c = Time.newInstance(9, 0, 0, 0),
            End_Time__c = Time.newInstance(17, 0, 0, 0),
            Recurrence__c = 'Weekly',
            Days_Of_Week__c = 'Mon;Tue'
        );
        insert template;

        Shift_Assignment__c assignment = new Shift_Assignment__c(
            Employee__c = employee.Id,
            Shift_Template__c = template.Id,
            Shift_Date__c = System.today(),
            Start_Time__c = Time.newInstance(9, 0, 0, 0),
            End_Time__c = Time.newInstance(17, 0, 0, 0),
            Assignment_Status__c = 'Scheduled'
        );
        insert assignment;

        Attendance__c attendance = new Attendance__c(
            Employee__c = employee.Id,
            Shift_Assignment__c = assignment.Id,
            Check_In__c = Datetime.newInstance(System.today(), Time.newInstance(9, 30, 0, 0)),
            Verification_Status__c = 'Failed',
            Anomaly_Flag__c = true,
            Anomaly_Reason__c = 'Late'
        );
        insert attendance;

        Leave_Request__c leaveRequest = new Leave_Request__c(
            Employee__c = employee.Id,
            Leave_Type__c = 'Sick',
            Start_Date__c = System.today().addDays(1),
            End_Date__c = System.today().addDays(2),
            Status__c = 'Submitted',
            Approver__c = UserInfo.getUserId(),
            Reason__c = 'Medical'
        );
        insert leaveRequest;

        Case supportCase = new Case(
            Status = 'New',
            Origin = 'Phone',
            Subject = 'Patient Follow-up',
            AccountId = employer.Id
        );
        insert supportCase;

        Case_Assignment__c caseAssignment = new Case_Assignment__c(
            Employee__c = employee.Id,
            Case__c = supportCase.Id,
            Assignment_Status__c = 'Assigned',
            Assigned_On__c = System.now()
        );
        insert caseAssignment;

        Test.startTest();
        WorkforceAdminMonitorController.Snapshot snapshot =
            WorkforceAdminMonitorController.getHomeSnapshot(5);
        Test.stopTest();

        System.assertEquals(1, snapshot.activeTemplates);
        System.assertEquals(1, snapshot.upcomingAssignments7Days);
        System.assertEquals(1, snapshot.scheduledAssignments);
        System.assertEquals(1, snapshot.attendanceAnomalies);
        System.assertEquals(1, snapshot.lateCheckins7Days);
        System.assertEquals(1, snapshot.leaveSubmitted);
        System.assertEquals(0, snapshot.leaveApproved);
        System.assertEquals(0, snapshot.leaveRejected);
        System.assertEquals(1, snapshot.openCaseAssignments);
        System.assertEquals(1, snapshot.scheduledShiftQueue.size());
        System.assertNotEquals(null, snapshot.scheduledShiftQueue[0].startTimeDisplay);
        System.assertNotEquals(null, snapshot.scheduledShiftQueue[0].endTimeDisplay);
        System.assertEquals(1, snapshot.attendanceExceptions.size());
        System.assertEquals(1, snapshot.pendingLeaveQueue.size());
    }
}
