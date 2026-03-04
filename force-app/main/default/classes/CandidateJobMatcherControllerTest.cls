@IsTest
private class CandidateJobMatcherControllerTest {
    private static Candidate__c makeCandidate() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'AI Match Candidate',
            Email__c = 'aimatch.candidate@example.com',
            Location__c = 'Austin, Texas',
            Years_of_Experience__c = 5
        );
        insert c;

        insert new Work_Experience__c(
            Candidate__c = c.Id,
            Role__c = 'Nurse',
            Organization__c = 'City Hospital'
        );

        insert new License_Certification__c(
            Candidate__c = c.Id,
            Name = 'RN License',
            Type__c = 'License'
        );

        insert new License_Certification__c(
            Candidate__c = c.Id,
            Name = 'BLS',
            Type__c = 'Certification'
        );

        insert new Clinical_Skill__c(
            Candidate__c = c.Id,
            Name = 'Critical Care',
            Skill_Type__c = 'Clinical'
        );

        insert new Procedure__c(
            Candidate__c = c.Id,
            Name = 'IV Cannulation',
            Category__c = 'Emergency'
        );

        insert new Technical_Skill__c(
            Candidate__c = c.Id,
            Name = 'EHR',
            Category__c = 'Software'
        );

        return c;
    }

    private static Job_Posting__c makeJob(String name, String role, Decimal minExp, Decimal maxExp, String city) {
        Job_Posting__c job = new Job_Posting__c(
            Name = name,
            Job_Title__c = name,
            Role_Type__c = role,
            Min_Experience_Years__c = minExp,
            Max_Experience_Years__c = maxExp,
            City__c = city,
            State__c = 'Texas',
            Country__c = 'USA'
        );
        insert job;
        return job;
    }

    @IsTest
    static void testAllJobPostingsAndMatchedJobs() {
        Candidate__c candidate = makeCandidate();

        Job_Posting__c goodJob = makeJob('ICU RN', 'Nurse', 3, 7, 'Austin');
        Job_Posting__c weakJob = makeJob('Remote Pharmacist', 'Pharmacist', 8, 12, 'Boston');

        insert new Job_License_Requirement__c(Job_Posting__c = goodJob.Id, License_Name__c = 'RN License');
        insert new Job_Certification_Requirement__c(Job_Posting__c = goodJob.Id, Certification_Name__c = 'BLS', Mandatory__c = true);
        insert new Job_Clinical_Skill__c(Job_Posting__c = goodJob.Id, Skill_Name__c = 'Critical Care', Skill_Level__c = 'Advanced', Mandatory__c = true);
        insert new Job_Procedure_Requirement__c(Job_Posting__c = goodJob.Id, Procedure_Name__c = 'IV Cannulation', Critical__c = true);

        insert new Job_License_Requirement__c(Job_Posting__c = weakJob.Id, License_Name__c = 'Pharmacist License');

        Test.startTest();
        List<Job_Posting__c> allJobs = CandidateJobMatcherController.getAllJobPostings();
        List<CandidateJobMatcherController.JobMatchResult> matches = CandidateJobMatcherController.getAiMatchedJobs(candidate.Id, 10);
        Test.stopTest();

        System.assert(allJobs.size() >= 2, 'Expected job postings to be returned.');
        System.assert(matches.size() > 0, 'Expected at least one matched job.');
        System.assertEquals(goodJob.Id, matches[0].jobPosting.Id, 'Best matched job should rank first.');
        System.assert(matches[0].matchScore > 0, 'Top match should have positive score.');
        System.assert(matches[0].reasons != null && !matches[0].reasons.isEmpty(), 'Reasons should be returned for explainability.');
    }

    @IsTest
    static void testMatchedJobsNullCandidateThrows() {
        Boolean threw = false;
        try {
            CandidateJobMatcherController.getAiMatchedJobs(null, 10);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Expected exception for null candidate id.');
    }
}