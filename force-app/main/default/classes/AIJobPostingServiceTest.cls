@isTest
private class AIJobPostingServiceTest {
    
    @testSetup
    static void setup() {
        // Create test data if needed
    }
    
    @isTest
    static void testProcessNLPInputSuccess() {
        Test.setMock(HttpCalloutMock.class, new AIJobPostingServiceMock('success'));
        
        Test.startTest();
        Map<String, Object> result = AIJobPostingService.processNLPInput(
            'We need a Senior Cardiologist in San Francisco for Healthcare department.'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Senior Cardiologist', result.get('name'), 'Job name should match');
    }
    
    @isTest
    static void testCreateJobPosting() {
        Map<String, Object> jobData = new Map<String, Object>{
            'name' => 'Test Job',
            'category' => 'Healthcare',
            'location' => 'San Francisco',
            'experienceLevel' => 'Senior Level',
            'specialization' => 'Cardiologist',
            'description' => 'Test description',
            'status' => 'Open',
            'startDate' => '2026-02-01',
            'endDate' => '2026-04-30'
        };
        
        Test.startTest();
        String jobId = AIJobPostingService.createJobPosting(jobData);
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Job ID should not be null');
        
        Job_Posting__c job = [SELECT Id, Name, Category__c, Location__c FROM Job_Posting__c WHERE Id = :jobId];
        System.assertEquals('Test Job', job.Name, 'Job name should match');
        System.assertEquals('Healthcare', job.Category__c, 'Category should match');
    }
    
    @isTest
    static void testCreateJobPostingWithNullDates() {
        Map<String, Object> jobData = new Map<String, Object>{
            'name' => 'Test Job',
            'category' => 'Technology',
            'location' => 'Remote',
            'experienceLevel' => 'Mid Level',
            'description' => 'Test description',
            'status' => 'Open',
            'startDate' => null,
            'endDate' => null
        };
        
        Test.startTest();
        String jobId = AIJobPostingService.createJobPosting(jobData);
        Test.stopTest();
        
        Job_Posting__c job = [SELECT Start_Date__c, End_Date__c FROM Job_Posting__c WHERE Id = :jobId];
        System.assertEquals(null, job.Start_Date__c, 'Start date should be null');
        System.assertEquals(null, job.End_Date__c, 'End date should be null');
    }
    
    @isTest
    static void testTestGeminiConnection() {
        Test.setMock(HttpCalloutMock.class, new AIJobPostingServiceMock('success'));
        
        Test.startTest();
        String result = AIJobPostingService.testGeminiConnection();
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    // Mock class for HTTP callouts
    private class AIJobPostingServiceMock implements HttpCalloutMock {
        String responseType;
        
        public AIJobPostingServiceMock(String responseType) {
            this.responseType = responseType;
        }
        
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