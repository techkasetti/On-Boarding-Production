public with sharing class LicenseVerificationQueueable implements Queueable, Database.AllowsCallouts {
private Id licenseVerificationId;
public LicenseVerificationQueueable(Id licenseVerificationId) {this.licenseVerificationId = licenseVerificationId;}
public void execute(QueueableContext context) {if (licenseVerificationId == null) {return;}MedicalLicenseVerificationService.verifyLicense(licenseVerificationId);}}