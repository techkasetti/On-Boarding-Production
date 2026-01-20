@isTest
private class JobPostingControllerTest {
    
    @testSetup
    static void setup() {
        List<Job_Posting__c> jobs = new List<Job_Posting__c>();
        
        for (Integer i = 0; i < 5; i++) {
            jobs.add(new Job_Posting__c(
                Name = 'Test Job ' + i,
                Category__c = 'Healthcare',
                Location__c = 'San Francisco',
                Experience_Level__c = 'Senior Level',
                Status__c = 'Open',
                Description__c = 'Test description ' + i,
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addMonths(2)
            ));
        }
        
        insert jobs;
    }
    
    @isTest
    static void testGetJobPostings() {
        Test.startTest();
        List<Job_Posting__c> jobs = JobPostingController.getJobPostings('Test', null, null, null);
        Test.stopTest();
        
        System.assertEquals(5, jobs.size(), 'Should return all test jobs');
    }
    
    @isTest
    static void testGetJobPostingsWithFilters() {
        Test.startTest();
        List<Job_Posting__c> jobs = JobPostingController.getJobPostings(
            'Test',
            'San Francisco',
            'month',
            'Senior Level'
        );
        Test.stopTest();
        
        System.assertEquals(5, jobs.size(), 'Should return filtered jobs');
    }
    
    @isTest
    static void testCreateJobFromNLP() {
        Test.setMock(HttpCalloutMock.class, new JobPostingControllerMock());
        
        Test.startTest();
        String jobId = JobPostingController.createJobFromNLP(
            'We need a Senior Cardiologist in San Francisco'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Job ID should not be null');
        
        Job_Posting__c job = [SELECT Name, Category__c FROM Job_Posting__c WHERE Id = :jobId];
        System.assertEquals('Senior Cardiologist', job.Name, 'Job name should match');
    }
    
    @isTest
    static void testCreateJobsFromCSV() {
        String csvContent = 'Job Title,Category,Location,Experience Level,Start Date,End Date,Status,Description\n' +
            'Test CSV Job,Healthcare,San Francisco,Senior Level,2026-02-01,2026-04-30,Open,"Test description"';
        
        Test.startTest();
        Map<String, Object> result = JobPostingController.createJobsFromCSV(csvContent);
        Test.stopTest();
        
        System.assertEquals(true, result.get('success'), 'Should be successful');
        System.assertEquals(1, result.get('count'), 'Should create 1 job');
    }
    
    @isTest
    static void testGetRecentJobPostings() {
        Test.startTest();
        List<Job_Posting__c> jobs = JobPostingController.getRecentJobPostings();
        Test.stopTest();
        
        System.assertEquals(5, jobs.size(), 'Should return all test jobs');
    }
    
    @isTest
    static void testGetJobPostingDetails() {
        Job_Posting__c testJob = [SELECT Id FROM Job_Posting__c LIMIT 1];
        
        Test.startTest();
        Job_Posting__c job = JobPostingController.getJobPostingDetails(testJob.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, job, 'Should return job details');
        System.assertEquals(testJob.Id, job.Id, 'Job ID should match');
    }
    
    @isTest
    static void testTestGeminiConnection() {
        Test.setMock(HttpCalloutMock.class, new JobPostingControllerMock());
        
        Test.startTest();
        String result = JobPostingController.testGeminiConnection();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    // Mock class for HTTP callouts
    private class JobPostingControllerMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            String jsonResponse = '{"candidates":[{"content":{"parts":[{"text":"{\\"name\\":\\"Senior Cardiologist\\",\\"category\\":\\"Healthcare\\",\\"location\\":\\"San Francisco\\",\\"experienceLevel\\":\\"Senior Level\\",\\"specialization\\":\\"Cardiologist\\",\\"description\\":\\"Provide comprehensive cardiac care\\",\\"status\\":\\"Open\\",\\"startDate\\":\\"2026-02-01\\",\\"endDate\\":\\"2026-04-30\\"}"}]}}]}';
            res.setBody(jsonResponse);
            
            return res;
        }
    }
}