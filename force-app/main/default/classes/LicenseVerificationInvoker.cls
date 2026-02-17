public with sharing class LicenseVerificationInvoker {
@InvocableMethod(
    label='verify medical license'
    description='Submits LicenseVerification__c records for asynchronous license verification via external API'
)
public static void submitForVerification(List<LicenseVerification__c> licenseRecords) {
    // Minimal no-op implementation just to validate the annotation compiles
    if (licenseRecords == null | licenseRecords.isEmpty()) {            return;        }
    for (LicenseVerification__c license : licenseRecords) {
        if (license.Id != null) {
            System.enqueueJob(new LicenseVerificationQueueable(license.Id));
        }

    }
}

}