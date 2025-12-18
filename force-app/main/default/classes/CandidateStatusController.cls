public with sharing class CandidateStatusController {
    // DTO for the LWC payload
    public class CandidateStatusDto {
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public List<EvalResultDto> results;
        @AuraEnabled public Map<String, String> routingInfo;
        public CandidateStatusDto() {
            this.results = new List<EvalResultDto>();
            this.routingInfo = null;
        }
    }

    // DTO for a single result row
    public class EvalResultDto {
        @AuraEnabled public String ruleName;
        @AuraEnabled public String outcome;
        @AuraEnabled public String details;
        @AuraEnabled public String action;
        public EvalResultDto(String ruleName, String outcome, String details, String action) {
            this.ruleName = ruleName;
            this.outcome = outcome;
            this.details = details;
            this.action = action;
        }
    }

    // Main method to get status
    @AuraEnabled(cacheable=true)
    public static CandidateStatusDto getCandidateStatus(Id candidateId) {
        if (candidateId == null) { throw new AuraHandledException('Candidate ID is required.'); }
        CandidateStatusDto dto = new CandidateStatusDto();
        dto.candidateId = candidateId;

        try {
            Candidate__c c = [SELECT Id, Name FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
            dto.name = c.Name;
        } catch (Exception e) {
            throw new AuraHandledException('Could not retrieve candidate information.');
        }

        List<Screening_Result__c> latestResults = [
            SELECT Correlation_Id__c FROM Screening_Result__c
            WHERE Candidate__c = :candidateId AND Correlation_Id__c != null
            ORDER BY CreatedDate DESC LIMIT 1
        ];

        if (latestResults.isEmpty()) {
            dto.status = 'Not Yet Screened';
            return dto;
        }
        String latestCorrelationId = latestResults[0].Correlation_Id__c;

        List<Screening_Result__c> screeningResults = [
            SELECT Id, Outcome__c, Details__c, Action__c, Screening_Rule__r.Name
            FROM Screening_Result__c
            WHERE Candidate__c = :candidateId AND Correlation_Id__c = :latestCorrelationId
            ORDER BY CreatedDate DESC
        ];

        boolean hasFailures = false;
        for (Screening_Result__c res : screeningResults) {
            dto.results.add(new EvalResultDto(
                res.Screening_Rule__r.Name, res.Outcome__c, res.Details__c, res.Action__c
            ));
            if (res.Outcome__c == 'Fail' | res.Outcome__c == 'Review') {
                hasFailures = true;
            }
            if (res.Action__c == 'RouteToJurisdiction' && (res.Outcome__c == 'Fail' || res.Outcome__c == 'Review')) {
                dto.routingInfo = new Map<String, String>{
                    'queue' => 'Jurisdiction Review',
                    'notes' => 'Candidate flagged for review based on rule: ' + res.Screening_Rule__r.Name
                };
            }
        }
        dto.status = hasFailures ? 'Action Required' : 'Passed';
        return dto;
    }

    // Method to trigger the screening
    @AuraEnabled
    public static void rerunScreening(Id candidateId) {
        if (candidateId == null) { throw new AuraHandledException('Candidate ID is required.'); }

        Candidate__c candidate;
        try {
            // Using the confirmed field name
            candidate = [SELECT Id, Interested_In_Job__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1];
        } catch (QueryException e) {
            throw new AuraHandledException('Could not find the candidate record.');
        }

        if (candidate.Interested_In_Job__c == null) {
            throw new AuraHandledException('Cannot run screening: This candidate is not associated with a job posting.');
        }

        try {
            // This map correctly associates the candidate with their specific job
            Map<Id, Id> candidateToJobMap = new Map<Id, Id>{ candidate.Id => candidate.Interested_In_Job__c };
            System.enqueueJob(new ScreeningQueueable(candidateToJobMap));
        } catch (Exception e) {
            throw new AuraHandledException('Failed to start the screening process: ' + e.getMessage());
        }
    }
}
