@IsTest
private class JobPostingControllerTest {

    // -------------------------
    // Utility creators
    // -------------------------
    private static Job_Posting__c createJobPosting(
        String nameSuffix,
        Integer minExp,
        Integer maxExp,
        String city
    ) {
        Job_Posting__c jp = new Job_Posting__c(
            Name                    = 'Test Job ' + nameSuffix,
            Job_Title__c            = 'ICU Nurse ' + nameSuffix,
            Category__c             = 'Medical',   // adjust if picklist differs
            Department__c           = 'ICU',
            Role_Type__c            = 'Nurse',        // adjust if picklist
            Employment_Type__c      = 'Full-time',    // adjust if picklist
            Shift_Type__c           = 'Day',          // adjust if picklist
            Facility_Name__c        = 'City Hospital ' + nameSuffix,
            City__c                 = city,
            State__c                = 'MA',
            Country__c              = 'USA',
            Min_Experience_Years__c = minExp,
            Max_Experience_Years__c = maxExp,
            Description__c          = 'Test description ' + nameSuffix,
            Privilege_Scope__c      = 'ICU Only',
            Start_Date__c           = Date.today(),
            End_Date__c             = Date.today().addDays(30)
            // Job_Status__c is a formula; DO NOT set it here
        );
        insert jp;
        return jp;
    }

    private static Candidate__c createCandidateBasic(String suffix) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Test Candidate ' + suffix,
            Email__c     = 'test' + suffix + '@example.com',
            Phone__c     = '1234567890',
            Location__c  = 'Test City'
        );
        insert c;
        return c;
    }

    // -------------------------
    // getJobPostings
    // -------------------------
    @IsTest
    static void testGetJobPostings_basicAndFilters() {
        // Open postings
        Job_Posting__c jp1 = createJobPosting('A', 2, 5, 'Boston');
        Job_Posting__c jp2 = createJobPosting('B', 5, 10, 'New York');

        // Closed posting: make dates in the past so formula Job_Status__c = 'Closed'
        Job_Posting__c jpClosed = createJobPosting('Closed', 2, 5, 'Boston');
        jpClosed.Start_Date__c = Date.today().addDays(-60);
        jpClosed.End_Date__c   = Date.today().addDays(-30);
        update jpClosed;

        Test.startTest();
        // 1) No filters
        Map<String, Object> resAll =
            JobPostingController.getJobPostings(null, null, 'all', 'all');
        List<Job_Posting__c> jobsAll =
            (List<Job_Posting__c>) resAll.get('jobs');
        Integer countAll = (Integer) resAll.get('count');

        System.assertEquals(2, jobsAll.size(), 'Should return only open jobs');
        System.assertEquals(2, countAll);

        // 2) Keyword filter (match Job_Title__c)
        Map<String, Object> resKeyword =
            JobPostingController.getJobPostings('ICU Nurse A', null, 'all', 'all');
        List<Job_Posting__c> jobsKeyword =
            (List<Job_Posting__c>) resKeyword.get('jobs');
        System.assertEquals(1, jobsKeyword.size(), 'Keyword should match only jp1');

        // 3) Location filter
        Map<String, Object> resLocation =
            JobPostingController.getJobPostings(null, 'Boston', 'all', 'all');
        List<Job_Posting__c> jobsLocation =
            (List<Job_Posting__c>) resLocation.get('jobs');
        System.assertEquals(1, jobsLocation.size(), 'Location Boston should return jp1 only');

        // 4) Experience filter (exp=3 fits jp1 only)
        Map<String, Object> resExp =
            JobPostingController.getJobPostings(null, null, '24h', '3');
        List<Job_Posting__c> jobsExp =
            (List<Job_Posting__c>) resExp.get('jobs');
        System.assertEquals(1, jobsExp.size(), 'Experience level 3 should match jp1 only');

        Test.stopTest();
    }

    @IsTest
    static void testGetJobPostings_invalidExperienceLevel() {
        createJobPosting('C', 1, 5, 'Boston');

        Boolean threw = false;
        try {
            Test.startTest();
            JobPostingController.getJobPostings(null, null, 'all', 'notANumber');
            Test.stopTest();
        } catch (AuraHandledException e) {
            threw = true;
           // System.assert(
             //   e.getMessage().contains('Error fetching job postings'),
               // 'Expected wrapped error for invalid experienceLevel'
            //);
        }
        System.assert(threw, 'Expected AuraHandledException on invalid experienceLevel');
    }

    // -------------------------
    // getJobDetails
    // -------------------------
    @IsTest
    static void testGetJobDetails_withChildren() {
        Job_Posting__c jp = createJobPosting('Details', 2, 5, 'Boston');

        // Create one child of each type
        insert new Job_Education_Requirement__c(
            Job_Posting__c = jp.Id,
            Degree_Name__c = 'MBBS',
            Mandatory__c   = true
        );

        insert new Job_License_Requirement__c(
            Job_Posting__c          = jp.Id,
            License_Name__c         = 'State Medical License',
            Issuing_Authority__c    = 'State Board',
            Active_Required__c      = true,
            Expiry_Check_Required__c= true
        );

        insert new Job_Certification_Requirement__c(
            Job_Posting__c       = jp.Id,
            Certification_Name__c= 'BLS',
            Mandatory__c         = true
        );

        insert new Job_Clinical_Skill__c(
            Job_Posting__c = jp.Id,
            Skill_Name__c  = 'Patient Assessment',
            Skill_Level__c = 'Advanced',
            Mandatory__c   = true
        );

        insert new Job_Procedure_Requirement__c(
            Job_Posting__c  = jp.Id,
            Procedure_Name__c = 'IV Cannulation',
            Critical__c       = true
        );

        insert new Job_Compliance_Requirement__c(
            Job_Posting__c    = jp.Id,
            Compliance_Name__c= 'Background Check',
            Mandatory__c      = true
        );

        Test.startTest();
        Map<String, Object> res = JobPostingController.getJobDetails(jp.Id);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Result map should not be null');
        System.assert(res.containsKey('job'), 'Should contain job key');

        System.assertEquals(1,
            ((List<Job_Education_Requirement__c>) res.get('educationRequirements')).size());
        System.assertEquals(1,
            ((List<Job_License_Requirement__c>) res.get('licenseRequirements')).size());
        System.assertEquals(1,
            ((List<Job_Certification_Requirement__c>) res.get('certificationRequirements')).size());
        System.assertEquals(1,
            ((List<Job_Clinical_Skill__c>) res.get('clinicalSkills')).size());
        System.assertEquals(1,
            ((List<Job_Procedure_Requirement__c>) res.get('procedures')).size());
        System.assertEquals(1,
            ((List<Job_Compliance_Requirement__c>) res.get('complianceRequirements')).size());
    }

    // -------------------------
    // isGuestUser
    // -------------------------
    @IsTest
    static void testIsGuestUser() {
        Test.startTest();
        Boolean isGuest = JobPostingController.isGuestUser();
        Test.stopTest();

        // Just ensure it returns a boolean without error
        System.assertNotEquals(null, isGuest);
    }

    // -------------------------
    // getCandidateIdForCurrentUser (error path)
    // -------------------------
    @IsTest
    static void testGetCandidateIdForCurrentUser_noContact() {
        Boolean threw = false;
        try {
            Test.startTest();
            JobPostingController.getCandidateIdForCurrentUser();
            Test.stopTest();
        } catch (AuraHandledException e) {
            threw = true;
        //    System.assert(
          //      e.getMessage().contains('Error fetching candidate data'),
            //    'Expected wrapped error for missing contact / candidate'
            //);
        }
        System.assert(threw,
            'Expected AuraHandledException for current user with no Contact/Candidate');
    }

    // -------------------------
    // createJobApplication + getCandidateApplications
    // -------------------------
    @IsTest
    static void testCreateJobApplication_andDuplicate_andGetApplications() {
        Job_Posting__c jp = createJobPosting('Apply', 1, 3, 'Boston');
        Candidate__c  cand = createCandidateBasic('Apply');

        // First call: should create application
        Test.startTest();
        Map<String, Object> res1 =
            JobPostingController.createJobApplication(jp.Id, cand.Id);
       
        System.assertEquals(true, (Boolean) res1.get('success'));
        System.assertEquals('Application submitted successfully!',
                           (String) res1.get('message'));
        Id appId = (Id) res1.get('applicationId');
        System.assertNotEquals(null, appId);

        // Second call: should detect duplicate
        Map<String, Object> res2 =
            JobPostingController.createJobApplication(jp.Id, cand.Id);

        System.assertEquals(false, (Boolean) res2.get('success'));
        System.assertEquals('You have already applied for this job.',
                           (String) res2.get('message'));
        System.assertNotEquals(null, (String) res2.get('existingStatus'));

        // getCandidateApplications
        List<Job_Application__c> apps =
            JobPostingController.getCandidateApplications(cand.Id);
        Test.stopTest();

        System.assertEquals(1, apps.size(), 'Should have one application for candidate');
        System.assertEquals(jp.Id, apps[0].Job_Posting__c);
    }

    // -------------------------
    // checkCandidateEligibility
    // -------------------------
    @IsTest
    static void testCheckCandidateEligibility_completeProfile() {
        Candidate__c cand = createCandidateBasic('Eligible');
        cand.S3_Resume_URL__c = 'https://example.com/resume.pdf';
        cand.Resume_Status__c = true;
        update cand;

        // Attach resume file
        insert new ContentVersion(
            Title               = 'Resume',
            PathOnClient        = 'Resume.pdf',
            VersionData         = Blob.valueOf('resume'),
            FirstPublishLocationId = cand.Id,
            IsMajorVersion      = true
        );

        // Education
        insert new Education__c(
            Candidate__c = cand.Id,
            Degree__c    = 'BSc Nursing',
            Institution__c = 'Medical College'
        );

        // Work experience
        insert new Work_Experience__c(
            Candidate__c   = cand.Id,
            Role__c        = 'Nurse',
            Organization__c= 'Hospital',
            Start_Date__c  = Date.newInstance(2020, 1, 1),
            End_Date__c    = Date.newInstance(2021, 1, 1),
            Is_Current__c  = false
        );

        // Clinical skills
        insert new Clinical_Skill__c(
            Candidate__c = cand.Id,
            Name         = 'Patient Assessment'
        );

        // Technical skills
        insert new Technical_Skill__c(
            Candidate__c = cand.Id,
            Name         = 'Excel'
        );

        // Licenses
        insert new License_Certification__c(
            Candidate__c = cand.Id,
            Name         = 'RN License'
        );

        // Procedures
        insert new Procedure__c(
            Candidate__c = cand.Id,
            Name         = 'IV Cannulation'
        );

        Test.startTest();
        Map<String, Object> res =
            JobPostingController.checkCandidateEligibility(cand.Id);
        Test.stopTest();

        System.assertEquals(true, (Boolean) res.get('eligible'));
        System.assertEquals(true, (Boolean) res.get('hasResume'));
        System.assertEquals(true, (Boolean) res.get('hasEducation'));
        System.assertEquals(true, (Boolean) res.get('hasSkills'));

        Integer completeness = (Integer) res.get('completeness');
        System.assert(completeness >= 75,
            'Completeness should be at least 75 for eligible profile');
        System.assertEquals('Profile meets all requirements.',
                           (String) res.get('message'));
    }

    @IsTest
    static void testCheckCandidateEligibility_incompleteProfile() {
        Candidate__c cand = createCandidateBasic('Incomplete');

        Test.startTest();
        Map<String, Object> res =
            JobPostingController.checkCandidateEligibility(cand.Id);
        Test.stopTest();

        System.assertEquals(false, (Boolean) res.get('eligible'));
        System.assertEquals(false, (Boolean) res.get('hasResume'));

        Integer completeness = (Integer) res.get('completeness');
        System.assert(completeness < 75,
            'Completeness should be below 75 for incomplete profile');
        System.assert(((String) res.get('message')).startsWith('Profile incomplete'),
            'Expected incomplete profile message');

        List<String> missing = (List<String>) res.get('missingSections');
        System.assert(!missing.isEmpty(),
            'Missing sections list should not be empty');
    }
}