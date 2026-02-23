public with sharing class LicenseNameAIService {

    // DTO for parsed AI response
    public class AiNameMatchResult {
        public String  decision;             // match | review | mismatch
        public Decimal score;                // 0.0 – 1.0
        public String  reason;               // explanation
        public Boolean requiresManualReview; // mapped from requires_manual_review
    }

    /**
     * Async entry point
     */
    @future(callout=true)
    public static void runForLicenseVerifications(Set<Id> licenseVerificationIds) {
        if (licenseVerificationIds == null || licenseVerificationIds.isEmpty()) {
            return;
        }

        Map<Id, LicenseVerification__c> lvById =
            new Map<Id, LicenseVerification__c>([
                SELECT Id,
                       Candidate__c,
                       Candidate__r.Full_Name__c,
                       Name_On_License__c
                FROM LicenseVerification__c
                WHERE Id IN :licenseVerificationIds
            ]);
            system.debug('LicenseNameAIService.runForLicenseVerifications: ' + lvById);

        if (lvById.isEmpty()) {
            return;
        }

        List<LicenseVerification__c> updates = new List<LicenseVerification__c>();

        for (LicenseVerification__c lv : lvById.values()) {

            if (lv.Candidate__c == null ||
                String.isBlank(lv.Candidate__r.Full_Name__c) ||
                String.isBlank(lv.Name_On_License__c)) {
                continue;
            }

            AiNameMatchResult aiResult =
                callAiNameValidation(lv.Candidate__r.Full_Name__c, lv.Name_On_License__c);

            LicenseVerification__c updateRec =
                new LicenseVerification__c(Id = lv.Id);

            if (aiResult != null) {
                updateRec.Name_Match_AI_Score__c    = aiResult.score;
                updateRec.Name_Match_AI_Decision__c =
                    normalizeDecisionLabel(aiResult.decision);
                updateRec.Name_Match_AI_Reason__c   = aiResult.reason;

                if (aiResult.requiresManualReview == true) {
                    updateRec.Requires_Manual_Review__c = true;
                }
            } else {
                updateRec.Name_Match_AI_Decision__c = 'Review';
                updateRec.Name_Match_AI_Reason__c =
                    'AI name validation failed or returned invalid data; manual review required.';
                updateRec.Requires_Manual_Review__c = true;
            }

            updates.add(updateRec);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    /**
     * External AI call via Named Credential
     */
    private static AiNameMatchResult callAiNameValidation(
        String profileName,
        String licenseName
    ) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                'callout:ProviderNameAI/v1/models/gemini-2.5-flash:generateContent'
            );
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('x-goog-api-key', 'AIzaSyDo8ARLUStUzL8pNo59yOimrVaj7Kx-uy8');

            String prompt =
                'You are a compliance assistant that decides whether two person names ' +
                'represent the same individual for medical license verification. ' +
                'Respond with ONLY strict JSON in this shape: ' +
                '{"decision":"match|review|mismatch","score":0.0,' +
                '"reason":"text","requires_manual_review":true|false}. ' +
                'Profile name: ' + profileName + '\n' +
                'License name: ' + licenseName;

            Map<String, Object> payload = new Map<String, Object>{
                'contents' => new List<Object>{
                    new Map<String, Object>{
                        'role'  => 'user',
                        'parts' => new List<Object>{
                            new Map<String, Object>{ 'text' => prompt }
                        }
                    }
                }
            };

            req.setBody(JSON.serialize(payload));

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                return null;
            }

            Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            System.debug('output'+ JSON.deserializeUntyped(res.getBody()));

            if (body == null || !body.containsKey('candidates')) {
                return null;
            }

            List<Object> candidates = (List<Object>) body.get('candidates');
            if (candidates.isEmpty()) {
                return null;
            }

            Map<String, Object> candidate =
                (Map<String, Object>) candidates[0];
            Map<String, Object> content =
                (Map<String, Object>) candidate.get('content');
            if (content == null || !content.containsKey('parts')) {
                return null;
            }

            List<Object> parts = (List<Object>) content.get('parts');
            if (parts.isEmpty()) {
                return null;
            }

            String rawText =
                (String) ((Map<String, Object>) parts[0]).get('text');
            if (String.isBlank(rawText)) {
                return null;
            }

            // Remove markdown fences if present
            String cleaned =
                rawText
                    .replace('```json', '')
                    .replace('```', '')
                    .trim();

            Map<String, Object> aiJson =
                (Map<String, Object>) JSON.deserializeUntyped(cleaned);

            AiNameMatchResult result = new AiNameMatchResult();
            result.decision =
                (String) aiJson.get('decision');
            result.score =
                aiJson.containsKey('score')
                    ? Decimal.valueOf(String.valueOf(aiJson.get('score')))
                    : null;
            result.reason =
                (String) aiJson.get('reason');
            result.requiresManualReview =
                aiJson.containsKey('requires_manual_review')
                    ? (Boolean) aiJson.get('requires_manual_review')
                    : false;

            return result;

        } catch (Exception e) {
            System.debug('AI name validation failed: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Normalize AI decision labels
     */
    private static String normalizeDecisionLabel(String decision) {
        if (String.isBlank(decision)) {
            return 'Review';
        }
        decision = decision.toLowerCase();
        if (decision == 'match') return 'Match';
        if (decision == 'mismatch') return 'Mismatch';
        return 'Review';
    }
}