public with sharing class PolicyRagPolicyIngestionService {

    private static final Integer DEFAULT_CHUNK_SIZE = 900;
    private static final Integer DEFAULT_OVERLAP = 120;

    public class IngestionRequest {
        @AuraEnabled public String title;
        @AuraEnabled public String jurisdiction;
        @AuraEnabled public String policyType;
        @AuraEnabled public String version;
        @AuraEnabled public String sourceRef;
        @AuraEnabled public String plainText;
        @AuraEnabled public Integer chunkSize;
        @AuraEnabled public Integer overlap;
        @AuraEnabled public Boolean activateDocument;
    }

    public class IngestionResult {
        @AuraEnabled public Id policyDocumentId;
        @AuraEnabled public Integer chunksCreated;
        @AuraEnabled public Integer chunksUpserted;
        @AuraEnabled public String message;
    }

    @AuraEnabled
    public static IngestionResult upsertDocumentAndChunks(IngestionRequest request) {
        if (request == null || String.isBlank(request.title) || String.isBlank(request.plainText)) {
            throw new AuraHandledException('title and plainText are required');
        }

        if (!Schema.sObjectType.Policy_Document__c.isCreateable() || !Schema.sObjectType.Policy_Chunk__c.isCreateable()) {
            throw new AuraHandledException('Insufficient object permissions for policy ingestion');
        }

        Integer chunkSize = request.chunkSize == null ? DEFAULT_CHUNK_SIZE : Math.max(300, Math.min(request.chunkSize, 4000));
        Integer overlap = request.overlap == null ? DEFAULT_OVERLAP : Math.max(0, Math.min(request.overlap, 500));

        Policy_Document__c policyDoc = findOrCreateDocument(request);

        List<String> parts = splitText(request.plainText, chunkSize, overlap);
        List<Policy_Chunk__c> upserts = new List<Policy_Chunk__c>();

        Integer seq = 1;
        for (String part : parts) {
            if (String.isBlank(part)) {
                continue;
            }

            Policy_Chunk__c chunk = new Policy_Chunk__c();
            chunk.Policy_Document__c = policyDoc.Id;
            chunk.Chunk_Id__c = buildChunkId(policyDoc.Id, seq);
            chunk.Source_Ref__c = String.isBlank(request.sourceRef) ? ('policy:' + policyDoc.Id + '#chunk-' + seq) : request.sourceRef + '#chunk-' + seq;
            chunk.Content__c = part;
            chunk.Sequence__c = seq;
            chunk.Jurisdiction__c = request.jurisdiction;
            chunk.Is_Active__c = true;
            chunk.Token_Count__c = estimateTokenCount(part);
            upserts.add(chunk);
            seq++;
        }

        if (!upserts.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(upserts, Policy_Chunk__c.Fields.Chunk_Id__c, false);

            IngestionResult output = new IngestionResult();
            output.policyDocumentId = policyDoc.Id;
            output.chunksUpserted = results.size();
            output.chunksCreated = countCreated(results);
            output.message = 'Policy chunks upserted successfully.';
            return output;
        }

        IngestionResult empty = new IngestionResult();
        empty.policyDocumentId = policyDoc.Id;
        empty.chunksCreated = 0;
        empty.chunksUpserted = 0;
        empty.message = 'No valid chunks produced from input text.';
        return empty;
    }

    private static Policy_Document__c findOrCreateDocument(IngestionRequest request) {
        List<Policy_Document__c> docs = [
            SELECT Id, Name, Title__c, Jurisdiction__c, Policy_Type__c, Version__c, Status__c
            FROM Policy_Document__c
            WHERE Title__c = :request.title
              AND Version__c = :request.version
            LIMIT 1
        ];

        Policy_Document__c policyDoc;
        if (docs.isEmpty()) {
            policyDoc = new Policy_Document__c();
            policyDoc.Title__c = request.title;
            policyDoc.Jurisdiction__c = request.jurisdiction;
            policyDoc.Policy_Type__c = request.policyType;
            policyDoc.Version__c = request.version;
            policyDoc.Status__c = (request.activateDocument == true ? 'Active' : 'Draft');
            policyDoc.Is_Current__c = request.activateDocument == true;
            insert policyDoc;
        } else {
            policyDoc = docs[0];
            policyDoc.Jurisdiction__c = request.jurisdiction;
            policyDoc.Policy_Type__c = request.policyType;
            policyDoc.Status__c = (request.activateDocument == true ? 'Active' : policyDoc.Status__c);
            policyDoc.Is_Current__c = request.activateDocument == true ? true : policyDoc.Is_Current__c;
            update policyDoc;
        }

        return policyDoc;
    }

    private static List<String> splitText(String input, Integer chunkSize, Integer overlap) {
        List<String> output = new List<String>();
        if (String.isBlank(input)) {
            return output;
        }

        String text = input.trim();
        Integer start = 0;
        Integer length = text.length();

        while (start < length) {
            Integer endIndex = Math.min(start + chunkSize, length);
            String piece = text.substring(start, endIndex).trim();
            if (!String.isBlank(piece)) {
                output.add(piece);
            }

            if (endIndex >= length) {
                break;
            }

            start = Math.max(start + 1, endIndex - overlap);
        }

        return output;
    }

    private static String buildChunkId(Id documentId, Integer sequence) {
        return 'doc_' + String.valueOf(documentId).substring(0, 8) + '_chunk_' + String.valueOf(sequence);
    }

    private static Integer estimateTokenCount(String text) {
        if (String.isBlank(text)) {
            return 0;
        }
        Integer chars = text.length();
        return Integer.valueOf(Math.ceil(chars / 4.0));
    }

    private static Integer countCreated(Database.UpsertResult[] results) {
        Integer count = 0;
        for (Database.UpsertResult result : results) {
            if (result.isSuccess() && result.isCreated()) {
                count++;
            }
        }
        return count;
    }
}
