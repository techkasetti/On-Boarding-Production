public with sharing class DynScr_AsyncRunner implements Queueable {

    private Id tenantId;
    private Map<String,Object> payload;

    public DynScr_AsyncRunner(Id t, Map<String,Object> p) {
        tenantId = t;
        payload = p;
    }

    public void execute(QueueableContext qc) {
        DynScr_Orchestrator.runScreening(tenantId, payload);
    }
}
