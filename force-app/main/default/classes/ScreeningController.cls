// public with sharing class ScreeningController {
//     public class RuleDto {
//         @AuraEnabled public String ruleKey;
//         @AuraEnabled public Integer priority;
//         @AuraEnabled public Boolean active;
//         @AuraEnabled public String condition;
//         @AuraEnabled public String action;
//         @AuraEnabled public String jurisdiction;
//         @AuraEnabled public String schemaVersion;
//         @AuraEnabled public String severity;
//         public RuleDto() {}
//         public RuleDto(String rk, Integer p, Boolean a, String c, String act, String jur, String sv, String sev) {
//             ruleKey = rk; priority = p; active = a; condition = c; action = act; jurisdiction = jur; schemaVersion = sv; severity = sev;
//         }
//     }

//     public class EvalResultDto {
//         @AuraEnabled public String ruleKey;
//         @AuraEnabled public String action;
//         @AuraEnabled public String outcome;
//         @AuraEnabled public Double score;
//         @AuraEnabled public String details;
//         public EvalResultDto() {}
//     }

//     public class CandidateStatusDto {
//         @AuraEnabled public Id candidateId;
//         @AuraEnabled public String name;
//         @AuraEnabled public String status;
//         @AuraEnabled public Object parsedJson; // map / object (serialized as JSON to LWC)
//         @AuraEnabled public List<EvalResultDto> results;
//         @AuraEnabled public Map<String,String> routing;
//         public CandidateStatusDto() {}
//     }

//     // ---------------------------
//     // NEW: Structured DTOs + method
//     // ---------------------------
//     // These are added as inner classes but do NOT change any existing functionality.
//     public class StructuredEvalResult {
//         @AuraEnabled public String ruleKey;
//         @AuraEnabled public String action;
//         @AuraEnabled public String outcome;
//         @AuraEnabled public Double score;
//         @AuraEnabled public String details;
//         @AuraEnabled public String jurisdiction;
//         public StructuredEvalResult() {}
//     }

//     public class StructuredEvalResponse {
//         @AuraEnabled public Id candidateId;
//         @AuraEnabled public String correlationId;
//         @AuraEnabled public String status;
//         @AuraEnabled public List<StructuredEvalResult> results;
//         public StructuredEvalResponse() {
//             results = new List<StructuredEvalResult>();
//             status = 'OK';
//         }
//     }

//     /**
//      * New: Structured runner for UI clients.
//      * - Does NOT replace existing runEvaluation (keeps backwards compatibility).
//      * - Returns a typed object (no escaped JSON strings).
//      */
//     @AuraEnabled
//     public static StructuredEvalResponse runEvaluationStructured(Id candidateId, String ruleKey) {
//         StructuredEvalResponse out = new StructuredEvalResponse();
//         out.candidateId = candidateId;
//         out.correlationId = 'corr-' + String.valueOf(Datetime.now().getTime()) + '-' + Math.abs(Crypto.getRandomInteger());
//         out.status = 'OK';

//         if (candidateId == null) {
//             out.status = 'ERROR';
//             StructuredEvalResult err = new StructuredEvalResult();
//             err.ruleKey = 'INVALID_INPUT';
//             err.details = 'candidateId is required';
//             out.results.add(err);
//             return out;
//         }

//         try {
//             // Prefer the structured accessor in EvaluateScreeningRules (returns EvalResultDto list)
//             List<EvaluateScreeningRules.EvalResultDto> evals = EvaluateScreeningRules.getEvaluationResults(candidateId);

//             if (evals != null) {
//                 for (EvaluateScreeningRules.EvalResultDto er : evals) {
//                     StructuredEvalResult r = new StructuredEvalResult();
//                     r.ruleKey = er.ruleKey;
//                     r.action = er.action;
//                     r.outcome = er.outcome;
//                     r.score = er.score;
//                     r.details = er.details;
//                     r.jurisdiction = er.jurisdiction;
//                     out.results.add(r);
//                 }
//             }
//         } catch (Exception ex) {
//             out.status = 'ERROR';
//             StructuredEvalResult err = new StructuredEvalResult();
//             err.ruleKey = 'SYSTEM_ERROR';
//             err.details = 'Error evaluating: ' + ex.getMessage();
//             out.results.add(err);
//         }

//         return out;
//     }

//     // -------------------------------------------------------------------------
//     // getRules - called by screeningAdmin LWC (cacheable)
//     // -------------------------------------------------------------------------
//     @AuraEnabled(cacheable=true)
//     public static List<RuleDto> getRules() {
//         List<RuleDto> out = new List<RuleDto>();
//         try {
//             // Reuse ScreeningRuleService.getActiveRules to fetch rules
//             // That method already reads Screening_Rule__mdt and returns only active rules.
//             List<ScreeningRuleService.Rule> rules = ScreeningRuleService.getActiveRules();
//             for (ScreeningRuleService.Rule r : rules) {
//                 RuleDto d = new RuleDto(r.ruleKey, r.priority, r.active, r.condition, r.action, r.jurisdiction, r.schemaVersion, r.severity);
//                 out.add(d);
//             }
//             // Additionally include inactive rules as well (so admin can see full set)
//             // To get all rules (including inactive) we'll query metadata directly (best-effort)
//             // We'll try to add inactive ones only if the mdts query is available (handled inside service)
//         } catch (Exception ex) {
//             // fallback sample rules (useful in sandboxes without metadata)
//             out.add(new RuleDto('SAMPLE_RULE_FAIL_IF_EXP_LT_2', 10, true, 'parsed_json.experience_years < 2', 'AutoReject', null, 'v1', 'Low'));
//             out.add(new RuleDto('SAMPLE_RULE_ROUTE_IN_IF_AADHAAR', 20, true, 'candidate.locale == \'IN\' AND parsed_json.has_aadhaar == true', 'RouteToJurisdiction', 'IN', 'v1', 'Medium'));
//         }
//         return out;
//     }

//     // -------------------------------------------------------------------------
//     // toggleRuleActive - admin action. Because Custom Metadata rows cannot be updated
//     // via normal Apex DML reliably across orgs, this method writes an audit entry
//     // recording the request and returns success. Platform admins should update
//     // the Custom Metadata frame in Setup to make permanent changes.
//     // -------------------------------------------------------------------------
//     @AuraEnabled
//     public static Boolean toggleRuleActive(String ruleKey, Boolean active) {
//         try {
//             // resolve current user's display name safely
//             String requestorId = UserInfo.getUserId();
//             String requestorName = requestorId;
//             try {
//                 User u = [SELECT Name FROM User WHERE Id = :requestorId LIMIT 1];
//                 if (u != null && String.isNotBlank(u.Name)) requestorName = u.Name;
//             } catch (Exception e) {
//                 // fallback left as UserId string
//             }

//             Screening_Audit__c a = new Screening_Audit__c();
//             a.Event_Type__c = 'TOGGLE_RULE_REQUEST';
//             a.Event_Payload__c = JSON.serializePretty(new Map<String,Object>{
//                 'ruleKey' => ruleKey,
//                 'requestedActive' => active,
//                 'requestor' => requestorId,
//                 'requestorName' => requestorName,
//                 'requestedAt' => Datetime.now()
//             });
//             a.Correlation_Id__c = 'toggle-' + String.valueOf(Datetime.now().getTime()) + '-' + requestorId;
//             a.Created_By__c = requestorName;
//             a.Created_At__c = Datetime.now();
//             insert a;
//             // Informational: returning true indicates the request was recorded. Admin must update metadata in Setup.
//             return true;
//         } catch (Exception ex) {
//             // best-effort: return false on failure
//             return false;
//         }
//     }

//     // -------------------------------------------------------------------------
//     // runEvaluation - call the EvaluateScreeningRules invocable for a single candidate.
//     // Optionally, you can pass a ruleKey to filter evaluation to a single rule (handled by the service if you extend it).
//     // -------------------------------------------------------------------------
//     @AuraEnabled
//     public static String runEvaluation(Id candidateId, String ruleKey) {
//         if (candidateId == null) {
//             throw new AuraHandledException('candidateId is required');
//         }
//         // Build request
//         EvaluateScreeningRules.Request req = new EvaluateScreeningRules.Request();
//         req.candidateId = candidateId;
//         // Optional: get candidate parsed json and pass as parsedJson to invocable; this avoids extra queries inside the invocable
//         try {
//             Candidate__c c = [SELECT Id, Name, Raw_Resume_Payload__c, Locale__c, Email__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
//             if (String.isNotBlank(c.Raw_Resume_Payload__c)) req.parsedJson = c.Raw_Resume_Payload__c;
//             // candidateFields optional: we can pass some candidate attributes packaged as JSON
//             Map<String,Object> candFields = new Map<String,Object>();
//             candFields.put('name', c.Name);
//             candFields.put('locale', c.Locale__c);
//             candFields.put('email', c.Email__c);
//             req.candidateFields = JSON.serialize(candFields);
//         } catch (Exception ex) {
//             // ignore, invocable can query if needed
//         }

//         List<EvaluateScreeningRules.Request> reqs = new List<EvaluateScreeningRules.Request>{ req };
//         List<EvaluateScreeningRules.Response> resp = EvaluateScreeningRules.run(reqs);
//         // Return the serialized response for the LWC (string)
//         return JSON.serializePretty(resp);
//     }

//     // -------------------------------------------------------------------------
//     // getCandidateStatus - returns an object consumed by candidateScreenStatus LWC:
//     // { candidateId, name, status, parsedJson (Map), results: [{ruleKey,...}], routing: {...} }
//     // -------------------------------------------------------------------------
//         @AuraEnabled(cacheable=true)
//     public static CandidateStatusDto getCandidateStatus(Id candidateId) {
//         if (candidateId == null) {
//             throw new AuraHandledException('candidateId required');
//         }
//         CandidateStatusDto out = new CandidateStatusDto();
//         out.candidateId = candidateId;
//         out.results = new List<EvalResultDto>();
//         out.routing = new Map<String,String>();

//         try {
//             // Load candidate record
//             Candidate__c c = [SELECT Id, Name, Status__c, Raw_Resume_Payload__c, Locale__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
//             out.name = c.Name;
//             out.status = c.Status__c;

//             // Parsed JSON: attempt to deserialize, then normalize
//             Map<String,Object> parsedJsonMap = null;
//             if (String.isNotBlank(c.Raw_Resume_Payload__c)) {
//                 try {
//                     parsedJsonMap = (Map<String,Object>) JSON.deserializeUntyped(c.Raw_Resume_Payload__c);
//                 } catch (Exception e) {
//                     parsedJsonMap = null;
//                 }
//             }
//             try {
//                 parsedJsonMap = ParsedJsonNormalizer.normalize(parsedJsonMap);
//             } catch (Exception e) {
//                 // Ensure parsedJsonMap is at least an empty map
//                 if (parsedJsonMap == null) parsedJsonMap = new Map<String,Object>();
//             }
//             // Place normalized map back into DTO so LWC sees the useful keys (experience_years, cert flags, etc)
//             out.parsedJson = parsedJsonMap;

//             // Query recent results ordered by evaluated date desc (so first occurrence per rule = latest)
//             // Increase LIMIT if you need more history, but keep reasonable for performance
//             List<Screening_Result__c> recent = [
//                 SELECT Id, Rule_Key__c, Outcome__c, Score__c, Details__c, Evaluated_At__c, Processed_By__c
//                 FROM Screening_Result__c
//                 WHERE Candidate__c = :candidateId
//                 ORDER BY Evaluated_At__c DESC NULLS LAST
//                 LIMIT 1000
//             ];

//             // Deduplicate by Rule_Key__c keeping the first (most recent) occurrence
//             Set<String> seenRules = new Set<String>();
//             List<Screening_Result__c> deduped = new List<Screening_Result__c>();
//             for (Screening_Result__c sr : recent) {
//                 String rk = sr.Rule_Key__c == null ? '' : sr.Rule_Key__c;
//                 if (!seenRules.contains(rk)) {
//                     seenRules.add(rk);
//                     deduped.add(sr);
//                 }
//             }

//             // Build DTO results list in the same order (most-recent-first per rule)
//             for (Screening_Result__c r : deduped) {
//                 EvalResultDto d = new EvalResultDto();
//                 d.ruleKey = r.Rule_Key__c;
//                 d.outcome = r.Outcome__c;
//                 d.score = (r.Score__c != null) ? Double.valueOf(r.Score__c) : 0.0;
//                 d.details = r.Details__c;
//                 d.action = null; // action isn't stored on Screening_Result__c in your schema; if you have it, map it here
//                 out.results.add(d);
//             }

//             // Routing suggestion: if any result indicates RouteToJurisdiction (either action text or details)
//             for (EvalResultDto er : out.results) {
//                 if (er.details != null && er.details.contains('RouteToJurisdiction')) {
//                     out.routing.put('queue','Jurisdiction Review');
//                     // Try to extract jurisdiction name from details (best-effort)
//                     // If not available, put a generic placeholder
//                     String jur = 'See rule details';
//                     // naive extraction attempt: look for "jurisdiction" or "IN" etc - keep simple
//                     // If you store jurisdiction in Screening_Result__c in future, prefer that
//                     out.routing.put('jurisdiction', jur);
//                     break;
//                 }
//             }

//         } catch (Exception ex) {
//             // return partial DTO with error recorded in audit for observability
//             try {
//                 Screening_Audit__c a = new Screening_Audit__c();
//                 a.Event_Type__c = 'GET_CANDIDATE_STATUS_ERROR';
//                 a.Event_Payload__c = 'Error fetching status for ' + String.valueOf(candidateId) + ' - ' + ex.getMessage();
//                 a.Created_At__c = Datetime.now();
//                 a.Created_By__c = 'SYSTEM';
//                 insert a;
//             } catch (Exception ignore) {}
//             // best-effort: at least return what we have
//         }
//         return out;
//     }


// }
public with sharing class ScreeningController {
    public class RuleDto {
        @AuraEnabled public String ruleKey;
        @AuraEnabled public Integer priority;
        @AuraEnabled public Boolean active;
        @AuraEnabled public String condition;
        @AuraEnabled public String action;
        @AuraEnabled public String jurisdiction;
        @AuraEnabled public String schemaVersion;
        @AuraEnabled public String severity;
        public RuleDto() {}
        public RuleDto(String rk, Integer p, Boolean a, String c, String act, String jur, String sv, String sev) {
            ruleKey = rk; priority = p; active = a; condition = c; action = act; jurisdiction = jur; schemaVersion = sv; severity = sev;
        }
    }

    public class EvalResultDto {
        @AuraEnabled public String ruleKey;
        @AuraEnabled public String action;
        @AuraEnabled public String outcome;
        @AuraEnabled public Double score;
        @AuraEnabled public String details;
        @AuraEnabled public String jurisdiction;
        public EvalResultDto() {}
    }

    public class CandidateStatusDto {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public Object parsedJson; // map / object (serialized as JSON to LWC)
        @AuraEnabled public List<EvalResultDto> results;
        @AuraEnabled public Map<String,String> routing;
        public CandidateStatusDto() {}
    }

    // -------------------------------------------------------------------------
    // getRules - called by screeningAdmin LWC (cacheable)
    // -------------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<RuleDto> getRules() {
        List<RuleDto> out = new List<RuleDto>();
        try {
            List<ScreeningRuleService.Rule> rules = ScreeningRuleService.getActiveRules();
            for (ScreeningRuleService.Rule r : rules) {
                RuleDto d = new RuleDto(r.ruleKey, r.priority, r.active, r.condition, r.action, r.jurisdiction, r.schemaVersion, r.severity);
                out.add(d);
            }
        } catch (Exception ex) {
            out.add(new RuleDto('SAMPLE_RULE_FAIL_IF_EXP_LT_2', 10, true, 'parsed_json.experience_years < 2', 'AutoReject', null, 'v1', 'Low'));
            out.add(new RuleDto('SAMPLE_RULE_ROUTE_IN_IF_AADHAAR', 20, true, 'candidate.locale == \'IN\' AND parsed_json.has_aadhaar == true', 'RouteToJurisdiction', 'IN', 'v1', 'Medium'));
        }
        return out;
    }

    // -------------------------------------------------------------------------
    // toggleRuleActive - admin action.
    // -------------------------------------------------------------------------
    @AuraEnabled
    public static Boolean toggleRuleActive(String ruleKey, Boolean active) {
        try {
            String requestorId = UserInfo.getUserId();
            String requestorName = requestorId;
            try {
                User u = [SELECT Name FROM User WHERE Id = :requestorId LIMIT 1];
                if (u != null && String.isNotBlank(u.Name)) requestorName = u.Name;
            } catch (Exception e) {}

            Screening_Audit__c a = new Screening_Audit__c();
            a.Event_Type__c = 'TOGGLE_RULE_REQUEST';
            a.Event_Payload__c = JSON.serializePretty(new Map<String,Object>{
                'ruleKey' => ruleKey,
                'requestedActive' => active,
                'requestor' => requestorId,
                'requestorName' => requestorName,
                'requestedAt' => Datetime.now()
            });
            a.Correlation_Id__c = 'toggle-' + String.valueOf(Datetime.now().getTime()) + '-' + requestorId;
            a.Created_By__c = requestorName;
            a.Created_At__c = Datetime.now();
            insert a;
            return true;
        } catch (Exception ex) {
            return false;
        }
    }

    // -------------------------------------------------------------------------
    // Existing runEvaluation for LWC (keeps returning serialized responses to be backward-compatible)
    // -------------------------------------------------------------------------
    @AuraEnabled
    public static String runEvaluation(Id candidateId, String ruleKey) {
        if (candidateId == null) {
            throw new AuraHandledException('candidateId is required');
        }
        EvaluateScreeningRules.Request req = new EvaluateScreeningRules.Request();
        req.candidateId = candidateId;
        try {
            Candidate__c c = [SELECT Id, Name, Raw_Resume_Payload__c, Locale__c, Email__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
            if (String.isNotBlank(c.Raw_Resume_Payload__c)) req.parsedJson = c.Raw_Resume_Payload__c;
            Map<String,Object> candFields = new Map<String,Object>();
            candFields.put('name', c.Name);
            candFields.put('locale', c.Locale__c);
            candFields.put('email', c.Email__c);
            req.candidateFields = JSON.serialize(candFields);
        } catch (Exception ex) {}
        List<EvaluateScreeningRules.Request> reqs = new List<EvaluateScreeningRules.Request>{ req };
        List<EvaluateScreeningRules.Response> resp = EvaluateScreeningRules.run(reqs);
        return JSON.serializePretty(resp);
    }

    // -------------------------------------------------------------------------
    // New: structured runEvaluation (returns typed result object) - for LWC clients
    // -------------------------------------------------------------------------
    public class StructuredEvalResult {
        @AuraEnabled public String ruleKey;
        @AuraEnabled public String action;
        @AuraEnabled public String outcome;
        @AuraEnabled public Double score;
        @AuraEnabled public String details;
        @AuraEnabled public String jurisdiction;
        public StructuredEvalResult() {}
    }

    public class StructuredEvalResponse {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String correlationId;
        @AuraEnabled public String status;
        @AuraEnabled public List<StructuredEvalResult> results;
        public StructuredEvalResponse() {
            results = new List<StructuredEvalResult>();
            status = 'OK';
        }
    }

    @AuraEnabled
    public static StructuredEvalResponse runEvaluationStructured(Id candidateId, String ruleKey) {
        if (candidateId == null) {
            throw new AuraHandledException('candidateId is required');
        }
        StructuredEvalResponse out = new StructuredEvalResponse();
        out.candidateId = candidateId;
        out.correlationId = 'corr-' + String.valueOf(Datetime.now().getTime()) + '-' + Math.abs(Crypto.getRandomInteger());
        out.status = 'OK';

        try {
            List<EvaluateScreeningRules.EvalResultDto> evals = EvaluateScreeningRules.getEvaluationResults(candidateId);
            if (evals != null) {
                for (EvaluateScreeningRules.EvalResultDto er : evals) {
                    StructuredEvalResult r = new StructuredEvalResult();
                    r.ruleKey = er.ruleKey;
                    r.action = er.action;
                    r.outcome = er.outcome;
                    r.score = er.score;
                    r.details = er.details;
                    r.jurisdiction = er.jurisdiction;
                    out.results.add(r);
                }
            }
        } catch (Exception ex) {
            out.status = 'ERROR';
            StructuredEvalResult errR = new StructuredEvalResult();
            errR.ruleKey = 'SYSTEM_ERROR';
            errR.details = 'Error evaluating: ' + ex.getMessage();
            out.results.add(errR);
        }
        return out;
    }

    // -------------------------------------------------------------------------
    // Candidate status for UI (dedupe latest per rule using CreatedDate)
    // -------------------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static CandidateStatusDto getCandidateStatus(Id candidateId) {
        if (candidateId == null) {
            throw new AuraHandledException('candidateId required');
        }
        CandidateStatusDto out = new CandidateStatusDto();
        out.candidateId = candidateId;
        out.results = new List<EvalResultDto>();
        out.routing = new Map<String,String>();

        try {
            // Query candidate core info
            Candidate__c c = [SELECT Id, Name, Status__c, Raw_Resume_Payload__c, Locale__c
                              FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
            out.name = c.Name;
            out.status = c.Status__c;

            // parsedJson: attempt to deserialize for the UI; leave as raw if deserialization fails
            if (String.isNotBlank(c.Raw_Resume_Payload__c)) {
                try {
                    out.parsedJson = JSON.deserializeUntyped(c.Raw_Resume_Payload__c);
                } catch (Exception e) {
                    out.parsedJson = c.Raw_Resume_Payload__c;
                }
            } else {
                out.parsedJson = null;
            }

            // Query recent screening results (ordered descending by CreatedDate).
            List<Screening_Result__c> allResults = [
                SELECT Id, Rule_Key__c, Outcome__c, Score__c, Details__c, CreatedDate
                FROM Screening_Result__c
                WHERE Candidate__c = :candidateId
                ORDER BY CreatedDate DESC
                LIMIT 500
            ];

            // Deduplicate: keep only the latest result per Rule_Key__c
            Map<String, Screening_Result__c> latestByRule = new Map<String, Screening_Result__c>();
            for (Screening_Result__c sr : allResults) {
                String rk = sr.Rule_Key__c == null ? '' : sr.Rule_Key__c;
                if (!latestByRule.containsKey(rk)) {
                    latestByRule.put(rk, sr); // first occurrence in descending order is the latest
                }
            }

            // Convert deduped map to DTO list, preserving a stable order (sort by CreatedDate desc)
            List<Screening_Result__c> dedupedList = new List<Screening_Result__c>();
            for (Screening_Result__c sr : latestByRule.values()) dedupedList.add(sr);

            // Sort dedupedList by CreatedDate DESC using a typed comparator inner class
            dedupedList.sort(new ScreeningResultCreatedDateComparator());

            for (Screening_Result__c r : dedupedList) {
                EvalResultDto d = new EvalResultDto();
                d.ruleKey = r.Rule_Key__c;
                d.outcome = r.Outcome__c;
                d.score = (r.Score__c != null) ? Double.valueOf(r.Score__c) : 0.0;
                d.details = r.Details__c;
                d.action = null;
                out.results.add(d);
            }

            // Basic routing suggestion: if any Screening_Result indicates RouteToJurisdiction, set routing map
            for (EvalResultDto er : out.results) {
                if (er.details != null && er.details.contains('RouteToJurisdiction')) {
                    out.routing.put('queue','Jurisdiction Review');
                    out.routing.put('jurisdiction','See rule details');
                    break;
                }
            }
        } catch (Exception ex) {
            // return partial DTO with error logged as audit
            try {
                Screening_Audit__c a = new Screening_Audit__c();
                a.Event_Type__c = 'GET_CANDIDATE_STATUS_ERROR';
                a.Event_Payload__c = 'Error fetching status for ' + String.valueOf(candidateId) + ' - ' + ex.getMessage();
                a.Created_At__c = Datetime.now();
                a.Created_By__c = 'SYSTEM';
                insert a;
            } catch (Exception ignore) {}
        }
        return out;
    }

    // Comparator class for sorting Screening_Result__c by CreatedDate desc
    private class ScreeningResultCreatedDateComparator implements System.Comparator<Screening_Result__c> {
        public Integer compare(Screening_Result__c a, Screening_Result__c b) {
            if (a == null && b == null) return 0;
            if (a == null) return 1;
            if (b == null) return -1;
            Datetime da = (a.CreatedDate == null) ? Datetime.newInstanceGmt(1970,1,1) : a.CreatedDate;
            Datetime db = (b.CreatedDate == null) ? Datetime.newInstanceGmt(1970,1,1) : b.CreatedDate;
            if (da == db) return 0;
            return (da > db) ? -1 : 1; // descending
        }
    }
}

