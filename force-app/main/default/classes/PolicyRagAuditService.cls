public with sharing class PolicyRagAuditService {

    public class AuditInput {
        public Id candidateId;
        public String question;
        public String jurisdiction;
        public String decision;
        public Decimal confidence;
        public String citationsJson;
        public String missingInformationJson;
        public String chunksUsedJson;
        public String modelResponseJson;
        public String correlationId;
        public String requestMode;
        public String retrievalQuery;
        public Boolean success;
        public String message;
    }

    public static void logRunAsync(AuditInput input) {
        if (input == null) {
            return;
        }

        if (!Schema.sObjectType.Policy_Run_Audit__c.isCreateable()) {
            return;
        }

        System.enqueueJob(new AuditQueueable(input));
    }

    public class AuditQueueable implements Queueable {
        private AuditInput audit;

        public AuditQueueable(AuditInput input) {
            this.audit = input;
        }

        public void execute(QueueableContext context) {
            if (audit == null) {
                return;
            }

            Policy_Run_Audit__c row = new Policy_Run_Audit__c();
            row.Candidate__c = audit.candidateId;
            row.Question__c = audit.question;
            row.Jurisdiction__c = audit.jurisdiction;
            row.Decision__c = audit.decision;
            row.Confidence__c = audit.confidence;
            row.Citations__c = audit.citationsJson;
            row.Missing_Information__c = audit.missingInformationJson;
            row.Chunks_Used__c = audit.chunksUsedJson;
            row.Model_Response__c = audit.modelResponseJson;
            row.Correlation_Id__c = audit.correlationId;
            row.Request_Mode__c = String.isBlank(audit.requestMode) ? 'MANUAL_INPUT' : audit.requestMode;
            row.Retrieval_Query__c = audit.retrievalQuery;
            row.Run_Timestamp__c = System.now();
            row.Success__c = audit.success;
            row.Message__c = audit.message;

            insert row;
        }
    }
}
