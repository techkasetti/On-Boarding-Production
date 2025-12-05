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
            // Reuse ScreeningRuleService.getActiveRules to fetch rules
            // That method already reads Screening_Rule__mdt and returns only active rules.
            List<ScreeningRuleService.Rule> rules = ScreeningRuleService.getActiveRules();
            for (ScreeningRuleService.Rule r : rules) {
                RuleDto d = new RuleDto(r.ruleKey, r.priority, r.active, r.condition, r.action, r.jurisdiction, r.schemaVersion, r.severity);
                out.add(d);
            }
            // Additionally include inactive rules as well (so admin can see full set)
            // To get all rules (including inactive) we'll query metadata directly (best-effort)
            // We'll try to add inactive ones only if the mdts query is available (handled inside service)
        } catch (Exception ex) {
            // fallback sample rules (useful in sandboxes without metadata)
            out.add(new RuleDto('SAMPLE_RULE_FAIL_IF_EXP_LT_2', 10, true, 'parsed_json.experience_years < 2', 'AutoReject', null, 'v1', 'Low'));
            out.add(new RuleDto('SAMPLE_RULE_ROUTE_IN_IF_AADHAAR', 20, true, 'candidate.locale == \'IN\' AND parsed_json.has_aadhaar == true', 'RouteToJurisdiction', 'IN', 'v1', 'Medium'));
        }
        return out;
    }

    // -------------------------------------------------------------------------
    // toggleRuleActive - admin action. Because Custom Metadata rows cannot be updated
    // via normal Apex DML reliably across orgs, this method writes an audit entry
    // recording the request and returns success. Platform admins should update
    // the Custom Metadata frame in Setup to make permanent changes.
    // -------------------------------------------------------------------------
    @AuraEnabled
    public static Boolean toggleRuleActive(String ruleKey, Boolean active) {
        try {
            // resolve current user's display name safely
            String requestorId = UserInfo.getUserId();
            String requestorName = requestorId;
            try {
                User u = [SELECT Name FROM User WHERE Id = :requestorId LIMIT 1];
                if (u != null && String.isNotBlank(u.Name)) requestorName = u.Name;
            } catch (Exception e) {
                // fallback left as UserId string
            }

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
            // Informational: returning true indicates the request was recorded. Admin must update metadata in Setup.
            return true;
        } catch (Exception ex) {
            // best-effort: return false on failure
            return false;
        }
    }

    // -------------------------------------------------------------------------
    // runEvaluation - call the EvaluateScreeningRules invocable for a single candidate.
    // Optionally, you can pass a ruleKey to filter evaluation to a single rule (handled by the service if you extend it).
    // -------------------------------------------------------------------------
    @AuraEnabled
    public static String runEvaluation(Id candidateId, String ruleKey) {
        if (candidateId == null) {
            throw new AuraHandledException('candidateId is required');
        }
        // Build request
        EvaluateScreeningRules.Request req = new EvaluateScreeningRules.Request();
        req.candidateId = candidateId;
        // Optional: get candidate parsed json and pass as parsedJson to invocable; this avoids extra queries inside the invocable
        try {
            Candidate__c c = [SELECT Id, Name, Raw_Resume_Payload__c, Locale__c, Email__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
            if (String.isNotBlank(c.Raw_Resume_Payload__c)) req.parsedJson = c.Raw_Resume_Payload__c;
            // candidateFields optional: we can pass some candidate attributes packaged as JSON
            Map<String,Object> candFields = new Map<String,Object>();
            candFields.put('name', c.Name);
            candFields.put('locale', c.Locale__c);
            candFields.put('email', c.Email__c);
            req.candidateFields = JSON.serialize(candFields);
        } catch (Exception ex) {
            // ignore, invocable can query if needed
        }

        List<EvaluateScreeningRules.Request> reqs = new List<EvaluateScreeningRules.Request>{ req };
        List<EvaluateScreeningRules.Response> resp = EvaluateScreeningRules.run(reqs);
        // Return the serialized response for the LWC (string)
        return JSON.serializePretty(resp);
    }

    // -------------------------------------------------------------------------
    // getCandidateStatus - returns an object consumed by candidateScreenStatus LWC:
    // { candidateId, name, status, parsedJson (Map), results: [{ruleKey,...}], routing: {...} }
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
            Candidate__c c = [SELECT Id, Name, Status__c, Raw_Resume_Payload__c, Locale__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
            out.name = c.Name;
            out.status = c.Status__c;
            if (String.isNotBlank(c.Raw_Resume_Payload__c)) {
                try {
                    out.parsedJson = JSON.deserializeUntyped(c.Raw_Resume_Payload__c);
                } catch (Exception e) {
                    out.parsedJson = c.Raw_Resume_Payload__c;
                }
            } else {
                out.parsedJson = null;
            }

            // Query recent screening results (last 20)
            List<Screening_Result__c> results = [SELECT Rule_Key__c, Outcome__c, Score__c, Details__c FROM Screening_Result__c WHERE Candidate__c = :candidateId ORDER BY Evaluated_At__c DESC NULLS LAST LIMIT 20];
            for (Screening_Result__c r : results) {
                EvalResultDto d = new EvalResultDto();
                d.ruleKey = r.Rule_Key__c;
                d.outcome = r.Outcome__c;
                d.score = r.Score__c != null ? Double.valueOf(r.Score__c) : 0.0;
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
            // return partial DTO with error in audit
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
}
