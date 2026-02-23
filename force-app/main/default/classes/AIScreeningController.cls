// public with sharing class AIScreeningController {
    
//     /**
//      * Invocable method for AI screening
//      */
//     @InvocableMethod(label='Run AI Screening' description='Analyze candidate using Grok AI')
//     public static List<AIScreeningResult> runAIScreening(List<AIScreeningRequest> requests) {
//         List<AIScreeningResult> results = new List<AIScreeningResult>();
        
//         for (AIScreeningRequest req : requests) {
//             results.add(performAIScreening(req.candidateId, req.correlationId));
//         }
        
//         return results;
//     }
    
//     public class AIScreeningRequest {
//         @InvocableVariable(required=true)
//         public Id candidateId;
        
//         @InvocableVariable(required=false)
//         public String correlationId;
//     }
    
//     public class AIScreeningResult {
//         @InvocableVariable
//         public Boolean success;
        
//         @InvocableVariable
//         public String message;
        
//         @InvocableVariable
//         public Id resultId;
        
//         @InvocableVariable
//         public Decimal aiScore;
        
//         @InvocableVariable
//         public String recommendation;
//     }
    
//     /**
//      * AuraEnabled method for LWC
//      */
//     @AuraEnabled
//     public static Map<String, Object> runAIScreeningForCandidate(Id candidateId) {
//         try {
//             // Get latest correlation ID if exists
//             String correlationId = getLatestCorrelationId(candidateId);
            
//             AIScreeningResult result = performAIScreening(candidateId, correlationId);
            
//             return new Map<String, Object>{
//                 'success' => result.success,
//                 'message' => result.message,
//                 'resultId' => result.resultId,
//                 'aiScore' => result.aiScore,
//                 'recommendation' => result.recommendation
//             };
//         } catch (Exception e) {
//             throw new AuraHandledException('AI Screening failed: ' + e.getMessage());
//         }
//     }
    
//     /**
//      * Get latest AI screening result for a candidate
//      */
//     @AuraEnabled(cacheable=true)
//     public static AI_Screening_Result__c getLatestAIResult(Id candidateId) {
//         List<AI_Screening_Result__c> results = [
//             SELECT Id, Overall_Score__c, Confidence_Level__c, Recommendation__c,
//                    Quick_Summary__c, Full_Analysis__c, Strengths__c, Concerns__c,
//                    Traditional_Score__c, Combined_Score__c, Rules_Evaluated__c,
//                    Status__c, Execution_Time__c, CreatedDate, Top_3_Strengths__c,
//                    Top_3_Concerns__c, AI_Model__c, Correlation_Id__c
//             FROM AI_Screening_Result__c
//             WHERE Candidate__c = :candidateId
//             AND Status__c = 'Completed'
//             ORDER BY CreatedDate DESC
//             LIMIT 1
//         ];
        
//         return results.isEmpty() ? null : results[0];
//     }
    
//     /**
//      * Core AI screening logic
//      */
//     private static AIScreeningResult performAIScreening(Id candidateId, String correlationId) {
//         AIScreeningResult result = new AIScreeningResult();
//         result.success = false;
        
//         Long startTime = System.currentTimeMillis();
        
//         try {
//             // 1. Load candidate with full details
//             Candidate__c candidate = ScreeningDataLoader.loadCandidateWithAllRelations(candidateId);
            
//             // 2. Load applicable rules
//             List<Screening_Rule__c> rules = getApplicableRules(candidate);
            
//             // 3. Get traditional screening score if exists
//             Decimal traditionalScore = getTraditionalScore(candidateId, correlationId);
            
//             // 4. Build AI prompt
//             String systemPrompt = buildSystemPrompt();
//             String userPrompt = buildUserPrompt(candidate, rules, traditionalScore);
            
//             System.debug('=== AI SCREENING STARTED ===');
//             System.debug('Candidate: ' + candidate.Name);
//             System.debug('Rules to consider: ' + rules.size());
            
//             // 5. Call Grok API
//             GrokAPIService.GrokResponse apiResponse = GrokAPIService.callGrokAPI(systemPrompt, userPrompt);
            
//             if (!apiResponse.success) {
//                 result.message = 'API call failed: ' + apiResponse.errorMessage;
//                 createFailedResult(candidateId, correlationId, apiResponse.errorMessage);
//                 return result;
//             }
            
//             // 6. Parse AI response
//             String aiContent = GrokAPIService.extractContent(apiResponse);
//             AIAnalysis analysis = parseAIResponse(aiContent);
            
//             // 7. Save AI_Screening_Result__c
//             AI_Screening_Result__c aiResult = new AI_Screening_Result__c();
//             aiResult.Candidate__c = candidateId;
//             aiResult.Job_Posting__c = candidate.Interested_In_Job__c;
//             aiResult.Correlation_Id__c = correlationId;
//             aiResult.AI_Model__c = 'grok-beta';
//             aiResult.Overall_Score__c = analysis.overallScore;
//             aiResult.Confidence_Level__c = analysis.confidenceLevel;
//             aiResult.Recommendation__c = analysis.recommendation;
//             aiResult.Quick_Summary__c = analysis.quickSummary;
//             aiResult.Full_Analysis__c = analysis.fullAnalysis;
//             aiResult.Strengths__c = JSON.serialize(analysis.strengths);
//             aiResult.Concerns__c = JSON.serialize(analysis.concerns);
            
//             // FIXED: Proper subList usage with bounds checking
//             List<String> topStrengths = new List<String>();
//             if (analysis.strengths.size() > 0) {
//                 Integer strengthLimit = Math.min(3, analysis.strengths.size());
//                 for (Integer i = 0; i < strengthLimit; i++) {
//                     topStrengths.add(analysis.strengths[i]);
//                 }
//             }
//             aiResult.Top_3_Strengths__c = String.join(topStrengths, ', ');
            
//             List<String> topConcerns = new List<String>();
//             if (analysis.concerns.size() > 0) {
//                 Integer concernLimit = Math.min(3, analysis.concerns.size());
//                 for (Integer i = 0; i < concernLimit; i++) {
//                     topConcerns.add(analysis.concerns[i]);
//                 }
//             }
//             aiResult.Top_3_Concerns__c = String.join(topConcerns, ', ');
            
//             aiResult.Traditional_Score__c = traditionalScore;
//             aiResult.Rules_Evaluated__c = rules.size();
//             aiResult.Status__c = 'Completed';
//             aiResult.Execution_Time__c = System.currentTimeMillis() - startTime;
//             aiResult.Tokens_Used__c = apiResponse.usage != null ? apiResponse.usage.total_tokens : 0;
//             aiResult.Response_Raw__c = JSON.serialize(apiResponse);
//             aiResult.Prompt_Version__c = 'v1.0';
            
//             insert aiResult;
            
//             result.success = true;
//             result.message = 'AI screening completed successfully';
//             result.resultId = aiResult.Id;
//             result.aiScore = analysis.overallScore;
//             result.recommendation = analysis.recommendation;
            
//             System.debug('AI Screening completed: Score=' + analysis.overallScore + 
//                         ', Recommendation=' + analysis.recommendation);
            
//         } catch (Exception e) {
//             result.message = 'Exception: ' + e.getMessage();
//             System.debug('ERROR in AI Screening: ' + e.getMessage());
//             System.debug('Stack trace: ' + e.getStackTraceString());
//             createFailedResult(candidateId, correlationId, e.getMessage());
//         }
        
//         return result;
//     }
    
//     /**
//      * Build system prompt for Grok
//      */
//     private static String buildSystemPrompt() {
//         return 'You are an expert healthcare recruitment AI assistant specializing in candidate evaluation. ' +
//                'Your role is to analyze healthcare candidates against job requirements and screening rules. ' +
//                'Provide structured, objective assessments focusing on qualifications, experience, and fit. ' +
//                'Always respond in valid JSON format with the following structure:\n\n' +
//                '{\n' +
//                '  "overallScore": [number 0-100],\n' +
//                '  "confidenceLevel": "[Very High|High|Medium|Low]",\n' +
//                '  "recommendation": "[STRONGLY_RECOMMEND|RECOMMEND|NEUTRAL|NOT_RECOMMEND|STRONGLY_NOT_RECOMMEND]",\n' +
//                '  "quickSummary": "[2-3 sentence executive summary]",\n' +
//                '  "fullAnalysis": "[detailed analysis text]",\n' +
//                '  "strengths": ["strength 1", "strength 2", ...],\n' +
//                '  "concerns": ["concern 1", "concern 2", ...]\n' +
//                '}\n\n' +
//                'Be thorough, fair, and evidence-based in your analysis.';
//     }
    
//     /**
//      * Build user prompt with candidate data
//      */
//     private static String buildUserPrompt(Candidate__c candidate, List<Screening_Rule__c> rules, Decimal traditionalScore) {
//         String prompt = 'Please analyze this healthcare candidate:\n\n';
        
//         // Candidate basics
//         prompt += '=== CANDIDATE PROFILE ===\n';
//         prompt += 'Name: ' + candidate.Name + '\n';
        
//         // FIXED: Proper type handling for Years_of_Experience__c
//         if (candidate.Years_of_Experience__c != null) {
//             prompt += 'Years of Experience: ' + String.valueOf(candidate.Years_of_Experience__c) + '\n';
//         } else {
//             prompt += 'Years of Experience: Not specified\n';
//         }
        
//         prompt += 'Location: ' + (candidate.Location__c != null ? candidate.Location__c : 'Not specified') + '\n\n';
        
//         // Licenses & Certifications
//         if (candidate.License_Certifications__r != null && !candidate.License_Certifications__r.isEmpty()) {
//             prompt += '=== LICENSES & CERTIFICATIONS ===\n';
//             for (License_Certification__c lic : candidate.License_Certifications__r) {
//                 prompt += '- ' + lic.Name + ' (' + lic.Type__c + ')';
//                 if (lic.Expiry_Date__c != null) {
//                     prompt += ' - Expires: ' + String.valueOf(lic.Expiry_Date__c);
//                 }
//                 prompt += '\n';
//             }
//             prompt += '\n';
//         }
        
//         // Education
//         if (candidate.Educations__r != null && !candidate.Educations__r.isEmpty()) {
//             prompt += '=== EDUCATION ===\n';
//             for (Education__c edu : candidate.Educations__r) {
//                 prompt += '- ' + edu.Degree__c + ' from ' + edu.Institution__c;
//                 if (edu.End_Year__c != null) {
//                     prompt += ' (' + edu.End_Year__c + ')';
//                 }
//                 prompt += '\n';
//             }
//             prompt += '\n';
//         }
        
//         // Work Experience
//         if (candidate.Work_Experiences__r != null && !candidate.Work_Experiences__r.isEmpty()) {
//             prompt += '=== WORK EXPERIENCE ===\n';
//             for (Work_Experience__c exp : candidate.Work_Experiences__r) {
//                 prompt += '- ' + exp.Role__c + ' at ' + exp.Organization__c;
//                 if (exp.Duration_Text__c != null) {
//                     prompt += ' (' + exp.Duration_Text__c + ')';
//                 }
//                 prompt += '\n';
//             }
//             prompt += '\n';
//         }
        
//         // Clinical Skills
//         if (candidate.Clinical_Skills__r != null && !candidate.Clinical_Skills__r.isEmpty()) {
//             prompt += '=== CLINICAL SKILLS ===\n';
//             for (Clinical_Skill__c skill : candidate.Clinical_Skills__r) {
//                 prompt += '- ' + skill.Name;
//                 if (skill.Skill_Type__c != null) {
//                     prompt += ' (' + skill.Skill_Type__c + ')';
//                 }
//                 prompt += '\n';
//             }
//             prompt += '\n';
//         }
        
//         // Screening Rules
//         if (rules != null && !rules.isEmpty()) {
//             prompt += '=== JOB REQUIREMENTS (Screening Rules) ===\n';
//             for (Screening_Rule__c rule : rules) {
//                 prompt += '- ' + rule.Name + ': ';
//                 prompt += 'Check ' + rule.Field_API_Name__c + ' ' + rule.Operator__c + ' "' + rule.Expected_Value__c + '"\n';
//             }
//             prompt += '\n';
//         }
        
//         // Traditional score
//         if (traditionalScore != null) {
//             prompt += '=== TRADITIONAL RULE-BASED SCORE ===\n';
//             prompt += 'Pass Rate: ' + traditionalScore.setScale(1) + '%\n\n';
//         }
        
//         prompt += 'Please provide your comprehensive AI-powered analysis in the JSON format specified.';
        
//         return prompt;
//     }
    
//     /**
//      * Parse AI response into structured data
//      */
//     private static AIAnalysis parseAIResponse(String content) {
//         AIAnalysis analysis = new AIAnalysis();
        
//         try {
//             // Try to parse as JSON
//             Map<String, Object> jsonData = (Map<String, Object>) JSON.deserializeUntyped(content);
            
//             analysis.overallScore = jsonData.containsKey('overallScore') ? 
//                                    Decimal.valueOf(String.valueOf(jsonData.get('overallScore'))) : 50.0;
//             analysis.confidenceLevel = jsonData.containsKey('confidenceLevel') ? 
//                                       (String) jsonData.get('confidenceLevel') : 'Medium';
//             analysis.recommendation = jsonData.containsKey('recommendation') ? 
//                                      (String) jsonData.get('recommendation') : 'NEUTRAL';
//             analysis.quickSummary = jsonData.containsKey('quickSummary') ? 
//                                    (String) jsonData.get('quickSummary') : '';
//             analysis.fullAnalysis = jsonData.containsKey('fullAnalysis') ? 
//                                    (String) jsonData.get('fullAnalysis') : content;
            
//             // Parse arrays
//             if (jsonData.containsKey('strengths')) {
//                 List<Object> strengthsList = (List<Object>) jsonData.get('strengths');
//                 for (Object s : strengthsList) {
//                     analysis.strengths.add(String.valueOf(s));
//                 }
//             }
            
//             if (jsonData.containsKey('concerns')) {
//                 List<Object> concernsList = (List<Object>) jsonData.get('concerns');
//                 for (Object c : concernsList) {
//                     analysis.concerns.add(String.valueOf(c));
//                 }
//             }
            
//         } catch (Exception e) {
//             // Fallback: treat as plain text
//             System.debug('Could not parse as JSON, using fallback');
//             analysis.overallScore = 50.0;
//             analysis.confidenceLevel = 'Low';
//             analysis.recommendation = 'NEUTRAL';
//             analysis.fullAnalysis = content;
            
//             // FIXED: Safe substring
//             if (content != null && content.length() > 500) {
//                 analysis.quickSummary = content.substring(0, 500);
//             } else if (content != null) {
//                 analysis.quickSummary = content;
//             } else {
//                 analysis.quickSummary = '';
//             }
//         }
        
//         return analysis;
//     }
    
//     /**
//      * Helper: Get applicable rules for candidate
//      */
//     private static List<Screening_Rule__c> getApplicableRules(Candidate__c candidate) {
//         if (candidate.Interested_In_Job__c == null) {
//             return new List<Screening_Rule__c>();
//         }
        
//         return [
//             SELECT Name, Target_Object__c, Field_API_Name__c, Operator__c, 
//                    Expected_Value__c, Rule_Category__c
//             FROM Screening_Rule__c
//             WHERE Applied_Role__c = :candidate.Interested_In_Job__c
//             AND Active__c = true
//             AND Is_Current_Version__c = true
//             ORDER BY Priority__c ASC
//             LIMIT 50
//         ];
//     }
    
//     /**
//      * Helper: Get traditional screening score
//      * FIXED: Calculate pass count in Apex since CASE expressions not supported in SOQL
//      */
//     private static Decimal getTraditionalScore(Id candidateId, String correlationId) {
//         if (String.isBlank(correlationId)) {
//             List<Screening_Result__c> latestResults = [
//                 SELECT Correlation_Id__c
//                 FROM Screening_Result__c
//                 WHERE Candidate__c = :candidateId
//                 ORDER BY CreatedDate DESC
//                 LIMIT 1
//             ];
            
//             if (latestResults.isEmpty()) return null;
//             correlationId = latestResults[0].Correlation_Id__c;
//         }
        
//         // FIXED: Query all results and calculate in code
//         List<Screening_Result__c> results = [
//             SELECT Outcome__c
//             FROM Screening_Result__c
//             WHERE Candidate__c = :candidateId
//             AND Correlation_Id__c = :correlationId
//         ];
        
//         if (results.isEmpty()) return null;
        
//         Integer total = results.size();
//         Integer passed = 0;
        
//         for (Screening_Result__c result : results) {
//             if (result.Outcome__c == 'Pass') {
//                 passed++;
//             }
//         }
        
//         return (Decimal.valueOf(passed) / Decimal.valueOf(total)) * 100;
//     }
    
//     /**
//      * Helper: Get latest correlation ID
//      */
//     private static String getLatestCorrelationId(Id candidateId) {
//         List<Screening_Result__c> results = [
//             SELECT Correlation_Id__c
//             FROM Screening_Result__c
//             WHERE Candidate__c = :candidateId
//             ORDER BY CreatedDate DESC
//             LIMIT 1
//         ];
        
//         return results.isEmpty() ? null : results[0].Correlation_Id__c;
//     }
    
//     /**
//      * Helper: Create failed result record
//      */
//     private static void createFailedResult(Id candidateId, String correlationId, String errorMessage) {
//         try {
//             AI_Screening_Result__c failedResult = new AI_Screening_Result__c();
//             failedResult.Candidate__c = candidateId;
//             failedResult.Correlation_Id__c = correlationId;
//             failedResult.Status__c = 'Failed';
//             failedResult.Error_Message__c = errorMessage;
//             failedResult.AI_Model__c = 'grok-beta';
//             insert failedResult;
//         } catch (Exception e) {
//             System.debug('Could not create failed result record: ' + e.getMessage());
//         }
//     }
    
//     /**
//      * Inner class for parsing AI response
//      */
//     private class AIAnalysis {
//         public Decimal overallScore;
//         public String confidenceLevel;
//         public String recommendation;
//         public String quickSummary;
//         public String fullAnalysis;
//         public List<String> strengths;
//         public List<String> concerns;
        
//         public AIAnalysis() {
//             this.strengths = new List<String>();
//             this.concerns = new List<String>();
//         }
//     }
// }

// =====================================================
// AI SCREENING CONTROLLER - UPDATED WITH BALANCED PROMPTS
// Gemini AI-powered candidate screening
// =====================================================
public with sharing class AIScreeningController {
    
    @InvocableMethod(label='Run AI Screening' description='Analyze candidate using Gemini AI')
    public static List<AIScreeningResult> runAIScreening(List<AIScreeningRequest> requests) {
        List<AIScreeningResult> results = new List<AIScreeningResult>();
        for (AIScreeningRequest req : requests) {
            results.add(performAIScreening(req.candidateId, req.correlationId, null, null));
        }
        return results;
    }
    
    public class AIScreeningRequest {
        @InvocableVariable(required=true)
        public Id candidateId;
        
        @InvocableVariable(required=false)
        public String correlationId;
    }
    
    public class AIScreeningResult {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
        @InvocableVariable public Id resultId;
        @InvocableVariable public Decimal aiScore;
        @InvocableVariable public String recommendation;
    }
    
    @AuraEnabled
public static Map<String, Object> runAIScreeningForCandidate(
    Id candidateId,
    Id jobApplicationId  
) {
    try {
        // Resolve jobPostingId from jobApplicationId upfront
        Id jobPostingId = null;
        if (jobApplicationId != null) {
            List<Job_Application__c> jobApps = [
                SELECT Job_Posting__c
                FROM Job_Application__c
                WHERE Id = :jobApplicationId
                LIMIT 1
            ];
            if (!jobApps.isEmpty()) {
                jobPostingId = jobApps[0].Job_Posting__c;
            }
        }

        // 🔥 FIX: Check if active rules exist for this job BEFORE calling AI
        if (jobPostingId != null) {
            List<Screening_Rule__c> activeRules = [
                SELECT Id 
                FROM Screening_Rule__c
                WHERE Applied_Role__c     = :jobPostingId
                AND Active__c             = true
                AND Is_Current_Version__c = true
                AND (Test_Mode_Only__c    = false OR Test_Mode_Only__c = null)
                LIMIT 1
            ];

            if (activeRules.isEmpty()) {
                throw new AuraHandledException(
                    'No active screening rules are defined for this job posting. AI screening requires at least one rule to evaluate against.'
                );
            }
        }

        // Get correlation ID filtered by the correct job posting
        String correlationId = jobPostingId != null
            ? getCorrelationIdByJobPosting(candidateId, jobPostingId)
            : getLatestCorrelationId(candidateId);

        AIScreeningResult result = performAIScreening(
            candidateId,
            correlationId,
            jobApplicationId,
            jobPostingId
        );

        return new Map<String, Object>{
            'success'        => result.success,
            'message'        => result.message,
            'resultId'       => result.resultId,
            'aiScore'        => result.aiScore,
            'recommendation' => result.recommendation
        };

    } catch (AuraHandledException e) {
        throw e; // Re-throw AuraHandledExceptions as-is so message reaches UI
    } catch (Exception e) {
        throw new AuraHandledException('AI Screening failed: ' + e.getMessage());
    }
}
    // 🔥 RENAMED & FIXED: Get correlation by Job Posting ID directly
    private static String getCorrelationIdByJobPosting(Id candidateId, Id jobPostingId) {
        try {
            List<Screening_Result__c> results = [
                SELECT Correlation_Id__c
                FROM Screening_Result__c
                WHERE Candidate__c     = :candidateId
                AND Job_Posting__c     = :jobPostingId
                AND Correlation_Id__c != null
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (!results.isEmpty()) {
                return results[0].Correlation_Id__c;
            }

            // Fallback to latest only if no job-specific result exists
            return getLatestCorrelationId(candidateId);

        } catch (Exception e) {
            System.debug('getCorrelationIdByJobPosting error: ' + e.getMessage());
            return getLatestCorrelationId(candidateId);
        }
    }

    // Keep old method for backward compatibility with Flow invocable
    private static String getCorrelationIdByJobApp(Id candidateId, Id jobApplicationId) {
        try {
            Job_Application__c jobApp = [
                SELECT Job_Posting__c
                FROM Job_Application__c
                WHERE Id = :jobApplicationId
                LIMIT 1
            ];

            if (jobApp.Job_Posting__c == null) {
                return getLatestCorrelationId(candidateId);
            }

            return getCorrelationIdByJobPosting(candidateId, jobApp.Job_Posting__c);

        } catch (Exception e) {
            System.debug('getCorrelationIdByJobApp error: ' + e.getMessage());
            return getLatestCorrelationId(candidateId);
        }
    }

    @AuraEnabled(cacheable=true)
    public static AI_Screening_Result__c getLatestAIResult(Id candidateId, Id jobApplicationId) {

        Id jobPostingId = null;
        if (jobApplicationId != null) {
            List<Job_Application__c> jobApps = [
                SELECT Job_Posting__c 
                FROM Job_Application__c 
                WHERE Id = :jobApplicationId 
                LIMIT 1
            ];
            if (!jobApps.isEmpty()) {
                jobPostingId = jobApps[0].Job_Posting__c;
            }
        }

        List<AI_Screening_Result__c> results;

        if (jobPostingId != null) {
            // 🔥 FIX: Now works correctly because save also uses jobPostingId
            results = [
                SELECT Id, Overall_Score__c, Confidence_Level__c, Recommendation__c,
                       Quick_Summary__c, Full_Analysis__c, Strengths__c, Concerns__c,
                       Traditional_Score__c, Combined_Score__c, Rules_Evaluated__c,
                       Status__c, Execution_Time__c, CreatedDate, Top_3_Strengths__c,
                       Top_3_Concerns__c, AI_Model__c, Correlation_Id__c
                FROM AI_Screening_Result__c
                WHERE Candidate__c  = :candidateId
                AND Job_Posting__c  = :jobPostingId
                AND Status__c       = 'Completed'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        } else {
            results = [
                SELECT Id, Overall_Score__c, Confidence_Level__c, Recommendation__c,
                       Quick_Summary__c, Full_Analysis__c, Strengths__c, Concerns__c,
                       Traditional_Score__c, Combined_Score__c, Rules_Evaluated__c,
                       Status__c, Execution_Time__c, CreatedDate, Top_3_Strengths__c,
                       Top_3_Concerns__c, AI_Model__c, Correlation_Id__c
                FROM AI_Screening_Result__c
                WHERE Candidate__c = :candidateId
                AND Status__c      = 'Completed'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        }

        return results.isEmpty() ? null : results[0];
    }

    private static List<Screening_Rule__c> getApplicableRulesByJobPosting(Id jobPostingId) {
        try {
            if (jobPostingId == null) return new List<Screening_Rule__c>();

            return [
                SELECT Name, Target_Object__c, Field_API_Name__c, 
                       Operator__c, Expected_Value__c, Rule_Category__c
                FROM Screening_Rule__c
                WHERE Applied_Role__c     = :jobPostingId
                AND Active__c             = true
                AND Is_Current_Version__c = true
                ORDER BY Priority__c ASC
                LIMIT 50
            ];
        } catch (Exception e) {
            System.debug('getApplicableRulesByJobPosting error: ' + e.getMessage());
            return new List<Screening_Rule__c>();
        }
    }

    private static List<Screening_Rule__c> getApplicableRulesByJobApp(Id jobApplicationId) {
        try {
            Job_Application__c jobApp = [
                SELECT Job_Posting__c
                FROM Job_Application__c
                WHERE Id = :jobApplicationId
                LIMIT 1
            ];

            if (jobApp.Job_Posting__c == null) return new List<Screening_Rule__c>();

            return getApplicableRulesByJobPosting(jobApp.Job_Posting__c);

        } catch (Exception e) {
            System.debug('getApplicableRulesByJobApp error: ' + e.getMessage());
            return new List<Screening_Rule__c>();
        }
    }

    // 🔥 FIX: Added jobPostingId parameter — used to correctly save Job_Posting__c on result
    private static AIScreeningResult performAIScreening(
        Id candidateId, 
        String correlationId, 
        Id jobApplicationId,
        Id jobPostingId        // 🔥 NEW param
    ) {
        AIScreeningResult result = new AIScreeningResult();
        result.success = false;
        
        Long startTime = System.currentTimeMillis();
        
        try {
            Candidate__c candidate = ScreeningDataLoader.loadCandidateWithAllRelations(candidateId);

            // 🔥 FIX: Use jobPostingId to get rules — most accurate source
            List<Screening_Rule__c> rules;
            if (jobPostingId != null) {
                rules = getApplicableRulesByJobPosting(jobPostingId);
            } else if (jobApplicationId != null) {
                rules = getApplicableRulesByJobApp(jobApplicationId);
            } else {
                rules = getApplicableRules(candidate);
            }

            Decimal traditionalScore = getTraditionalScore(candidateId, correlationId);
            
            String systemPrompt  = buildSystemPrompt();
            String userPrompt    = buildUserPrompt(candidate, rules, traditionalScore);
            String combinedPrompt = systemPrompt + '\n\n' + userPrompt;

            System.debug('=== AI SCREENING STARTED ===');
            System.debug('Candidate: ' + candidate.Name);
            System.debug('Rules to consider: ' + rules.size());
            System.debug('Job Posting ID: ' + jobPostingId);

            GeminiAPIService.GeminiResponse apiResponse = GeminiAPIService.callGeminiAPI(
                combinedPrompt, 
                'gemini-2.0-flash-exp'
            );
            
            if (!apiResponse.success) {
                result.message = 'API call failed: ' + apiResponse.errorMessage;
                createFailedResult(candidateId, correlationId, jobPostingId, apiResponse.errorMessage);
                return result;
            }
            
            String aiContent = GeminiAPIService.extractContent(apiResponse);
            
            System.debug('=== RAW AI RESPONSE ===');
            System.debug(aiContent);
            
            AIAnalysis analysis = parseAIResponse(aiContent);
            
            System.debug('=== PARSED ANALYSIS ===');
            System.debug('Score: '          + analysis.overallScore);
            System.debug('Recommendation: ' + analysis.recommendation);
            System.debug('Confidence: '     + analysis.confidenceLevel);
            System.debug('Strengths count: ' + analysis.strengths.size());
            System.debug('Concerns count: '  + analysis.concerns.size());
            
            AI_Screening_Result__c aiResult = new AI_Screening_Result__c();
            aiResult.Candidate__c      = candidateId;

            // 🔥 FIX: Save the CORRECT job posting — use jobPostingId if available,
            //         otherwise fall back to candidate's default job
            aiResult.Job_Posting__c    = jobPostingId != null 
                                         ? jobPostingId 
                                         : candidate.Interested_In_Job__c;

            aiResult.Correlation_Id__c    = correlationId;
            aiResult.AI_Model__c          = 'gemini-2.0-flash-exp';
            aiResult.Overall_Score__c     = analysis.overallScore;
            aiResult.Confidence_Level__c  = analysis.confidenceLevel;
            aiResult.Recommendation__c    = analysis.recommendation;
            aiResult.Quick_Summary__c     = analysis.quickSummary;
            aiResult.Full_Analysis__c     = analysis.fullAnalysis;
            aiResult.Strengths__c         = JSON.serialize(analysis.strengths);
            aiResult.Concerns__c          = JSON.serialize(analysis.concerns);
            
            List<String> topStrengths = new List<String>();
            Integer strengthLimit = Math.min(3, analysis.strengths.size());
            for (Integer i = 0; i < strengthLimit; i++) {
                topStrengths.add(analysis.strengths[i]);
            }
            aiResult.Top_3_Strengths__c = String.join(topStrengths, ', ');
            
            List<String> topConcerns = new List<String>();
            Integer concernLimit = Math.min(3, analysis.concerns.size());
            for (Integer i = 0; i < concernLimit; i++) {
                topConcerns.add(analysis.concerns[i]);
            }
            aiResult.Top_3_Concerns__c = String.join(topConcerns, ', ');
            
            aiResult.Traditional_Score__c = traditionalScore;
            aiResult.Rules_Evaluated__c   = rules.size();
            aiResult.Status__c            = 'Completed';
            aiResult.Execution_Time__c    = System.currentTimeMillis() - startTime;
            aiResult.Tokens_Used__c       = apiResponse.usageMetadata != null 
                                            ? apiResponse.usageMetadata.totalTokenCount : 0;
            aiResult.Response_Raw__c      = JSON.serialize(apiResponse);
            aiResult.Prompt_Version__c    = 'v1.1';
            
            insert aiResult;
            
            result.success        = true;
            result.message        = 'AI screening completed successfully';
            result.resultId       = aiResult.Id;
            result.aiScore        = analysis.overallScore;
            result.recommendation = analysis.recommendation;
            
            System.debug('AI Screening completed: Score=' + analysis.overallScore + 
                        ', Recommendation=' + analysis.recommendation +
                        ', Job_Posting__c saved=' + aiResult.Job_Posting__c);
            
        } catch (Exception e) {
            result.message = 'Exception: ' + e.getMessage();
            System.debug('ERROR in AI Screening: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            createFailedResult(candidateId, correlationId, jobPostingId, e.getMessage());
        }
        
        return result;
    }
    
    private static String buildSystemPrompt() {
        return 'You are an expert healthcare recruitment AI assistant specializing in candidate evaluation. ' +
               'Your role is to analyze healthcare candidates against job requirements and screening rules. ' +
               'Provide structured, objective assessments focusing on qualifications, experience, and fit. ' +
               '\n\n' +
               '**IMPORTANT GUIDELINES:**\n' +
               '- Use "STRONGLY_RECOMMEND" or "STRONGLY_NOT_RECOMMEND" ONLY for exceptional cases (top 10% or bottom 10%)\n' +
               '- Most candidates should receive "RECOMMEND", "NEUTRAL", or "NOT_RECOMMEND"\n' +
               '- "High" or "Very High" confidence should be reserved for clear-cut cases with strong evidence\n' +
               '- If you have doubts or missing information, use "Medium" confidence and "NEUTRAL" recommendation\n' +
               '- Balance is key: highlight BOTH strengths AND concerns for every candidate\n' +
               '- Confidence indicates certainty of analysis, NOT candidate quality\n' +
               '  Example: High confidence + NOT_RECOMMEND = Very sure candidate does not fit\n' +
               '\n\n' +
               'Always respond in valid JSON format with the following structure:\n\n' +
               '{\n' +
               '  "overallScore": [number 0-100],\n' +
               '  "confidenceLevel": "Very High" | "High" | "Medium" | "Low",\n' +
               '  "recommendation": "STRONGLY_RECOMMEND" | "RECOMMEND" | "NEUTRAL" | "NOT_RECOMMEND" | "STRONGLY_NOT_RECOMMEND",\n' +
               '  "quickSummary": "[2-3 sentence executive summary]",\n' +
               '  "fullAnalysis": "[detailed analysis text]",\n' +
               '  "strengths": ["strength 1", "strength 2", ...],\n' +
               '  "concerns": ["concern 1", "concern 2", ...]\n' +
               '}\n\n' +
               'CRITICAL: Use ONLY these exact values:\n' +
               '- confidenceLevel: "Very High", "High", "Medium", or "Low" (NOT "Very Low")\n' +
               '- recommendation: "STRONGLY_RECOMMEND", "RECOMMEND", "NEUTRAL", "NOT_RECOMMEND", or "STRONGLY_NOT_RECOMMEND"\n\n' +
               'Be thorough, fair, and evidence-based in your analysis. Avoid extreme recommendations unless clearly warranted.';
    }
    
    private static String buildUserPrompt(Candidate__c candidate, List<Screening_Rule__c> rules, Decimal traditionalScore) {
        String prompt = 'Please analyze this healthcare candidate:\n\n';
        
        prompt += '=== CANDIDATE PROFILE ===\n';
        prompt += 'Name: ' + candidate.Name + '\n';
        
        if (candidate.Years_of_Experience__c != null) {
            prompt += 'Years of Experience: ' + String.valueOf(candidate.Years_of_Experience__c) + '\n';
        } else {
            prompt += 'Years of Experience: Not specified\n';
        }
        
        prompt += 'Location: ' + (candidate.Location__c != null ? candidate.Location__c : 'Not specified') + '\n\n';
        
        if (candidate.License_Certifications__r != null && !candidate.License_Certifications__r.isEmpty()) {
            prompt += '=== LICENSES & CERTIFICATIONS ===\n';
            for (License_Certification__c lic : candidate.License_Certifications__r) {
                prompt += '- ' + lic.Name + ' (' + lic.Type__c + ')';
                if (lic.Expiry_Date__c != null) {
                    prompt += ' - Expires: ' + String.valueOf(lic.Expiry_Date__c);
                }
                prompt += '\n';
            }
            prompt += '\n';
        }
        
        if (candidate.Educations__r != null && !candidate.Educations__r.isEmpty()) {
            prompt += '=== EDUCATION ===\n';
            for (Education__c edu : candidate.Educations__r) {
                prompt += '- ' + edu.Degree__c + ' from ' + edu.Institution__c;
                if (edu.End_Year__c != null) {
                    prompt += ' (' + edu.End_Year__c + ')';
                }
                prompt += '\n';
            }
            prompt += '\n';
        }
        
        if (candidate.Work_Experiences__r != null && !candidate.Work_Experiences__r.isEmpty()) {
            prompt += '=== WORK EXPERIENCE ===\n';
            for (Work_Experience__c exp : candidate.Work_Experiences__r) {
                prompt += '- ' + exp.Role__c + ' at ' + exp.Organization__c;
                if (exp.Duration_Text__c != null) {
                    prompt += ' (' + exp.Duration_Text__c + ')';
                }
                prompt += '\n';
            }
            prompt += '\n';
        }
        
        if (candidate.Clinical_Skills__r != null && !candidate.Clinical_Skills__r.isEmpty()) {
            prompt += '=== CLINICAL SKILLS ===\n';
            for (Clinical_Skill__c skill : candidate.Clinical_Skills__r) {
                prompt += '- ' + skill.Name;
                if (skill.Skill_Type__c != null) {
                    prompt += ' (' + skill.Skill_Type__c + ')';
                }
                prompt += '\n';
            }
            prompt += '\n';
        }
        
        if (rules != null && !rules.isEmpty()) {
            prompt += '=== JOB REQUIREMENTS (Screening Rules) ===\n';
            for (Screening_Rule__c rule : rules) {
                prompt += '- ' + rule.Name + ': ';
                prompt += 'Check ' + rule.Field_API_Name__c + ' ' + rule.Operator__c + ' "' + rule.Expected_Value__c + '"\n';
            }
            prompt += '\n';
        }
        
        if (traditionalScore != null) {
            prompt += '=== TRADITIONAL RULE-BASED SCORE ===\n';
            prompt += 'Pass Rate: ' + traditionalScore.setScale(1) + '%\n\n';
        }
        
        prompt += 'Please provide your comprehensive AI-powered analysis in the JSON format specified.';
        
        return prompt;
    }
    
    private static AIAnalysis parseAIResponse(String content) {
        AIAnalysis analysis = new AIAnalysis();
        
        try {
            String cleanContent = content;
            
            if (cleanContent.contains('```json')) {
                cleanContent = cleanContent.substringAfter('```json').trim();
                if (cleanContent.contains('```')) {
                    cleanContent = cleanContent.substringBefore('```').trim();
                }
            } else if (cleanContent.contains('```')) {
                cleanContent = cleanContent.substringAfter('```').trim();
                if (cleanContent.contains('```')) {
                    cleanContent = cleanContent.substringBefore('```').trim();
                }
            }
            
            Map<String, Object> jsonData = (Map<String, Object>) JSON.deserializeUntyped(cleanContent);
            
            if (jsonData.containsKey('overallScore')) {
                Object scoreObj = jsonData.get('overallScore');
                if (scoreObj instanceof Integer) {
                    analysis.overallScore = Decimal.valueOf((Integer) scoreObj);
                } else if (scoreObj instanceof Decimal) {
                    analysis.overallScore = (Decimal) scoreObj;
                } else {
                    analysis.overallScore = Decimal.valueOf(String.valueOf(scoreObj));
                }
            } else {
                analysis.overallScore = 50.0;
            }
            
            analysis.confidenceLevel = jsonData.containsKey('confidenceLevel')
                ? normalizeConfidenceLevel((String) jsonData.get('confidenceLevel'))
                : 'Medium';
            
            analysis.recommendation = jsonData.containsKey('recommendation')
                ? normalizeRecommendation((String) jsonData.get('recommendation'))
                : 'NEUTRAL';
            
            analysis.quickSummary = jsonData.containsKey('quickSummary') 
                ? (String) jsonData.get('quickSummary') : '';
            
            analysis.fullAnalysis = jsonData.containsKey('fullAnalysis') 
                ? (String) jsonData.get('fullAnalysis') : content;
            
            if (jsonData.containsKey('strengths')) {
                for (Object s : (List<Object>) jsonData.get('strengths')) {
                    analysis.strengths.add(String.valueOf(s));
                }
            }
            
            if (jsonData.containsKey('concerns')) {
                for (Object c : (List<Object>) jsonData.get('concerns')) {
                    analysis.concerns.add(String.valueOf(c));
                }
            }
            
        } catch (Exception e) {
            System.debug('Could not parse as JSON: ' + e.getMessage());
            analysis.overallScore    = 50.0;
            analysis.confidenceLevel = 'Low';
            analysis.recommendation  = 'NEUTRAL';
            analysis.fullAnalysis    = content;
            analysis.quickSummary    = content != null && content.length() > 500 
                                       ? content.substring(0, 500) + '...' 
                                       : (content != null ? content : 'No summary available');
        }
        
        return analysis;
    }
    
    private static String normalizeRecommendation(String rawRecommendation) {
        if (String.isBlank(rawRecommendation)) return 'NEUTRAL';
        
        String normalized = rawRecommendation.trim().toUpperCase();
        Set<String> validValues = new Set<String>{
            'STRONGLY_RECOMMEND', 'RECOMMEND', 'NEUTRAL', 
            'NOT_RECOMMEND', 'STRONGLY_NOT_RECOMMEND'
        };
        
        if (validValues.contains(normalized)) return normalized;
        
        if (normalized.contains('STRONGLY') && normalized.contains('RECOMMEND') && !normalized.contains('NOT')) {
            return 'STRONGLY_RECOMMEND';
        } else if (normalized.contains('STRONGLY') && (normalized.contains('NOT') || normalized.contains('REJECT'))) {
            return 'STRONGLY_NOT_RECOMMEND';
        } else if (normalized.contains('NOT') && normalized.contains('RECOMMEND')) {
            return 'NOT_RECOMMEND';
        } else if (normalized.contains('RECOMMEND')) {
            return 'RECOMMEND';
        } else if (normalized.contains('NEUTRAL') || normalized.contains('MAYBE')) {
            return 'NEUTRAL';
        }
        
        return 'NEUTRAL';
    }
    
    private static String normalizeConfidenceLevel(String rawConfidence) {
        if (String.isBlank(rawConfidence)) return 'Medium';
        
        String normalized = rawConfidence.trim();
        Set<String> validValues = new Set<String>{'Very High', 'High', 'Medium', 'Low'};
        
        if (validValues.contains(normalized)) return normalized;
        
        String lower = normalized.toLowerCase();
        if (lower.contains('very high') || lower.contains('veryhigh') || lower.contains('excellent')) {
            return 'Very High';
        } else if (lower.contains('high') || lower.contains('strong')) {
            return 'High';
        } else if (lower.contains('low')) {
            return 'Low';
        } else if (lower.contains('medium') || lower.contains('moderate') || lower.contains('average')) {
            return 'Medium';
        }
        
        return 'Medium';
    }
    
    private static List<Screening_Rule__c> getApplicableRules(Candidate__c candidate) {
        if (candidate.Interested_In_Job__c == null) return new List<Screening_Rule__c>();
        
        return [
            SELECT Name, Target_Object__c, Field_API_Name__c, Operator__c, 
                   Expected_Value__c, Rule_Category__c
            FROM Screening_Rule__c
            WHERE Applied_Role__c     = :candidate.Interested_In_Job__c
            AND Active__c             = true
            AND Is_Current_Version__c = true
            ORDER BY Priority__c ASC
            LIMIT 50
        ];
    }
    
    private static Decimal getTraditionalScore(Id candidateId, String correlationId) {
        if (String.isBlank(correlationId)) {
            List<Screening_Result__c> latestResults = [
                SELECT Correlation_Id__c
                FROM Screening_Result__c
                WHERE Candidate__c = :candidateId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (latestResults.isEmpty()) return null;
            correlationId = latestResults[0].Correlation_Id__c;
        }
        
        List<Screening_Result__c> results = [
            SELECT Outcome__c
            FROM Screening_Result__c
            WHERE Candidate__c    = :candidateId
            AND Correlation_Id__c = :correlationId
        ];
        
        if (results.isEmpty()) return null;
        
        Integer total  = results.size();
        Integer passed = 0;
        for (Screening_Result__c res : results) {
            if (res.Outcome__c == 'Pass') passed++;
        }
        
        return (Decimal.valueOf(passed) / Decimal.valueOf(total)) * 100;
    }
    
    private static String getLatestCorrelationId(Id candidateId) {
        List<Screening_Result__c> results = [
            SELECT Correlation_Id__c
            FROM Screening_Result__c
            WHERE Candidate__c = :candidateId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0].Correlation_Id__c;
    }
    
    // 🔥 FIX: Added jobPostingId param so failed result also saves correct Job_Posting__c
    private static void createFailedResult(Id candidateId, String correlationId, Id jobPostingId, String errorMessage) {
        try {
            AI_Screening_Result__c failedResult = new AI_Screening_Result__c();
            failedResult.Candidate__c      = candidateId;
            failedResult.Job_Posting__c    = jobPostingId; // 🔥 FIXED
            failedResult.Correlation_Id__c = correlationId;
            failedResult.Status__c         = 'Failed';
            failedResult.Error_Message__c  = errorMessage;
            failedResult.AI_Model__c       = 'gemini-2.0-flash-exp';
            insert failedResult;
        } catch (Exception e) {
            System.debug('Could not create failed result record: ' + e.getMessage());
        }
    }
    
    private class AIAnalysis {
        public Decimal overallScore;
        public String confidenceLevel;
        public String recommendation;
        public String quickSummary;
        public String fullAnalysis;
        public List<String> strengths;
        public List<String> concerns;
        
        public AIAnalysis() {
            this.strengths = new List<String>();
            this.concerns  = new List<String>();
        }
    }
}