public without sharing class EligibilityAICaller {

    /* ============================================================
       FLOW INPUT/OUTPUT WRAPPERS
    ============================================================ */
    public class FlowInput {
        @InvocableVariable(
            label='Job Application ID' 
            description='The ID of the Job Application record'
            required=true
        )
        public Id jobApplicationId;
    }
    
    public class FlowOutput {
        @InvocableVariable(label='Success')
        public Boolean success;
        
        @InvocableVariable(label='Message')
        public String message;
    }

    /* ============================================================
       INVOCABLE METHOD - CALLED FROM FLOW (NO CALLOUT)
    ============================================================ */
    @InvocableMethod(
        label='Run AI Eligibility Check' 
        description='Evaluates candidate eligibility using AI'
        category='Job Application'
    )
    public static List<FlowOutput> callEligibilityAIFromFlow(List<FlowInput> inputs) {
        
        List<FlowOutput> outputs = new List<FlowOutput>();
        
        for (FlowInput input : inputs) {
            FlowOutput output = new FlowOutput();
            
            // Call the @future method asynchronously
            callEligibilityAIAsync(input.jobApplicationId);
            
            output.success = true;
            output.message = 'AI eligibility check queued successfully';
            outputs.add(output);
        }
        
        return outputs;
    }

    /* ============================================================
       FUTURE METHOD - RUNS ASYNCHRONOUSLY WITH CALLOUT
    ============================================================ */
    @future(callout=true)
    public static void callEligibilityAIAsync(Id jobApplicationId) {
        
        try {
            System.debug('=== AI Eligibility START (Async) ===');

            // 1️⃣ Fetch Job Application
            Job_Application__c app = [
                SELECT Id, Candidate__c, Job_Posting__c
                FROM Job_Application__c
                WHERE Id = :jobApplicationId
                LIMIT 1
            ];

            if (app.Candidate__c == null || app.Job_Posting__c == null) {
                System.debug('❌ ERROR: Missing Candidate or Job Posting');
                return;
            }

            // 2️⃣ Gather Full Data
            JobRequirements jobReq = gatherJobRequirements(app.Job_Posting__c);
            CandidateQualifications cand = gatherCandidateQualifications(app.Candidate__c);

            if (jobReq == null || cand == null) {
                System.debug('❌ ERROR: Unable to gather data');
                return;
            }

            // 3️⃣ Build Prompt
            String prompt = buildPrompt(jobReq, cand);

            // 4️⃣ AI CALL WITH RETRY
            Map<String, Object> parsed = null;
            String rawText = null;
            Integer attempts = 0;

            while (attempts < 3) {
                attempts++;
                System.debug('🔄 AI Attempt #' + attempts);

                GeminiAPIService.GeminiResponse aiRes =
                    GeminiAPIService.callGeminiAPIWithPrompt(prompt);

                if (!aiRes.success) {
                    System.debug('❌ API Error: ' + aiRes.errorMessage);
                    if (attempts == 3) {
                        return;
                    }
                    continue;
                }

                rawText = GeminiAPIService.extractContent(aiRes);

                try {
                    parsed = safeParseAIResponse(rawText);
                    System.debug('✅ JSON Parsed Successfully');
                    break;
                } catch (Exception ex) {
                    System.debug('⚠️ Parse failed: ' + ex.getMessage());
                    if (attempts == 3) {
                        System.debug('❌ All retry attempts exhausted');
                        return;
                    }
                    prompt = buildRepairPrompt(rawText);
                }
            }

            // 5️⃣ Extract Values
            Decimal score = 0;
            if (parsed.containsKey('eligibilityScore')) {
                score = Decimal.valueOf(String.valueOf(parsed.get('eligibilityScore')));
            }
            System.debug('Eligibility Score: ' + score);

            String finalStatus = (score > 70) ? 'Eligibility Passed' : 'Eligibility Failed';
            System.debug('Final Status: ' + finalStatus);

            // 6️⃣ Store Results
            app.Eligibility_Score__c = score.setScale(2);
            app.Eligibility_Summary__c = String.valueOf(parsed.get('summary'));
            app.Eligibility_Pros__c = String.valueOf(parsed.get('pros'));
            app.Eligibility_Cons__c = String.valueOf(parsed.get('cons'));
            app.Status__c = finalStatus;

            update app;

            System.debug('✅ === RECORD UPDATED SUCCESSFULLY ===');

        } catch (Exception e) {
            System.debug('❌ EXCEPTION: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
    }

    /* ============================================================
       INTERNAL CLASSES (NO CHANGES)
    ============================================================ */
    public class AIResult {
        public Boolean success;
        public String rawResponse;
        public String cleanedJson;
        public String error;
        public AIResult() { success = false; }
    }

    public class JobRequirements {
        public String title;
        public Decimal minExp;
        public Decimal maxExp;
        public String description;
        public List<String> education = new List<String>();
        public List<String> licenses = new List<String>();
        public List<String> certifications = new List<String>();
        public List<String> skills = new List<String>();
        public List<String> procedures = new List<String>();
    }

    public class CandidateQualifications {
        public List<String> education = new List<String>();
        public List<String> licenses = new List<String>();
        public List<String> certifications = new List<String>();
        public List<String> skills = new List<String>();
        public List<String> techSkills = new List<String>();
        public List<String> experience = new List<String>();
        public List<String> procedures = new List<String>();
    }

    /* ============================================================
       HELPER METHODS (NO CHANGES - keeping your existing code)
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
        Integer lastBrace = cleaned.lastIndexOf('}');

        if (firstBrace == -1 || lastBrace == -1)
            throw new AuraHandledException('Invalid JSON structure');

        String jsonOnly = cleaned.substring(firstBrace, lastBrace + 1);
        return (Map<String, Object>) JSON.deserializeUntyped(jsonOnly);
    }

    private static String buildRepairPrompt(String broken) {
        return 'Fix the following JSON and return valid JSON only:\n' + broken;
    }

    private static JobRequirements gatherJobRequirements(Id jobPostingId) {
        Job_Posting__c jp = [
            SELECT Job_Title__c, Min_Experience_Years__c,
                   Max_Experience_Years__c, Description__c
            FROM Job_Posting__c
            WHERE Id = :jobPostingId
            LIMIT 1
        ];

        JobRequirements req = new JobRequirements();
        req.title = jp.Job_Title__c;
        req.minExp = jp.Min_Experience_Years__c;
        req.maxExp = jp.Max_Experience_Years__c;
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

    private static String buildPrompt(JobRequirements j, CandidateQualifications c) {
        String p = '';

        p += 'You are an enterprise medical credential evaluator for a large healthcare network.\n';
        p += 'Perform a strict but fair eligibility evaluation.\n\n';

        p += '=== EQUIVALENCY RULES (MANDATORY) ===\n';
        p += '- Treat abbreviations and full forms as equivalent Example: (ACLS = Advanced Cardiac Life Support).\n';
        p += '- Treat BLS = Basic Life Support.\n';
        p += '- Treat MBBS = Bachelor of Medicine and Bachelor of Surgery.\n';
        p += '- Treat MD = Doctor of Medicine.\n';
        p += '- Treat licensing naming variations as equivalent if governing body matches.\n';
        p += '- Do NOT penalize formatting differences.\n';
        p += '- Focus on competency equivalence, not wording differences.\n\n';

        p += '=== MANDATORY REQUIREMENT LOGIC ===\n';
        p += '- If mandatory education is missing → major penalty.\n';
        p += '- If required license is missing or expired → major penalty.\n';
        p += '- If critical procedures are missing → significant penalty.\n';
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
        p += '90–100 = Fully meets or exceeds all major requirements.\n';
        p += '75–89 = Meets core requirements with minor gaps.\n';
        p += '60–74 = Partial alignment.\n';
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