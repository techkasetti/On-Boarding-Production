public with sharing class CandidateScoreComparator implements Comparator<CandidateMatchWrapper> {

    public Integer compare(
        CandidateMatchWrapper a,
        CandidateMatchWrapper b
    ) {
        // Descending order
        if (a.score == b.score) return 0;
        return a.score > b.score ? -1 : 1;
    }
    public CandidateScoreComparator() {

    }
}