public with sharing class CandidateMatchWrapper {
    @AuraEnabled public Id candidateId;
    @AuraEnabled public String candidateName;
    @AuraEnabled public Decimal score;
    @AuraEnabled public String scoreLabel;


    public CandidateMatchWrapper() {

    }
}