@IsTest
private class CSVJobPostingProcessorTest {

    @IsTest
    static void testParseAndEnrichCSV_NoDescriptionColumn() {
        // No "Description" header → descriptionIndex = -1 → AI is NOT called
        String csv =
            'Job Title,Category,Role Type,Min Experience,Max Experience,Credentialing Required,Start Date,End Date\n' +
            '"Staff Nurse","Medical","Nurse","2","5","yes","2026-01-01","2026-06-30"';

        Test.startTest();
        List<Map<String, Object>> jobs = CSVJobPostingProcessor.parseAndEnrichCSV(csv);
        Test.stopTest();

        System.assertEquals(1, jobs.size(), 'Should parse exactly one job');

        Map<String, Object> wrapper = jobs[0];
        System.assert(wrapper.containsKey('jobPosting'), 'Wrapper should contain jobPosting key');

        Map<String, Object> jobPosting = (Map<String, Object>) wrapper.get('jobPosting');

        // Header mapping and type conversion checks
        System.assertEquals('Staff Nurse', (String) jobPosting.get('Job_Title__c'));
        System.assertEquals('Medical', (String) jobPosting.get('Category__c'));
        System.assertEquals('Nurse', (String) jobPosting.get('Role_Type__c'));
        System.assertEquals(Decimal.valueOf(2), (Decimal) jobPosting.get('Min_Experience_Years__c'));
        System.assertEquals(Decimal.valueOf(5), (Decimal) jobPosting.get('Max_Experience_Years__c'));
        System.assertEquals(true, (Boolean) jobPosting.get('Credentialing_Required__c'));
        System.assertEquals('2026-01-01', (String) jobPosting.get('Start_Date__c'));
        System.assertEquals('2026-06-30', (String) jobPosting.get('End_Date__c'));

        // In the "no description" branch we should get all child collections present and empty
        System.assert(wrapper.containsKey('educationRequirements'));
        System.assert(wrapper.containsKey('licenseRequirements'));
        System.assert(wrapper.containsKey('certificationRequirements'));
        System.assert(wrapper.containsKey('clinicalSkills'));
        System.assert(wrapper.containsKey('procedureRequirements'));
        System.assert(wrapper.containsKey('complianceRequirements'));

        System.assertEquals(0, ((List<Object>) wrapper.get('educationRequirements')).size());
        System.assertEquals(0, ((List<Object>) wrapper.get('licenseRequirements')).size());
        System.assertEquals(0, ((List<Object>) wrapper.get('certificationRequirements')).size());
        System.assertEquals(0, ((List<Object>) wrapper.get('clinicalSkills')).size());
        System.assertEquals(0, ((List<Object>) wrapper.get('procedureRequirements')).size());
        System.assertEquals(0, ((List<Object>) wrapper.get('complianceRequirements')).size());
    }

    @IsTest
    static void testParseAndEnrichCSV_WithDescription_AIFallback() {
        // Includes "Description" column → AI path is executed.
        // In test context the callout should fail and be caught, triggering fallback
        String csv =
            'Job Title,Category,Role Type,Min Experience,Max Experience,Start Date,End Date,Description\n' +
            '"Senior Cardiologist","Medical","Doctor","5","15","2026-02-01","2026-12-31",' +
            '"Responsible for ICU care. Requires MBBS, MD, valid license, BLS, ACLS."';

        Test.startTest();
        List<Map<String, Object>> jobs = CSVJobPostingProcessor.parseAndEnrichCSV(csv);
        Test.stopTest();

        System.assertEquals(1, jobs.size(), 'Should parse exactly one job');

        Map<String, Object> wrapper = jobs[0];
        System.assert(wrapper.containsKey('jobPosting'), 'Wrapper should contain jobPosting');

        Map<String, Object> jobPosting = (Map<String, Object>) wrapper.get('jobPosting');
        System.assertEquals('Senior Cardiologist', (String) jobPosting.get('Job_Title__c'));
        System.assertEquals(Decimal.valueOf(5), (Decimal) jobPosting.get('Min_Experience_Years__c'));
        System.assertEquals(Decimal.valueOf(15), (Decimal) jobPosting.get('Max_Experience_Years__c'));
        System.assertEquals('2026-02-01', (String) jobPosting.get('Start_Date__c'));
        System.assertEquals('2026-12-31', (String) jobPosting.get('End_Date__c'));

        // Whether AI succeeds or fails, the code guarantees these keys exist.
        // In test (no mocks) AI should throw a callout exception and trigger the fallback,
        // which creates empty child lists.
        System.assert(wrapper.containsKey('educationRequirements'));
        System.assert(wrapper.containsKey('licenseRequirements'));
        System.assert(wrapper.containsKey('certificationRequirements'));
        System.assert(wrapper.containsKey('clinicalSkills'));
        System.assert(wrapper.containsKey('procedureRequirements'));
        System.assert(wrapper.containsKey('complianceRequirements'));

        // We only assert they are Lists and don't blow up; in the fallback they will be empty.
        System.assertNotEquals(null, (List<Object>) wrapper.get('educationRequirements'));
        System.assertNotEquals(null, (List<Object>) wrapper.get('licenseRequirements'));
        System.assertNotEquals(null, (List<Object>) wrapper.get('certificationRequirements'));
        System.assertNotEquals(null, (List<Object>) wrapper.get('clinicalSkills'));
        System.assertNotEquals(null, (List<Object>) wrapper.get('procedureRequirements'));
        System.assertNotEquals(null, (List<Object>) wrapper.get('complianceRequirements'));
    }

    @IsTest
    static void testParseAndEnrichCSV_InvalidInput_ThrowsCSVParseException() {
        Boolean threw = false;

        Test.startTest();
        try {
            // Passing null will cause a NullPointerException on split(),
            // which is caught and rethrown as CSVParseException.
            CSVJobPostingProcessor.parseAndEnrichCSV(null);
        } catch (CSVJobPostingProcessor.CSVParseException e) {
            threw = true;
            System.assert(e.getMessage().startsWith('Error parsing CSV'),
                'Expected CSVParseException with error parsing message');
        }
        Test.stopTest();

        System.assert(threw, 'Expected CSVParseException to be thrown for null input');
    }

    @IsTest
    static void testParseAndEnrichCSV_HeaderOnly_NoRows() {
        // CSV with only header row should not throw, just return empty list
        String csv = 'Job Title,Category,Role Type\n';

        Test.startTest();
        List<Map<String, Object>> jobs = CSVJobPostingProcessor.parseAndEnrichCSV(csv);
        Test.stopTest();

        System.assertEquals(0, jobs.size(), 'No data rows → no jobs returned');
    }
}