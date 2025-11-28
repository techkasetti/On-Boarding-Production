public with sharing class Onb_ErrorLogService {
    public static Id logError(String context, String message, Exception ex) {
        try {
            if (!Schema.getGlobalDescribe().containsKey('Error_Log__c')) {
                System.debug(
                    'ErrorLogService: Error_Log__c missing. Context: ' +
                    context +
                    ' msg:' +
                    message
                );
                return null;
            }

            Error_Log__c e = new Error_Log__c();
            e.Name = 'err:' +
                (context == null ? 'null' : context) +
                ':' +
                String.valueOf(Datetime.now().getTime());
            e.Context__c = context;
            e.Message__c = message;

            if (ex != null) {
                e.StackTrace__c = ex.getStackTraceString();
            }

            insert e;
            return e.Id;
        } catch (Exception inner1) {
            System.debug('ErrorLogService failed: ' + inner1.getMessage());
            return null;
        }
    }

    public static Id logError(String context, String message) {
        return logError(context, message, null);
    }

    public static Id logError(String context, Exception ex) {
        return logError(context, ex == null ? null : ex.getMessage(), ex);
    }
}
