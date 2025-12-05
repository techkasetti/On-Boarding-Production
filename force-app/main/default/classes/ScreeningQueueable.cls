public with sharing class ScreeningQueueable implements Queueable, Database.AllowsCallouts {
    public List<Id> candidateIds;
    public ScreeningQueueable(List<Id> ids) { candidateIds = ids; }

    public void execute(QueueableContext qc) {
        if (candidateIds == null || candidateIds.isEmpty()) return;
        List<EvaluateScreeningRules.Request> requests = new List<EvaluateScreeningRules.Request>();
        for (Id cid : candidateIds) {
            EvaluateScreeningRules.Request r = new EvaluateScreeningRules.Request();
            r.candidateId = cid;
            requests.add(r);
        }
        // call invocable synchronously
        EvaluateScreeningRules.run(requests);
    }
}
