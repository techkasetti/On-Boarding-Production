public with sharing class PolicyRagPolicyRepository {

    private static final Integer DEFAULT_MAX_CHUNKS = 8;
    private static final Integer MAX_SCAN = 500;

    public class RetrievalResult {
        @AuraEnabled public List<PolicyRagComplianceCopilotService.PolicyChunkInput> chunks;
        @AuraEnabled public Integer totalCandidatesScanned;
        @AuraEnabled public String retrievalMode;
    }

    private class ScoredChunk implements Comparable {
        public Decimal score;
        public PolicyRagComplianceCopilotService.PolicyChunkInput chunk;

        public Integer compareTo(Object otherObj) {
            ScoredChunk otherChunk = (ScoredChunk) otherObj;
            if (otherChunk == null) {
                return -1;
            }

            if (score == otherChunk.score) {
                return 0;
            }

            return score > otherChunk.score ? -1 : 1;
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getRetrievedChunksJson(String question, String jurisdiction, String policyType, Integer maxChunks) {
        List<PolicyRagComplianceCopilotService.PolicyChunkInput> chunks =
            retrieveChunks(question, jurisdiction, policyType, maxChunks);
        return JSON.serialize(chunks);
    }

    public static List<PolicyRagComplianceCopilotService.PolicyChunkInput> retrieveChunks(
        String question,
        String jurisdiction,
        String policyType,
        Integer maxChunks
    ) {
        Integer limitSize = (maxChunks == null || maxChunks <= 0) ? DEFAULT_MAX_CHUNKS : Math.min(maxChunks, 20);

        if (!Schema.sObjectType.Policy_Chunk__c.isAccessible() || !Schema.sObjectType.Policy_Document__c.isAccessible()) {
            return new List<PolicyRagComplianceCopilotService.PolicyChunkInput>();
        }

        String cleanJurisdiction = String.isBlank(jurisdiction) ? null : jurisdiction.trim();
        String cleanPolicyType = String.isBlank(policyType) ? null : policyType.trim();
        Set<String> questionTokens = tokenize(question);

        List<Policy_Chunk__c> candidates = [
            SELECT Id,
                   Chunk_Id__c,
                   Source_Ref__c,
                   Content__c,
                   Keywords__c,
                   Jurisdiction__c,
                   Is_Active__c,
                   Policy_Document__r.Status__c,
                   Policy_Document__r.Policy_Type__c
            FROM Policy_Chunk__c
            WHERE Is_Active__c = true
              AND Policy_Document__r.Status__c = 'Active'
            ORDER BY LastModifiedDate DESC
            LIMIT :MAX_SCAN
        ];

        List<ScoredChunk> scored = new List<ScoredChunk>();
        for (Policy_Chunk__c row : candidates) {
            if (cleanJurisdiction != null && !String.isBlank(row.Jurisdiction__c) && row.Jurisdiction__c != cleanJurisdiction) {
                continue;
            }

            if (cleanPolicyType != null && row.Policy_Document__r.Policy_Type__c != cleanPolicyType) {
                continue;
            }

            Decimal score = scoreChunk(questionTokens, row, cleanJurisdiction, cleanPolicyType);
            if (score <= 0) {
                continue;
            }

            PolicyRagComplianceCopilotService.PolicyChunkInput chunk =
                new PolicyRagComplianceCopilotService.PolicyChunkInput();
            chunk.chunkId = row.Chunk_Id__c;
            chunk.source = String.isBlank(row.Source_Ref__c) ? 'policy-repository' : row.Source_Ref__c;
            chunk.content = row.Content__c;

            ScoredChunk scoredChunk = new ScoredChunk();
            scoredChunk.score = score;
            scoredChunk.chunk = chunk;
            scored.add(scoredChunk);
        }

        scored.sort();

        List<PolicyRagComplianceCopilotService.PolicyChunkInput> out =
            new List<PolicyRagComplianceCopilotService.PolicyChunkInput>();
        for (ScoredChunk scoredChunk : scored) {
            out.add(scoredChunk.chunk);
            if (out.size() >= limitSize) {
                break;
            }
        }

        return out;
    }

    private static Decimal scoreChunk(
        Set<String> queryTokens,
        Policy_Chunk__c chunk,
        String jurisdiction,
        String policyType
    ) {
        Decimal score = 0;

        Set<String> chunkTokens = tokenize((chunk.Content__c == null ? '' : chunk.Content__c) + ' ' +
                                           (chunk.Keywords__c == null ? '' : chunk.Keywords__c));

        for (String token : queryTokens) {
            if (chunkTokens.contains(token)) {
                score += 1;
            }
        }

        if (!String.isBlank(jurisdiction)) {
            if (chunk.Jurisdiction__c == jurisdiction) {
                score += 2;
            }
        }

        if (!String.isBlank(policyType) && chunk.Policy_Document__r.Policy_Type__c == policyType) {
            score += 2;
        }

        if (String.isBlank(chunk.Source_Ref__c)) {
            score -= 0.1;
        }

        return score;
    }

    private static Set<String> tokenize(String input) {
        Set<String> tokens = new Set<String>();
        if (String.isBlank(input)) {
            return tokens;
        }

        String normalized = input.toLowerCase().replaceAll('[^a-z0-9]+', ' ');
        for (String token : normalized.split(' ')) {
            if (!String.isBlank(token) && token.length() >= 3) {
                tokens.add(token);
            }
        }

        return tokens;
    }
}
