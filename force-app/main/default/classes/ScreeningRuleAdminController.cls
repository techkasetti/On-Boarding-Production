public with sharing class ScreeningRuleAdminController {

    /**
     * Save a rule as Custom Metadata record DynScr_Rule__mdt using Metadata API (async).
     *
     * Returns:
     * { success: Boolean, jobId: String (AsyncResult Id if enqueued), message: String }
     *
     * Notes:
     * - This enqueues a metadata deployment. The deployment is asynchronous and may take a few seconds.
     * - You cannot rely on a single universal Apex call to check deployment status across ALL orgs
     *   (some orgs have different Metadata.Operations signatures). Therefore this method returns the
     *   async job id and a client can inspect Deployment Status in Setup or via CLI / tooling.
     */
    @AuraEnabled
    public static Map<String, Object> saveRule(String name, String expr, Boolean enabled) {
        Map<String, Object> out = new Map<String, Object>{
            'success' => false,
            'jobId' => null,
            'message' => ''
        };

        if (String.isBlank(name) || String.isBlank(expr)) {
            out.put('message', 'name & expression required');
            return out;
        }

        // Validate the metadata type exists in the org
        if (!Schema.getGlobalDescribe().containsKey('DynScr_Rule__mdt')) {
            out.put('message', 'Custom Metadata type DynScr_Rule__mdt not found in this org. Deploy the type first.');
            return out;
        }

        try {
            // Build the CustomMetadata component
            // fullName must be: <CustomMetadataTypeAPIName>.<DeveloperName>
            String fullName = 'DynScr_Rule.' + name.replaceAll('[^A-Za-z0-9_]', '_');

            Metadata.CustomMetadata cm = new Metadata.CustomMetadata();
            cm.fullName = fullName;

            // Build field values - store everything as strings
            List<Metadata.CustomMetadataValue> vals = new List<Metadata.CustomMetadataValue>();

            Metadata.CustomMetadataValue vExpr = new Metadata.CustomMetadataValue();
            vExpr.field = 'Expression__c';
            vExpr.value = expr;
            vals.add(vExpr);

            Metadata.CustomMetadataValue vActive = new Metadata.CustomMetadataValue();
            vActive.field = 'Active__c';
            vActive.value = (enabled == true) ? 'true' : 'false';
            vals.add(vActive);

            // Optional: set a Label value (the 'Label' field can be set via metadata value)
            Metadata.CustomMetadataValue vLabel = new Metadata.CustomMetadataValue();
            vLabel.field = 'Label';
            vLabel.value = name;
            vals.add(vLabel);

            cm.values = vals;

            // Put into DeployContainer and enqueue
            Metadata.DeployContainer container = new Metadata.DeployContainer();
            container.addMetadata(cm);

            // Enqueue the metadata deployment. This returns an AsyncResult Id in Id form.
            // This call is available in orgs that support the Apex Metadata API.
            Id asyncResultId = Metadata.Operations.enqueueDeployment(container, null);

            out.put('success', true);
            out.put('jobId', String.valueOf(asyncResultId));
            out.put('message', 'Metadata deployment enqueued. Use Deployment Status (Setup) or CLI to track the jobId.');
            return out;

        } catch (Exception ex) {
            out.put('message', 'Failed to enqueue metadata deployment: ' + ex.getMessage());
            return out;
        }
    }

    /**
     * Preview evaluation uses the existing interpreter (no DML).
     */
    @AuraEnabled
    public static Object previewRule(String expr, String payloadJson) {
        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
            Boolean matched = DynScr_RuleInterpreter.evaluate(new DynScr_Rule__mdt(Expression__c = expr), payload);
            return new Map<String, Object>{ 'matched' => matched };
        } catch (Exception ex) {
            return new Map<String, Object>{ 'error' => ex.getMessage() };
        }
    }
}