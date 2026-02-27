@IsTest
private class JobPostingAdminControllerTest {
    @IsTest
    static void testValidationPaths() {
        try {
            JobPostingAdminController.saveJobPosting('');
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            JobPostingAdminController.getPicklistValues('Bad_Field__c');
            System.assert(false, 'Expected invalid field exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void testSaveAndDeleteJobPosting() {
        String cat = JobPostingAdminController.getPicklistValues('Category__c').isEmpty()
            ? null : JobPostingAdminController.getPicklistValues('Category__c')[0].get('value');
        String roleType = JobPostingAdminController.getPicklistValues('Role_Type__c').isEmpty()
            ? null : JobPostingAdminController.getPicklistValues('Role_Type__c')[0].get('value');
        String empType = JobPostingAdminController.getPicklistValues('Employment_Type__c').isEmpty()
            ? null : JobPostingAdminController.getPicklistValues('Employment_Type__c')[0].get('value');

        Map<String, Object> jobMap = new Map<String, Object>{
            'jobPosting' => new Map<String, Object>{
                'Job_Title__c' => 'Admin Test Job',
                'Category__c' => cat,
                'Role_Type__c' => roleType,
                'Employment_Type__c' => empType,
                'Facility_Name__c' => 'Main Facility',
                'City__c' => 'Austin',
                'State__c' => 'TX',
                'Country__c' => 'USA',
                'Start_Date__c' => String.valueOf(Date.today()),
                'End_Date__c' => String.valueOf(Date.today().addDays(30))
            },
            'educationRequirements' => new List<Object>(),
            'licenseRequirements' => new List<Object>(),
            'certificationRequirements' => new List<Object>(),
            'clinicalSkills' => new List<Object>(),
            'procedureRequirements' => new List<Object>(),
            'complianceRequirements' => new List<Object>()
        };

        Test.startTest();
        String jobId = JobPostingAdminController.saveJobPosting(JSON.serialize(jobMap));
        List<Job_Posting__c> jobs = JobPostingAdminController.getJobPostings();
        JobPostingAdminController.deleteJobPosting(jobId);
        Test.stopTest();

        System.assert(String.isNotBlank(jobId));
        System.assert(!jobs.isEmpty());
    }
}
