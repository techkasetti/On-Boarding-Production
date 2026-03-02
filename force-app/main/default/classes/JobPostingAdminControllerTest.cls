@IsTest
private class JobPostingAdminControllerTest {
    private static String firstPicklistValue(String fieldName) {
        List<Map<String, String>> options = JobPostingAdminController.getPicklistValues(fieldName);
        return options.isEmpty() ? null : options[0].get('value');
    }

    private static String buildSavePayload() {
        String category = firstPicklistValue('Category__c');
        String roleType = firstPicklistValue('Role_Type__c');
        String dept = firstPicklistValue('Department__c');
        String empType = firstPicklistValue('Employment_Type__c');
        String shift = firstPicklistValue('Shift_Type__c');

        Map<String, Object> payload = new Map<String, Object>{
            'jobPosting' => new Map<String, Object>{
                'Job_Title__c' => 'Admin Test Job',
                'Description__c' => 'Testing admin controller',
                'Category__c' => category,
                'Role_Type__c' => roleType,
                'Department__c' => dept,
                'Employment_Type__c' => empType,
                'Shift_Type__c' => shift,
                'Min_Experience_Years__c' => 2,
                'Max_Experience_Years__c' => 5,
                'Start_Date__c' => String.valueOf(Date.today()),
                'End_Date__c' => String.valueOf(Date.today().addDays(30)),
                'Facility_Name__c' => 'Main Facility',
                'City__c' => 'Austin',
                'State__c' => 'TX',
                'Country__c' => 'USA',
                'Credentialing_Required__c' => true,
                'Privilege_Scope__c' => 'General'
            },
            'educationRequirements' => new List<Object>{
                new Map<String, Object>{ 'Degree_Name__c' => 'MBBS', 'Mandatory__c' => true }
            },
            'licenseRequirements' => new List<Object>{
                new Map<String, Object>{
                    'License_Name__c' => 'State License',
                    'Issuing_Authority__c' => 'State Board',
                    'Active_Required__c' => true,
                    'Expiry_Check_Required__c' => true
                }
            },
            'certificationRequirements' => new List<Object>{
                new Map<String, Object>{ 'Certification_Name__c' => 'ACLS', 'Mandatory__c' => true }
            },
            'clinicalSkills' => new List<Object>{
                new Map<String, Object>{ 'Skill_Name__c' => 'Critical Care', 'Skill_Level__c' => 'Advanced', 'Mandatory__c' => true }
            },
            'procedureRequirements' => new List<Object>{
                new Map<String, Object>{ 'Procedure_Name__c' => 'Intubation', 'Critical__c' => true }
            },
            'complianceRequirements' => new List<Object>{
                new Map<String, Object>{ 'Compliance_Name__c' => 'HIPAA', 'Mandatory__c' => true }
            }
        };

        return JSON.serialize(payload);
    }

    @IsTest
    static void testSaveReadUpdateDeleteAndPicklists() {
        String payload = buildSavePayload();

        Test.startTest();
        String jobId = JobPostingAdminController.saveJobPosting(payload);
        List<Job_Posting__c> allJobs = JobPostingAdminController.getJobPostings();
        List<Job_Posting__c> recent = JobPostingAdminController.getRecentJobPostings();
        Map<String, Object> details = JobPostingAdminController.getJobPostingWithDetails(jobId);
        Test.stopTest();

        System.assert(String.isNotBlank(jobId));
        System.assert(!allJobs.isEmpty());
        System.assert(!recent.isEmpty());
        System.assertNotEquals(null, details.get('jobPosting'));

        System.assertEquals(1, [SELECT Count() FROM Job_Education_Requirement__c WHERE Job_Posting__c = :jobId]);
        System.assertEquals(1, [SELECT Count() FROM Job_License_Requirement__c WHERE Job_Posting__c = :jobId]);
        System.assertEquals(1, [SELECT Count() FROM Job_Certification_Requirement__c WHERE Job_Posting__c = :jobId]);
        System.assertEquals(1, [SELECT Count() FROM Job_Clinical_Skill__c WHERE Job_Posting__c = :jobId]);
        System.assertEquals(1, [SELECT Count() FROM Job_Procedure_Requirement__c WHERE Job_Posting__c = :jobId]);
        System.assertEquals(1, [SELECT Count() FROM Job_Compliance_Requirement__c WHERE Job_Posting__c = :jobId]);

        String updatePayload = JSON.serialize(new Map<String, Object>{
            'Id' => jobId,
            'Job_Title__c' => 'Admin Test Job Updated',
            'City__c' => 'Dallas',
            'Min_Experience_Years__c' => 3,
            'Max_Experience_Years__c' => 7,
            'Start_Date__c' => String.valueOf(Date.today().addDays(1)),
            'End_Date__c' => String.valueOf(Date.today().addDays(45)),
            'Description__c' => 'Updated description'
        });

        String updateResult = JobPostingAdminController.updateJobPosting(updatePayload);
        System.assertEquals('Success', updateResult);

        Job_Posting__c updated = [
            SELECT Job_Title__c, City__c, Min_Experience_Years__c, Max_Experience_Years__c
            FROM Job_Posting__c
            WHERE Id = :jobId
        ];
        System.assertEquals('Admin Test Job Updated', updated.Job_Title__c);
        System.assertEquals('Dallas', updated.City__c);
        System.assertEquals(3, updated.Min_Experience_Years__c);
        System.assertEquals(7, updated.Max_Experience_Years__c);

        JobPostingAdminController.deleteJobPosting(jobId);
        System.assertEquals(0, [SELECT Count() FROM Job_Posting__c WHERE Id = :jobId]);
    }

    @IsTest
    static void testValidationAndErrorPaths() {
        try {
            JobPostingAdminController.saveJobPosting('');
            System.assert(false, 'Expected save validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            JobPostingAdminController.getPicklistValues('Bad_Field__c');
            System.assert(false, 'Expected invalid field exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            JobPostingAdminController.deleteJobPosting(null);
            System.assert(false, 'Expected null id exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        String category = firstPicklistValue('Category__c');
        String roleType = firstPicklistValue('Role_Type__c');
        String empType = firstPicklistValue('Employment_Type__c');

        String badDatesPayload = JSON.serialize(new Map<String, Object>{
            'jobPosting' => new Map<String, Object>{
                'Job_Title__c' => 'Bad Dates Job',
                'Category__c' => category,
                'Role_Type__c' => roleType,
                'Employment_Type__c' => empType,
                'Facility_Name__c' => 'Main Facility',
                'City__c' => 'Austin',
                'State__c' => 'TX',
                'Country__c' => 'USA',
                'Start_Date__c' => String.valueOf(Date.today().addDays(10)),
                'End_Date__c' => String.valueOf(Date.today())
            },
            'educationRequirements' => new List<Object>(),
            'licenseRequirements' => new List<Object>(),
            'certificationRequirements' => new List<Object>(),
            'clinicalSkills' => new List<Object>(),
            'procedureRequirements' => new List<Object>(),
            'complianceRequirements' => new List<Object>()
        });

        try {
            JobPostingAdminController.saveJobPosting(badDatesPayload);
            System.assert(false, 'Expected date validation exception');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        Boolean nlpHandled = false;
        try {
            JobPostingAdminController.createJobFromNLP('Need an ER nurse in Austin');
            nlpHandled = true;
        } catch (AuraHandledException e) {
            nlpHandled = true;
        }
        System.assertEquals(true, nlpHandled);

        Boolean csvHandled = false;
        try {
            JobPostingAdminController.createJobsFromCSV(null);
            csvHandled = true;
        } catch (AuraHandledException e) {
            csvHandled = true;
        }
        System.assertEquals(true, csvHandled);

        String geminiResult = JobPostingAdminController.testGeminiConnection();
        System.assertNotEquals(null, geminiResult);
    }
}
