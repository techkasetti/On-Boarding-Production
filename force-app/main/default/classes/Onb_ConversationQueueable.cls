public with sharing class Onb_ConversationQueueable implements Queueable, Database.AllowsCallouts {
    private Id convId;
    public Onb_ConversationQueueable(Id conversationId) {
        this.convId = conversationId;
    }

    public void execute(QueueableContext ctx) {
        try {
            Conversation__c conv = [SELECT Id, Transcript__c, Candidate__c, Status__c, ChatFlowVersion__c, Language__c, Translated_Transcript__c
                                    FROM Conversation__c WHERE Id = :convId LIMIT 1];

            // Mark processing
            conv.Status__c = 'PROCESSING';
            update conv;

            // Parse transcript messages
            List<Onb_TranscriptParser.ChatMessage> msgs = Onb_TranscriptParser.parseMessages(conv.Transcript__c);

            // 1) Language detection: if conversation doesn't have Language__c set, detect from first non-empty message
            if (String.isBlank(conv.Language__c) && msgs.size() > 0) {
                String firstText = null;
                for (Onb_TranscriptParser.ChatMessage m : msgs) {
                    if (!String.isBlank(m.text)) { firstText = m.text; break; }
                }
                if (!String.isBlank(firstText)) {
                    Onb_LanguageService.DetectResult dr = Onb_LanguageService.detectLanguage(firstText);
                    if (!String.isBlank(dr.language)) {
                        conv.Language__c = dr.language;
                    }
                }
            }

            // 2) Basic processing example: check for keyword that indicates external verification required
            Boolean needsVerify = false;
            for (Onb_TranscriptParser.ChatMessage m : msgs) {
                if (m.text != null && m.text.toLowerCase().contains('verify id')) {
                    needsVerify = true;
                    break;
                }
            }

            // 3) Optional: translate transcript for admin/tenant view if language detected and not english (tenantLang could be read from tenant settings)
            String tenantLang = 'en'; // TODO: replace with tenant/tenant settings
            if (!String.isBlank(conv.Language__c) && conv.Language__c != tenantLang) {
                // translate entire transcript (simplified approach)
                try {
                    String translated = Onb_LanguageService.translateText(conv.Transcript__c, tenantLang);
                    conv.Translated_Transcript__c = translated;
                } catch (Exception ex) {
                    // swallow translation errors; keep translated null
                }
            } else {
                // Clear any stale translation if same language
                conv.Translated_Transcript__c = null;
            }

            // 4) Finalize status
            conv.Status__c = needsVerify ? 'OPEN' : 'COMPLETED';
            update conv;

            // Hook: enqueue additional feature-specific jobs here if needed
            // e.g., System.enqueueJob(new Onb_SomeOtherFeatureQueueable(conv.Id));
        } catch (Exception ex) {
            try {
                if (convId != null) {
                    Conversation__c failureConv = new Conversation__c(Id = convId, Status__c = 'FAILED');
                    update failureConv;
                }
                // Optionally: call Onb_ErrorLogService.log(ex, ...) for observability
            } catch (Exception ignoreEx) {
                // swallow
            }
        }
    }
}
