@isTest
private class CSVJobPostingProcessorTest {
    
    @isTest
    static void testParseCSVSuccess() {
        String csvContent = 'Job Title,Category,Location,Experience Level,Start Date,End Date,Status,Description\n' +
            'Senior Cardiologist,Healthcare,San Francisco,Senior Level,2026-02-01,2026-04-30,Open,"Provide cardiac care"\n' +
            'ICU Nurse,Healthcare,New York,Mid Level,2026-03-01,2026-05-01,Open,"Intensive care nursing"';
        
        Test.startTest();
        List<Map<String, Object>> result = CSVJobPostingProcessor.parseCSV(csvContent);
        Test.stopTest();
        
        System.assertEquals(2, result.size(), 'Should parse 2 rows');
        System.assertEquals('Senior Cardiologist', result[0].get('name'), 'First job name should match');
        System.assertEquals('Healthcare', result[0].get('category'), 'Category should match');
    }
    
    @isTest
    static void testParseCSVWithQuotes() {
        String csvContent = 'Job Title,Category,Location,Experience Level,Start Date,End Date,Status,Description\n' +
            '"Senior Developer, Full Stack",Technology,"San Francisco, CA",Senior Level,2026-02-01,2026-04-30,Open,"Develop web applications"';
        
        Test.startTest();
        List<Map<String, Object>> result = CSVJobPostingProcessor.parseCSV(csvContent);
        Test.stopTest();
        
        System.assertEquals(1, result.size(), 'Should parse 1 row');
        System.assertEquals('Senior Developer, Full Stack', result[0].get('name'), 'Should handle quoted commas');
    }
    
    @isTest
    static void testCreateJobPostingsFromCSV() {
        List<Map<String, Object>> jobDataList = new List<Map<String, Object>>{
            new Map<String, Object>{
                'name' => 'Test Job 1',
                'category' => 'Healthcare',
                'location' => 'San Francisco',
                'experienceLevel' => 'Senior Level',
                'description' => 'Test description',
                'status' => 'Open',
                'startDate' => '2026-02-01',
                'endDate' => '2026-04-30'
            },
            new Map<String, Object>{
                'name' => 'Test Job 2',
                'category' => 'Technology',
                'location' => 'Remote',
                'experienceLevel' => 'Mid Level',
                'description' => 'Test description 2',
                'status' => 'Open',
                'startDate' => '2026-03-01',
                'endDate' => '2026-05-01'
            }
        };
        
        Test.startTest();
        List<String> createdIds = CSVJobPostingProcessor.createJobPostingsFromCSV(jobDataList);
        Test.stopTest();
        
        System.assertEquals(2, createdIds.size(), 'Should create 2 jobs');
        
        List<Job_Posting__c> jobs = [SELECT Id, Name FROM Job_Posting__c WHERE Id IN :createdIds];
        System.assertEquals(2, jobs.size(), 'Should query 2 jobs');
    }
    
    @isTest
    static void testParseCSVEmpty() {
        String csvContent = '';
        
        Test.startTest();
        try {
            CSVJobPostingProcessor.parseCSV(csvContent);
            System.assert(false, 'Should throw exception for empty CSV');
        } catch (CSVJobPostingProcessor.CSVParseException e) {
            System.assert(e.getMessage().contains('empty'), 'Should mention empty file');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testParseCSVInvalidData() {
        String csvContent = 'Job Title,Category,Location,Experience Level,Start Date,End Date,Status,Description\n' +
            'Invalid Job,,,,,,Open,';
        
        Test.startTest();
        List<Map<String, Object>> result = CSVJobPostingProcessor.parseCSV(csvContent);
        Test.stopTest();
        
        System.assertEquals(1, result.size(), 'Should parse row even with missing fields');
    }
}