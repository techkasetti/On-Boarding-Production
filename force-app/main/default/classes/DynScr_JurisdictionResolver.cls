public with sharing class DynScr_JurisdictionResolver {

    public static String resolve(Map<String, Object> payload) {

        String country = (String) payload.get('country');
        String state = (String) payload.get('state');

        List<DynScr_Jurisdiction__mdt> rows =
            [SELECT Country__c, State__c, RoutingKey__c FROM DynScr_Jurisdiction__mdt];

        for (DynScr_Jurisdiction__mdt j : rows) {
            if (j.Country__c == country &&
                (j.State__c == null || j.State__c == state)) {
                return j.RoutingKey__c;
            }
        }
        return 'DEFAULT';
    }
}
