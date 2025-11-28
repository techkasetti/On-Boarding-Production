public with sharing class Onb_IntakeController {
    public class ConversationDTO {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Transcript;
        @AuraEnabled public String Status;
        @AuraEnabled public Datetime StartedAt;
        @AuraEnabled public Id CandidateId;
        @AuraEnabled public String ChatFlowVersion;
    }

    /**
     * Create candidate.
     * Use null for optional params if not provided.
     */
    @AuraEnabled
    public static Candidate__c createCandidate(String name, String email, Id tenantId, String phone, String preferredLanguage) {
        Candidate__c c = new Candidate__c(Name = name);
        if (!String.isBlank(email)) c.Email__c = email;
        if (tenantId != null) c.Tenant__c = tenantId;
        if (!String.isBlank(phone)) c.Phone__c = phone;
        if (!String.isBlank(preferredLanguage)) c.Preferred_Language__c = preferredLanguage;
        // use ProfileStatus__c as per schema
        c.Status__c = 'NEW';
        insert c;
        return c;
    }

    /**
     * Start a conversation for a candidate.
     * chatFlowVersion may be null.
     */
    @AuraEnabled
    public static ConversationDTO startConversationWithFlow(Id candidateId, String chatFlowVersion) {
        Conversation__c conv = new Conversation__c();
        conv.Candidate__c = candidateId;
        conv.Transcript__c = '';
        conv.StartedAt__c = Datetime.now();
        conv.Status__c = 'OPEN';
        conv.ChatFlowVersion__c = chatFlowVersion;
        insert conv;

        System.enqueueJob(new Onb_ConversationQueueable(conv.Id));

        ConversationDTO dto = new ConversationDTO();
        dto.Id = conv.Id;
        dto.Transcript = conv.Transcript__c;
        dto.Status = conv.Status__c;
        dto.StartedAt = conv.StartedAt__c;
        dto.CandidateId = conv.Candidate__c;
        dto.ChatFlowVersion = conv.ChatFlowVersion__c;
        return dto;
    }

    /**
     * Backwards-compatible name without chatFlowVersion:
     * Call startConversationWithFlow(candidateId, null)
     */
    @AuraEnabled
    public static ConversationDTO startConversation(Id candidateId) {
        return startConversationWithFlow(candidateId, null);
    }

    /**
     * Get conversation (cacheable)
     */
    @AuraEnabled(cacheable=true)
    public static ConversationDTO getConversation(Id conversationId) {
        Conversation__c conv = [SELECT Id, Transcript__c, Status__c, StartedAt__c, Candidate__c, ChatFlowVersion__c
                                FROM Conversation__c WHERE Id = :conversationId LIMIT 1];
        ConversationDTO dto = new ConversationDTO();
        dto.Id = conv.Id;
        dto.Transcript = conv.Transcript__c;
        dto.Status = conv.Status__c;
        dto.StartedAt = conv.StartedAt__c;
        dto.CandidateId = conv.Candidate__c;
        dto.ChatFlowVersion = conv.ChatFlowVersion__c;
        return dto;
    }

    /**
     * Add message with optional channel.
     * Use null for channel to default to 'web'.
     */
    @AuraEnabled
    public static ConversationDTO addMessageWithChannel(Id conversationId, String author, String text, String channel) {
        Conversation__c conv = [SELECT Id, Transcript__c, Candidate__c, Status__c FROM Conversation__c WHERE Id = :conversationId LIMIT 1];
        String useChannel = String.isBlank(channel) ? 'web' : channel;
        conv.Transcript__c = Onb_TranscriptParser.appendMessage(conv.Transcript__c, author, text, useChannel);
        update conv;

        // Enqueue processing for background tasks
        System.enqueueJob(new Onb_ConversationQueueable(conv.Id));

        ConversationDTO dto = new ConversationDTO();
        dto.Id = conv.Id;
        dto.Transcript = conv.Transcript__c;
        dto.Status = conv.Status__c;
        dto.CandidateId = conv.Candidate__c;
        return dto;
    }

    /**
     * Backwards-compatible addMessage without channel param:
     * Call addMessageWithChannel(conversationId, author, text, null)
     */
    @AuraEnabled
    public static ConversationDTO addMessage(Id conversationId, String author, String text) {
        return addMessageWithChannel(conversationId, author, text, null);
    }
}
