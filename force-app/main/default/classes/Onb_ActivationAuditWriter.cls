public with sharing class Onb_ActivationAuditWriter {
    public class Result {
        @AuraEnabled public Boolean ok;
        @AuraEnabled public Id id;
        @AuraEnabled public String message;
    }

    public static Result write(String action, String notes, Id targetId) {
        Result r = new Result();
        r.ok = false;

        try {
            if (!Schema.getGlobalDescribe().containsKey('ActivationAudit__c')) {
                r.message = 'ActivationAudit__c not present';
                return r;
            }

            ActivationAudit__c a = new ActivationAudit__c();
            a.Name = action + ':' + (targetId == null
                ? String.valueOf(Datetime.now().getTime())
                : String.valueOf(targetId));
            a.Action__c = action;
            a.Notes__c = notes;
            a.Target__c = targetId;

            insert a;

            r.ok = true;
            r.id = a.Id;
            return r;
        } catch (Exception ex) {
            Onb_ErrorLogService.logError('ActivationAuditWriter.write', ex);
            r.message = ex.getMessage();
            return r;
        }
    }
}
