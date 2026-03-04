@IsTest
private class OnboardingOrchestratorV2Test {
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"ok":true}');
            return res;
        }
    }

    private class EmptyBodyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('');
            return res;
        }
    }

    private class ErrorStatusMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"boom"}');
            return res;
        }
    }

    private class UnauthorizedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new System.CalloutException('Unauthorized endpoint, please check Remote Site Settings.');
        }
    }

    private class NetworkMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new System.CalloutException('Read timed out');
        }
    }

    private static Candidate__c createCandidate(String suffix) {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'OnbV2 Candidate ' + suffix,
            Email__c = 'onbv2.' + suffix + '@example.com'
        );
        insert c;
        return c;
    }

    private static String buildPayload(Id candidateId, String phone, List<String> licenses, List<String> clinical,
        List<String> tech, List<String> procedures, List<String> publications, List<String> memberships,
        String role, String org, String eduDegree, String internOrg, List<String> rotations) {

        Map<String, Object> payload = new Map<String, Object>{
            'candidateId' => String.valueOf(candidateId),
            'personalInformation' => new Map<String, Object>{
                'value' => new Map<String, Object>{
                    'phone' => phone
                }
            },
            'licensesAndCertifications' => new Map<String, Object>{ 'value' => licenses },
            'clinicalSkills' => new Map<String, Object>{ 'value' => clinical },
            'technicalSkills' => new Map<String, Object>{ 'value' => tech },
            'proceduresPerformed' => new Map<String, Object>{ 'value' => procedures },
            'researchAndPublications' => new Map<String, Object>{ 'value' => publications },
            'professionalMemberships' => new Map<String, Object>{ 'value' => memberships },
            'workExperience' => new Map<String, Object>{
                'value' => new Map<String, Object>{
                    'role' => role,
                    'organization' => org,
                    'duration' => '2 years',
                    'responsibilities' => new List<String>{ 'Care', 'Rounds' }
                }
            },
            'education' => new Map<String, Object>{
                'value' => new Map<String, Object>{
                    'degree' => eduDegree,
                    'institution' => 'Medical University',
                    'year' => '2019',
                    'details' => 'Top rank'
                }
            },
            'internship' => new Map<String, Object>{
                'value' => new Map<String, Object>{
                    'organization' => internOrg,
                    'duration' => '1 year',
                    'rotations' => rotations
                }
            }
        };

        return JSON.serialize(payload);
    }

    @IsTest
    static void testFetchResumePreviewV2Branches() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        String ok = OnboardingOrchestratorV2.fetchResumePreviewV2(null);
        Test.stopTest();
        System.assertEquals('{"ok":true}', ok);

        Test.setMock(HttpCalloutMock.class, new EmptyBodyMock());
        try {
            OnboardingOrchestratorV2.fetchResumePreviewV2(null);
            System.assert(false, 'Expected empty response exception');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        Test.setMock(HttpCalloutMock.class, new ErrorStatusMock());
        try {
            OnboardingOrchestratorV2.fetchResumePreviewV2(null);
            System.assert(false, 'Expected webhook error');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        Test.setMock(HttpCalloutMock.class, new UnauthorizedMock());
        try {
            OnboardingOrchestratorV2.fetchResumePreviewV2(null);
            System.assert(false, 'Expected remote site error');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        Test.setMock(HttpCalloutMock.class, new NetworkMock());
        try {
            OnboardingOrchestratorV2.fetchResumePreviewV2(null);
            System.assert(false, 'Expected network error');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    @IsTest
    static void testPersistStructuredResumeDataInsertUpdateDeleteFlows() {
        Candidate__c c = createCandidate('sync');

        String payload1 = buildPayload(
            c.Id, '9000000001',
            new List<String>{ 'BLS', 'ACLS' },
            new List<String>{ 'Cardiology', 'Trauma' },
            new List<String>{ 'EHR', 'Excel' },
            new List<String>{ 'Intubation', 'Suturing' },
            new List<String>{ 'Paper A', 'Paper B' },
            new List<String>{ 'AMA', 'Cardio Assoc' },
            'Resident', 'City Hospital', 'MBBS', 'Metro Hospital',
            new List<String>{ 'ICU', 'ER' }
        );

        Test.startTest();
        OnboardingOrchestratorV2.persistStructuredResumeData(payload1);
        Test.stopTest();

        System.assertEquals(2, [SELECT Count() FROM License_Certification__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(2, [SELECT Count() FROM Clinical_Skill__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(2, [SELECT Count() FROM Technical_Skill__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(2, [SELECT Count() FROM Procedure__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(2, [SELECT Count() FROM Research_Publication__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(2, [SELECT Count() FROM Membership__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(1, [SELECT Count() FROM Work_Experience__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(1, [SELECT Count() FROM Education__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(1, [SELECT Count() FROM Internship__c WHERE Candidate__c = :c.Id]);

        Id internshipId = [SELECT Id FROM Internship__c WHERE Candidate__c = :c.Id LIMIT 1].Id;
        System.assertEquals(2, [SELECT Count() FROM Internship_Rotation__c WHERE Internship__c = :internshipId]);

        // second sync: update one existing, insert one new, delete stale
        String payload2 = buildPayload(
            c.Id, '9000000002',
            new List<String>{ 'BLS', 'PALS' },
            new List<String>{ 'Cardiology' },
            new List<String>{ 'EHR', 'PowerBI' },
            new List<String>{ 'Intubation' },
            new List<String>{ 'Paper A', 'Paper C' },
            new List<String>{ 'AMA' },
            'Senior Resident', 'County Hospital', 'MD', 'Central Hospital',
            new List<String>{ 'ER' }
        );

        OnboardingOrchestratorV2.persistStructuredResumeData(payload2);

        Candidate__c updatedCandidate = [SELECT Phone__c FROM Candidate__c WHERE Id = :c.Id LIMIT 1];
        System.assertEquals('9000000002', updatedCandidate.Phone__c);

        System.assertEquals(2, [SELECT Count() FROM License_Certification__c WHERE Candidate__c = :c.Id]); // BLS + PALS
        System.assertEquals(1, [SELECT Count() FROM Clinical_Skill__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(2, [SELECT Count() FROM Technical_Skill__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(1, [SELECT Count() FROM Procedure__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(2, [SELECT Count() FROM Research_Publication__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(1, [SELECT Count() FROM Membership__c WHERE Candidate__c = :c.Id]);
        System.assertEquals(1, [SELECT Count() FROM Internship_Rotation__c WHERE Internship__c = :internshipId]);

        Work_Experience__c we = [SELECT Role__c, Organization__c FROM Work_Experience__c WHERE Candidate__c = :c.Id LIMIT 1];
        System.assertEquals('Senior Resident', we.Role__c);
        System.assertEquals('County Hospital', we.Organization__c);

        Education__c ed = [SELECT Degree__c FROM Education__c WHERE Candidate__c = :c.Id LIMIT 1];
        System.assertEquals('MD', ed.Degree__c);
    }

    @IsTest
    static void testPersistStructuredResumeDataNegativePaths() {
        try {
            OnboardingOrchestratorV2.persistStructuredResumeData('not-json');
            System.assert(false, 'Expected invalid JSON exception');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }

        try {
            OnboardingOrchestratorV2.persistStructuredResumeData('{"candidateId":null}');
            System.assert(false, 'Expected missing candidate exception');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }
}
