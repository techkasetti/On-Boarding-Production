@IsTest
private class CandidateProfileControllerTest {
    private static Candidate__c createCandidate() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Profile Candidate',
            Email__c = 'profile.candidate@example.com',
            Resume_parsing_using_ai__c = true,
            Resume_Status__c = true
        );
        insert c;
        return c;
    }

    @IsTest
    static void testProfileReadSaveDeleteAndDuplicates() {
        Candidate__c candidate = createCandidate();

        String workJson = JSON.serialize(new Map<String, Object>{
            'Candidate__c' => candidate.Id,
            'Role__c' => 'RN',
            'Organization__c' => 'General Hospital',
            'Start_Date__c' => '2020-01-01',
            'End_Date__c' => '2021-01-01',
            'Is_Current__c' => false,
            'Responsibilities__c' => 'Patient care'
        });
        Id workId = CandidateProfileController.saveRecord(workJson, 'workExperience');

        String educationJson = JSON.serialize(new Map<String, Object>{
            'Candidate__c' => candidate.Id,
            'Degree__c' => 'MBBS',
            'Institution__c' => 'Med University',
            'Start_Year__c' => 2012,
            'End_Year__c' => 2017,
            'Details__c' => 'Good standing'
        });
        Id educationId = CandidateProfileController.saveRecord(educationJson, 'education');

        String licenseJson = JSON.serialize(new Map<String, Object>{
            'Candidate__c' => candidate.Id,
            'Name' => 'State Medical License',
            'Type__c' => 'Medical License',
            'Issue_Date__c' => '2021-06-01',
            'Expiry_Date__c' => '2028-06-01',
            'Notes__c' => 'Active'
        });
        Id licenseId = CandidateProfileController.saveRecord(licenseJson, 'license');

        String clinicalJson = JSON.serialize(new Map<String, Object>{
            'Candidate__c' => candidate.Id,
            'Name' => 'Emergency Care',
            'Skill_Type__c' => 'Critical Care',
            'Description__c' => 'ER management'
        });
        Id clinicalId = CandidateProfileController.saveRecord(clinicalJson, 'clinicalSkill');

        String technicalJson = JSON.serialize(new Map<String, Object>{
            'Candidate__c' => candidate.Id,
            'Name' => 'EHR',
            'Category__c' => 'Software',
            'Description__c' => 'Epic'
        });
        Id technicalId = CandidateProfileController.saveRecord(technicalJson, 'technicalSkill');

        String procedureJson = JSON.serialize(new Map<String, Object>{
            'Candidate__c' => candidate.Id,
            'Name' => 'Intubation',
            'Category__c' => 'Critical',
            'Notes__c' => 'Experienced'
        });
        Id procedureId = CandidateProfileController.saveRecord(procedureJson, 'procedure');

        String internshipJson = JSON.serialize(new Map<String, Object>{
            'Candidate__c' => candidate.Id,
            'Organization__c' => 'City Hospital',
            'Start_Date__c' => '2016-01-01',
            'End_Date__c' => '2016-12-31'
        });
        Id internshipId = CandidateProfileController.saveRecord(internshipJson, 'internship');

        String researchJson = JSON.serialize(new Map<String, Object>{
            'Candidate__c' => candidate.Id,
            'Title__c' => 'Cardio Study',
            'Type__c' => 'Journal',
            'Publication_Date__c' => '2022-01-01',
            'Description__c' => 'Peer reviewed'
        });
        Id researchId = CandidateProfileController.saveRecord(researchJson, 'research');

        String membershipJson = JSON.serialize(new Map<String, Object>{
            'Candidate__c' => candidate.Id,
            'Organization_Name__c' => 'Medical Association',
            'Membership_Type__c' => 'Professional',
            'Member_Id__c' => 'M-1001',
            'Member_Since__c' => '2020-01-01'
        });
        Id membershipId = CandidateProfileController.saveRecord(membershipJson, 'membership');

        // Update path with Id present
        String workUpdateJson = JSON.serialize(new Map<String, Object>{
            'Id' => workId,
            'Candidate__c' => candidate.Id,
            'Role__c' => 'Senior RN',
            'Organization__c' => 'General Hospital',
            'Start_Date__c' => '2020-01-01',
            'End_Date__c' => '2022-01-01',
            'Is_Current__c' => false,
            'Responsibilities__c' => 'Lead nurse'
        });
        CandidateProfileController.saveRecord(workUpdateJson, 'workExperience');

        Test.startTest();
        CandidateProfileController.ProfileDataDto dto = CandidateProfileController.getProfileData(candidate.Id);
        String duplicateMsg = CandidateProfileController.checkDuplicate(
            String.valueOf(candidate.Id),
            'workExperience',
            '{"Role__c":"Senior RN","Organization__c":"General Hospital"}',
            null
        );
        String noDupMsg = CandidateProfileController.checkDuplicate(
            String.valueOf(candidate.Id),
            'workExperience',
            '{"Role__c":"Senior RN","Organization__c":"General Hospital"}',
            String.valueOf(workId)
        );
        Test.stopTest();

        System.assertEquals(candidate.Id, dto.candidate.Id);
        System.assertEquals(1, dto.workExperiences.size());
        System.assertEquals(1, dto.educations.size());
        System.assertEquals(1, dto.licenses.size());
        System.assertEquals(1, dto.clinicalSkills.size());
        System.assertEquals(1, dto.technicalSkills.size());
        System.assertEquals(1, dto.procedures.size());
        System.assertEquals(1, dto.internships.size());
        System.assertEquals(1, dto.researchPublications.size());
        System.assertEquals(1, dto.memberships.size());
        System.assertNotEquals(null, duplicateMsg);
        System.assertEquals(null, noDupMsg);

        CandidateProfileController.deleteRecord(workId, 'workExperience');
        CandidateProfileController.deleteRecord(educationId, 'education');
        CandidateProfileController.deleteRecord(clinicalId, 'clinicalSkill');
        CandidateProfileController.deleteRecord(technicalId, 'technicalSkill');
        CandidateProfileController.deleteRecord(procedureId, 'procedure');
        CandidateProfileController.deleteRecord(internshipId, 'internship');
        CandidateProfileController.deleteRecord(researchId, 'research');
        CandidateProfileController.deleteRecord(membershipId, 'membership');

        System.assertEquals(0, [SELECT Count() FROM Work_Experience__c WHERE Candidate__c = :candidate.Id]);
        System.assertEquals(0, [SELECT Count() FROM Education__c WHERE Candidate__c = :candidate.Id]);
        System.assertEquals(0, [SELECT Count() FROM Clinical_Skill__c WHERE Candidate__c = :candidate.Id]);
        System.assertEquals(0, [SELECT Count() FROM Technical_Skill__c WHERE Candidate__c = :candidate.Id]);
        System.assertEquals(0, [SELECT Count() FROM Procedure__c WHERE Candidate__c = :candidate.Id]);
        System.assertEquals(0, [SELECT Count() FROM Internship__c WHERE Candidate__c = :candidate.Id]);
        System.assertEquals(0, [SELECT Count() FROM Research_Publication__c WHERE Candidate__c = :candidate.Id]);
        System.assertEquals(0, [SELECT Count() FROM Membership__c WHERE Candidate__c = :candidate.Id]);

        // License record deleted separately after document tests
        CandidateProfileController.deleteRecord(licenseId, 'license');
        System.assertEquals(0, [SELECT Count() FROM License_Certification__c WHERE Candidate__c = :candidate.Id]);
    }

    @IsTest
    static void testDocumentsResumeAndNegativePaths() {
        Candidate__c candidate = createCandidate();

        License_Certification__c license = new License_Certification__c(
            Candidate__c = candidate.Id,
            Name = 'Doc License',
            Type__c = 'Medical License'
        );
        insert license;

        ContentVersion licenseFile = new ContentVersion(
            Title = 'LicenseProof',
            PathOnClient = 'LicenseProof.pdf',
            VersionData = Blob.valueOf('license'),
            FirstPublishLocationId = license.Id,
            IsMajorVersion = true
        );
        insert licenseFile;

        ContentVersion candidateResume = new ContentVersion(
            Title = 'CandidateResume',
            PathOnClient = 'CandidateResume.pdf',
            VersionData = Blob.valueOf('resume'),
            FirstPublishLocationId = candidate.Id,
            IsMajorVersion = true
        );
        insert candidateResume;

        ContentVersion savedResume = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :candidateResume.Id
        ];

        Test.startTest();
        List<CandidateProfileController.DocumentInfo> docs = CandidateProfileController.getLicenseDocuments(license.Id);
        Map<String, Object> resumeInfo = CandidateProfileController.getCandidateResumeInfo(candidate.Id);
        CandidateProfileController.uploadResumeFile(candidate.Id, 'FreshResume.pdf', EncodingUtil.base64Encode(Blob.valueOf('new resume')));
        CandidateProfileController.resetResumeStatus(candidate.Id);
        CandidateProfileController.deleteLicenseDocument(savedResume.ContentDocumentId);
        Test.stopTest();

        Candidate__c updated = [SELECT Resume_Status__c FROM Candidate__c WHERE Id = :candidate.Id];
        System.assertEquals(false, updated.Resume_Status__c);
        System.assertEquals(1, docs.size());
        System.assertEquals(true, (Boolean) resumeInfo.get('hasResume'));
        System.assertEquals(true, (Boolean) resumeInfo.get('useAiParsing'));

        try {
            CandidateProfileController.getProfileData(null);
            System.assert(false, 'Expected exception for null candidate Id');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            CandidateProfileController.getProfileData('003000000000000AAA');
            System.assert(false, 'Expected candidate not found exception');
        } catch (Exception e) {
            System.assert(true);
        }

        try {
            CandidateProfileController.saveRecord('', 'workExperience');
            System.assert(false, 'Expected save validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            CandidateProfileController.saveRecord('{"Candidate__c":null}', 'badType');
            System.assert(false, 'Expected invalid type exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            CandidateProfileController.deleteRecord(null, 'workExperience');
            System.assert(false, 'Expected delete validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            CandidateProfileController.deleteRecord(candidate.Id, 'badType');
            System.assert(false, 'Expected invalid type exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            CandidateProfileController.deleteLicenseDocument(null);
            System.assert(false, 'Expected document validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        System.assertEquals(0, CandidateProfileController.getLicenseDocuments(null).size());
    }

    @IsTest
    static void testDuplicateBranchesAndErrorBranches() {
        Candidate__c candidate = createCandidate();

        insert new Work_Experience__c(Candidate__c = candidate.Id, Role__c = 'RN', Organization__c = 'GH');
        insert new Education__c(Candidate__c = candidate.Id, Degree__c = 'MBBS', Institution__c = 'MU');
        insert new License_Certification__c(Candidate__c = candidate.Id, Name = 'State License');
        insert new Clinical_Skill__c(Candidate__c = candidate.Id, Name = 'Critical Care');
        insert new Technical_Skill__c(Candidate__c = candidate.Id, Name = 'EHR');
        insert new Procedure__c(Candidate__c = candidate.Id, Name = 'Intubation');
        insert new Internship__c(Candidate__c = candidate.Id, Organization__c = 'City Hospital');
        insert new Research_Publication__c(Candidate__c = candidate.Id, Title__c = 'Cardio Study');
        insert new Membership__c(Candidate__c = candidate.Id, Organization_Name__c = 'Medical Association');

        System.assertNotEquals(null, CandidateProfileController.checkDuplicate(String.valueOf(candidate.Id), 'education', '{"Degree__c":"MBBS","Institution__c":"MU"}', null));
        System.assertNotEquals(null, CandidateProfileController.checkDuplicate(String.valueOf(candidate.Id), 'license', '{"Name":"State License"}', null));
        System.assertNotEquals(null, CandidateProfileController.checkDuplicate(String.valueOf(candidate.Id), 'clinicalSkill', '{"Name":"Critical Care"}', null));
        System.assertNotEquals(null, CandidateProfileController.checkDuplicate(String.valueOf(candidate.Id), 'technicalSkill', '{"Name":"EHR"}', null));
        System.assertNotEquals(null, CandidateProfileController.checkDuplicate(String.valueOf(candidate.Id), 'procedure', '{"Name":"Intubation"}', null));
        System.assertNotEquals(null, CandidateProfileController.checkDuplicate(String.valueOf(candidate.Id), 'internship', '{"Organization__c":"City Hospital"}', null));
        System.assertNotEquals(null, CandidateProfileController.checkDuplicate(String.valueOf(candidate.Id), 'research', '{"Title__c":"Cardio Study"}', null));
        System.assertNotEquals(null, CandidateProfileController.checkDuplicate(String.valueOf(candidate.Id), 'membership', '{"Organization_Name__c":"Medical Association"}', null));

        System.assertEquals(null, CandidateProfileController.checkDuplicate(null, 'workExperience', '{"Role__c":"RN"}', null));
        System.assertEquals(null, CandidateProfileController.checkDuplicate(String.valueOf(candidate.Id), 'workExperience', 'not-json', null));

        // Parse error branches
        String badDateJson = JSON.serialize(new Map<String, Object>{
            'Candidate__c' => candidate.Id,
            'Organization__c' => 'Bad Date Org',
            'Start_Date__c' => 'bad-date',
            'End_Date__c' => ''
        });
        Id internshipId = CandidateProfileController.saveRecord(badDateJson, 'internship');
        System.assertNotEquals(null, internshipId);

        String badDecimalJson = JSON.serialize(new Map<String, Object>{
            'Candidate__c' => candidate.Id,
            'Institution__c' => 'Bad Decimal U',
            'Degree__c' => 'Test Degree',
            'Start_Year__c' => 'not-a-number',
            'End_Year__c' => ''
        });
        Id educationId = CandidateProfileController.saveRecord(badDecimalJson, 'education');
        System.assertNotEquals(null, educationId);

        try {
            CandidateProfileController.uploadResumeFile(candidate.Id, 'Broken.pdf', '%%%notbase64%%%');
            System.assert(false, 'Expected invalid base64 exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            CandidateProfileController.resetResumeStatus(null);
            System.assert(false, 'Expected reset failure for null id');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            CandidateProfileController.deleteLicenseDocument('069000000000000AAA');
            System.assert(false, 'Expected delete failure for unknown content doc');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
