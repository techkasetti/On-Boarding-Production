@IsTest
private class CandidateHiringMonitorControllerTest {
    private static Candidate__c makeCandidate(String suffix, String status, Integer convertedDaysAgo) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Monitor Candidate ' + suffix,
            Email__c = 'monitor.' + suffix + '@example.com',
            Status__c = status
        );
        if (convertedDaysAgo != null) {
            c.Converted_To_Employee_On__c = System.now().addDays(-convertedDaysAgo);
        }
        insert c;
        return c;
    }

    @IsTest
    static void testSnapshotForCompliancePipeline() {
        Candidate__c ready = makeCandidate('ready', 'Offer Accepted - Compliance Pending', 4);
        Candidate__c missingEmployee = makeCandidate('missing', 'Offer Accepted - Compliance Pending', 2);
        Candidate__c hired = makeCandidate('hired', 'Hired', 1);

        Employee__c emp = new Employee__c(
            Candidate__c = ready.Id,
            Employment_Status__c = 'Pending Activation',
            Identity_Mode__c = 'Hybrid',
            Is_External_Login_Only__c = true,
            Join_Date__c = Date.today()
        );
        insert emp;

        ready.Employee__c = emp.Id;
        ready.Identity_Phase__c = 'Hybrid';
        ready.PHI_Access_Granted__c = false;
        update ready;

        insert new HIPAACompliance__c(
            Candidate__c = ready.Id,
            Status__c = 'Completed',
            HIPAA_Training_Completed_Date__c = Date.today().addDays(-1),
            Acknowledgment_Signed_Date__c = Date.today().addDays(-1)
        );

        insert new HIPAACompliance__c(
            Candidate__c = missingEmployee.Id,
            Status__c = 'Completed',
            HIPAA_Training_Completed_Date__c = Date.today().addDays(-1),
            Acknowledgment_Signed_Date__c = Date.today().addDays(-1)
        );

        insert new Employee_Conversion_Audit__c(
            Candidate__c = ready.Id,
            Employee__c = emp.Id,
            Stage__c = 'Conversion',
            Status__c = 'Success',
            Message__c = 'Converted successfully',
            Occurred_At__c = System.now().addDays(-1)
        );
        insert new Employee_Conversion_Audit__c(
            Candidate__c = missingEmployee.Id,
            Stage__c = 'Conversion',
            Status__c = 'Failed',
            Message__c = 'Candidate missing on job application.',
            Occurred_At__c = System.now().addDays(-2)
        );

        Test.startTest();
        CandidateHiringMonitorController.Snapshot snap =
            CandidateHiringMonitorController.getHomeSnapshot(5);
        Test.stopTest();

        System.assertNotEquals(null, snap);
        System.assertEquals(2, snap.totalPendingCompliance);
        System.assertEquals(1, snap.readyButStillPending);
        System.assertEquals(1, snap.pendingMissingEmployee);
        System.assertEquals(1, snap.agingPendingOver3Days);
        System.assertEquals(3, snap.convertedLast7Days);
        System.assertEquals(1, snap.hiredLast7Days);
        System.assertEquals(3.0, snap.averagePendingAgeDays);
        System.assertEquals(1, snap.readyQueue.size());
        System.assertEquals(1, snap.missingEmployeeQueue.size());
        System.assertEquals(2, snap.oldestPendingQueue.size());
        System.assertEquals(ready.Id, snap.readyQueue[0].candidateId);
        System.assertEquals(true, snap.readyQueue[0].hipaaComplete);
        System.assertEquals(1, snap.conversionSuccessLast7Days);
        System.assertEquals(1, snap.conversionFailedLast7Days);
        System.assertNotEquals(null, snap.lastConversionFailureMessage);
    }

    @IsTest
    static void testSnapshotWithNoPendingCandidates() {
        makeCandidate('hiredOnly', 'Hired', 1);

        CandidateHiringMonitorController.Snapshot snap =
            CandidateHiringMonitorController.getHomeSnapshot(null);

        System.assertEquals(0, snap.totalPendingCompliance);
        System.assertEquals(0, snap.readyButStillPending);
        System.assertEquals(0, snap.pendingMissingEmployee);
        System.assertEquals(0, snap.agingPendingOver3Days);
        System.assertEquals(0, snap.averagePendingAgeDays);
        System.assertEquals(0, snap.readyQueue.size());
        System.assertEquals(0, snap.missingEmployeeQueue.size());
        System.assertEquals(0, snap.oldestPendingQueue.size());
        System.assertEquals(0, snap.conversionSuccessLast7Days);
        System.assertEquals(0, snap.conversionFailedLast7Days);
    }
}
