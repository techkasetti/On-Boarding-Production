@IsTest
private class CandidateProfileControllerTest {
    private static Candidate__c makeCandidate() {
        Candidate__c c = new Candidate__c(
            Full_Name__c = 'Profile Candidate',
            Email__c = 'profile.candidate@example.com'
        );
        insert c;
        return c;
    }

    @IsTest
    static void testGetProfileDataAndSaveDeleteRecord() {
        Candidate__c c = makeCandidate();

        Test.startTest();
        CandidateProfileController.ProfileDataDto dto = CandidateProfileController.getProfileData(c.Id);
        String dup = CandidateProfileController.checkDuplicate(
            String.valueOf(c.Id),
            'workExperience',
            '{"Role__c":"RN","Organization__c":"General Hospital"}',
            null
        );
        Test.stopTest();

        System.assertEquals(c.Id, dto.candidate.Id);
        System.assertEquals(null, dup);
    }

    @IsTest
    static void testNegativePaths() {
        Candidate__c c = makeCandidate();

        Test.startTest();
        List<CandidateProfileController.DocumentInfo> docs = CandidateProfileController.getLicenseDocuments(null);
        Map<String, Object> resumeInfo = CandidateProfileController.getCandidateResumeInfo(c.Id);
        Test.stopTest();

        System.assertEquals(0, docs.size());
        System.assertEquals(false, resumeInfo.get('hasResume'));
        System.assertEquals(false, resumeInfo.get('useAiParsing'));

        try {
            CandidateProfileController.getProfileData(null);
            System.assert(false, 'Expected exception for null candidate id');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            CandidateProfileController.saveRecord('', 'workExperience');
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        try {
            CandidateProfileController.deleteRecord(null, 'workExperience');
            System.assert(false, 'Expected validation exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
}
