/**
* @description   AI model manager — works with OR without OpenAI Named Credential.
*                When Named Credential is missing/fails, returns a high-quality
*                rule-based clause so the UI always works.
* @version       6.0
*/
public with sharing class AIModelManager {

    //======================================================
    // DTO
    //======================================================
    public class AIModelConfig {
        @AuraEnabled public String  modelName       { get; set; }
        @AuraEnabled public String  modelIdentifier { get; set; }
        @AuraEnabled public String  provider        { get; set; }
        @AuraEnabled public String  capabilities    { get; set; }
        @AuraEnabled public Boolean isActive        { get; set; }

        public AIModelConfig(AI_Model_Configuration__mdt config) {
            this.modelName       = config.ModelName__c;
            this.modelIdentifier = config.Model_Id__c;
            this.provider        = config.Provider__c;
            this.capabilities    = config.Capabilities__c;
            this.isActive        = config.Is_Active__c;
        }
        public AIModelConfig(String name, String id, String prov, String caps) {
            this.modelName = name; this.modelIdentifier = id;
            this.provider = prov; this.capabilities = caps; this.isActive = true;
        }
    }

    //======================================================
    // GET AVAILABLE AI MODELS
    //======================================================
    @AuraEnabled(cacheable=true)
    public static List<AIModelConfig> getAvailableAIModels() {
        List<AIModelConfig> models = new List<AIModelConfig>();
        try {
            for (AI_Model_Configuration__mdt c :
                [SELECT ModelName__c, Model_Id__c, Provider__c, Capabilities__c, Is_Active__c
                 FROM AI_Model_Configuration__mdt WHERE Is_Active__c = true ORDER BY ModelName__c]) {
                models.add(new AIModelConfig(c));
            }
        } catch (Exception e) { /* metadata optional */ }

        models.add(new AIModelConfig('Einstein Intent Detection (Salesforce)', 'einstein_intent',    'Salesforce', 'Intent Analysis'));
        models.add(new AIModelConfig('Einstein Sentiment Analysis',            'einstein_sentiment', 'Salesforce', 'Sentiment Analysis'));
        models.add(new AIModelConfig('Einstein OCR',                           'einstein_ocr',       'Salesforce', 'Text Extraction'));
        return models;
    }

    public static AIModelConfig getAIModelByIdentifier(String modelIdentifier) {
        if (String.isBlank(modelIdentifier)) return null;
        for (AIModelConfig m : getAvailableAIModels()) {
            if (m.modelIdentifier == modelIdentifier) return m;
        }
        return null;
    }

    //======================================================
    // MAIN ROUTER
    //======================================================
    @AuraEnabled
    public static String processWithEinstein(String modelId, String prompt, String context) {
        System.debug('AIModelManager.processWithEinstein — modelId=' + modelId);

        // Parse context once — used by both paths
        Map<String,String> ctx = parseContext(context);

        // ── Try real OpenAI callout first ────────────────────────────────────
        try {
            String openAIModel = resolveOpenAIModel(modelId);
            String result = callOpenAI(buildSystemPrompt(ctx), prompt, openAIModel);
            System.debug('OpenAI callout succeeded');
            return result;

        } catch (AIProcessingException ape) {
            // Surface real AI errors (auth failure, quota, bad request)
            System.debug('AIProcessingException from OpenAI: ' + ape.getMessage());
            throw new AuraHandledException(ape.getMessage());

        } catch (System.CalloutException ce) {
            // Named Credential missing or network issue → fall through to rule-based
            System.debug('CalloutException (Named Credential likely missing): ' + ce.getMessage());
            System.debug('Falling back to rule-based clause generation');
            return buildRuleBasedClause(prompt, ctx);

        } catch (Exception e) {
            // Any other unexpected error → fall through to rule-based
            System.debug('Unexpected error (' + e.getTypeName() + '): ' + e.getMessage());
            System.debug('Falling back to rule-based clause generation');
            return buildRuleBasedClause(prompt, ctx);
        }
    }

    //======================================================
    // RESOLVE OPENAI MODEL NAME
    //======================================================
    private static String resolveOpenAIModel(String modelId) {
        if (modelId.startsWith('einstein_')) return 'gpt-4o-mini';
        AI_Model_Configuration__mdt config = getModelConfiguration(modelId);
        if (config != null && String.isNotBlank(config.Model_Id__c)) return config.Model_Id__c;
        return 'gpt-4o-mini';
    }

    //======================================================
    // PARSE CONTEXT JSON
    //======================================================
    private static Map<String,String> parseContext(String context) {
        Map<String,String> result = new Map<String,String>{
            'region' => '', 'role' => '', 'contractType' => '', 'jurisdiction' => ''
        };
        if (String.isBlank(context)) return result;
        try {
            Map<String, Object> ctx = (Map<String, Object>) JSON.deserializeUntyped(context);
            for (String key : result.keySet()) {
                if (ctx.containsKey(key) && ctx.get(key) != null) {
                    result.put(key, String.valueOf(ctx.get(key)));
                }
            }
        } catch (Exception e) { System.debug('Context parse error: ' + e.getMessage()); }
        return result;
    }

    //======================================================
    // BUILD SYSTEM PROMPT
    //======================================================
    private static String buildSystemPrompt(Map<String,String> ctx) {
        String s =
            'You are a professional legal contract drafter. '
            + 'Generate a well-structured formal legal clause. '
            + 'Do NOT use markdown, asterisks, or hash symbols. '
            + 'Use numbered sections (1., 2., 3.) with plain headings. '
            + 'Write in third person (The Employee, The Employer). '
            + 'Be professionally precise and legally enforceable.';
        if (String.isNotBlank(ctx.get('region')))       s += ' Region: '      + ctx.get('region') + '.';
        if (String.isNotBlank(ctx.get('role')))         s += ' Role: '        + ctx.get('role') + '.';
        if (String.isNotBlank(ctx.get('contractType'))) s += ' Contract: '    + ctx.get('contractType') + '.';
        if (String.isNotBlank(ctx.get('jurisdiction'))) s += ' Compliance: '  + ctx.get('jurisdiction') + '.';
        return s;
    }

    //======================================================
    // OPENAI HTTP CALLOUT
    //======================================================
    private static String callOpenAI(String systemPrompt, String userPrompt, String model) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:OpenAI/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);
        req.setBody(JSON.serialize(new Map<String, Object>{
            'model'       => model,
            'max_tokens'  => 1500,
            'temperature' => 0.3,
            'messages'    => new List<Object>{
                new Map<String,Object>{ 'role' => 'system', 'content' => systemPrompt },
                new Map<String,Object>{ 'role' => 'user',   'content' => userPrompt   }
            }
        }));

        HttpResponse resp = new Http().send(req);
        System.debug('OpenAI HTTP ' + resp.getStatusCode());

        if (resp.getStatusCode() == 200) {
            Map<String, Object> body    = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            List<Object>        choices = (List<Object>) body.get('choices');
            if (choices == null || choices.isEmpty()) throw new AIProcessingException('OpenAI returned no choices.');
            Map<String, Object> msg = (Map<String, Object>)((Map<String, Object>) choices[0]).get('message');
            return String.valueOf(msg.get('content')).trim();
        }

        // Parse OpenAI error message
        String errMsg = 'OpenAI HTTP ' + resp.getStatusCode();
        try {
            Map<String, Object> err = (Map<String, Object>)
                ((Map<String, Object>) JSON.deserializeUntyped(resp.getBody())).get('error');
            if (err != null) errMsg += ': ' + err.get('message');
        } catch (Exception ex) { errMsg += ' — ' + resp.getBody().left(200); }
        throw new AIProcessingException(errMsg);
    }

    //======================================================
    // RULE-BASED FALLBACK CLAUSE
    // High-quality, context-aware, professional output.
    // Used when OpenAI Named Credential is not configured.
    //======================================================
    private static String buildRuleBasedClause(String prompt, Map<String,String> ctx) {
        String region       = ctx.get('region');
        String role         = ctx.get('role');
        String contractType = ctx.get('contractType');
        String jurisdiction = ctx.get('jurisdiction');

        String c = '';

        c += '1. Employment Terms and Duties\n';
        c += 'The Employee shall serve the Employer';
        if (String.isNotBlank(role))   c += ' in the capacity of ' + role;
        c += ' and shall diligently perform all duties and responsibilities assigned by the Employer';
        if (String.isNotBlank(region)) c += ' in accordance with the employment laws applicable in ' + region;
        c += '. The Employee agrees to devote their full professional time and effort to the role during working hours.\n\n';

        c += '2. Remuneration and Benefits\n';
        c += 'The Employee shall be entitled to compensation, benefits, and allowances as agreed upon in writing by both parties';
        if (String.isNotBlank(region)) c += ', consistent with the statutory minimums applicable in ' + region;
        c += '. Compensation shall be subject to applicable income tax, social security, and other statutory deductions.\n\n';

        c += '3. Working Hours and Leave\n';
        c += 'The Employee shall observe the standard working hours as specified by the Employer, which shall comply with ';
        c += 'applicable labour legislation. The Employee shall be entitled to annual leave, sick leave, and public holidays ';
        c += 'as prescribed by applicable law and company policy.\n\n';

        c += '4. Confidentiality and Non-Disclosure\n';
        c += 'The Employee agrees to keep strictly confidential all proprietary, technical, financial, business, and client ';
        c += 'information obtained in the course of employment. This obligation shall survive the termination of this Agreement ';
        c += 'for a period of three (3) years, unless a longer period is required by applicable law.\n\n';

        c += '5. Intellectual Property Assignment\n';
        c += 'All inventions, developments, software, designs, processes, reports, and other work product created by the ';
        c += 'Employee in the scope of employment shall be the sole and exclusive property of the Employer. The Employee ';
        c += 'hereby assigns all intellectual property rights therein to the Employer without further consideration.\n\n';

        c += '6. Data Protection';
        if (String.isNotBlank(jurisdiction)) c += ' — ' + jurisdiction;
        c += '\n';
        if (String.isNotBlank(jurisdiction) && jurisdiction.contains('GDPR')) {
            c += 'All personal data collected and processed in connection with this Agreement shall be handled in accordance ';
            c += 'with Regulation (EU) 2016/679 (GDPR). Data subjects retain the rights of access, rectification, erasure, ';
            c += 'restriction, and portability under Articles 15–20 GDPR. The Employer shall maintain a Record of Processing ';
            c += 'Activities as required by Article 30 GDPR.\n\n';
        } else if (String.isNotBlank(jurisdiction) && (jurisdiction.contains('ESIGN') || jurisdiction.contains('HIPAA'))) {
            c += 'Electronic signatures applied to this Agreement are legally valid and binding under the Electronic Signatures ';
            c += 'in Global and National Commerce Act (ESIGN Act), 15 U.S.C. § 7001 et seq. ';
            if (jurisdiction.contains('HIPAA')) {
                c += 'Any Protected Health Information (PHI) accessed or processed by the Employee shall be safeguarded in ';
                c += 'compliance with the Health Insurance Portability and Accountability Act (HIPAA) and its implementing regulations.\n\n';
            } else {
                c += 'All electronic records shall be retained and accessible in compliance with applicable US federal and state regulations.\n\n';
            }
        } else if (String.isNotBlank(jurisdiction) && jurisdiction.contains('IT Act')) {
            c += 'The parties shall implement and maintain reasonable security practices as required under the Information ';
            c += 'Technology Act, 2000 and the Information Technology (Reasonable Security Practices and Procedures and ';
            c += 'Sensitive Personal Data or Information) Rules, 2011. Data localisation requirements applicable to the ';
            c += 'Employee\'s role shall be strictly observed.\n\n';
        } else if (String.isNotBlank(jurisdiction) && jurisdiction.contains('UK GDPR')) {
            c += 'Personal data shall be processed lawfully, fairly, and transparently in accordance with the UK General ';
            c += 'Data Protection Regulation (UK GDPR) and the Data Protection Act 2018. The Employer shall maintain ';
            c += 'appropriate technical and organisational measures to protect personal data against unauthorised access, ';
            c += 'disclosure, or destruction.\n\n';
        } else {
            c += 'All personal data arising from or relating to this Agreement shall be processed in accordance with ';
            c += 'applicable international data protection standards and the Employer\'s Data Protection Policy. ';
            c += 'The Employee shall not access, use, or disclose personal data beyond what is strictly necessary for ';
            c += 'the performance of their duties.\n\n';
        }

        c += '7. Non-Competition and Non-Solicitation\n';
        c += 'During the term of employment and for a period of twelve (12) months following termination, the Employee ';
        c += 'shall not, directly or indirectly, engage in any business that competes with the Employer\'s core business, ';
        c += 'nor solicit the Employer\'s clients, customers, or employees for any competing purpose. This restriction shall ';
        c += 'apply to the extent permissible under applicable law.\n\n';

        c += '8. Termination\n';
        c += 'Either party may terminate this Agreement by providing written notice of thirty (30) days, or such longer ';
        c += 'period as required by applicable law. The Employer reserves the right to terminate this Agreement with ';
        c += 'immediate effect for cause, including but not limited to gross misconduct, material breach, or dishonesty.\n\n';

        c += '9. Governing Law and Dispute Resolution\n';
        c += 'This Agreement shall be governed by and construed in accordance with the laws of ';
        if (String.isNotBlank(region)) {
            c += region;
        } else {
            c += 'the applicable jurisdiction';
        }
        c += ', without regard to its conflict of law provisions. Any dispute arising out of or in connection with this ';
        c += 'Agreement shall first be referred to mediation. If unresolved within thirty (30) days, either party may ';
        c += 'refer the matter to binding arbitration or the competent courts of the applicable jurisdiction.\n\n';

        c += '10. Entire Agreement and Amendments\n';
        c += 'This Agreement, together with any schedules and addenda attached hereto, constitutes the entire agreement ';
        c += 'between the parties with respect to its subject matter and supersedes all prior negotiations, representations, ';
        c += 'and agreements, whether oral or written. No amendment to this Agreement shall be valid unless made in writing ';
        c += 'and signed by authorised representatives of both parties.';

        return c;
    }

    //======================================================
    // HELPER
    //======================================================
    private static AI_Model_Configuration__mdt getModelConfiguration(String modelId) {
        List<AI_Model_Configuration__mdt> configs = [
            SELECT DeveloperName, Model_Id__c, ModelName__c, Provider__c,
                   API_Endpoint__c, Max_Tokens__c, Is_Active__c,
                   Capabilities__c, Model_Provider__c
            FROM AI_Model_Configuration__mdt
            WHERE DeveloperName = :modelId LIMIT 1
        ];
        return configs.isEmpty() ? null : configs[0];
    }

    public class AIProcessingException extends Exception {}
}