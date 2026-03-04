// =====================================================
// WORKFLOW ROUTING SERVICE
// Handles journey paths and queue assignments
// =====================================================

public with sharing class WorkflowRoutingService {
    
    public class RoutingDecision {
        @AuraEnabled public String journeyPath;
        @AuraEnabled public String queueName;
        @AuraEnabled public String assignedTo;
        @AuraEnabled public Integer escalationLevel;
        @AuraEnabled public String reason;
        @AuraEnabled public List<String> requiredActions;
        @AuraEnabled public Boolean requiresManualReview;
        @AuraEnabled public String correlationId;
        
        public RoutingDecision() {
            this.requiredActions = new List<String>();
            this.requiresManualReview = false;
            this.escalationLevel = 0;
        }
    }
    
    public static RoutingDecision determineRouting(Id candidateId, String correlationId) {
        System.debug('Determining routing for candidate: ' + candidateId);
        
        RoutingDecision decision = new RoutingDecision();
        decision.correlationId = correlationId;
        
        Candidate__c candidate = [
            SELECT Id, Name, Interested_In_Job__c, Interested_In_Job__r.Name,
                   Interested_In_Job__r.Default_Journey_Path__c
            FROM Candidate__c 
            WHERE Id = :candidateId 
            LIMIT 1
        ];
        
        List<Screening_Result__c> results = [
            SELECT Id, Outcome__c, Action__c, Details__c,
                   Screening_Rule__r.Journey_Path__c,
                   Screening_Rule__r.Route_To_Queue__c,
                   Screening_Rule__r.Escalation_Level__c,
                   Screening_Rule__r.Name
            FROM Screening_Result__c
            WHERE Candidate__c = :candidateId
            AND Correlation_Id__c = :correlationId
            ORDER BY Screening_Rule__r.Escalation_Level__c DESC NULLS LAST
        ];
        
        System.debug('Found ' + results.size() + ' screening results for routing');
        
        if (results.isEmpty()) {
            decision.reason = 'No screening results found';
            decision.queueName = 'Default Queue';
            decision.journeyPath = 'Not Defined';
            return decision;
        }
        
        Boolean hasFailures = false;
        Boolean hasReviews = false;
        Integer highestEscalation = 0;
        String primaryJourneyPath = null;
        String primaryQueue = null;
        
        for (Screening_Result__c result : results) {
            System.debug('Result: ' + result.Screening_Rule__r.Name + ' = ' + result.Outcome__c);
            
            if (result.Outcome__c == 'Fail') {
                hasFailures = true;
                decision.requiredActions.add('Review failure: ' + result.Screening_Rule__r.Name);
            }
            
            if (result.Outcome__c == 'Review') {
                hasReviews = true;
                decision.requiresManualReview = true;
                decision.requiredActions.add('Manual review: ' + result.Screening_Rule__r.Name);
            }
            
            if (result.Screening_Rule__r.Escalation_Level__c != null) {
                Integer level = result.Screening_Rule__r.Escalation_Level__c.intValue();
                if (level > highestEscalation) {
                    highestEscalation = level;
                    primaryJourneyPath = result.Screening_Rule__r.Journey_Path__c;
                    primaryQueue = result.Screening_Rule__r.Route_To_Queue__c;
                }
            }
            
            if (result.Action__c == 'RouteToJurisdiction') {
                decision.queueName = 'Jurisdiction Review Queue';
                decision.reason = 'Requires jurisdiction-specific review';
                decision.escalationLevel = 5;
                decision.journeyPath = 'Jurisdiction Review';
                return decision;
            }
        }
        
        decision.escalationLevel = highestEscalation;
        
        if (hasFailures) {
            decision.journeyPath = primaryJourneyPath != null ? primaryJourneyPath : 'Failure Review';
            decision.queueName = primaryQueue != null ? primaryQueue : 'Failure Review Queue';
            decision.reason = 'Failed one or more criteria';
        } else if (hasReviews) {
            decision.journeyPath = primaryJourneyPath != null ? primaryJourneyPath : 'Manual Review';
            decision.queueName = primaryQueue != null ? primaryQueue : 'Manual Review Queue';
            decision.reason = 'Requires manual review';
        } else {
            decision.journeyPath = primaryJourneyPath != null ? primaryJourneyPath : 
                                  (candidate.Interested_In_Job__r.Default_Journey_Path__c != null ? 
                                   candidate.Interested_In_Job__r.Default_Journey_Path__c : 
                                   'Standard Approval');
            decision.queueName = primaryQueue != null ? primaryQueue : 'Approved Candidates Queue';
            decision.reason = 'Passed all screening criteria';
        }
        
        System.debug('Routing Decision: ' + decision.journeyPath + ' -> ' + decision.queueName);
        
        return decision;
    }
    
    public static void createRoutingDecisionRecord(RoutingDecision decision, Id candidateId) {
        Routing_Decision__c record = new Routing_Decision__c();
        record.Candidate__c = candidateId;
        record.Journey_Path__c = decision.journeyPath;
        record.Assigned_Queue__c = decision.queueName;
        record.Escalation_Level__c = decision.escalationLevel;
        record.Requires_Manual_Review__c = decision.requiresManualReview;
        record.Decision_Reason__c = decision.reason;
        record.Required_Actions__c = String.join(decision.requiredActions, '\n');
        record.Correlation_Id__c = decision.correlationId;
        record.Decision_Date__c = System.now();
        record.Decision_Made_By__c = UserInfo.getUserId();
        record.Status__c = 'Pending';
        
        insert record;
    }
}