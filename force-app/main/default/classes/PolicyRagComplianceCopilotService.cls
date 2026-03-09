public with sharing class PolicyRagComplianceCopilotService {

    private static final Integer MAX_CHUNKS = 20;
    private static final Integer MAX_CHUNK_CONTENT_LENGTH = 1600;
    private static final Integer DEFAULT_SEARCH_LIMIT = 8;
    private static final Integer DEFAULT_RETRIEVAL_MAX_CHUNKS = 8;

    private static final String SYSTEM_PROMPT =
        'You are a healthcare onboarding compliance copilot. ' +
        'You must answer strictly using retrieved policy/context snippets. ' +
        'If evidence is insufficient, return decision as MANUAL_REVIEW and include "Insufficient policy evidence" in answer. ' +
        'Never invent regulations. Never use outside knowledge. Return JSON only.';

    public class PolicyChunkInput {
        @AuraEnabled public String chunkId;
        @AuraEnabled public String source;
        @AuraEnabled public String content;
    }

    public class CopilotRequest {
        @AuraEnabled public String question;
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String jurisdiction;
        @AuraEnabled public List<PolicyChunkInput> retrievedChunks;
        @AuraEnabled public Boolean useStoredEvidence;
        @AuraEnabled public String policyType;
        @AuraEnabled public Integer maxChunks;
    }

    public class CopilotResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String correlationId;

        @AuraEnabled public String decision;
        @AuraEnabled public String answer;
        @AuraEnabled public String reasoning;
        @AuraEnabled public List<String> citations;
        @AuraEnabled public List<String> missing_information;
        @AuraEnabled public Decimal confidence;

        @AuraEnabled public String retrievalMode;
        @AuraEnabled public String retrievedChunksJson;
    }

    public class FlowInput {
        @InvocableVariable(required=true label='Question')
        public String question;

        @InvocableVariable(required=true label='Candidate Id')
        public Id candidateId;

        @InvocableVariable(required=false label='Jurisdiction')
        public String jurisdiction;

        @InvocableVariable(required=false label='Retrieved Chunks JSON')
        public String retrievedChunksJson;

        @InvocableVariable(required=false label='Use Stored Evidence')
        public Boolean useStoredEvidence;

        @InvocableVariable(required=false label='Policy Type Filter')
        public String policyType;

        @InvocableVariable(required=false label='Maximum Retrieved Chunks')
        public Integer maxChunks;
    }

    public class FlowOutput {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
        @InvocableVariable public String correlationId;

        @InvocableVariable public String decision;
        @InvocableVariable public String answer;
        @InvocableVariable public String reasoning;
        @InvocableVariable public String citationsJson;
        @InvocableVariable public String missingInformationJson;
        @InvocableVariable public Decimal confidence;
        @InvocableVariable public String retrievalMode;
        @InvocableVariable public String retrievedChunksJson;
    }

    public class CandidateOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String label;
    }

    public class ResolveCandidateResult {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String candidateName;
        @AuraEnabled public String source;
        @AuraEnabled public String message;
        @AuraEnabled public List<CandidateOption> suggestions;
    }

    @AuraEnabled
    public static CopilotResponse evaluateFromJson(
        String question,
        Id candidateId,
        String jurisdiction,
        String retrievedChunksJson
    ) {
        CopilotRequest req = new CopilotRequest();
        req.question = question;
        req.candidateId = candidateId;
        req.jurisdiction = jurisdiction;
        req.retrievedChunks = parseChunksJson(retrievedChunksJson);
        req.useStoredEvidence = false;
        return evaluate(req);
    }

    @AuraEnabled
    public static CopilotResponse evaluateUsingStoredEvidence(
        String question,
        Id candidateId,
        String jurisdiction,
        String policyType,
        Integer maxChunks
    ) {
        CopilotRequest req = new CopilotRequest();
        req.question = question;
        req.candidateId = candidateId;
        req.jurisdiction = jurisdiction;
        req.policyType = policyType;
        req.maxChunks = maxChunks;
        req.useStoredEvidence = true;
        req.retrievedChunks = new List<PolicyChunkInput>();
        return evaluate(req);
    }

    @AuraEnabled
    public static CopilotResponse evaluate(CopilotRequest request) {
        String correlationId = 'PCRAG-' + String.valueOf(Datetime.now().getTime());

        if (request == null) {
            return buildManualReview(correlationId, 'Request is required.', null, 'MANUAL_INPUT');
        }

        if (String.isBlank(request.question)) {
            return buildManualReview(correlationId, 'Question is required.', request, 'MANUAL_INPUT');
        }

        if (request.candidateId == null) {
            return buildManualReview(correlationId, 'candidateId is required.', request, 'MANUAL_INPUT');
        }

        List<PolicyChunkInput> normalizedChunks = normalizeChunks(request.retrievedChunks);
        String retrievalMode = 'MANUAL_INPUT';

        if (request.useStoredEvidence == true) {
            Integer retrievalSize = request.maxChunks == null ? DEFAULT_RETRIEVAL_MAX_CHUNKS : request.maxChunks;
            normalizedChunks = PolicyRagPolicyRepository.retrieveChunks(
                request.question,
                request.jurisdiction,
                request.policyType,
                retrievalSize
            );
            retrievalMode = 'STORED_RETRIEVAL';
        }

        if (normalizedChunks.isEmpty()) {
            return buildInsufficientEvidence(correlationId, 'No retrieved policy chunks were provided.', request, retrievalMode, normalizedChunks);
        }

        try {
            String candidateSummaryJson = buildCandidateContextJson(request.candidateId);
            String userPrompt = buildUserPrompt(
                request.question,
                candidateSummaryJson,
                request.jurisdiction,
                normalizedChunks
            );

            GeminiAPIService.GeminiResponse modelResponse = GeminiAPIService.callGeminiAPI(
                SYSTEM_PROMPT,
                userPrompt
            );

            if (modelResponse == null || modelResponse.success != true) {
                String err = modelResponse == null ? 'No response from model.' : modelResponse.errorMessage;
                return buildManualReview(correlationId, 'Copilot call failed: ' + err, request, retrievalMode, normalizedChunks);
            }

            String raw = GeminiAPIService.extractContent(modelResponse);
            if (String.isBlank(raw)) {
                return buildManualReview(correlationId, 'Copilot returned empty content.', request, retrievalMode, normalizedChunks);
            }

            CopilotResponse parsed = parseAndValidateOutput(raw, normalizedChunks, correlationId);
            if (parsed == null) {
                return buildManualReview(correlationId, 'Unable to parse copilot output.', request, retrievalMode, normalizedChunks);
            }

            parsed.retrievalMode = retrievalMode;
            parsed.retrievedChunksJson = JSON.serialize(normalizedChunks);
            publishAudit(request, parsed, normalizedChunks, retrievalMode);

            return parsed;
        } catch (Exception ex) {
            return buildManualReview(correlationId, 'Copilot execution error: ' + ex.getMessage(), request, retrievalMode, normalizedChunks);
        }
    }

    @AuraEnabled(cacheable=true)
    public static ResolveCandidateResult resolveCandidateContext(Id recordId) {
        ResolveCandidateResult result = new ResolveCandidateResult();
        result.suggestions = new List<CandidateOption>();

        if (recordId == null) {
            result.message = 'recordId is not available.';
            result.suggestions = searchCandidates(null, DEFAULT_SEARCH_LIMIT);
            return result;
        }

        if (!Schema.sObjectType.Candidate__c.isAccessible()) {
            result.message = 'Insufficient access to Candidate__c.';
            return result;
        }

        Schema.SObjectType recordType = recordId.getSObjectType();
        Schema.DescribeSObjectResult describeRecordType = recordType.getDescribe();
        if (!describeRecordType.isAccessible()) {
            result.message = 'Insufficient access to source record.';
            return result;
        }

        String sourceApiName = describeRecordType.getName();

        if (sourceApiName == 'Candidate__c') {
            Candidate__c directCandidate = getCandidateById(recordId);
            if (directCandidate != null) {
                result.candidateId = directCandidate.Id;
                result.candidateName = toCandidateDisplayName(directCandidate);
                result.source = 'RECORD_SELF';
                result.message = 'Autofilled from Candidate record.';
                return result;
            }
        }

        Id relatedCandidateId = extractCandidateFromRelatedRecord(recordId, describeRecordType);
        if (relatedCandidateId != null) {
            Candidate__c relatedCandidate = getCandidateById(relatedCandidateId);
            if (relatedCandidate != null) {
                result.candidateId = relatedCandidate.Id;
                result.candidateName = toCandidateDisplayName(relatedCandidate);
                result.source = 'RELATED_LOOKUP';
                result.message = 'Autofilled from related candidate lookup.';
                return result;
            }
        }

        result.source = 'NO_MATCH';
        result.message = 'Could not infer candidate from this record. Select from suggestions.';
        result.suggestions = searchCandidates(null, DEFAULT_SEARCH_LIMIT);
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<CandidateOption> searchCandidates(String searchTerm, Integer limitSize) {
        Integer safeLimit = (limitSize == null || limitSize <= 0) ? DEFAULT_SEARCH_LIMIT : limitSize;
        safeLimit = Math.min(20, safeLimit);

        if (!Schema.sObjectType.Candidate__c.isAccessible()) {
            return new List<CandidateOption>();
        }

        String term = String.isBlank(searchTerm) ? null : ('%' + searchTerm.trim() + '%');
        List<Candidate__c> records;

        if (String.isBlank(searchTerm)) {
            records = [
                SELECT Id, Name, Full_Name__c, Email__c
                FROM Candidate__c
                ORDER BY LastModifiedDate DESC
                LIMIT :safeLimit
            ];
        } else {
            records = [
                SELECT Id, Name, Full_Name__c, Email__c
                FROM Candidate__c
                WHERE Name LIKE :term
                    OR Full_Name__c LIKE :term
                    OR Email__c LIKE :term
                ORDER BY LastModifiedDate DESC
                LIMIT :safeLimit
            ];
        }

        List<CandidateOption> out = new List<CandidateOption>();
        for (Candidate__c candidate : records) {
            CandidateOption opt = new CandidateOption();
            opt.id = candidate.Id;
            opt.name = toCandidateDisplayName(candidate);
            opt.email = candidate.Email__c;
            opt.label = opt.name + ' (' + String.valueOf(candidate.Id) + ')' +
                (String.isBlank(candidate.Email__c) ? '' : ' - ' + candidate.Email__c);
            out.add(opt);
        }

        return out;
    }

    @InvocableMethod(
        label='Policy RAG Compliance Copilot'
        description='Runs policy-grounded compliance decision support and returns structured decision JSON fields.'
        category='Compliance'
    )
    public static List<FlowOutput> runForFlow(List<FlowInput> inputs) {
        List<FlowOutput> outputs = new List<FlowOutput>();
        if (inputs == null || inputs.isEmpty()) {
            return outputs;
        }

        for (FlowInput input : inputs) {
            CopilotRequest req = new CopilotRequest();
            req.question = input.question;
            req.candidateId = input.candidateId;
            req.jurisdiction = input.jurisdiction;
            req.retrievedChunks = parseChunksJson(input.retrievedChunksJson);
            req.useStoredEvidence = input.useStoredEvidence;
            req.policyType = input.policyType;
            req.maxChunks = input.maxChunks;

            CopilotResponse res = evaluate(req);

            FlowOutput out = new FlowOutput();
            out.success = res.success;
            out.message = res.message;
            out.correlationId = res.correlationId;
            out.decision = res.decision;
            out.answer = res.answer;
            out.reasoning = res.reasoning;
            out.citationsJson = JSON.serialize(res.citations);
            out.missingInformationJson = JSON.serialize(res.missing_information);
            out.confidence = res.confidence;
            out.retrievalMode = res.retrievalMode;
            out.retrievedChunksJson = res.retrievedChunksJson;

            outputs.add(out);
        }

        return outputs;
    }

    private static String buildCandidateContextJson(Id candidateId) {
        if (!Schema.sObjectType.Candidate__c.isAccessible()) {
            throw new AuraHandledException('Insufficient access to Candidate__c');
        }

        try {
            CandidateComplianceSummaryController.CandidateComplianceSummary summary =
                CandidateComplianceSummaryController.getCandidateComplianceSummary(candidateId);
            return JSON.serialize(summary);
        } catch (Exception ex) {
            List<Candidate__c> candidates = [
                SELECT Id, Name, Full_Name__c, Email__c
                FROM Candidate__c
                WHERE Id = :candidateId
                LIMIT 1
            ];

            if (candidates.isEmpty()) {
                throw new AuraHandledException('Candidate not found or not accessible');
            }

            Candidate__c c = candidates[0];
            Map<String, Object> fallbackContext = new Map<String, Object>{
                'candidateId' => c.Id,
                'candidateName' => String.isBlank(c.Full_Name__c) ? c.Name : c.Full_Name__c,
                'email' => c.Email__c,
                'contextMode' => 'FALLBACK_MINIMAL',
                'contextWarning' => 'Compliance summary unavailable: ' + ex.getMessage()
            };

            return JSON.serialize(fallbackContext);
        }
    }

    private static String buildUserPrompt(
        String question,
        String candidateSummaryJson,
        String jurisdiction,
        List<PolicyChunkInput> chunks
    ) {
        List<Map<String, Object>> promptChunks = new List<Map<String, Object>>();
        for (PolicyChunkInput chunk : chunks) {
            promptChunks.add(new Map<String, Object>{
                'chunk_id' => chunk.chunkId,
                'source' => chunk.source,
                'content' => chunk.content
            });
        }

        String prompt = '';
        prompt += 'Question:\n' + question + '\n\n';
        prompt += 'Candidate Context:\n' + candidateSummaryJson + '\n\n';
        prompt += 'Retrieved Policy Chunks:\n' + JSON.serialize(promptChunks) + '\n\n';
        prompt += 'Jurisdiction:\n' + String.valueOf(jurisdiction) + '\n\n';

        prompt += 'Task:\n';
        prompt += '1) Answer using only retrieved chunks.\n';
        prompt += '2) Decision must be exactly one of: ALLOW, BLOCK, MANUAL_REVIEW.\n';
        prompt += '3) Cite only chunk IDs present in retrieved chunks.\n';
        prompt += '4) If evidence is insufficient, decision must be MANUAL_REVIEW.\n';
        prompt += '5) Return strict JSON only with this schema:\n';
        prompt += '{"decision":"ALLOW|BLOCK|MANUAL_REVIEW","answer":"string","reasoning":"string","citations":["chunk_id"],"missing_information":["string"],"confidence":0.0}';

        return prompt;
    }

    private static CopilotResponse parseAndValidateOutput(
        String rawOutput,
        List<PolicyChunkInput> inputChunks,
        String correlationId
    ) {
        Map<String, Object> json = safeDeserializeJsonObject(rawOutput);
        if (json == null) {
            return null;
        }

        Set<String> allowedChunkIds = new Set<String>();
        for (PolicyChunkInput chunk : inputChunks) {
            allowedChunkIds.add(chunk.chunkId);
        }

        CopilotResponse response = new CopilotResponse();
        response.success = true;
        response.message = 'OK';
        response.correlationId = correlationId;

        String decision = String.valueOf(json.get('decision'));
        decision = normalizeDecision(decision);

        response.answer = trimToLength(String.valueOf(json.get('answer')), 4000);
        response.reasoning = trimToLength(String.valueOf(json.get('reasoning')), 4000);

        response.citations = new List<String>();
        for (String citation : toStringList(json.get('citations'))) {
            if (allowedChunkIds.contains(citation)) {
                response.citations.add(citation);
            }
        }

        response.missing_information = toStringList(json.get('missing_information'));
        response.confidence = normalizeConfidence(json.get('confidence'));

        if (String.isBlank(response.answer)) {
            response.answer = 'Insufficient policy evidence';
            response.missing_information.add('Model returned empty answer.');
            decision = 'MANUAL_REVIEW';
        }

        if (response.citations.isEmpty()) {
            if (!response.missing_information.contains('No valid policy citations returned.')) {
                response.missing_information.add('No valid policy citations returned.');
            }
        }

        response.decision = decision;
        return response;
    }

    private static String normalizeDecision(String decision) {
        if (String.isBlank(decision)) {
            return 'MANUAL_REVIEW';
        }

        String normalized = decision.trim().toUpperCase();
        if (normalized == 'ALLOW' || normalized == 'BLOCK' || normalized == 'MANUAL_REVIEW') {
            return normalized;
        }

        return 'MANUAL_REVIEW';
    }

    private static Decimal normalizeConfidence(Object confidenceObj) {
        Decimal confidence = 0;
        try {
            if (confidenceObj != null) {
                confidence = Decimal.valueOf(String.valueOf(confidenceObj));
            }
        } catch (Exception ex) {
            confidence = 0;
        }

        if (confidence < 0) confidence = 0;
        if (confidence > 1) confidence = 1;

        return confidence.setScale(3);
    }

    private static List<String> toStringList(Object raw) {
        List<String> out = new List<String>();
        if (raw == null) {
            return out;
        }

        List<Object> items = new List<Object>();
        try {
            items = (List<Object>) raw;
        } catch (Exception ex) {
            try {
                Object reparsed = JSON.deserializeUntyped(JSON.serialize(raw));
                if (reparsed instanceof List<Object>) {
                    items = (List<Object>) reparsed;
                }
            } catch (Exception ignored) {
                return out;
            }
        }

        for (Object item : items) {
            String value = String.valueOf(item);
            if (!String.isBlank(value)) {
                out.add(value.trim());
            }
        }

        return out;
    }

    private static Map<String, Object> safeDeserializeJsonObject(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }

        String cleaned = stripCodeFences(raw);

        Integer firstBrace = cleaned.indexOf('{');
        Integer lastBrace = cleaned.lastIndexOf('}');
        if (firstBrace < 0 || lastBrace < 0 || lastBrace < firstBrace) {
            return null;
        }

        String jsonOnly = cleaned.substring(firstBrace, lastBrace + 1);

        Object parsed = JSON.deserializeUntyped(jsonOnly);
        if (parsed instanceof Map<String, Object>) {
            return (Map<String, Object>) parsed;
        }

        return null;
    }

    private static String stripCodeFences(String text) {
        String out = text == null ? '' : text.trim();
        if (out.startsWith('```json')) {
            out = out.substring(7).trim();
        } else if (out.startsWith('```')) {
            out = out.substring(3).trim();
        }

        if (out.endsWith('```')) {
            out = out.substring(0, out.length() - 3).trim();
        }

        return out;
    }

    private static List<PolicyChunkInput> normalizeChunks(List<PolicyChunkInput> chunks) {
        List<PolicyChunkInput> out = new List<PolicyChunkInput>();
        if (chunks == null) {
            return out;
        }

        Set<String> seenIds = new Set<String>();
        Integer index = 0;

        for (PolicyChunkInput chunk : chunks) {
            if (out.size() >= MAX_CHUNKS) {
                break;
            }
            if (chunk == null || String.isBlank(chunk.content)) {
                continue;
            }

            PolicyChunkInput normalized = new PolicyChunkInput();
            String chunkId = String.isBlank(chunk.chunkId)
                ? 'chunk_' + String.valueOf(index)
                : chunk.chunkId.trim();

            if (seenIds.contains(chunkId)) {
                continue;
            }

            seenIds.add(chunkId);
            normalized.chunkId = chunkId;
            normalized.source = String.isBlank(chunk.source) ? 'unknown' : chunk.source.trim();
            normalized.content = trimToLength(chunk.content.trim(), MAX_CHUNK_CONTENT_LENGTH);

            out.add(normalized);
            index++;
        }

        return out;
    }

    private static String trimToLength(String value, Integer maxLen) {
        if (value == null) {
            return null;
        }
        if (maxLen == null || maxLen <= 0 || value.length() <= maxLen) {
            return value;
        }
        return value.substring(0, maxLen);
    }

    private static Candidate__c getCandidateById(Id candidateId) {
        List<Candidate__c> records = [
            SELECT Id, Name, Full_Name__c, Email__c
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }

    private static String toCandidateDisplayName(Candidate__c candidate) {
        return String.isBlank(candidate.Full_Name__c) ? candidate.Name : candidate.Full_Name__c;
    }

    private static Id extractCandidateFromRelatedRecord(
        Id recordId,
        Schema.DescribeSObjectResult describeRecordType
    ) {
        Map<String, Schema.SObjectField> fields = describeRecordType.fields.getMap();
        List<String> candidateLookupFields = new List<String>();
        List<String> preferredFields = new List<String>();

        for (String fieldApi : fields.keySet()) {
            Schema.DescribeFieldResult dfr = fields.get(fieldApi).getDescribe();
            if (dfr.getType() != Schema.DisplayType.Reference || !dfr.isAccessible()) {
                continue;
            }

            for (Schema.SObjectType refType : dfr.getReferenceTo()) {
                if (refType.getDescribe().getName() == 'Candidate__c') {
                    candidateLookupFields.add(fieldApi);
                    if (fieldApi == 'Candidate__c' || fieldApi == 'Provider__c') {
                        preferredFields.add(fieldApi);
                    }
                    break;
                }
            }
        }

        if (candidateLookupFields.isEmpty()) {
            return null;
        }

        List<String> orderedFields = new List<String>();
        orderedFields.addAll(preferredFields);
        for (String fieldApi : candidateLookupFields) {
            if (!preferredFields.contains(fieldApi)) {
                orderedFields.add(fieldApi);
            }
        }
        candidateLookupFields = orderedFields;

        String query =
            'SELECT ' + String.join(candidateLookupFields, ',') +
            ' FROM ' + describeRecordType.getName() +
            ' WHERE Id = :recordId LIMIT 1';

        List<SObject> rows = Database.query(query);
        if (rows.isEmpty()) {
            return null;
        }

        SObject row = rows[0];
        for (String fieldApi : candidateLookupFields) {
            Id found = (Id) row.get(fieldApi);
            if (found != null) {
                return found;
            }
        }

        return null;
    }

    @TestVisible
    private static List<PolicyChunkInput> parseChunksJson(String retrievedChunksJson) {
        List<PolicyChunkInput> chunks = new List<PolicyChunkInput>();
        if (String.isBlank(retrievedChunksJson)) {
            return chunks;
        }

        try {
            Object raw = JSON.deserializeUntyped(retrievedChunksJson);
            if (!(raw instanceof List<Object>)) {
                return chunks;
            }

            for (Object row : (List<Object>) raw) {
                if (!(row instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> m = (Map<String, Object>) row;
                PolicyChunkInput chunk = new PolicyChunkInput();
                chunk.chunkId = String.valueOf(m.get('chunkId'));
                chunk.source = String.valueOf(m.get('source'));
                chunk.content = String.valueOf(m.get('content'));
                chunks.add(chunk);
            }
        } catch (Exception ex) {
            return new List<PolicyChunkInput>();
        }

        return chunks;
    }

    private static CopilotResponse buildInsufficientEvidence(
        String correlationId,
        String details,
        CopilotRequest request,
        String retrievalMode,
        List<PolicyChunkInput> chunksUsed
    ) {
        CopilotResponse response = new CopilotResponse();
        response.success = true;
        response.message = 'Insufficient policy evidence';
        response.correlationId = correlationId;
        response.decision = 'MANUAL_REVIEW';
        response.answer = 'Insufficient policy evidence';
        response.reasoning = 'Copilot requires retrieved policy chunks to support a decision.';
        response.citations = new List<String>();
        response.missing_information = new List<String>{ details };
        response.confidence = 0;
        response.retrievalMode = retrievalMode;
        response.retrievedChunksJson = JSON.serialize(chunksUsed);

        publishAudit(request, response, chunksUsed, retrievalMode);
        return response;
    }

    private static CopilotResponse buildManualReview(
        String correlationId,
        String details,
        CopilotRequest request,
        String retrievalMode
    ) {
        return buildManualReview(correlationId, details, request, retrievalMode, new List<PolicyChunkInput>());
    }

    private static CopilotResponse buildManualReview(
        String correlationId,
        String details,
        CopilotRequest request,
        String retrievalMode,
        List<PolicyChunkInput> chunksUsed
    ) {
        CopilotResponse response = new CopilotResponse();
        response.success = true;
        response.message = details;
        response.correlationId = correlationId;
        response.decision = 'MANUAL_REVIEW';
        response.answer = 'Insufficient policy evidence';
        response.reasoning = 'System fallback to manual review due to validation or execution issue.';
        response.citations = new List<String>();
        response.missing_information = new List<String>{ details };
        response.confidence = 0;
        response.retrievalMode = retrievalMode;
        response.retrievedChunksJson = JSON.serialize(chunksUsed);

        publishAudit(request, response, chunksUsed, retrievalMode);
        return response;
    }

    private static void publishAudit(
        CopilotRequest request,
        CopilotResponse response,
        List<PolicyChunkInput> chunksUsed,
        String requestMode
    ) {
        if (request == null || response == null) {
            return;
        }

        PolicyRagAuditService.AuditInput input = new PolicyRagAuditService.AuditInput();
        input.candidateId = request.candidateId;
        input.question = request.question;
        input.jurisdiction = request.jurisdiction;
        input.decision = response.decision;
        input.confidence = response.confidence;
        input.citationsJson = JSON.serialize(response.citations);
        input.missingInformationJson = JSON.serialize(response.missing_information);
        input.chunksUsedJson = JSON.serialize(chunksUsed);
        input.modelResponseJson = JSON.serialize(response);
        input.correlationId = response.correlationId;
        input.requestMode = requestMode;
        input.retrievalQuery = request.question;
        input.success = response.success;
        input.message = response.message;

        PolicyRagAuditService.logRunAsync(input);
    }
}
