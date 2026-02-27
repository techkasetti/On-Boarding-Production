@IsTest
private class CandidateScoreComparatorTest {
    @IsTest
    static void testCompareOrdering() {
        CandidateMatchWrapper high = new CandidateMatchWrapper();
        high.score = 90;
        CandidateMatchWrapper low = new CandidateMatchWrapper();
        low.score = 40;
        CandidateMatchWrapper same = new CandidateMatchWrapper();
        same.score = 90;

        CandidateScoreComparator comparator = new CandidateScoreComparator();

        System.assertEquals(-1, comparator.compare(high, low), 'Higher score should come first');
        System.assertEquals(1, comparator.compare(low, high), 'Lower score should come later');
        System.assertEquals(0, comparator.compare(high, same), 'Equal scores should compare as equal');
    }
}
