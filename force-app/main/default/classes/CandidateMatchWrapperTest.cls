@IsTest
private class CandidateMatchWrapperTest {
    @IsTest
    static void testWrapperSetters() {
        CandidateMatchWrapper wrapper = new CandidateMatchWrapper();
        wrapper.candidateName = 'Alex';
        wrapper.score = 82;
        wrapper.scoreLabel = 'Strong';

        System.assertEquals('Alex', wrapper.candidateName);
        System.assertEquals(82, wrapper.score);
        System.assertEquals('Strong', wrapper.scoreLabel);
    }
}
