@IsTest
private class AIJobPostingServiceTest {

    // ---------------------------------------------------------------------
    // Helper to build a full AI data structure as parseAIResponse would return
    // ---------------------------------------------------------------------
    private static Map<String, Object> buildFullAIData() {
        Map<String, Object> jobPosting = new Map<String, Object>{
            'Job_Title__c'             => 'Consultant Cardiologist',
            'Description__c'           => 'Provide comprehensive cardiac care',
            'Category__c'              => 'Medical',
            'Role_Type__c'             => 'Doctor',
            'Department__c'            => 'Emergency',
            'Employment_Type__c'       => 'Full-time',
            'Shift_Type__c'            => 'Day',
            'Min_Experience_Years__c'  => 2,
            'Max_Experience_Years__c'  => 10,
            'Start_Date__c'            => '2026-02-01',
            'End_Date__c'              => '2026-04-01',
            'Facility_Name__c'         => 'City Hospital',
            'City__c'                  => 'San Francisco',
            'State__c'                 => 'CA',
            'Country__c'               => 'USA',
            'Credentialing_Required__c'=> true,
            'Privilege_Scope__c'       => 'Full cardiology privileges'
        };

        List<Object> educationRequirements = new List<Object>{
            new Map<String, Object>{
                'Degree_Name__c' => 'MBBS',
                'Mandatory__c'   => true
            }
        };

        List<Object> licenseRequirements = new List<Object>{
            new Map<String, Object>{
                'License_Name__c'          => 'Medical Council Registration',
                'Issuing_Authority__c'     => 'Medical Council of USA',
                'Active_Required__c'       => true,
                'Expiry_Check_Required__c' => true
            }
        };

        List<Object> certificationRequirements = new List<Object>{
            new Map<String, Object>{
                'Certification_Name__c' => 'BLS',
                'Mandatory__c'          => true
            }
        };

        List<Object> clinicalSkills = new List<Object>{
            new Map<String, Object>{
                'Skill_Name__c'  => 'ECG Interpretation',
                'Skill_Level__c' => 'Advanced',
                'Mandatory__c'   => true
            }
        };

        List<Object> procedureRequirements = new List<Object>{
            new Map<String, Object>{
                'Procedure_Name__c' => 'IV Cannulation',
                'Critical__c'       => true
            }
        };

        List<Object> complianceRequirements = new List<Object>{
            new Map<String, Object>{
                'Compliance_Name__c' => 'HIPAA',
                'Mandatory__c'       => true
            }
        };

        Map<String, Object> aiData = new Map<String, Object>();
        aiData.put('jobPosting', jobPosting);
        aiData.put('educationRequirements', educationRequirements);
        aiData.put('licenseRequirements', licenseRequirements);
        aiData.put('certificationRequirements', certificationRequirements);
        aiData.put('clinicalSkills', clinicalSkills);
        aiData.put('procedureRequirements', procedureRequirements);
        aiData.put('complianceRequirements', complianceRequirements);

        return aiData;
    }

    // ---------------------------------------------------------------------
    // Test: Successful creation of comprehensive job posting (main + children)
    // ---------------------------------------------------------------------
    @IsTest
    static void testCreateComprehensiveJobPosting_FullData() {
        Map<String, Object> aiData = buildFullAIData();

        Test.startTest();
        String jobPostingId = AIJobPostingService.createComprehensiveJobPosting(aiData);
        Test.stopTest();

        System.assertNotEquals(null, jobPostingId, 'Job Posting Id should not be null');

        // Verify main Job_Posting__c record
        Job_Posting__c jp = [
            SELECT Job_Title__c, Description__c, Category__c, Role_Type__c,
                   Department__c, Employment_Type__c, Shift_Type__c,
                   Min_Experience_Years__c, Max_Experience_Years__c,
                   Start_Date__c, End_Date__c,
                   Facility_Name__c, City__c, State__c, Country__c,
                   Credentialing_Required__c, Privilege_Scope__c
            FROM Job_Posting__c
            WHERE Id = :jobPostingId
        ];

        System.assertEquals('Consultant Cardiologist', jp.Job_Title__c);
        System.assertEquals('Provide comprehensive cardiac care', jp.Description__c);
        System.assertEquals('Medical', jp.Category__c);
        System.assertEquals('Doctor', jp.Role_Type__c);
        System.assertEquals('Emergency', jp.Department__c);
        System.assertEquals('Full-time', jp.Employment_Type__c);
        System.assertEquals('Day', jp.Shift_Type__c);
        System.assertEquals(2, jp.Min_Experience_Years__c);
        System.assertEquals(10, jp.Max_Experience_Years__c);
        System.assertEquals(Date.newInstance(2026, 2, 1), jp.Start_Date__c);
        System.assertEquals(Date.newInstance(2026, 4, 1), jp.End_Date__c);
        System.assertEquals('City Hospital', jp.Facility_Name__c);
        System.assertEquals('San Francisco', jp.City__c);
        System.assertEquals('CA', jp.State__c);
        System.assertEquals('USA', jp.Country__c);
        System.assertEquals(true, jp.Credentialing_Required__c);
        System.assertEquals('Full cardiology privileges', jp.Privilege_Scope__c);

        // Verify child records

        // Education
        List<Job_Education_Requirement__c> edu = [
            SELECT Job_Posting__c, Degree_Name__c, Mandatory__c
            FROM Job_Education_Requirement__c
            WHERE Job_Posting__c = :jobPostingId
        ];
        System.assertEquals(1, edu.size(), 'One education requirement expected');
        System.assertEquals('MBBS', edu[0].Degree_Name__c);
        System.assertEquals(true, edu[0].Mandatory__c);

        // License
        List<Job_License_Requirement__c> lic = [
            SELECT License_Name__c, Issuing_Authority__c,
                   Active_Required__c, Expiry_Check_Required__c
            FROM Job_License_Requirement__c
            WHERE Job_Posting__c = :jobPostingId
        ];
        System.assertEquals(1, lic.size(), 'One license requirement expected');
        System.assertEquals('Medical Council Registration', lic[0].License_Name__c);
        System.assertEquals('Medical Council of USA', lic[0].Issuing_Authority__c);
        System.assertEquals(true, lic[0].Active_Required__c);
        System.assertEquals(true, lic[0].Expiry_Check_Required__c);

        // Certification
        List<Job_Certification_Requirement__c> certs = [
            SELECT Certification_Name__c, Mandatory__c
            FROM Job_Certification_Requirement__c
            WHERE Job_Posting__c = :jobPostingId
        ];
        System.assertEquals(1, certs.size(), 'One certification requirement expected');
        System.assertEquals('BLS', certs[0].Certification_Name__c);
        System.assertEquals(true, certs[0].Mandatory__c);

        // Clinical skills
        List<Job_Clinical_Skill__c> skills = [
            SELECT Skill_Name__c, Skill_Level__c, Mandatory__c
            FROM Job_Clinical_Skill__c
            WHERE Job_Posting__c = :jobPostingId
        ];
        System.assertEquals(1, skills.size(), 'One clinical skill expected');
        System.assertEquals('ECG Interpretation', skills[0].Skill_Name__c);
        System.assertEquals('Advanced', skills[0].Skill_Level__c);
        System.assertEquals(true, skills[0].Mandatory__c);

        // Procedures
        List<Job_Procedure_Requirement__c> procs = [
            SELECT Procedure_Name__c, Critical__c
            FROM Job_Procedure_Requirement__c
            WHERE Job_Posting__c = :jobPostingId
        ];
        System.assertEquals(1, procs.size(), 'One procedure requirement expected');
        System.assertEquals('IV Cannulation', procs[0].Procedure_Name__c);
        System.assertEquals(true, procs[0].Critical__c);

        // Compliance
        List<Job_Compliance_Requirement__c> comps = [
            SELECT Compliance_Name__c, Mandatory__c
            FROM Job_Compliance_Requirement__c
            WHERE Job_Posting__c = :jobPostingId
        ];
        System.assertEquals(1, comps.size(), 'One compliance requirement expected');
        System.assertEquals('HIPAA', comps[0].Compliance_Name__c);
        System.assertEquals(true, comps[0].Mandatory__c);
    }

    // ---------------------------------------------------------------------
    // Test: Defaults and missing optional child lists
    // ---------------------------------------------------------------------
    @IsTest
    static void testCreateComprehensiveJobPosting_DefaultsAndNoChildren() {
        // jobPosting with minimal required plus some missing fields to trigger defaults
        Map<String, Object> jobPosting = new Map<String, Object>{
            'Job_Title__c'       => 'Staff Nurse',
            'Category__c'        => null,        // should default to Medical
            'Role_Type__c'       => 'Nurse',
            'Employment_Type__c' => null,        // should default to Full-time
            'Facility_Name__c'   => 'General Hospital',
            'City__c'            => 'Boston',
            'State__c'           => 'MA',
            'Country__c'         => 'USA',
            'Start_Date__c'      => null,        // should default to today + 30
            'Min_Experience_Years__c' => null,
            'Max_Experience_Years__c' => null,
            'Credentialing_Required__c' => null  // should use default false
        };

        Map<String, Object> aiData = new Map<String, Object>{
            'jobPosting'             => jobPosting,
            'educationRequirements'  => new List<Object>(),
            'licenseRequirements'    => new List<Object>(),
            'certificationRequirements' => new List<Object>(),
            'clinicalSkills'         => new List<Object>(),
            'procedureRequirements'  => new List<Object>(),
            'complianceRequirements' => new List<Object>()
        };

        Date todayPlus30 = Date.today().addDays(30);

        Test.startTest();
        String jobPostingId = AIJobPostingService.createComprehensiveJobPosting(aiData);
        Test.stopTest();

        Job_Posting__c jp = [
            SELECT Job_Title__c, Category__c, Role_Type__c, Employment_Type__c,
                   Facility_Name__c, City__c, State__c, Country__c,
                   Start_Date__c, Min_Experience_Years__c, Max_Experience_Years__c,
                   Credentialing_Required__c
            FROM Job_Posting__c
            WHERE Id = :jobPostingId
        ];

        System.assertEquals('Staff Nurse', jp.Job_Title__c);
        System.assertEquals('Medical', jp.Category__c, 'Category should default to Medical');
        System.assertEquals('Nurse', jp.Role_Type__c);
        System.assertEquals('Full-time', jp.Employment_Type__c, 'Employment type should default to Full-time');
        System.assertEquals('General Hospital', jp.Facility_Name__c);
        System.assertEquals('Boston', jp.City__c);
        System.assertEquals('MA', jp.State__c);
        System.assertEquals('USA', jp.Country__c);
        System.assertEquals(todayPlus30, jp.Start_Date__c, 'Start date should default to today + 30 days');
        System.assertEquals(null, jp.Min_Experience_Years__c);
        System.assertEquals(null, jp.Max_Experience_Years__c);
        System.assertEquals(false, jp.Credentialing_Required__c, 'Should use default false');

        // No child records expected
        System.assertEquals(0, [SELECT COUNT() FROM Job_Education_Requirement__c WHERE Job_Posting__c = :jobPostingId]);
        System.assertEquals(0, [SELECT COUNT() FROM Job_License_Requirement__c   WHERE Job_Posting__c = :jobPostingId]);
        System.assertEquals(0, [SELECT COUNT() FROM Job_Certification_Requirement__c WHERE Job_Posting__c = :jobPostingId]);
        System.assertEquals(0, [SELECT COUNT() FROM Job_Clinical_Skill__c        WHERE Job_Posting__c = :jobPostingId]);
        System.assertEquals(0, [SELECT COUNT() FROM Job_Procedure_Requirement__c WHERE Job_Posting__c = :jobPostingId]);
        System.assertEquals(0, [SELECT COUNT() FROM Job_Compliance_Requirement__c WHERE Job_Posting__c = :jobPostingId]);
    }

    // ---------------------------------------------------------------------
    // Test: Validation error path (missing required fields) and rollback
    // ---------------------------------------------------------------------
    @IsTest
    static void testCreateComprehensiveJobPosting_MissingRequired() {
        // Missing Job_Title__c -> should throw CalloutException and rollback
        Map<String, Object> jobPosting = new Map<String, Object>{
            // 'Job_Title__c' missing
            'Category__c'        => 'Medical',
            'Role_Type__c'       => 'Doctor',
            'Employment_Type__c' => 'Full-time',
            'Facility_Name__c'   => 'City Hospital',
            'City__c'            => 'San Francisco',
            'State__c'           => 'CA',
            'Country__c'         => 'USA'
        };

        Map<String, Object> aiData = new Map<String, Object>{
            'jobPosting' => jobPosting
        };

        Integer beforeCount = [SELECT COUNT() FROM Job_Posting__c];
        Boolean exceptionThrown = false;

        try {
            Test.startTest();
            AIJobPostingService.createComprehensiveJobPosting(aiData);
            Test.stopTest();
        } catch (CalloutException e) {
            exceptionThrown = true;
            System.assert(
                e.getMessage().contains('Job Title is required'),
                'Exception message should mention Job Title'
            );
        }

        System.assertEquals(true, exceptionThrown, 'Expected CalloutException to be thrown');

        Integer afterCount = [SELECT COUNT() FROM Job_Posting__c];
        System.assertEquals(
            beforeCount,
            afterCount,
            'No Job_Posting__c records should have been inserted due to rollback'
        );
    }

    // ---------------------------------------------------------------------
    // Test: Helper methods getString, getDate, getDecimal, getBoolean
    // ---------------------------------------------------------------------
    @IsTest
    static void testHelperMethods() {
        Map<String, Object> data = new Map<String, Object>{
            'stringKey'   => ' Test String ',
            'nullString'  => 'null',
            'dateKey'     => '2026-02-01',
            'badDate'     => '2026/02/01',
            'decimalKey'  => '123.45',
            'badDecimal'  => 'abc',
            'boolTrue1'   => true,
            'boolTrue2'   => 'Yes',
            'boolFalse1'  => false,
            'boolFalse2'  => '0',
            'boolUnknown' => 'maybe'
        };

        // getString
        System.assertEquals('Test String', AIJobPostingService.getString(data, 'stringKey'));
        System.assertEquals(null, AIJobPostingService.getString(data, 'nullString'));

        // getDate
        Date d = AIJobPostingService.getDate(data, 'dateKey');
        System.assertEquals(Date.newInstance(2026, 2, 1), d);
        System.assertEquals(null, AIJobPostingService.getDate(data, 'badDate'));

        // getDecimal
        Decimal dec = AIJobPostingService.getDecimal(data, 'decimalKey');
        System.assertEquals(123.45, dec);
        System.assertEquals(null, AIJobPostingService.getDecimal(data, 'badDecimal'));

        // getBoolean
        System.assertEquals(true,  AIJobPostingService.getBoolean(data, 'boolTrue1', false));
        System.assertEquals(true,  AIJobPostingService.getBoolean(data, 'boolTrue2', false));
        System.assertEquals(false, AIJobPostingService.getBoolean(data, 'boolFalse1', true));
        System.assertEquals(false, AIJobPostingService.getBoolean(data, 'boolFalse2', true));
        // unknown value -> default
        System.assertEquals(true,  AIJobPostingService.getBoolean(data, 'boolUnknown', true));
    }

    // ---------------------------------------------------------------------
    // Test: processNLPInput with mocked Gemini response
    // ---------------------------------------------------------------------
    @IsTest
    static void testProcessNLPInput_Success() {
        Test.setMock(HttpCalloutMock.class, new GeminiApiMock());

        Test.startTest();
        Map<String, Object> result = AIJobPostingService.processNLPInput(
            'We need a Consultant Cardiologist in San Francisco.'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result map should not be null');
        System.assert(result.containsKey('jobPosting'), 'Result should contain jobPosting key');

        Map<String, Object> jobPosting = (Map<String, Object>) result.get('jobPosting');
        System.assertEquals('Consultant Cardiologist', jobPosting.get('Job_Title__c'));
        System.assertEquals('Medical', jobPosting.get('Category__c'));
        System.assertEquals('Doctor', jobPosting.get('Role_Type__c'));
        System.assertEquals('San Francisco', jobPosting.get('City__c'));
    }

    // ---------------------------------------------------------------------
    // Test: testGeminiConnection with mocked Gemini response
    // ---------------------------------------------------------------------
    @IsTest
    static void testTestGeminiConnection() {
        Test.setMock(HttpCalloutMock.class, new GeminiApiMock());

        Test.startTest();
        String result = AIJobPostingService.testGeminiConnection();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result string should not be null');
        System.assert(
            result.startsWith('Gemini Test Result:') ||
            result.startsWith('Gemini Test Error:'),
            'Result should be prefixed by Gemini Test Result/Error'
        );
    }

    // ---------------------------------------------------------------------
    // HttpCalloutMock for Gemini API
    // This is designed to match what GeminiAPIService.extractContent expects:
    //  body.candidates[0].content.parts[0].text contains the JSON string.
    // ---------------------------------------------------------------------
    private class GeminiApiMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            // Inner JSON exactly as AIJobPostingService expects (jobPosting + child arrays)
            String innerJson =
                '{' +
                    '"jobPosting":{' +
                        '"Job_Title__c":"Consultant Cardiologist",' +
                        '"Description__c":"Provide comprehensive cardiac care",' +
                        '"Category__c":"Medical",' +
                        '"Role_Type__c":"Doctor",' +
                        '"Employment_Type__c":"Full-time",' +
                        '"Facility_Name__c":"City Hospital",' +
                        '"City__c":"San Francisco",' +
                        '"State__c":"CA",' +
                        '"Country__c":"USA",' +
                        '"Start_Date__c":"2026-02-01",' +
                        '"End_Date__c":"2026-04-01"' +
                    '},' +
                    '"educationRequirements":[{"Degree_Name__c":"MBBS","Mandatory__c":true}],' +
                    '"licenseRequirements":[{"License_Name__c":"Medical Council Registration","Issuing_Authority__c":"Medical Council of USA","Active_Required__c":true,"Expiry_Check_Required__c":true}],' +
                    '"certificationRequirements":[{"Certification_Name__c":"BLS","Mandatory__c":true}],' +
                    '"clinicalSkills":[{"Skill_Name__c":"ECG Interpretation","Skill_Level__c":"Advanced","Mandatory__c":true}],' +
                    '"procedureRequirements":[{"Procedure_Name__c":"IV Cannulation","Critical__c":true}],' +
                    '"complianceRequirements":[{"Compliance_Name__c":"HIPAA","Mandatory__c":true}]' +
                '}';

            // Gemini-style wrapper response
            String body =
                '{' +
                    '"candidates":[{' +
                        '"content":{"parts":[{' +
                            '"text":"' + innerJson.replace('"', '\\"') + '"' +
                        '}]}' +
                    '}],' +
                    '"modelVersion":"test-model"' +
                '}';

            res.setBody(body);
            return res;
        }
    }
}