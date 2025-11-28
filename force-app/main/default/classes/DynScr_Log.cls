public with sharing class DynScr_Log {
    public static void error(String where1, String msg) {
        System.debug(LoggingLevel.ERROR, '[DynScr][' + where1 + '] ' + msg);
    }
}
