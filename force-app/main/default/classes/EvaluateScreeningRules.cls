// public with sharing class EvaluateScreeningRules {
//     // Invocable input wrapper
//     public class Request {
//         @InvocableVariable(required=true)
//         public Id candidateId;

//         @InvocableVariable
//         public String parsedJson; // stringified JSON

//         @InvocableVariable
//         public String candidateFields; // optional: JSON string for candidate-specific fields

//         public Request() {}
//     }

//     // Invocable output wrapper
//     public class Response {
//         @InvocableVariable
//         public Id candidateId;

//         @InvocableVariable
//         public String correlationId;

//         @InvocableVariable
//         public String status;

//         @InvocableVariable
//         public String resultsJson;

//         public Response() {}
//     }

//     @InvocableMethod(label='Evaluate Screening Rules' description='Bulk-safe invocable to evaluate screening rules for a list of candidates')
//     public static List<Response> run(List<Request> requests) {
//         List<Response> responses = new List<Response>();
//         if (requests == null || requests.isEmpty()) return responses;

//         // Bulk processing in batches of 50 to avoid large transactions.
//         Integer BATCH = 50;
//         for (Integer i = 0; i < requests.size(); i += BATCH) {
//             Integer endIdx = Math.min(i + BATCH, requests.size());

//             // --- create slice manually (avoid subList compile issues) ---
//             List<Request> slice = new List<Request>();
//             for (Integer k = i; k < endIdx; k++) {
//                 slice.add(requests[k]);
//             }

//             // collect candidate Ids
//             Set<Id> candIds = new Set<Id>();
//             for (Request r : slice) if (r.candidateId != null) candIds.add(r.candidateId);

//             // Query candidate records
//             Map<Id, SObject> candMap = new Map<Id,SObject>();
//             if (!candIds.isEmpty()) {
//                 // minimal fields, adjust if your Candidate__c has different API names
//                 List<Candidate__c> cands = [SELECT Id, Name, Email__c, Locale__c, Status__c, Raw_Resume_Payload__c FROM Candidate__c WHERE Id IN :candIds];
//                 for (Candidate__c c : cands) candMap.put(c.Id, c);
//             }

//             // Process each request
//             List<Screening_Result__c> resultsToInsert = new List<Screening_Result__c>();
//             List<Screening_Audit__c> auditToInsert = new List<Screening_Audit__c>();
//             List<Response> batchResponses = new List<Response>();

//             for (Request req : slice) {
//                 Response resp = new Response();
//                 resp.candidateId = req.candidateId;
//                 resp.correlationId = 'corr-' + String.valueOf(Datetime.now().getTime()) + '-' + Math.abs(Crypto.getRandomInteger());
//                 resp.status = 'OK';
//                 try {
//                     Map<String,Object> candidateMap = new Map<String,Object>();
//                     Map<String,Object> parsedJson = new Map<String,Object>();

//                     // populate candidateMap from queried record if available
//                     if (candMap.containsKey(req.candidateId)) {
//                         Candidate__c cRec = (Candidate__c) candMap.get(req.candidateId);
//                         candidateMap.put('id', String.valueOf(cRec.Id));
//                         candidateMap.put('name', String.valueOf(cRec.Name));
//                         candidateMap.put('locale', String.valueOf(cRec.Locale__c));
//                         candidateMap.put('email', String.valueOf(cRec.Email__c));
//                         // try to parse parsed JSON from record if present and request didn't include one
//                         if (String.isNotBlank(cRec.Raw_Resume_Payload__c) && String.isBlank(req.parsedJson)) {
//                             try {
//                                 parsedJson = (Map<String,Object>) JSON.deserializeUntyped(cRec.Raw_Resume_Payload__c);
//                             } catch (Exception ex) { parsedJson = new Map<String,Object>(); }
//                         }
//                     }
//                     // If request provided parsedJson override, use that
//                     if (String.isNotBlank(req.parsedJson)) {
//                         try {
//                             parsedJson = (Map<String,Object>) JSON.deserializeUntyped(req.parsedJson);
//                         } catch (Exception ex) { parsedJson = new Map<String,Object>(); }
//                     }
//                     // If candidateFields provided as JSON string, merge into candidateMap
//                     if (String.isNotBlank(req.candidateFields)) {
//                         try {
//                             Map<String,Object> extra = (Map<String,Object>) JSON.deserializeUntyped(req.candidateFields);
//                             for (String k : extra.keySet()) candidateMap.put(k, extra.get(k));
//                         } catch (Exception ex) {}
//                     }

//                     // ---- NEW: normalize parsed JSON so rules work against canonical fields ----
//                     try {
//                         parsedJson = ParsedJsonNormalizer.normalize(parsedJson);
//                     } catch (Exception ex) {
//                         // defensive: do not break evaluation if normalizer fails; keep the parsedJson as-is
//                         parsedJson = (parsedJson == null) ? new Map<String,Object>() : parsedJson;
//                     }
//                     // -----------------------------------------------------------------------

//                     // Evaluate rules
//                     List<ScreeningRuleService.EvalResult> reslist = ScreeningRuleService.evaluateAll(String.valueOf(req.candidateId), candidateMap, parsedJson);

//                     // persist each to Screening_Result__c
//                     for (ScreeningRuleService.EvalResult er : reslist) {
//                         Screening_Result__c sr = new Screening_Result__c();
//                         sr.Candidate__c = req.candidateId;
//                         sr.Rule_Key__c = er.ruleKey;
//                         sr.Outcome__c = er.outcome;
//                         // Score__c is Number — convert Decimal to Double safely via string if needed
//                         sr.Score__c = (er.score != null) ? Double.valueOf(String.valueOf(er.score)) : 0;
//                         sr.Details__c = er.details;
//                         sr.Evaluated_At__c = Datetime.now();
//                         sr.Processed_By__c = 'AUTOMATION';
//                         resultsToInsert.add(sr);

//                         // form audit
//                         Screening_Audit__c aud = new Screening_Audit__c();
//                         aud.Candidate__c = req.candidateId;
//                         aud.Event_Type__c = 'RULE_EVALUATED';
//                         aud.Event_Payload__c = JSON.serializePretty(new Map<String,Object>{ 'ruleKey'=>er.ruleKey, 'outcome'=>er.outcome, 'score'=>er.score, 'details'=>er.details });
//                         aud.Correlation_Id__c = resp.correlationId;
//                         aud.Created_By__c = 'SYSTEM';
//                         aud.Created_At__c = Datetime.now();
//                         auditToInsert.add(aud);
//                     }

//                     // Optionally call external webhook for decisioning (demo)
//                     try {
//                         // For demo, call webhook site and pass payload; ignore response for now
//                         String payload = JSON.serializePretty(new Map<String,Object>{
//                             'candidateId' => String.valueOf(req.candidateId),
//                             'correlationId' => resp.correlationId,
//                             'results' => reslist
//                         });
//                         // Use CalloutClient to send (non-blocking in real world; here synchronous)
//                         HttpResponse hres = CalloutClient.postToWebhook('', payload, resp.correlationId);
//                         if (hres != null && hres.getStatusCode() >= 200 && hres.getStatusCode() < 300) {
//                             // log in audit
//                             Screening_Audit__c aud2 = new Screening_Audit__c();
//                             aud2.Candidate__c = req.candidateId;
//                             aud2.Event_Type__c = 'CALL_OUTBOUND';
//                             aud2.Event_Payload__c = 'Webhook status ' + String.valueOf(hres.getStatusCode()) + ' body: ' + hres.getBody();
//                             aud2.Correlation_Id__c = resp.correlationId;
//                             aud2.Created_By__c = 'SYSTEM';
//                             aud2.Created_At__c = Datetime.now();
//                             auditToInsert.add(aud2);
//                         }
//                     } catch (Exception ex) {
//                         // swallow callout exceptions (log)
//                         Screening_Audit__c audErr = new Screening_Audit__c();
//                         audErr.Candidate__c = req.candidateId;
//                         audErr.Event_Type__c = 'CALL_OUTBOUND_ERROR';
//                         audErr.Event_Payload__c = 'Callout failed: ' + ex.getMessage();
//                         audErr.Correlation_Id__c = resp.correlationId;
//                         audErr.Created_By__c = 'SYSTEM';
//                         audErr.Created_At__c = Datetime.now();
//                         auditToInsert.add(audErr);
//                     }

//                     resp.resultsJson = JSON.serializePretty(reslist);
//                 } catch (Exception ex) {
//                     resp.status = 'ERROR';
//                     resp.resultsJson = 'Exception: ' + ex.getMessage();
//                     // ensure audit
//                     Screening_Audit__c aud = new Screening_Audit__c();
//                     aud.Candidate__c = req.candidateId;
//                     aud.Event_Type__c = 'EVALUATION_ERROR';
//                     aud.Event_Payload__c = 'Exception: ' + ex.getMessage();
//                     aud.Correlation_Id__c = resp.correlationId;
//                     aud.Created_By__c = 'SYSTEM';
//                     aud.Created_At__c = Datetime.now();
//                     auditToInsert.add(aud);
//                 }

//                 batchResponses.add(resp);
//             } // end for each request

//             // DML - one transaction for the batch slice
//             if (!resultsToInsert.isEmpty()) insert resultsToInsert;
//             if (!auditToInsert.isEmpty()) insert auditToInsert;
//             responses.addAll(batchResponses);
//         } // end batching

//         return responses;
//     }
// }
public with sharing class EvaluateScreeningRules {
    // Invocable input wrapper
    public class Request {
        @InvocableVariable(required=true)
        public Id candidateId;

        @InvocableVariable
        public String parsedJson; // stringified JSON

        @InvocableVariable
        public String candidateFields; // optional: JSON string for candidate-specific fields

        public Request() {}
    }

    // Invocable output wrapper (Flow-friendly types only)
    public class Response {
        @InvocableVariable
        public Id candidateId;

        @InvocableVariable
        public String correlationId;

        @InvocableVariable
        public String status;

        // keep string for Flow compatibility (stringified array)
        @InvocableVariable
        public String resultsJson;

        public Response() {}
    }

    // DTO for structured responses to LWCs / clients
    public class EvalResultDto {
        @AuraEnabled public String ruleKey { get; set; }
        @AuraEnabled public String action { get; set; }
        @AuraEnabled public String outcome { get; set; }
        @AuraEnabled public Double score { get; set; }
        @AuraEnabled public String details { get; set; }
        @AuraEnabled public String jurisdiction { get; set; }
        public EvalResultDto() {}
        public EvalResultDto(String rk, String act, String outc, Decimal sc, String d, String jur) {
            ruleKey = rk; action = act; outcome = outc; score = (sc==null?0:Double.valueOf(String.valueOf(sc))); details = d; jurisdiction = jur;
        }
    }

    // -------------------------------------------------------------------------
    // Flow-invocable entrypoint (unchanged logic except we keep resultsJson as string)
    // -------------------------------------------------------------------------
    @InvocableMethod(label='Evaluate Screening Rules' description='Bulk-safe invocable to evaluate screening rules for a list of candidates')
    public static List<Response> run(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) return responses;

        Integer BATCH = 50;
        for (Integer i = 0; i < requests.size(); i += BATCH) {
            Integer endIdx = Math.min(i + BATCH, requests.size());

            // build slice
            List<Request> slice = new List<Request>();
            for (Integer k = i; k < endIdx; k++) slice.add(requests[k]);

            // collect ids
            Set<Id> candIds = new Set<Id>();
            for (Request r : slice) if (r.candidateId != null) candIds.add(r.candidateId);

            // query candidates
            Map<Id, Candidate__c> candMap = new Map<Id, Candidate__c>();
            if (!candIds.isEmpty()) {
                for (Candidate__c c : [SELECT Id, Name, Email__c, Locale__c, Status__c, Raw_Resume_Payload__c FROM Candidate__c WHERE Id IN :candIds]) {
                    candMap.put(c.Id, c);
                }
            }

            List<Screening_Result__c> resultsToInsert = new List<Screening_Result__c>();
            List<Screening_Audit__c> auditToInsert = new List<Screening_Audit__c>();
            List<Response> batchResponses = new List<Response>();

            for (Request req : slice) {
                Response resp = new Response();
                resp.candidateId = req.candidateId;
                resp.correlationId = 'corr-' + String.valueOf(Datetime.now().getTime()) + '-' + Math.abs(Crypto.getRandomInteger());
                resp.status = 'OK';

                try {
                    Map<String,Object> candidateMap = new Map<String,Object>();
                    Map<String,Object> parsedJson = new Map<String,Object>();

                    // populate candidateMap and parsedJson from DB or request
                    if (candMap.containsKey(req.candidateId)) {
                        Candidate__c cRec = candMap.get(req.candidateId);
                        candidateMap.put('id', String.valueOf(cRec.Id));
                        candidateMap.put('name', String.valueOf(cRec.Name));
                        candidateMap.put('locale', String.valueOf(cRec.Locale__c));
                        candidateMap.put('email', String.valueOf(cRec.Email__c));

                        if (String.isNotBlank(cRec.Raw_Resume_Payload__c) && String.isBlank(req.parsedJson)) {
                            try {
                                parsedJson = (Map<String,Object>) JSON.deserializeUntyped(cRec.Raw_Resume_Payload__c);
                            } catch (Exception ex) { parsedJson = new Map<String,Object>(); }
                        }
                    }

                    if (String.isNotBlank(req.parsedJson)) {
                        try {
                            parsedJson = (Map<String,Object>) JSON.deserializeUntyped(req.parsedJson);
                        } catch (Exception ex) { parsedJson = new Map<String,Object>(); }
                    }

                    if (String.isNotBlank(req.candidateFields)) {
                        try {
                            Map<String,Object> extra = (Map<String,Object>) JSON.deserializeUntyped(req.candidateFields);
                            for (String k : extra.keySet()) candidateMap.put(k, extra.get(k));
                        } catch (Exception ex) {}
                    }

                    // Normalize parsed JSON (defensive)
                    try {
                        parsedJson = ParsedJsonNormalizer.normalize(parsedJson);
                    } catch (Exception ex) {
                        parsedJson = (parsedJson == null) ? new Map<String,Object>() : parsedJson;
                    }

                    // Evaluate rules
                    List<ScreeningRuleService.EvalResult> reslist = ScreeningRuleService.evaluateAll(String.valueOf(req.candidateId), candidateMap, parsedJson);

                    // persist Screening_Result__c + audits
                    for (ScreeningRuleService.EvalResult er : reslist) {
                        Screening_Result__c sr = new Screening_Result__c();
                        sr.Candidate__c = req.candidateId;
                        sr.Rule_Key__c = er.ruleKey;
                        sr.Outcome__c = er.outcome;
                        sr.Score__c = er.score != null ? Double.valueOf(String.valueOf(er.score)) : 0;
                        sr.Details__c = er.details;
                        sr.Evaluated_At__c = Datetime.now();
                        sr.Processed_By__c = 'AUTOMATION';
                        resultsToInsert.add(sr);

                        Screening_Audit__c aud = new Screening_Audit__c();
                        aud.Candidate__c = req.candidateId;
                        aud.Event_Type__c = 'RULE_EVALUATED';
                        aud.Event_Payload__c = JSON.serializePretty(new Map<String,Object>{ 'ruleKey'=>er.ruleKey, 'outcome'=>er.outcome, 'score'=>er.score, 'details'=>er.details });
                        aud.Correlation_Id__c = resp.correlationId;
                        aud.Created_By__c = 'SYSTEM';
                        aud.Created_At__c = Datetime.now();
                        auditToInsert.add(aud);
                    }

                    // callout demo (non-blocking in real world)
                    try {
                        String payload = JSON.serializePretty(new Map<String,Object>{
                            'candidateId' => String.valueOf(req.candidateId),
                            'correlationId' => resp.correlationId,
                            'results' => reslist
                        });
                        HttpResponse hres = CalloutClient.postToWebhook('', payload, resp.correlationId);
                        if (hres != null && hres.getStatusCode() >= 200 && hres.getStatusCode() < 300) {
                            Screening_Audit__c aud2 = new Screening_Audit__c();
                            aud2.Candidate__c = req.candidateId;
                            aud2.Event_Type__c = 'CALL_OUTBOUND';
                            aud2.Event_Payload__c = 'Webhook status ' + String.valueOf(hres.getStatusCode()) + ' body: ' + hres.getBody();
                            aud2.Correlation_Id__c = resp.correlationId;
                            aud2.Created_By__c = 'SYSTEM';
                            aud2.Created_At__c = Datetime.now();
                            auditToInsert.add(aud2);
                        }
                    } catch (Exception ex) {
                        Screening_Audit__c audErr = new Screening_Audit__c();
                        audErr.Candidate__c = req.candidateId;
                        audErr.Event_Type__c = 'CALL_OUTBOUND_ERROR';
                        audErr.Event_Payload__c = 'Callout failed: ' + ex.getMessage();
                        audErr.Correlation_Id__c = resp.correlationId;
                        audErr.Created_By__c = 'SYSTEM';
                        audErr.Created_At__c = Datetime.now();
                        auditToInsert.add(audErr);
                    }

                    // For Flow keep the results as a serialized string (Flow-friendly)
                    resp.resultsJson = JSON.serializePretty(reslist);

                } catch (Exception ex) {
                    resp.status = 'ERROR';
                    resp.resultsJson = 'Exception: ' + ex.getMessage();
                    Screening_Audit__c aud = new Screening_Audit__c();
                    aud.Candidate__c = req.candidateId;
                    aud.Event_Type__c = 'EVALUATION_ERROR';
                    aud.Event_Payload__c = 'Exception: ' + ex.getMessage();
                    aud.Correlation_Id__c = resp.correlationId;
                    aud.Created_By__c = 'SYSTEM';
                    aud.Created_At__c = Datetime.now();
                    auditToInsert.add(aud);
                }

                batchResponses.add(resp);
            }

            if (!resultsToInsert.isEmpty()) insert resultsToInsert;
            if (!auditToInsert.isEmpty()) insert auditToInsert;
            responses.addAll(batchResponses);
        }

        return responses;
    }

    // -------------------------------------------------------------------------
    // New: AuraEnabled method for LWCs / clients to get structured evaluation results
    // -------------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<EvalResultDto> getEvaluationResults(Id candidateId) {
        if (candidateId == null) {
            throw new AuraHandledException('candidateId required');
        }
        // Build candidateMap and parsedJson similar to invocable but for single-candidate
        Map<String,Object> candidateMap = new Map<String,Object>();
        Map<String,Object> parsedJson = new Map<String,Object>();

        try {
            Candidate__c c = [SELECT Id, Name, Locale__c, Raw_Resume_Payload__c, Email__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
            candidateMap.put('id', String.valueOf(c.Id));
            candidateMap.put('name', String.valueOf(c.Name));
            candidateMap.put('locale', String.valueOf(c.Locale__c));
            candidateMap.put('email', String.valueOf(c.Email__c));
            if (String.isNotBlank(c.Raw_Resume_Payload__c)) {
                try {
                    parsedJson = (Map<String,Object>) JSON.deserializeUntyped(c.Raw_Resume_Payload__c);
                } catch (Exception ex) { parsedJson = new Map<String,Object>(); }
            }
        } catch (Exception ex) {
            // return empty list on failure
            return new List<EvalResultDto>();
        }

        // Normalize
        try {
            parsedJson = ParsedJsonNormalizer.normalize(parsedJson);
        } catch (Exception ex) {
            parsedJson = (parsedJson == null) ? new Map<String,Object>() : parsedJson;
        }

        List<ScreeningRuleService.EvalResult> evals = ScreeningRuleService.evaluateAll(String.valueOf(candidateId), candidateMap, parsedJson);

        List<EvalResultDto> out = new List<EvalResultDto>();
        for (ScreeningRuleService.EvalResult er : evals) {
            out.add(new EvalResultDto(er.ruleKey, er.action, er.outcome, er.score, er.details, er.jurisdiction));
        }
        return out;
    }
}
