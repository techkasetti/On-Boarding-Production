// /**
//  * SignatureRequestController
//  * All fields verified against describe output on DocumentLifecycleConfiguration__c
//  */
// public with sharing class SignatureRequestController {

//     // ══════════════════════════════════════════════════════════════
//     // CONFIRMED FIELDS ON DocumentLifecycleConfiguration__c:
//     //   id, ownerid, isdeleted, name, createddate, createdbyid,
//     //   lastmodifieddate, lastmodifiedbyid, systemmodstamp,
//     //   lastvieweddate, lastreferenceddate,
//     //   clauses__c (TEXTAREA), createdby__c (STRING),
//     //   createddate__c (DATETIME), created_date__c (DATETIME),
//     //   employee_name__c (STRING), name__c (STRING),
//     //   region__c (PICKLIST), role__c (PICKLIST),
//     //   signature_request__c (REFERENCE), status__c (STRING),
//     //   company_name__c (STRING), clause__c (TEXTAREA),
//     //   contract_type__c (STRING), documenttitle__c (STRING),
//     //   template__c (STRING), position__c (STRING),
//     //   address__c (TEXTAREA), department__c (STRING),
//     //   effective_date__c (DATE), expiry_date__c (DATE),
//     //   additional_notes__c (TEXTAREA), jurisdiction_label__c (STRING),
//     //   candidate__c (REFERENCE)
//     // ══════════════════════════════════════════════════════════════

//     // ★ READ accessor — used for all SOQL queries in the signing flow
//     private without sharing class GuestAccessor {

//         public Signature_Request__c getRequest(String requestId) {
//             List<Signature_Request__c> rows = [
//                 SELECT Id, Status__c, SignerName__c, Candidate__c,
//                        Document_Lifecycle_Configuration__c
//                 FROM Signature_Request__c
//                 WHERE Id = :requestId
//                 LIMIT 1
//             ];
//             return rows.isEmpty() ? null : rows[0];
//         }

//         public String getFaceToken(String candidateId) {
//             List<Candidate__c> rows = [
//                 SELECT Id, Face_Token__c, Face_Token_Status__c
//                 FROM Candidate__c
//                 WHERE Id = :candidateId
//                 LIMIT 1
//             ];
//             if (rows.isEmpty()) {
//                 throw new AuraHandledException('Candidate record not found.');
//             }
//             Candidate__c c = rows[0];
//             if (String.isBlank(c.Face_Token__c)) {
//                 throw new AuraHandledException(
//                     'No profile photo found. Please upload a profile photo before signing.'
//                 );
//             }
//             if (c.Face_Token_Status__c == 'Failed') {
//                 throw new AuraHandledException(
//                     'Your profile photo could not be processed. Please re-upload your photo.'
//                 );
//             }
//             if (c.Face_Token_Status__c == 'Pending') {
//                 throw new AuraHandledException(
//                     'Profile photo is still being processed. Please wait a moment and try again.'
//                 );
//             }
//             return c.Face_Token__c;
//         }

//         public Signature_Request__c getRequestForSubmit(String requestId) {
//             List<Signature_Request__c> rows = [
//                 SELECT Id,
//                        SignerEmail__c,
//                        Candidate__c,
//                        SignerName__c,
//                        CreatedDate__c,
//                        Fraud_Rules_To_Run__c,
//                        Status__c,
//                        Document_Lifecycle_Configuration__c,
//                        Document_Lifecycle_Configuration__r.Id,
//                        Document_Lifecycle_Configuration__r.Name,
//                        Document_Lifecycle_Configuration__r.Name__c,
//                        Document_Lifecycle_Configuration__r.DocumentTitle__c,
//                        Document_Lifecycle_Configuration__r.Template__c,
//                        Document_Lifecycle_Configuration__r.Employee_Name__c,
//                        Document_Lifecycle_Configuration__r.Company_Name__c,
//                        Document_Lifecycle_Configuration__r.Position__c,
//                        Document_Lifecycle_Configuration__r.Department__c,
//                        Document_Lifecycle_Configuration__r.Address__c,
//                        Document_Lifecycle_Configuration__r.Additional_Notes__c,
//                        Document_Lifecycle_Configuration__r.Effective_Date__c,
//                        Document_Lifecycle_Configuration__r.Expiry_Date__c,
//                        Document_Lifecycle_Configuration__r.Region__c,
//                        Document_Lifecycle_Configuration__r.Role__c,
//                        Document_Lifecycle_Configuration__r.Contract_Type__c,
//                        Document_Lifecycle_Configuration__r.Jurisdiction_Label__c,
//                        Document_Lifecycle_Configuration__r.Clause__c,
//                        Document_Lifecycle_Configuration__r.Clauses__c
//                 FROM Signature_Request__c
//                 WHERE Id = :requestId
//                 LIMIT 1
//             ];
//             return rows.isEmpty() ? null : rows[0];
//         }

//         public Signature_Request__c getRequestForFraud(String requestId) {
//             List<Signature_Request__c> rows = [
//                 SELECT Id, SignerEmail__c, IPAddress__c,
//                        IP_Country__c, IP_Country_Code__c, IP_Region_Name__c, IP_City__c,
//                        SigningLocation__c, Time_To_Complete_Seconds__c,
//                        CompletedDate__c, Fraud_Rules_To_Run__c
//                 FROM Signature_Request__c
//                 WHERE Id = :requestId
//                 LIMIT 1
//             ];
//             return rows.isEmpty() ? null : rows[0];
//         }

//         public DocumentLifecycleConfiguration__c getDocument(String documentId) {
//             List<DocumentLifecycleConfiguration__c> rows = [
//                 SELECT Id,
//                        Name,
//                        Name__c,
//                        DocumentTitle__c,
//                        Template__c,
//                        Clause__c,
//                        Clauses__c,
//                        Region__c,
//                        Role__c,
//                        Contract_Type__c,
//                        Jurisdiction_Label__c,
//                        Employee_Name__c,
//                        Company_Name__c,
//                        Position__c,
//                        Department__c,
//                        Address__c,
//                        Additional_Notes__c,
//                        Effective_Date__c,
//                        Expiry_Date__c,
//                        Status__c,
//                        Candidate__c
//                 FROM DocumentLifecycleConfiguration__c
//                 WHERE Id = :documentId
//                 LIMIT 1
//             ];
//             return rows.isEmpty() ? null : rows[0];
//         }

//         public List<Signature_Request__c> getSignatureRequestsForDoc(String documentId) {
//             return [
//                 SELECT Id, SignerName__c, SignerEmail__c,
//                        Status__c, CreatedDate__c, CompletedDate__c
//                 FROM Signature_Request__c
//                 WHERE Document_Lifecycle_Configuration__c = :documentId
//                 ORDER BY CreatedDate__c DESC
//             ];
//         }
//     }

//     // ★ NEW — WRITE accessor
//     // The Experience Cloud / guest user does not have edit rights on
//     // Signature_Request__c or DocumentLifecycleConfiguration__c through the
//     // normal sharing model.  All DML inside submitSignature is delegated here
//     // so it runs without sharing checks, exactly as GuestAccessor already does
//     // for SOQL queries.
//     private without sharing class GuestWriter {

//         // Update the main request record (status, sig data, geo fields, etc.)
//         public void updateRequest(Signature_Request__c req) {
//             System.debug('[GuestWriter] updateRequest — Id: ' + req.Id + ' | Status: ' + req.Status__c);
//             update req;
//         }

//         // Flip the document status to SIGNED
//         public void updateDocumentStatus(Id documentId, String status) {
//             System.debug('[GuestWriter] updateDocumentStatus — documentId: ' + documentId + ' | status: ' + status);
//             update new DocumentLifecycleConfiguration__c(Id = documentId, Status__c = status);
//         }

//         // Persist fraud analysis results back onto the request
//         public void updateFraudFields(Signature_Request__c fu) {
//             System.debug('[GuestWriter] updateFraudFields — Id: ' + fu.Id
//                 + ' | riskLevel: ' + fu.Fraud_Risk_Level__c
//                 + ' | score: '     + fu.Fraud_Score__c);
//             update fu;
//         }
//     }

//     // ══════════════════════════════════════════════════════════════
//     // GET SIGNATURE REQUEST
//     // ══════════════════════════════════════════════════════════════
//     @AuraEnabled(cacheable=true)
//     public static Signature_Request__c getSignatureRequest(String requestId) {
//         if (String.isBlank(requestId)) {
//             throw new AuraHandledException('Invalid access.');
//         }
//         Signature_Request__c req = new GuestAccessor().getRequest(requestId);
//         if (req == null) {
//             throw new AuraHandledException('Invalid or expired signing link.');
//         }
//         return req;
//     }

//     // ══════════════════════════════════════════════════════════════
//     // LOG SIGNATURE VIEWED
//     // ══════════════════════════════════════════════════════════════
//     @AuraEnabled
//     public static void logSignatureViewed(Id requestId) {
//         AuditTrailManager.logSignatureActivity(
//             requestId, 'Signature Viewed', 'SUCCESS', 'Signer opened the document'
//         );
//     }

//     // ══════════════════════════════════════════════════════════════
//     // INITIATE SIGNATURE REQUEST
//     // ══════════════════════════════════════════════════════════════
//     @AuraEnabled
//     public static String initiateSignatureRequest(
//         String documentId, String signerEmail,
//         String signerName, List<String> activeToggles
//     ) {
//         try {
//             String rules = (activeToggles != null && !activeToggles.isEmpty())
//                 ? String.join(activeToggles, ';') : null;

//             DocumentLifecycleConfiguration__c doc = [
//                 SELECT Candidate__c FROM DocumentLifecycleConfiguration__c
//                 WHERE Id = :documentId LIMIT 1
//             ];

//             Signature_Request__c newRequest = new Signature_Request__c(
//                 Document_Lifecycle_Configuration__c = documentId,
//                 Candidate__c                        = doc.Candidate__c,
//                 SignerEmail__c                      = signerEmail,
//                 SignerName__c                       = signerName,
//                 Status__c                           = 'Pending',
//                 CreatedDate__c                      = DateTime.now(),
//                 Fraud_Rules_To_Run__c               = rules
//             );
//             insert newRequest;
//             EmailNotificationService.sendSignatureRequest(newRequest.Id);
//             update new DocumentLifecycleConfiguration__c(Id = documentId, Status__c = 'SENT');
//             AuditTrailManager.logDocumentActivity(
//                 newRequest.Document_Lifecycle_Configuration__c, 'Signature Requested',
//                 'Request sent to ' + signerName + ' <' + signerEmail + '>'
//             );
//             return newRequest.Id;
//         } catch (Exception e) {
//             throw new AuraHandledException('Failed to create signature request: ' + e.getMessage());
//         }
//     }

//     // ══════════════════════════════════════════════════════════════
//     // SEND REMINDER EMAIL
//     // ══════════════════════════════════════════════════════════════
//     @AuraEnabled
//     public static void sendReminderEmail(String documentId) {
//         try {
//             List<Signature_Request__c> requests = [
//                 SELECT Id, SignerEmail__c, SignerName__c, Status__c
//                 FROM Signature_Request__c
//                 WHERE Document_Lifecycle_Configuration__c = :documentId
//                   AND Status__c IN ('Pending', 'Sent')
//                 ORDER BY CreatedDate DESC LIMIT 1
//             ];
//             if (requests.isEmpty()) {
//                 throw new AuraHandledException('No active signature request found.');
//             }
//             EmailNotificationService.sendSignatureRequest(requests[0].Id);
//             AuditTrailManager.logDocumentActivity(
//                 documentId, 'Reminder Email Sent',
//                 'Reminder sent to ' + requests[0].SignerName__c + ' <' + requests[0].SignerEmail__c + '>'
//             );
//         } catch (AuraHandledException e) {
//             throw e;
//         } catch (Exception e) {
//             throw new AuraHandledException('Failed to send reminder: ' + e.getMessage());
//         }
//     }

//     // ══════════════════════════════════════════════════════════════
//     // SUBMIT SIGNATURE
//     // ══════════════════════════════════════════════════════════════
//     @AuraEnabled
//     public static String submitSignature(
//         String requestId,
//         String signatureData,
//         String signatureMethod,
//         String userContextJSON
//     ) {
//         System.debug('submitSignature called — requestId: ' + requestId);
//         try {
//             GuestAccessor accessor = new GuestAccessor();
//             // ★ NEW: writer handles all DML without sharing restrictions
//             GuestWriter   writer   = new GuestWriter();

//             Signature_Request__c request = accessor.getRequestForSubmit(requestId);
//             if (request == null) {
//                 throw new AuraHandledException('Signature request not found. Please use a valid signing link.');
//             }
//             if (request.Status__c == 'Signed' || request.Status__c == 'Completed') {
//                 throw new AuraHandledException('This document has already been signed.');
//             }

//             System.debug('submitSignature — request found, Status: ' + request.Status__c);

//             // Parse context
//             Map<String, Object> contextMap =
//                 (Map<String, Object>) JSON.deserializeUntyped(userContextJSON);
//             String clientIp   = (String) contextMap.get('ip');
//             String location   = (String) contextMap.get('location');
//             String rulesToRun = request.Fraud_Rules_To_Run__c;

//             if (rulesToRun != null && rulesToRun.contains('IP_ANOMALY')) {
//                 request.IPAddress__c = clientIp;
//             }
//             if (rulesToRun != null && rulesToRun.contains('LOCATION_ANOMALY')) {
//                 request.SigningLocation__c = location;
//                 if (String.isNotBlank(clientIp)) {
//                     Map<String, String> geo = getGeoFromIp(clientIp);
//                     if (geo != null) {
//                         request.IP_Country__c      = geo.get('country');
//                         request.IP_Country_Code__c = geo.get('countryCode');
//                         request.IP_Region_Code__c  = geo.get('region');
//                         request.IP_Region_Name__c  = geo.get('regionName');
//                         request.IP_City__c         = geo.get('city');
//                     }
//                 }
//             }
//             if (rulesToRun != null && rulesToRun.contains('BEHAVIORAL_ANOMALY')) {
//                 if (contextMap.containsKey('timeToSign')) {
//                     request.Time_To_Complete_Seconds__c = (Decimal) contextMap.get('timeToSign');
//                 }
//             }

//             request.Status__c          = 'Signed';
//             request.CompletedDate__c   = DateTime.now();
//             request.SignatureData__c   = signatureData;
//             request.SignatureMethod__c = signatureMethod;

//             System.debug('submitSignature — calling writer.updateRequest');
//             // ★ FIX: delegate update to GuestWriter (without sharing) instead of
//             //   calling update directly in this with sharing context, which caused
//             //   INSUFFICIENT_ACCESS_OR_READONLY for the guest/community user.
//             writer.updateRequest(request);
//             System.debug('submitSignature — writer.updateRequest done');

//             System.debug('submitSignature — calling writer.updateDocumentStatus');
//             writer.updateDocumentStatus(request.Document_Lifecycle_Configuration__c, 'SIGNED');
//             System.debug('submitSignature — writer.updateDocumentStatus done');

//             // Fraud check — non-blocking
//             try {
//                 Signature_Request__c reqFraud = accessor.getRequestForFraud(request.Id);
//                 if (reqFraud != null) {
//                     FraudDetectionRulesEngine.FraudAnalysisResult fr =
//                         FraudDetectionRulesEngine.runSelectedChecks(reqFraud);
//                     Signature_Request__c fu = new Signature_Request__c(Id = request.Id);
//                     fu.Fraud_Risk_Level__c       = (fr != null) ? fr.riskLevel : 'LOW';
//                     fu.Fraud_Score__c            = (fr != null) ? fr.overallRiskScore : 0;
//                     fu.Fraud_Analysis_Details__c = (fr != null && fr.reasons != null && !fr.reasons.isEmpty())
//                         ? String.join(fr.reasons, '; ') : 'No anomalies detected';
//                     // ★ FIX: also use writer for fraud update
//                     writer.updateFraudFields(fu);
//                 }
//             } catch (Exception fraudEx) {
//                 System.debug('Fraud check non-blocking error: ' + fraudEx.getMessage());
//             }

//             AuditTrailManager.logSignatureCompletion(request.Id, signatureMethod);

//             // Build document HTML
//             DocumentLifecycleConfiguration__c doc = request.Document_Lifecycle_Configuration__r;
//             String clauseHtml = '';
//             if (String.isNotBlank(doc.Clauses__c)) {
//                 clauseHtml = doc.Clauses__c;
//             } else if (String.isNotBlank(doc.Clause__c)) {
//                 clauseHtml = doc.Clause__c;
//             }

//             String fullDocHtml = EmailNotificationService.buildProfessionalDocHtml(
//                 doc, clauseHtml, request.Id
//             );

//             // Build signature HTML block
//             String signatureHtml = '';
//             if (signatureMethod == 'Type') {
//                 signatureHtml =
//                     '<div style="font-family:\'Dancing Script\',cursive,Georgia,serif;'
//                     + 'font-size:28px;color:#0f172a;padding-bottom:2px;line-height:1.2;">'
//                     + signatureData + '</div>';
//             } else if (signatureMethod == 'Draw') {
//                 signatureHtml =
//                     '<img src="' + signatureData + '" alt="Signature" '
//                     + 'style="max-height:52px;max-width:240px;object-fit:contain;display:block;" />';
//             } else if (signatureMethod == 'Upload') {
//                 String fileIdStr = signatureData.substringAfterLast('/');
//                 List<ContentVersion> cvList = String.valueOf(fileIdStr).startsWith('068')
//                     ? [SELECT VersionData FROM ContentVersion WHERE Id = :fileIdStr LIMIT 1]
//                     : [SELECT VersionData FROM ContentVersion
//                        WHERE ContentDocumentId = :fileIdStr ORDER BY CreatedDate DESC LIMIT 1];
//                 if (!cvList.isEmpty()) {
//                     signatureHtml =
//                         '<img src="data:image/png;base64,'
//                         + EncodingUtil.base64Encode(cvList[0].VersionData)
//                         + '" alt="Signature" '
//                         + 'style="max-height:52px;max-width:240px;object-fit:contain;display:block;" />';
//                 }
//             }

//             String signedDocHtml  = fullDocHtml.replace('SIGNATURE_BLOCK_EMPLOYEE', signatureHtml);
//             String signedFullPage =
//                 '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"/>'
//                 + '<meta name="viewport" content="width=device-width,initial-scale=1.0"/>'
//                 + '<title>Signed Document</title><style>'
//                 + '*{box-sizing:border-box;margin:0;padding:0}'
//                 + 'body{background:#e8ecf0;padding:32px 16px;font-family:Georgia,serif}'
//                 + '@media print{body{background:#fff;padding:0}}'
//                 + '</style></head><body>' + signedDocHtml + '</body></html>';

//             // S3 upload — non-blocking
//             try {
//                 String safeName = String.isNotBlank(request.SignerEmail__c)
//                     ? request.SignerEmail__c.replaceAll('[^a-zA-Z0-9]', '_') : 'Signer';
//                 String s3Key = 'SignedDocument-' + safeName + '-' + DateTime.now().getTime() + '.html';
//                 S3Uploaderesign.uploadFileToS3Async('esign-signed-documents-kt', s3Key, Blob.valueOf(signedFullPage));
//                 AuditTrailManager.logDocumentActivity(
//                     request.Document_Lifecycle_Configuration__c,
//                     'Signed Document Uploaded',
//                     'Uploaded to S3 for ' + request.SignerEmail__c
//                 );
//             } catch (Exception s3Ex) {
//                 System.debug('S3 upload non-blocking error: ' + s3Ex.getMessage());
//             }

//             // Completion email — non-blocking
//             try {
//                 EmailNotificationService.sendSigningCompletedEmail(
//                     request.SignerEmail__c, request.SignerName__c, request.Id, signedDocHtml
//                 );
//             } catch (Exception emailEx) {
//                 System.debug('Completion email non-blocking error: ' + emailEx.getMessage());
//             }

//             System.debug('submitSignature SUCCESS for: ' + requestId);
//             return 'SUCCESS';

//         } catch (AuraHandledException e) {
//             throw e;
//         } catch (Exception e) {
//             System.debug('submitSignature FATAL: ' + e.getMessage() + '\n' + e.getStackTraceString());
//             throw new AuraHandledException('Signature submission failed: ' + e.getMessage());
//         }
//     }

//     // ══════════════════════════════════════════════════════════════
//     // GET DOCUMENT DATA
//     // ══════════════════════════════════════════════════════════════
//     @AuraEnabled(cacheable=true)
//     public static DocumentData getDocumentData(String documentId) {
//         System.debug('getDocumentData — documentId: ' + documentId);
//         if (String.isBlank(documentId)) {
//             throw new AuraHandledException('Document ID is required.');
//         }

//         GuestAccessor accessor = new GuestAccessor();
//         DocumentData data = new DocumentData();

//         data.document = accessor.getDocument(documentId);
//         if (data.document == null) {
//             throw new AuraHandledException('Document not found for ID: ' + documentId);
//         }

//         if (String.isNotBlank(data.document.Clauses__c)) {
//             data.renderedContent = data.document.Clauses__c;
//         } else if (String.isNotBlank(data.document.Clause__c)) {
//             data.renderedContent = data.document.Clause__c;
//         }

//         data.signatureRequests = accessor.getSignatureRequestsForDoc(documentId);

//         System.debug('getDocumentData — name: ' + data.document.Name
//             + ' | clause length: ' + (data.renderedContent != null ? data.renderedContent.length() : 0)
//             + ' | requests: ' + data.signatureRequests.size());

//         return data;
//     }

//     // ══════════════════════════════════════════════════════════════
//     // GET CANDIDATE FACE TOKEN
//     // ══════════════════════════════════════════════════════════════
//     @AuraEnabled(cacheable=false)
//     public static String getCandidateFaceToken(String candidateId) {
//         if (String.isBlank(candidateId)) {
//             throw new AuraHandledException('Candidate ID is required.');
//         }
//         return new GuestAccessor().getFaceToken(candidateId);
//     }

//     // ══════════════════════════════════════════════════════════════
//     // HELPERS
//     // ══════════════════════════════════════════════════════════════
//     private static Map<String, String> getGeoFromIp(String ip) {
//         Map<String, String> g = new Map<String, String>{
//             'country' => 'Unknown', 'countryCode' => null,
//             'region'  => null,      'regionName'  => null, 'city' => null
//         };
//         if (String.isBlank(ip) || ip == '127.0.0.1') return g;
//         try {
//             HttpRequest req = new HttpRequest();
//             req.setEndpoint('callout:IP_Geolocation_Service/json/' + ip);
//             req.setMethod('GET');
//             req.setTimeout(4000);
//             HttpResponse res = new Http().send(req);
//             if (res.getStatusCode() == 200) {
//                 Map<String, Object> r = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
//                 g.put('country',     (String) r.get('country'));
//                 g.put('countryCode', (String) r.get('countryCode'));
//                 g.put('region',      (String) r.get('region'));
//                 g.put('regionName',  (String) r.get('regionName'));
//                 g.put('city',        (String) r.get('city'));
//             }
//         } catch (Exception e) {
//             System.debug('Geo lookup failed: ' + e.getMessage());
//         }
//         return g;
//     }

//     // ══════════════════════════════════════════════════════════════
//     // WRAPPER
//     // ══════════════════════════════════════════════════════════════
//     public class DocumentData {
//         @AuraEnabled public DocumentLifecycleConfiguration__c document;
//         @AuraEnabled public List<Signature_Request__c>        signatureRequests;
//         @AuraEnabled public String                            renderedContent;
//     }
// }

/**
 * SignatureRequestController
 * All fields verified against describe output on DocumentLifecycleConfiguration__c
 */
public with sharing class SignatureRequestController {

    private without sharing class GuestAccessor {

        public Signature_Request__c getRequest(String requestId) {
            List<Signature_Request__c> rows = [
                SELECT Id, Status__c, SignerName__c, Candidate__c,
                       Document_Lifecycle_Configuration__c
                FROM Signature_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }

        public String getFaceToken(String candidateId) {
            List<Candidate__c> rows = [
                SELECT Id, Face_Token__c, Face_Token_Status__c
                FROM Candidate__c
                WHERE Id = :candidateId
                LIMIT 1
            ];
            if (rows.isEmpty()) {
                throw new AuraHandledException('Candidate record not found.');
            }
            Candidate__c c = rows[0];
            if (String.isBlank(c.Face_Token__c)) {
                throw new AuraHandledException(
                    'No profile photo found. Please upload a profile photo before signing.'
                );
            }
            if (c.Face_Token_Status__c == 'Failed') {
                throw new AuraHandledException(
                    'Your profile photo could not be processed. Please re-upload your photo.'
                );
            }
            if (c.Face_Token_Status__c == 'Pending') {
                throw new AuraHandledException(
                    'Profile photo is still being processed. Please wait a moment and try again.'
                );
            }
            return c.Face_Token__c;
        }

        public Signature_Request__c getRequestForSubmit(String requestId) {
            List<Signature_Request__c> rows = [
                SELECT Id,
                       SignerEmail__c,
                       Candidate__c,
                       SignerName__c,
                       CreatedDate__c,
                       Fraud_Rules_To_Run__c,
                       Status__c,
                       Document_Lifecycle_Configuration__c,
                       Document_Lifecycle_Configuration__r.Id,
                       Document_Lifecycle_Configuration__r.Name,
                       Document_Lifecycle_Configuration__r.Name__c,
                       Document_Lifecycle_Configuration__r.DocumentTitle__c,
                       Document_Lifecycle_Configuration__r.Template__c,
                       Document_Lifecycle_Configuration__r.Employee_Name__c,
                       Document_Lifecycle_Configuration__r.Company_Name__c,
                       Document_Lifecycle_Configuration__r.Position__c,
                       Document_Lifecycle_Configuration__r.Department__c,
                       Document_Lifecycle_Configuration__r.Address__c,
                       Document_Lifecycle_Configuration__r.Additional_Notes__c,
                       Document_Lifecycle_Configuration__r.Effective_Date__c,
                       Document_Lifecycle_Configuration__r.Expiry_Date__c,
                       Document_Lifecycle_Configuration__r.Region__c,
                       Document_Lifecycle_Configuration__r.Role__c,
                       Document_Lifecycle_Configuration__r.Contract_Type__c,
                       Document_Lifecycle_Configuration__r.Jurisdiction_Label__c,
                       Document_Lifecycle_Configuration__r.Clause__c,
                       Document_Lifecycle_Configuration__r.Clauses__c
                FROM Signature_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }

        public Signature_Request__c getRequestForFraud(String requestId) {
            List<Signature_Request__c> rows = [
                SELECT Id, SignerEmail__c, IPAddress__c,
                       IP_Country__c, IP_Country_Code__c, IP_Region_Name__c, IP_City__c,
                       SigningLocation__c, Time_To_Complete_Seconds__c,
                       CompletedDate__c, Fraud_Rules_To_Run__c
                FROM Signature_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }

        public DocumentLifecycleConfiguration__c getDocument(String documentId) {
            List<DocumentLifecycleConfiguration__c> rows = [
                SELECT Id,
                       Name,
                       Name__c,
                       DocumentTitle__c,
                       Template__c,
                       Clause__c,
                       Clauses__c,
                       Region__c,
                       Role__c,
                       Contract_Type__c,
                       Jurisdiction_Label__c,
                       Employee_Name__c,
                       Company_Name__c,
                       Position__c,
                       Department__c,
                       Address__c,
                       Additional_Notes__c,
                       Effective_Date__c,
                       Expiry_Date__c,
                       Status__c,
                       Candidate__c
                FROM DocumentLifecycleConfiguration__c
                WHERE Id = :documentId
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }

        public List<Signature_Request__c> getSignatureRequestsForDoc(String documentId) {
            return [
                SELECT Id, SignerName__c, SignerEmail__c,
                       Status__c, CreatedDate__c, CompletedDate__c
                FROM Signature_Request__c
                WHERE Document_Lifecycle_Configuration__c = :documentId
                ORDER BY CreatedDate__c DESC
            ];
        }
    }

    private without sharing class GuestWriter {

        public void updateRequest(Signature_Request__c req) {
            System.debug('[GuestWriter] updateRequest — Id: ' + req.Id + ' | Status: ' + req.Status__c);
            update req;
        }

        public void updateDocumentStatus(Id documentId, String status) {
            System.debug('[GuestWriter] updateDocumentStatus — documentId: ' + documentId + ' | status: ' + status);
            update new DocumentLifecycleConfiguration__c(Id = documentId, Status__c = status);
        }

        public void updateFraudFields(Signature_Request__c fu) {
            System.debug('[GuestWriter] updateFraudFields — Id: ' + fu.Id
                + ' | riskLevel: ' + fu.Fraud_Risk_Level__c
                + ' | score: '     + fu.Fraud_Score__c);
            update fu;
        }

        // ★ NEW — Save the signed HTML document as a ContentVersion linked to the
        //   Signature Request.  File name: "{SignerName} - Signed Document.html"
       public void saveSignedDocument(Id requestId, String signerName, String htmlContent) {

    System.debug('saveSignedDocument START');

    String safeName = String.isNotBlank(signerName) ? signerName.trim() : 'Signer';

    ContentVersion cv = new ContentVersion();
    cv.Title = safeName + ' - Signed Document';
    cv.PathOnClient = safeName + ' - Signed Document.html';
    cv.VersionData = Blob.valueOf(htmlContent);
    cv.IsMajorVersion = true;
    cv.Origin = 'H';

    insert cv;

    System.debug('ContentVersion inserted: ' + cv.Id);

    cv = [
        SELECT ContentDocumentId
        FROM ContentVersion
        WHERE Id = :cv.Id
        LIMIT 1
    ];

    ContentDocumentLink link = new ContentDocumentLink();
    link.ContentDocumentId = cv.ContentDocumentId;
    link.LinkedEntityId = requestId;
    link.ShareType = 'V';
    link.Visibility = 'AllUsers';

    insert link;

    System.debug('ContentDocumentLink created');
}

        // ★ NEW — Rename the face-verified image and link it to the Signature Request.
        //   File name: "{SignerName} - Face Verified"
        public void linkFaceImageToRequest(Id requestId, Id faceContentVersionId, String signerName) {
            System.debug('[GuestWriter] linkFaceImageToRequest — requestId: ' + requestId
                + ' | faceContentVersionId: ' + faceContentVersionId);
            if (faceContentVersionId == null) {
                System.debug('[GuestWriter] linkFaceImageToRequest — null faceContentVersionId, skipping');
                return;
            }
            try {
                String safeName = String.isNotBlank(signerName) ? signerName.trim() : 'Signer';

                List<ContentVersion> cvRows = [
                    SELECT Id, ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :faceContentVersionId
                    LIMIT 1
                ];
                if (cvRows.isEmpty()) {
                    System.debug('[GuestWriter] linkFaceImageToRequest — ContentVersion not found, skipping');
                    return;
                }

                Id contentDocumentId = cvRows[0].ContentDocumentId;
                System.debug('[GuestWriter] linkFaceImageToRequest — contentDocumentId: ' + contentDocumentId);

                // Rename the document to "{SignerName} - Face Verified"
                update new ContentDocument(Id = contentDocumentId, Title = safeName + ' - Face Verified');

                // Link to the Signature Request (avoid duplicates)
                List<ContentDocumentLink> existing = [
                    SELECT Id FROM ContentDocumentLink
                    WHERE ContentDocumentId = :contentDocumentId
                    AND   LinkedEntityId    = :requestId
                    LIMIT 1
                ];
                if (existing.isEmpty()) {
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.ContentDocumentId = contentDocumentId;
                    cdl.LinkedEntityId    = requestId;
                    cdl.ShareType         = 'V';
                    cdl.Visibility        = 'AllUsers';
                    insert cdl;
                    System.debug('[GuestWriter] linkFaceImageToRequest — ContentDocumentLink inserted');
                } else {
                    System.debug('[GuestWriter] linkFaceImageToRequest — link already exists, skipping');
                }
            } catch (Exception e) {
                System.debug('[GuestWriter] linkFaceImageToRequest ERROR (non-blocking): ' + e.getMessage());
            }
        }
    }

    // ══════════════════════════════════════════════════════════════
    // GET SIGNATURE REQUEST
    // ══════════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=true)
    public static Signature_Request__c getSignatureRequest(String requestId) {
        if (String.isBlank(requestId)) {
            throw new AuraHandledException('Invalid access.');
        }
        Signature_Request__c req = new GuestAccessor().getRequest(requestId);
        if (req == null) {
            throw new AuraHandledException('Invalid or expired signing link.');
        }
        return req;
    }

    // // ══════════════════════════════════════════════════════════════
    // // LOG SIGNATURE VIEWED
    // // ══════════════════════════════════════════════════════════════
    // @AuraEnabled
    // public static void logSignatureViewed(Id requestId) {
    //     AuditTrailManager.logSignatureActivity(
    //         requestId, 'Signature Viewed', 'SUCCESS', 'Signer opened the document'
    //     );
    // }

    // ══════════════════════════════════════════════════════════════
    // INITIATE SIGNATURE REQUEST
    // ══════════════════════════════════════════════════════════════
    @AuraEnabled
    public static String initiateSignatureRequest(
        String documentId, String signerEmail,
        String signerName, List<String> activeToggles
    ) {
        try {
            String rules = (activeToggles != null && !activeToggles.isEmpty())
                ? String.join(activeToggles, ';') : null;

            DocumentLifecycleConfiguration__c doc = [
                SELECT Candidate__c FROM DocumentLifecycleConfiguration__c
                WHERE Id = :documentId LIMIT 1
            ];

            Signature_Request__c newRequest = new Signature_Request__c(
                Document_Lifecycle_Configuration__c = documentId,
                Candidate__c                        = doc.Candidate__c,
                SignerEmail__c                      = signerEmail,
                SignerName__c                       = signerName,
                Status__c                           = 'Pending',
                CreatedDate__c                      = DateTime.now(),
                Fraud_Rules_To_Run__c               = rules
            );
            insert newRequest;
            EmailNotificationService.sendSignatureRequest(newRequest.Id);
            update new DocumentLifecycleConfiguration__c(Id = documentId, Status__c = 'SENT');
            AuditTrailManager.logDocumentActivity(
                newRequest.Document_Lifecycle_Configuration__c, 'Signature Requested',
                'Request sent to ' + signerName + ' <' + signerEmail + '>'
            );
            return newRequest.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to create signature request: ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════════════════════════
    // SEND REMINDER EMAIL
    // ══════════════════════════════════════════════════════════════
    @AuraEnabled
    public static void sendReminderEmail(String documentId) {
        try {
            List<Signature_Request__c> requests = [
                SELECT Id, SignerEmail__c, SignerName__c, Status__c
                FROM Signature_Request__c
                WHERE Document_Lifecycle_Configuration__c = :documentId
                  AND Status__c IN ('Pending', 'Sent')
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            if (requests.isEmpty()) {
                throw new AuraHandledException('No active signature request found.');
            }
            EmailNotificationService.sendSignatureRequest(requests[0].Id);
            AuditTrailManager.logDocumentActivity(
                documentId, 'Reminder Email Sent',
                'Reminder sent to ' + requests[0].SignerName__c + ' <' + requests[0].SignerEmail__c + '>'
            );
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to send reminder: ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════════════════════════
    // SUBMIT SIGNATURE
    // ★ Added param: faceContentVersionId
    // ══════════════════════════════════════════════════════════════
    @AuraEnabled
    public static String submitSignature(
        String requestId,
        String signatureData,
        String signatureMethod,
        String userContextJSON,
        String faceContentVersionId
    ) {
        System.debug('submitSignature called — requestId: ' + requestId);
        System.debug('submitSignature — faceContentVersionId: ' + faceContentVersionId);
        try {
            GuestAccessor accessor = new GuestAccessor();
            GuestWriter   writer   = new GuestWriter();

            Signature_Request__c request = accessor.getRequestForSubmit(requestId);
            if (request == null) {
                throw new AuraHandledException('Signature request not found. Please use a valid signing link.');
            }
            if (request.Status__c == 'Signed' || request.Status__c == 'Completed') {
                throw new AuraHandledException('This document has already been signed.');
            }

            System.debug('submitSignature — request found, Status: ' + request.Status__c);
            System.debug('submitSignature — signerName: ' + request.SignerName__c);

            Map<String, Object> contextMap =
                (Map<String, Object>) JSON.deserializeUntyped(userContextJSON);
            String clientIp   = (String) contextMap.get('ip');
            String location   = (String) contextMap.get('location');
            String rulesToRun = request.Fraud_Rules_To_Run__c;

            if (rulesToRun != null && rulesToRun.contains('IP_ANOMALY')) {
                request.IPAddress__c = clientIp;
            }
            if (rulesToRun != null && rulesToRun.contains('LOCATION_ANOMALY')) {
                request.SigningLocation__c = location;
                if (String.isNotBlank(clientIp)) {
                    Map<String, String> geo = getGeoFromIp(clientIp);
                    if (geo != null) {
                        request.IP_Country__c      = geo.get('country');
                        request.IP_Country_Code__c = geo.get('countryCode');
                        request.IP_Region_Code__c  = geo.get('region');
                        request.IP_Region_Name__c  = geo.get('regionName');
                        request.IP_City__c         = geo.get('city');
                    }
                }
            }
            if (rulesToRun != null && rulesToRun.contains('BEHAVIORAL_ANOMALY')) {
                if (contextMap.containsKey('timeToSign')) {
                    request.Time_To_Complete_Seconds__c = (Decimal) contextMap.get('timeToSign');
                }
            }

            request.Status__c          = 'Signed';
            request.CompletedDate__c   = DateTime.now();
            request.SignatureData__c   = signatureData;
            request.SignatureMethod__c = signatureMethod;

            System.debug('submitSignature — calling writer.updateRequest');
            writer.updateRequest(request);
            System.debug('submitSignature — writer.updateRequest done');

            System.debug('submitSignature — calling writer.updateDocumentStatus');
            writer.updateDocumentStatus(request.Document_Lifecycle_Configuration__c, 'SIGNED');
            System.debug('submitSignature — writer.updateDocumentStatus done');

            // Fraud check — non-blocking
            try {
                Signature_Request__c reqFraud = accessor.getRequestForFraud(request.Id);
                if (reqFraud != null) {
                    FraudDetectionRulesEngine.FraudAnalysisResult fr =
                        FraudDetectionRulesEngine.runSelectedChecks(reqFraud);
                    Signature_Request__c fu = new Signature_Request__c(Id = request.Id);
                    fu.Fraud_Risk_Level__c       = (fr != null) ? fr.riskLevel : 'LOW';
                    fu.Fraud_Score__c            = (fr != null) ? fr.overallRiskScore : 0;
                    fu.Fraud_Analysis_Details__c = (fr != null && fr.reasons != null && !fr.reasons.isEmpty())
                        ? String.join(fr.reasons, '; ') : 'No anomalies detected';
                    writer.updateFraudFields(fu);
                }
            } catch (Exception fraudEx) {
                System.debug('Fraud check non-blocking error: ' + fraudEx.getMessage());
            }

            AuditTrailManager.logSignatureCompletion(request.Id, signatureMethod);

            // Build document HTML
            DocumentLifecycleConfiguration__c doc = request.Document_Lifecycle_Configuration__r;
            String clauseHtml = '';
            if (String.isNotBlank(doc.Clauses__c)) {
                clauseHtml = doc.Clauses__c;
            } else if (String.isNotBlank(doc.Clause__c)) {
                clauseHtml = doc.Clause__c;
            }

            String fullDocHtml = EmailNotificationService.buildProfessionalDocHtml(
                doc, clauseHtml, request.Id
            );

            // Build signature HTML block
            String signatureHtml = '';
            if (signatureMethod == 'Type') {
                signatureHtml =
                    '<div style="font-family:\'Dancing Script\',cursive,Georgia,serif;'
                    + 'font-size:28px;color:#0f172a;padding-bottom:2px;line-height:1.2;">'
                    + signatureData + '</div>';
            } else if (signatureMethod == 'Draw') {
                signatureHtml =
                    '<img src="' + signatureData + '" alt="Signature" '
                    + 'style="max-height:52px;max-width:240px;object-fit:contain;display:block;" />';
            } else if (signatureMethod == 'Upload') {
                String fileIdStr = signatureData.substringAfterLast('/');
                List<ContentVersion> cvList = String.valueOf(fileIdStr).startsWith('068')
                    ? [SELECT VersionData FROM ContentVersion WHERE Id = :fileIdStr LIMIT 1]
                    : [SELECT VersionData FROM ContentVersion
                       WHERE ContentDocumentId = :fileIdStr ORDER BY CreatedDate DESC LIMIT 1];
                if (!cvList.isEmpty()) {
                    signatureHtml =
                        '<img src="data:image/png;base64,'
                        + EncodingUtil.base64Encode(cvList[0].VersionData)
                        + '" alt="Signature" '
                        + 'style="max-height:52px;max-width:240px;object-fit:contain;display:block;" />';
                }
            }

            String signedDocHtml  = fullDocHtml.replace('SIGNATURE_BLOCK_EMPLOYEE', signatureHtml);
            String signedFullPage =
                '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"/>'
                + '<meta name="viewport" content="width=device-width,initial-scale=1.0"/>'
                + '<title>Signed Document</title><style>'
                + '*{box-sizing:border-box;margin:0;padding:0}'
                + 'body{background:#e8ecf0;padding:32px 16px;font-family:Georgia,serif}'
                + '@media print{body{background:#fff;padding:0}}'
                + '</style></head><body>' + signedDocHtml + '</body></html>';

            // ★ NEW — Save signed document as ContentVersion linked to Signature Request
            //   File name: "{SignerName} - Signed Document.html"
            System.debug('submitSignature — saving signed document to ContentVersion');
            writer.saveSignedDocument(request.Id, request.SignerName__c, signedFullPage);
            System.debug('submitSignature — signed document saved');

            // ★ NEW — Rename face image + link it to Signature Request
            //   File name: "{SignerName} - Face Verified"
            System.debug('submitSignature — linking face image to request');
            writer.linkFaceImageToRequest(
                request.Id,
                String.isNotBlank(faceContentVersionId) ? (Id) faceContentVersionId : null,
                request.SignerName__c
            );
            System.debug('submitSignature — face image linked');

            // S3 upload — non-blocking
            try {
                String safeName = String.isNotBlank(request.SignerEmail__c)
                    ? request.SignerEmail__c.replaceAll('[^a-zA-Z0-9]', '_') : 'Signer';
                String s3Key = 'SignedDocument-' + safeName + '-' + DateTime.now().getTime() + '.html';
                S3Uploaderesign.uploadFileToS3Async('esign-signed-documents-kt', s3Key, Blob.valueOf(signedFullPage));
                AuditTrailManager.logDocumentActivity(
                    request.Document_Lifecycle_Configuration__c,
                    'Signed Document Uploaded',
                    'Uploaded to S3 for ' + request.SignerEmail__c
                );
            } catch (Exception s3Ex) {
                System.debug('S3 upload non-blocking error: ' + s3Ex.getMessage());
            }

            // Completion email — non-blocking
            try {
                EmailNotificationService.sendSigningCompletedEmail(
                    request.SignerEmail__c, request.SignerName__c, request.Id, signedDocHtml
                );
            } catch (Exception emailEx) {
                System.debug('Completion email non-blocking error: ' + emailEx.getMessage());
            }

            System.debug('submitSignature SUCCESS for: ' + requestId);
            return 'SUCCESS';

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('submitSignature FATAL: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Signature submission failed: ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════════════════════════
    // GET DOCUMENT DATA
    // ══════════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=true)
    public static DocumentData getDocumentData(String documentId) {
        System.debug('getDocumentData — documentId: ' + documentId);
        if (String.isBlank(documentId)) {
            throw new AuraHandledException('Document ID is required.');
        }

        GuestAccessor accessor = new GuestAccessor();
        DocumentData data = new DocumentData();

        data.document = accessor.getDocument(documentId);
        if (data.document == null) {
            throw new AuraHandledException('Document not found for ID: ' + documentId);
        }

        if (String.isNotBlank(data.document.Clauses__c)) {
            data.renderedContent = data.document.Clauses__c;
        } else if (String.isNotBlank(data.document.Clause__c)) {
            data.renderedContent = data.document.Clause__c;
        }

        data.signatureRequests = accessor.getSignatureRequestsForDoc(documentId);

        System.debug('getDocumentData — name: ' + data.document.Name
            + ' | clause length: ' + (data.renderedContent != null ? data.renderedContent.length() : 0)
            + ' | requests: ' + data.signatureRequests.size());

        return data;
    }

    // ══════════════════════════════════════════════════════════════
    // GET CANDIDATE FACE TOKEN
    // ══════════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=false)
    public static String getCandidateFaceToken(String candidateId) {
        if (String.isBlank(candidateId)) {
            throw new AuraHandledException('Candidate ID is required.');
        }
        return new GuestAccessor().getFaceToken(candidateId);
    }

    // ══════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════
    private static Map<String, String> getGeoFromIp(String ip) {
        Map<String, String> g = new Map<String, String>{
            'country' => 'Unknown', 'countryCode' => null,
            'region'  => null,      'regionName'  => null, 'city' => null
        };
        if (String.isBlank(ip) || ip == '127.0.0.1') return g;
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:IP_Geolocation_Service/json/' + ip);
            req.setMethod('GET');
            req.setTimeout(4000);
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> r = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                g.put('country',     (String) r.get('country'));
                g.put('countryCode', (String) r.get('countryCode'));
                g.put('region',      (String) r.get('region'));
                g.put('regionName',  (String) r.get('regionName'));
                g.put('city',        (String) r.get('city'));
            }
        } catch (Exception e) {
            System.debug('Geo lookup failed: ' + e.getMessage());
        }
        return g;
    }

    // ══════════════════════════════════════════════════════════════
    // WRAPPER
    // ══════════════════════════════════════════════════════════════
    public class DocumentData {
        @AuraEnabled public DocumentLifecycleConfiguration__c document;
        @AuraEnabled public List<Signature_Request__c>        signatureRequests;
        @AuraEnabled public String                            renderedContent;
    }
}