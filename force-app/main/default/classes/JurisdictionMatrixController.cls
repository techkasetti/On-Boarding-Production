public with sharing class JurisdictionMatrixController {

    /**
     * Load active and inactive rows (cacheable).
     */
    @AuraEnabled(cacheable=true)
    public static List<DynScr_Jurisdiction__mdt> loadMatrix(){
        // Defensive: if metadata type missing, return empty list
        if (!Schema.getGlobalDescribe().containsKey('DynScr_Jurisdiction__mdt')) return new List<DynScr_Jurisdiction__mdt>();
        // Return all records so admin UI can show Active vs Inactive
        return [SELECT Id, DeveloperName, Country__c, State__c, RoutingKey__c, Active__c, Description__c FROM DynScr_Jurisdiction__mdt ORDER BY DeveloperName];
    }

    /**
     * Upsert a jurisdiction mapping as a Custom Metadata record.
     * Returns a map: { success: Boolean, jobId: String (async), message: String }
     *
     * - country/state are normalized into a DeveloperName (e.g. US_CA)
     * - operation is done through Metadata API (async). Caller must check Deployment Status in Setup or via CLI.
     */
    @AuraEnabled
    public static Map<String,Object> upsertMatrix(String country, String state, String routingKey) {
        Map<String,Object> out = new Map<String,Object>{ 'success' => false, 'jobId' => null, 'message' => '' };

        if (String.isBlank(country) || String.isBlank(routingKey)) {
            out.put('message', 'country and routingKey are required');
            return out;
        }

        if (!Schema.getGlobalDescribe().containsKey('DynScr_Jurisdiction__mdt')) {
            out.put('message', 'Custom Metadata type DynScr_Jurisdiction__mdt not found. Deploy type first.');
            return out;
        }

        try {
            // Build developer name (safe chars)
            String devName = (country + (String.isBlank(state) ? '' : ('_' + state))).replaceAll('[^A-Za-z0-9_]', '_');

            // Construct CustomMetadata component
            String fullName = 'DynScr_Jurisdiction.' + devName;

            Metadata.CustomMetadata cm = new Metadata.CustomMetadata();
            cm.fullName = fullName;

            List<Metadata.CustomMetadataValue> vals = new List<Metadata.CustomMetadataValue>();

            Metadata.CustomMetadataValue vCountry = new Metadata.CustomMetadataValue();
            vCountry.field = 'Country__c';
            vCountry.value = country;
            vals.add(vCountry);

            Metadata.CustomMetadataValue vState = new Metadata.CustomMetadataValue();
            vState.field = 'State__c';
            vState.value = state == null ? '' : state;
            vals.add(vState);

            Metadata.CustomMetadataValue vRouting = new Metadata.CustomMetadataValue();
            vRouting.field = 'RoutingKey__c';
            vRouting.value = routingKey;
            vals.add(vRouting);

            Metadata.CustomMetadataValue vActive = new Metadata.CustomMetadataValue();
            vActive.field = 'Active__c';
            vActive.value = 'true';
            vals.add(vActive);

            // optional label
            Metadata.CustomMetadataValue vLabel = new Metadata.CustomMetadataValue();
            vLabel.field = 'Label';
            vLabel.value = devName;
            vals.add(vLabel);

            cm.values = vals;

            // enqueue
            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(cm);

            Id asyncId = Metadata.Operations.enqueueDeployment(container, null);

            out.put('success', true);
            out.put('jobId', String.valueOf(asyncId));
            out.put('message', 'Metadata deployment enqueued (create/update). Use Deployment Status in Setup to monitor.');
            return out;

        } catch (Exception ex) {
            out.put('message', 'Failed to enqueue metadata deploy: ' + ex.getMessage());
            return out;
        }
    }

    /**
     * "Delete" (soft) a Custom Metadata record: we mark Active__c = false via metadata deployment.
     * Deleting metadata records programmatically requires destructiveChanges which is painful;
     * instead we here update the Active__c flag to false so the UI/orchestrator can ignore it.
     *
     * Returns map: { success: Boolean, jobId: String|null, message: String }
     */
    @AuraEnabled
    public static Map<String,Object> deleteMatrix(String devName) {
        Map<String,Object> out = new Map<String,Object>{ 'success' => false, 'jobId' => null, 'message' => '' };

        if (String.isBlank(devName)) {
            out.put('message', 'DeveloperName is required for deletion (format: COUNTRY[_STATE])');
            return out;
        }

        if (!Schema.getGlobalDescribe().containsKey('DynScr_Jurisdiction__mdt')) {
            out.put('message', 'Custom Metadata type DynScr_Jurisdiction__mdt not found.');
            return out;
        }

        try {
            String safeDevName = devName.replaceAll('[^A-Za-z0-9_]', '_');
            String fullName = 'DynScr_Jurisdiction.' + safeDevName;

            Metadata.CustomMetadata cm = new Metadata.CustomMetadata();
            cm.fullName = fullName;

            List<Metadata.CustomMetadataValue> vals = new List<Metadata.CustomMetadataValue>();

            Metadata.CustomMetadataValue vActive = new Metadata.CustomMetadataValue();
            vActive.field = 'Active__c';
            vActive.value = 'false';
            vals.add(vActive);

            cm.values = vals;

            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(cm);

            Id asyncId = Metadata.Operations.enqueueDeployment(container, null);

            out.put('success', true);
            out.put('jobId', String.valueOf(asyncId));
            out.put('message', 'Metadata deployment enqueued (deactivate). Use Deployment Status in Setup to monitor.');
            return out;

        } catch (Exception ex) {
            out.put('message', 'Failed to enqueue deactivate deploy: ' + ex.getMessage());
            return out;
        }
    }
}
