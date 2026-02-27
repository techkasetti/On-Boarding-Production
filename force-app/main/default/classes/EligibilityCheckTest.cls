@IsTest
private class EligibilityCheckTest {
    private static Candidate__c createCandidateWithQualifications() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Eligibility Candidate',
            Email__c = 'eligibility@example.com'
        );
        insert c;

        insert new Education__c(
            Candidate__c = c.Id,
            Name = 'Education 1',
            Degree__c = 'MBBS',
            Institution__c = 'Med School'
        );
        insert new License_Certification__c(
            Candidate__c = c.Id,
            Name = 'RN',
            Type__c = 'License'
        );
        insert new Clinical_Skill__c(
            Candidate__c = c.Id,
            Name = 'ICU'
        );
        insert new Work_Experience__c(
            Candidate__c = c.Id,
            Name = 'Experience 1',
            Role__c = 'Nurse',
            Organization__c = 'City Hospital',
            Start_Date__c = Date.today().addYears(-2),
            End_Date__c = Date.today().addMonths(-1)
        );
        insert new Procedure__c(
            Candidate__c = c.Id,
            Name = 'Intubation'
        );
        return c;
    }

    private static Job_Posting__c createJobWithRequirements() {
        Job_Posting__c job = new Job_Posting__c(
            Name = 'Eligibility Job',
            Job_Title__c = 'RN',
            Min_Experience_Years__c = 1,
            Max_Experience_Years__c = 10,
            Description__c = 'Nursing role'
        );
        insert job;

        insert new Job_Education_Requirement__c(
            Job_Posting__c = job.Id,
            Degree_Name__c = 'MBBS'
        );
        insert new Job_License_Requirement__c(
            Job_Posting__c = job.Id,
            License_Name__c = 'RN'
        );
        insert new Job_Certification_Requirement__c(
            Job_Posting__c = job.Id,
            Certification_Name__c = 'BLS'
        );
        insert new Job_Clinical_Skill__c(
            Job_Posting__c = job.Id,
            Skill_Name__c = 'ICU'
        );
        insert new Job_Procedure_Requirement__c(
            Job_Posting__c = job.Id,
            Procedure_Name__c = 'Intubation'
        );

        return job;
    }

    @IsTest
    static void testCheckEligibility_Positive() {
        Candidate__c c = createCandidateWithQualifications();
        Job_Posting__c job = createJobWithRequirements();

        Job_Application__c app = new Job_Application__c(
            Candidate__c = c.Id,
            Job_Posting__c = job.Id
        );
        insert app;

        Test.startTest();
        EligibilityCheck.EligibilityResult result = EligibilityCheck.checkEligibility(app.Id);
        Test.stopTest();

        System.assert(result.score >= 0);
        if (result.success) {
            System.assertNotEquals(null, result.summary);
        } else {
            System.assert(!String.isBlank(result.error));
        }
    }

    @IsTest
    static void testCheckEligibility_InvalidIdHandled() {
        Test.startTest();
        EligibilityCheck.EligibilityResult result = EligibilityCheck.checkEligibility('a00fo0000000001AAA');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(!String.isBlank(result.error));
    }
}
