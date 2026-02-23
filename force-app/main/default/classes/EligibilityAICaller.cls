// public without sharing class EligibilityAICaller {

//     /* ============================================================
//        RESPONSE WRAPPER
//     ============================================================ */
//     public class AIResult {
//         @AuraEnabled public Boolean success;
//         @AuraEnabled public String rawResponse;
//         @AuraEnabled public String cleanedJson;
//         @AuraEnabled public String error;

//         public AIResult() { success = false; }
//     }

//     /* ============================================================
//        MAIN ENTRY — JOB APPLICATION ID
//     ============================================================ */
//     @AuraEnabled
//     public static AIResult callEligibilityAI(Id jobApplicationId) {

//         AIResult result = new AIResult();

//         try {

//             System.debug('=== AI Eligibility START ===');

//             // 1️⃣ Fetch Job Application
//             Job_Application__c app = [
//                 SELECT Id, Candidate__c, Job_Posting__c
//                 FROM Job_Application__c
//                 WHERE Id = :jobApplicationId
//                 LIMIT 1
//             ];

//             if (app.Candidate__c == null || app.Job_Posting__c == null) {
//                 result.error = 'Missing Candidate or Job Posting';
//                 return result;
//             }

//             // 2️⃣ Gather Full Data
//             JobRequirements jobReq = gatherJobRequirements(app.Job_Posting__c);
//             CandidateQualifications cand = gatherCandidateQualifications(app.Candidate__c);

//             if (jobReq == null || cand == null) {
//                 result.error = 'Unable to gather job or candidate data';
//                 return result;
//             }

//             // 3️⃣ Build Prompt
//             String prompt = buildPrompt(jobReq, cand);

//             // 4️⃣ AI CALL WITH RETRY
//             Map<String, Object> parsed = null;
//             String rawText = null;
//             Integer attempts = 0;

//             while (attempts < 3) {

//                 attempts++;
//                 System.debug('AI Attempt #' + attempts);

//                 GeminiAPIService.GeminiResponse aiRes =
//                     GeminiAPIService.callGeminiAPIWithPrompt(prompt);

//                 if (!aiRes.success) {
//                     result.error = aiRes.errorMessage;
//                     return result;
//                 }

//                 rawText = GeminiAPIService.extractContent(aiRes);
//                 result.rawResponse = rawText;

//                 try {
//                     parsed = safeParseAIResponse(rawText);
//                     break;
//                 } catch (Exception ex) {

//                     System.debug('Parse failed: ' + ex.getMessage());

//                     if (attempts == 3) {
//                         result.error = 'AI returned invalid JSON after retries';
//                         return result;
//                     }

//                     prompt = buildRepairPrompt(rawText);
//                 }
//             }

//             // 5️⃣ Extract Values
//             Decimal score = 0;
//             if (parsed.containsKey('eligibilityScore')) {
//                 score = Decimal.valueOf(String.valueOf(parsed.get('eligibilityScore')));
//             }

//             String finalStatus = (score > 70) ? 'Eligibility Passed' : 'Eligibility Failed';

//             // 6️⃣ Store Results
//             app.Eligibility_Score__c = score.setScale(2);
//             app.Eligibility_Summary__c = String.valueOf(parsed.get('summary'));
//             app.Eligibility_Pros__c = String.valueOf(parsed.get('pros'));
//             app.Eligibility_Cons__c = String.valueOf(parsed.get('cons'));
//             app.Status__c = finalStatus;

//             update app;

//             result.success = true;
//             result.cleanedJson = JSON.serializePretty(parsed);

//             System.debug('=== STORED SUCCESSFULLY ===');

//             return result;

//         } catch (Exception e) {
//             result.error = e.getMessage();
//             System.debug('Exception: ' + e.getMessage());
//             return result;
//         }
//     }

//     /* ============================================================
//        SAFE JSON PARSER
//     ============================================================ */
//     private static Map<String, Object> safeParseAIResponse(String raw) {

//         String cleaned = raw.trim();

//         if (cleaned.startsWith('```json'))
//             cleaned = cleaned.substring(7);
//         if (cleaned.startsWith('```'))
//             cleaned = cleaned.substring(3);
//         if (cleaned.endsWith('```'))
//             cleaned = cleaned.substring(0, cleaned.length() - 3);

//         Integer firstBrace = cleaned.indexOf('{');
//         Integer lastBrace = cleaned.lastIndexOf('}');

//         if (firstBrace == -1 || lastBrace == -1)
//             throw new AuraHandledException('Invalid JSON structure');

//         String jsonOnly = cleaned.substring(firstBrace, lastBrace + 1);

//         return (Map<String, Object>) JSON.deserializeUntyped(jsonOnly);
//     }

//     private static String buildRepairPrompt(String broken) {

//         return 'Fix the following JSON and return valid JSON only:\n' + broken;
//     }

//     /* ============================================================
//        DATA STRUCTURES
//     ============================================================ */
//     public class JobRequirements {
//         public String title;
//         public Decimal minExp;
//         public Decimal maxExp;
//         public String description;
//         public List<String> education = new List<String>();
//         public List<String> licenses = new List<String>();
//         public List<String> certifications = new List<String>();
//         public List<String> skills = new List<String>();
//         public List<String> procedures = new List<String>();
//     }

//     public class CandidateQualifications {
//         public List<String> education = new List<String>();
//         public List<String> licenses = new List<String>();
//         public List<String> certifications = new List<String>();
//         public List<String> skills = new List<String>();
//         public List<String> techSkills = new List<String>();
//         public List<String> experience = new List<String>();
//         public List<String> procedures = new List<String>();
//     }

//     /* ============================================================
//        FULL DATA GATHERING — JOB
//     ============================================================ */
//     private static JobRequirements gatherJobRequirements(Id jobPostingId) {

//         Job_Posting__c jp = [
//             SELECT Job_Title__c, Min_Experience_Years__c,
//                    Max_Experience_Years__c, Description__c
//             FROM Job_Posting__c
//             WHERE Id = :jobPostingId
//             LIMIT 1
//         ];

//         JobRequirements req = new JobRequirements();
//         req.title = jp.Job_Title__c;
//         req.minExp = jp.Min_Experience_Years__c;
//         req.maxExp = jp.Max_Experience_Years__c;
//         req.description = jp.Description__c;

//         for (Job_Education_Requirement__c e :
//             [SELECT Degree_Name__c FROM Job_Education_Requirement__c
//              WHERE Job_Posting__c = :jobPostingId]) {
//             req.education.add(e.Degree_Name__c);
//         }

//         for (Job_License_Requirement__c l :
//             [SELECT License_Name__c FROM Job_License_Requirement__c
//              WHERE Job_Posting__c = :jobPostingId]) {
//             req.licenses.add(l.License_Name__c);
//         }

//         for (Job_Certification_Requirement__c c :
//             [SELECT Certification_Name__c FROM Job_Certification_Requirement__c
//              WHERE Job_Posting__c = :jobPostingId]) {
//             req.certifications.add(c.Certification_Name__c);
//         }

//         for (Job_Clinical_Skill__c s :
//             [SELECT Skill_Name__c FROM Job_Clinical_Skill__c
//              WHERE Job_Posting__c = :jobPostingId]) {
//             req.skills.add(s.Skill_Name__c);
//         }

//         for (Job_Procedure_Requirement__c p :
//             [SELECT Procedure_Name__c FROM Job_Procedure_Requirement__c
//              WHERE Job_Posting__c = :jobPostingId]) {
//             req.procedures.add(p.Procedure_Name__c);
//         }

//         return req;
//     }

//     /* ============================================================
//        FULL DATA GATHERING — CANDIDATE
//     ============================================================ */
//     private static CandidateQualifications gatherCandidateQualifications(Id candidateId) {

//         CandidateQualifications c = new CandidateQualifications();

//         for (Education__c e :
//             [SELECT Degree__c, Institution__c FROM Education__c
//              WHERE Candidate__c = :candidateId]) {
//             c.education.add(e.Degree__c + ' - ' + e.Institution__c);
//         }

//         for (License_Certification__c l :
//             [SELECT Name FROM License_Certification__c
//              WHERE Candidate__c = :candidateId]) {
//             c.licenses.add(l.Name);
//         }

//         for (Clinical_Skill__c s :
//             [SELECT Name FROM Clinical_Skill__c
//              WHERE Candidate__c = :candidateId]) {
//             c.skills.add(s.Name);
//         }

//         for (Technical_Skill__c t :
//             [SELECT Name FROM Technical_Skill__c
//              WHERE Candidate__c = :candidateId]) {
//             c.techSkills.add(t.Name);
//         }

//         for (Work_Experience__c w :
//             [SELECT Role__c, Organization__c FROM Work_Experience__c
//              WHERE Candidate__c = :candidateId]) {
//             c.experience.add(w.Role__c + ' at ' + w.Organization__c);
//         }

//         for (Procedure__c p :
//             [SELECT Name FROM Procedure__c
//              WHERE Candidate__c = :candidateId]) {
//             c.procedures.add(p.Name);
//         }

//         return c;
//     }

//     /* ============================================================
//        PROMPT BUILDER
//     ============================================================ */
//     private static String buildPrompt(JobRequirements j, CandidateQualifications c) {

//     String p = '';

//     p += 'You are an enterprise medical credential evaluator for a large healthcare network.\n';
//     p += 'Perform a strict but fair eligibility evaluation.\n\n';

//     p += '=== EQUIVALENCY RULES (MANDATORY) ===\n';
//     p += '- Treat abbreviations and full forms as equivalent Example: (ACLS = Advanced Cardiac Life Support).\n';
//     p += '- Treat BLS = Basic Life Support.\n';
//     p += '- Treat MBBS = Bachelor of Medicine and Bachelor of Surgery.\n';
//     p += '- Treat MD = Doctor of Medicine.\n';
//     p += '- Treat licensing naming variations as equivalent if governing body matches.\n';
//     p += '- Do NOT penalize formatting differences.\n';
//     p += '- Focus on competency equivalence, not wording differences.\n\n';

//     p += '=== MANDATORY REQUIREMENT LOGIC ===\n';
//     p += '- If mandatory education is missing → major penalty.\n';
//     p += '- If required license is missing or expired → major penalty.\n';
//     p += '- If critical procedures are missing → significant penalty.\n';
//     p += '- Experience range should be interpreted reasonably.\n\n';

//     p += '=== JOB REQUIREMENTS ===\n';
//     p += 'Title: ' + j.title + '\n';
//     p += 'Experience Required: ' + j.minExp + '-' + j.maxExp + ' years\n';
//     p += 'Required Education: ' + String.join(j.education, ', ') + '\n';
//     p += 'Required Licenses: ' + String.join(j.licenses, ', ') + '\n';
//     p += 'Required Certifications: ' + String.join(j.certifications, ', ') + '\n';
//     p += 'Required Clinical Skills: ' + String.join(j.skills, ', ') + '\n';
//     p += 'Required Procedures: ' + String.join(j.procedures, ', ') + '\n\n';

//     p += '=== CANDIDATE QUALIFICATIONS ===\n';
//     p += 'Education: ' + String.join(c.education, ', ') + '\n';
//     p += 'Licenses: ' + String.join(c.licenses, ', ') + '\n';
//     p += 'Certifications: ' + String.join(c.certifications, ', ') + '\n';
//     p += 'Clinical Skills: ' + String.join(c.skills, ', ') + '\n';
//     p += 'Technical Skills: ' + String.join(c.techSkills, ', ') + '\n';
//     p += 'Experience: ' + String.join(c.experience, ', ') + '\n';
//     p += 'Procedures: ' + String.join(c.procedures, ', ') + '\n\n';

//     p += '=== SCORING SCALE ===\n';
//     p += '90–100 = Fully meets or exceeds all major requirements.\n';
//     p += '75–89 = Meets core requirements with minor gaps.\n';
//     p += '60–74 = Partial alignment.\n';
//     p += 'Below 60 = Significant qualification gaps.\n\n';

//     p += 'Return STRICT JSON only:\n';
//     p += '{\n';
//     p += '  "eligibilityScore": <0-100>,\n';
//     p += '  "summary": "<short professional summary>",\n';
//     p += '  "pros": "<bullet-style strengths>",\n';
//     p += '  "cons": "<bullet-style gaps>"\n';
//     p += '}';

//     return p;
// }

// }
public without sharing class EligibilityAICaller {

    /* ============================================================
       RESPONSE WRAPPER — for LWC / AuraEnabled callers
    ============================================================ */
    public class AIResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String rawResponse;
        @AuraEnabled public String cleanedJson;
        @AuraEnabled public String error;

        public AIResult() { success = false; }
    }

    /* ============================================================
       FLOW INPUT WRAPPER
    ============================================================ */
    public class FlowRequest {
        @InvocableVariable(label='Job Application ID' required=true)
        public Id jobApplicationId;
    }

    /* ============================================================
       FLOW OUTPUT WRAPPER
    ============================================================ */
    public class FlowResponse {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Eligibility Score')
        public Decimal eligibilityScore;

        @InvocableVariable(label='Eligibility Status')
        public String eligibilityStatus;

        @InvocableVariable(label='Summary')
        public String summary;

        @InvocableVariable(label='Error Message')
        public String error;

        @InvocableVariable(label='Cleaned JSON')
        public String cleanedJson;
    }

    /* ============================================================
       INVOCABLE METHOD — called by Salesforce Flow
    ============================================================ */
    @InvocableMethod(
        label='Run Eligibility AI'
        description='Evaluates candidate eligibility using Gemini AI and updates the Job Application record'
        category='Job Application'
    )
    public static List<FlowResponse> runEligibilityFromFlow(List<FlowRequest> requests) {

        List<FlowResponse> responses = new List<FlowResponse>();

        for (FlowRequest req : requests) {
            FlowResponse res = new FlowResponse();

            try {
                AIResult aiResult = callEligibilityAI(req.jobApplicationId);

                res.success     = aiResult.success;
                res.error       = aiResult.error;
                res.cleanedJson = aiResult.cleanedJson;

                if (aiResult.success && aiResult.cleanedJson != null) {
                    Map<String, Object> parsed =
                        (Map<String, Object>) JSON.deserializeUntyped(aiResult.cleanedJson);

                    res.eligibilityScore =
                        Decimal.valueOf(String.valueOf(parsed.get('eligibilityScore')));

                    res.summary = String.valueOf(parsed.get('summary'));

                    res.eligibilityStatus = (res.eligibilityScore > 70)
                        ? 'Eligibility Passed'
                        : 'Eligibility Failed';
                }

            } catch (Exception e) {
                res.success = false;
                res.error   = e.getMessage();
            }

            responses.add(res);
        }

        return responses;
    }

    /* ============================================================
       MAIN ENTRY — JOB APPLICATION ID (used by LWC & Flow wrapper)
    ============================================================ */
    @AuraEnabled
    public static AIResult callEligibilityAI(Id jobApplicationId) {

        AIResult result = new AIResult();

        try {

            System.debug('=== AI Eligibility START ===');

            // 1. Fetch Job Application
            Job_Application__c app = [
                SELECT Id, Candidate__c, Job_Posting__c
                FROM Job_Application__c
                WHERE Id = :jobApplicationId
                LIMIT 1
            ];

            if (app.Candidate__c == null || app.Job_Posting__c == null) {
                result.error = 'Missing Candidate or Job Posting';
                return result;
            }

            // 2. Gather Full Data
            JobRequirements jobReq = gatherJobRequirements(app.Job_Posting__c);
            CandidateQualifications cand = gatherCandidateQualifications(app.Candidate__c);

            if (jobReq == null || cand == null) {
                result.error = 'Unable to gather job or candidate data';
                return result;
            }

            // 3. Build Prompt
            String prompt = buildPrompt(jobReq, cand);

            // 4. AI Call with Retry
            Map<String, Object> parsed = null;
            String rawText = null;
            Integer attempts = 0;

            while (attempts < 3) {

                attempts++;
                System.debug('AI Attempt #' + attempts);

                GeminiAPIService.GeminiResponse aiRes =
                    GeminiAPIService.callGeminiAPIWithPrompt(prompt);

                if (!aiRes.success) {
                    result.error = aiRes.errorMessage;
                    return result;
                }

                rawText = GeminiAPIService.extractContent(aiRes);
                result.rawResponse = rawText;

                try {
                    parsed = safeParseAIResponse(rawText);
                    break;
                } catch (Exception ex) {

                    System.debug('Parse failed: ' + ex.getMessage());

                    if (attempts == 3) {
                        result.error = 'AI returned invalid JSON after retries';
                        return result;
                    }

                    prompt = buildRepairPrompt(rawText);
                }
            }

            // 5. Extract Values
            Decimal score = 0;
            if (parsed.containsKey('eligibilityScore')) {
                score = Decimal.valueOf(String.valueOf(parsed.get('eligibilityScore')));
            }

            String finalStatus = (score > 70) ? 'Eligibility Passed' : 'Eligibility Failed';

            // 6. Store Results on Job Application
            app.Eligibility_Score__c    = score.setScale(2);
            app.Eligibility_Summary__c  = String.valueOf(parsed.get('summary'));
            app.Eligibility_Pros__c     = String.valueOf(parsed.get('pros'));
            app.Eligibility_Cons__c     = String.valueOf(parsed.get('cons'));
            app.Status__c               = finalStatus;

            update app;

            result.success     = true;
            result.cleanedJson = JSON.serializePretty(parsed);

            System.debug('=== STORED SUCCESSFULLY ===');

            return result;

        } catch (Exception e) {
            result.error = e.getMessage();
            System.debug('Exception: ' + e.getMessage());
            return result;
        }
    }

    /* ============================================================
       SAFE JSON PARSER
    ============================================================ */
    private static Map<String, Object> safeParseAIResponse(String raw) {

        String cleaned = raw.trim();

        if (cleaned.startsWith('```json'))
            cleaned = cleaned.substring(7);
        if (cleaned.startsWith('```'))
            cleaned = cleaned.substring(3);
        if (cleaned.endsWith('```'))
            cleaned = cleaned.substring(0, cleaned.length() - 3);

        Integer firstBrace = cleaned.indexOf('{');
        Integer lastBrace  = cleaned.lastIndexOf('}');

        if (firstBrace == -1 || lastBrace == -1)
            throw new AuraHandledException('Invalid JSON structure');

        String jsonOnly = cleaned.substring(firstBrace, lastBrace + 1);

        return (Map<String, Object>) JSON.deserializeUntyped(jsonOnly);
    }

    private static String buildRepairPrompt(String broken) {
        return 'Fix the following JSON and return valid JSON only:\n' + broken;
    }

    /* ============================================================
       DATA STRUCTURES
    ============================================================ */
    public class JobRequirements {
        public String title;
        public Decimal minExp;
        public Decimal maxExp;
        public String description;
        public List<String> education      = new List<String>();
        public List<String> licenses       = new List<String>();
        public List<String> certifications = new List<String>();
        public List<String> skills         = new List<String>();
        public List<String> procedures     = new List<String>();
    }

    public class CandidateQualifications {
        public List<String> education      = new List<String>();
        public List<String> licenses       = new List<String>();
        public List<String> certifications = new List<String>();
        public List<String> skills         = new List<String>();
        public List<String> techSkills     = new List<String>();
        public List<String> experience     = new List<String>();
        public List<String> procedures     = new List<String>();
    }

    /* ============================================================
       FULL DATA GATHERING — JOB
    ============================================================ */
    private static JobRequirements gatherJobRequirements(Id jobPostingId) {

        Job_Posting__c jp = [
            SELECT Job_Title__c, Min_Experience_Years__c,
                   Max_Experience_Years__c, Description__c
            FROM Job_Posting__c
            WHERE Id = :jobPostingId
            LIMIT 1
        ];

        JobRequirements req = new JobRequirements();
        req.title       = jp.Job_Title__c;
        req.minExp      = jp.Min_Experience_Years__c;
        req.maxExp      = jp.Max_Experience_Years__c;
        req.description = jp.Description__c;

        for (Job_Education_Requirement__c e :
            [SELECT Degree_Name__c FROM Job_Education_Requirement__c
             WHERE Job_Posting__c = :jobPostingId]) {
            req.education.add(e.Degree_Name__c);
        }

        for (Job_License_Requirement__c l :
            [SELECT License_Name__c FROM Job_License_Requirement__c
             WHERE Job_Posting__c = :jobPostingId]) {
            req.licenses.add(l.License_Name__c);
        }

        for (Job_Certification_Requirement__c c :
            [SELECT Certification_Name__c FROM Job_Certification_Requirement__c
             WHERE Job_Posting__c = :jobPostingId]) {
            req.certifications.add(c.Certification_Name__c);
        }

        for (Job_Clinical_Skill__c s :
            [SELECT Skill_Name__c FROM Job_Clinical_Skill__c
             WHERE Job_Posting__c = :jobPostingId]) {
            req.skills.add(s.Skill_Name__c);
        }

        for (Job_Procedure_Requirement__c p :
            [SELECT Procedure_Name__c FROM Job_Procedure_Requirement__c
             WHERE Job_Posting__c = :jobPostingId]) {
            req.procedures.add(p.Procedure_Name__c);
        }

        return req;
    }

    /* ============================================================
       FULL DATA GATHERING — CANDIDATE
    ============================================================ */
    private static CandidateQualifications gatherCandidateQualifications(Id candidateId) {

        CandidateQualifications c = new CandidateQualifications();

        for (Education__c e :
            [SELECT Degree__c, Institution__c FROM Education__c
             WHERE Candidate__c = :candidateId]) {
            c.education.add(e.Degree__c + ' - ' + e.Institution__c);
        }

        for (License_Certification__c l :
            [SELECT Name FROM License_Certification__c
             WHERE Candidate__c = :candidateId]) {
            c.licenses.add(l.Name);
        }

        for (Clinical_Skill__c s :
            [SELECT Name FROM Clinical_Skill__c
             WHERE Candidate__c = :candidateId]) {
            c.skills.add(s.Name);
        }

        for (Technical_Skill__c t :
            [SELECT Name FROM Technical_Skill__c
             WHERE Candidate__c = :candidateId]) {
            c.techSkills.add(t.Name);
        }

        for (Work_Experience__c w :
            [SELECT Role__c, Organization__c FROM Work_Experience__c
             WHERE Candidate__c = :candidateId]) {
            c.experience.add(w.Role__c + ' at ' + w.Organization__c);
        }

        for (Procedure__c p :
            [SELECT Name FROM Procedure__c
             WHERE Candidate__c = :candidateId]) {
            c.procedures.add(p.Name);
        }

        return c;
    }

    /* ============================================================
       PROMPT BUILDER
    ============================================================ */
    private static String buildPrompt(JobRequirements j, CandidateQualifications c) {

        String p = '';

        p += 'You are an enterprise medical credential evaluator for a large healthcare network.\n';
        p += 'Perform a strict but fair eligibility evaluation.\n\n';

        p += '=== EQUIVALENCY RULES (MANDATORY) ===\n';
        p += '- Treat abbreviations and full forms as equivalent (e.g. ACLS = Advanced Cardiac Life Support).\n';
        p += '- Treat BLS = Basic Life Support.\n';
        p += '- Treat MBBS = Bachelor of Medicine and Bachelor of Surgery.\n';
        p += '- Treat MD = Doctor of Medicine.\n';
        p += '- Treat licensing naming variations as equivalent if governing body matches.\n';
        p += '- Do NOT penalize formatting differences.\n';
        p += '- Focus on competency equivalence, not wording differences.\n\n';

        p += '=== MANDATORY REQUIREMENT LOGIC ===\n';
        p += '- If mandatory education is missing, major penalty.\n';
        p += '- If required license is missing or expired, major penalty.\n';
        p += '- If critical procedures are missing, significant penalty.\n';
        p += '- Experience range should be interpreted reasonably.\n\n';

        p += '=== JOB REQUIREMENTS ===\n';
        p += 'Title: ' + j.title + '\n';
        p += 'Experience Required: ' + j.minExp + '-' + j.maxExp + ' years\n';
        p += 'Required Education: ' + String.join(j.education, ', ') + '\n';
        p += 'Required Licenses: ' + String.join(j.licenses, ', ') + '\n';
        p += 'Required Certifications: ' + String.join(j.certifications, ', ') + '\n';
        p += 'Required Clinical Skills: ' + String.join(j.skills, ', ') + '\n';
        p += 'Required Procedures: ' + String.join(j.procedures, ', ') + '\n\n';

        p += '=== CANDIDATE QUALIFICATIONS ===\n';
        p += 'Education: ' + String.join(c.education, ', ') + '\n';
        p += 'Licenses: ' + String.join(c.licenses, ', ') + '\n';
        p += 'Certifications: ' + String.join(c.certifications, ', ') + '\n';
        p += 'Clinical Skills: ' + String.join(c.skills, ', ') + '\n';
        p += 'Technical Skills: ' + String.join(c.techSkills, ', ') + '\n';
        p += 'Experience: ' + String.join(c.experience, ', ') + '\n';
        p += 'Procedures: ' + String.join(c.procedures, ', ') + '\n\n';

        p += '=== SCORING SCALE ===\n';
        p += '90-100 = Fully meets or exceeds all major requirements.\n';
        p += '75-89  = Meets core requirements with minor gaps.\n';
        p += '60-74  = Partial alignment.\n';
        p += 'Below 60 = Significant qualification gaps.\n\n';

        p += 'Return STRICT JSON only:\n';
        p += '{\n';
        p += '  "eligibilityScore": <0-100>,\n';
        p += '  "summary": "<short professional summary>",\n';
        p += '  "pros": "<bullet-style strengths>",\n';
        p += '  "cons": "<bullet-style gaps>"\n';
        p += '}';

        return p;
    }
}