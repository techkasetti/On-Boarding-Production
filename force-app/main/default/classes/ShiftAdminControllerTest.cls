@IsTest
public class ShiftAdminControllerTest {
    @IsTest
    static void testShiftAdminFlow() {
        Account employer = new Account(Name = 'Workforce Org');
        insert employer;

        Employee__c employee = new Employee__c(Employer_Account__c = employer.Id);
        insert employee;

        ShiftAdminController.TemplateInput templateInput = new ShiftAdminController.TemplateInput();
        templateInput.name = 'Template A';
        templateInput.employerAccountId = employer.Id;
        templateInput.status = 'Active';
        templateInput.shiftType = 'Day';
        templateInput.startTime = '08:00';
        templateInput.endTime = '16:00';
        templateInput.recurrence = 'Weekly';
        templateInput.daysOfWeek = 'Mon;Tue';
        templateInput.maxHeadcount = 5;
        templateInput.requiredSkill = 'Nurse';
        templateInput.complianceRequired = true;

        Test.startTest();
        Id templateId = ShiftAdminController.createTemplate(templateInput);
        Test.stopTest();
        System.assertNotEquals(null, templateId);

        ShiftAdminController.AssignmentInput assignmentInput = new ShiftAdminController.AssignmentInput();
        assignmentInput.employeeId = employee.Id;
        assignmentInput.templateId = templateId;
        assignmentInput.shiftDate = System.today();
        assignmentInput.startTime = '08:00';
        assignmentInput.endTime = '16:00';
        assignmentInput.status = 'Scheduled';

        Test.startTest();
        Id assignmentId = ShiftAdminController.createAssignment(assignmentInput);
        Test.stopTest();
        System.assertNotEquals(null, assignmentId);

        List<ShiftAdminController.SelectOption> accounts =
            ShiftAdminController.getEmployerAccounts();
        System.assert(!accounts.isEmpty());

        List<ShiftAdminController.TemplateRow> templates =
            ShiftAdminController.getTemplateRows(employer.Id);
        System.assertEquals(1, templates.size());
        System.assertNotEquals(null, templates[0].startTimeDisplay);
        System.assertNotEquals(null, templates[0].endTimeDisplay);
        System.assertEquals('08:00', templates[0].startTimeValue);

        List<ShiftAdminController.AssignmentRow> assignments =
            ShiftAdminController.getAssignments(employer.Id, System.today(), System.today());
        System.assertEquals(1, assignments.size());
        System.assertEquals('08:00', assignments[0].startTimeValue);

        ShiftAdminController.ConflictResult conflictResult =
            ShiftAdminController.checkAssignmentConflicts(
                employee.Id,
                System.today(),
                '07:30',
                '09:00'
            );
        System.assertEquals(true, conflictResult.hasConflict);
        System.assertEquals(1, conflictResult.conflicts.size());

        // Overnight shift should be supported and should conflict into the next day.
        ShiftAdminController.AssignmentInput overnightAssignmentInput = new ShiftAdminController.AssignmentInput();
        overnightAssignmentInput.employeeId = employee.Id;
        overnightAssignmentInput.templateId = templateId;
        overnightAssignmentInput.shiftDate = System.today();
        overnightAssignmentInput.startTime = '22:00';
        overnightAssignmentInput.endTime = '06:00';
        overnightAssignmentInput.status = 'Scheduled';
        insert new Shift_Assignment__c(
            Employee__c = overnightAssignmentInput.employeeId,
            Shift_Template__c = overnightAssignmentInput.templateId,
            Shift_Date__c = overnightAssignmentInput.shiftDate,
            Start_Time__c = Time.newInstance(22, 0, 0, 0),
            End_Time__c = Time.newInstance(6, 0, 0, 0),
            Assignment_Status__c = overnightAssignmentInput.status
        );

        ShiftAdminController.ConflictResult overnightConflictResult =
            ShiftAdminController.checkAssignmentConflicts(
                employee.Id,
                System.today().addDays(1),
                '05:00',
                '07:00'
            );
        System.assertEquals(true, overnightConflictResult.hasConflict);

        // Delete a template without dependent assignments.
        Shift_Template__c removableTemplate = new Shift_Template__c(
            Name = 'Template To Delete',
            Employer_Account__c = employer.Id,
            Template_Status__c = 'Draft',
            Shift_Type__c = 'Day',
            Start_Time__c = Time.newInstance(10, 0, 0, 0),
            End_Time__c = Time.newInstance(12, 0, 0, 0),
            Recurrence__c = 'None'
        );
        insert removableTemplate;

        ShiftAdminController.deleteTemplate(removableTemplate.Id);
        Integer removedCount = [
            SELECT COUNT()
            FROM Shift_Template__c
            WHERE Id = :removableTemplate.Id
        ];
        System.assertEquals(0, removedCount);
    }
}
