/**
 * EmailNotificationService
 *
 * CHANGES:
 * 1. buildProfessionalDocHtml() is now PUBLIC (was private) so that
 *    SignatureRequestController.submitSignature() can call it to build
 *    the full professional document before stamping the signature.
 *
 * 2. sendSigningCompletedEmail() has an overload that accepts the full
 *    signed document HTML so the signer's confirmation email contains
 *    the complete document with their signature embedded.
 */
public with sharing class EmailNotificationService {

    // ══════════════════════════════════════════════════════════════════
    // SEND SIGNATURE REQUEST EMAIL
    // ══════════════════════════════════════════════════════════════════
    public static void sendSignatureRequest(Id requestId) {
        try {
            Signature_Request__c req = [
                SELECT Id,
                       SignerEmail__c,
                       SignerName__c,
                       Status__c,
                       Document_Lifecycle_Configuration__c,
                       Document_Lifecycle_Configuration__r.Name,
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
                       Document_Lifecycle_Configuration__r.ContentDocumentString__c
                FROM Signature_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];

            if (req == null || String.isBlank(req.SignerEmail__c)) return;

            DocumentLifecycleConfiguration__c doc = req.Document_Lifecycle_Configuration__r;

            // Fetch stored Apex clause HTML from ContentVersion
            String apexClauseHtml = '';
            if (doc != null && doc.ContentDocumentString__c != null) {
                List<ContentVersion> versions = [
                    SELECT VersionData
                    FROM ContentVersion
                    WHERE ContentDocumentId = :doc.ContentDocumentString__c
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!versions.isEmpty()) {
                    apexClauseHtml = versions[0].VersionData.toString();
                }
            }

         String siteBaseUrl = 'https://ktonboarding-dev-ed.develop.my.site.com/candidate/esign';
String signUrl = siteBaseUrl + '?c__requestId=' + requestId;

            // Build full professional document HTML — contains SIGNATURE_BLOCK_EMPLOYEE
            String docHtml = buildProfessionalDocHtml(doc, apexClauseHtml, requestId);

            String signerName   = req.SignerName__c != null ? req.SignerName__c : 'Signer';
            String companyName  = (doc != null && doc.Company_Name__c  != null) ? doc.Company_Name__c  : 'The Company';
            String contractType = (doc != null && doc.Contract_Type__c != null) ? doc.Contract_Type__c : 'Agreement';

            String emailBody =
                '<!DOCTYPE html><html><head><meta charset="UTF-8"/>'
                + '<style>'
                + 'body{margin:0;padding:0;background:#e8ecf0;font-family:Georgia,serif;}'
                + '.email-wrap{max-width:920px;margin:0 auto;padding:24px 16px;}'
                + '.email-banner{background:linear-gradient(135deg,#0f172a,#1e40af);border-radius:12px 12px 0 0;padding:28px 36px;color:#fff;}'
                + '.email-banner h1{margin:0;font-size:20px;font-weight:400;font-family:Georgia,serif;}'
                + '.email-banner p{margin:8px 0 0;font-size:13px;color:rgba(255,255,255,0.7);font-family:Arial,sans-serif;}'
                + '.email-body{background:#fff;padding:28px 36px;border-left:1px solid #e2e8f0;border-right:1px solid #e2e8f0;}'
                + '.email-body p{font-size:14px;line-height:1.8;color:#334155;margin:0 0 16px;font-family:Arial,sans-serif;}'
                + '.sign-btn{display:inline-block;background:linear-gradient(135deg,#1e40af,#3b82f6);color:#fff!important;'
                + 'text-decoration:none;padding:14px 36px;border-radius:8px;font-size:15px;font-weight:600;'
                + 'font-family:Arial,sans-serif;letter-spacing:0.5px;margin:8px 0 20px;}'
                + '.doc-section{margin-top:28px;border-top:2px solid #e2e8f0;padding-top:20px;}'
                + '.doc-label{font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;'
                + 'font-family:Arial,sans-serif;font-weight:600;margin-bottom:12px;}'
                + '.email-footer{background:#f8fafc;border:1px solid #e2e8f0;border-radius:0 0 12px 12px;'
                + 'padding:16px 36px;font-size:11px;color:#94a3b8;font-family:Arial,sans-serif;text-align:center;}'
                + '</style></head><body>'
                + '<div class="email-wrap">'
                +   '<div class="email-banner">'
                +     '<h1>You have a document to sign</h1>'
                +     '<p>' + companyName + ' &middot; ' + contractType + '</p>'
                +   '</div>'
                +   '<div class="email-body">'
                +     '<p>Hello <strong>' + signerName + '</strong>,</p>'
                +     '<p>' + companyName + ' has sent you a <strong>' + contractType + '</strong> for your '
                +       'electronic signature. Please review the document below carefully and click the button to sign.</p>'
                +     '<a href="' + signUrl + '" class="sign-btn">&#9999;&#65039; Sign Document Now</a>'
                +     '<p style="font-size:12px;color:#94a3b8;font-family:Arial,sans-serif;">'
                +       'If the button doesn\'t work, copy this link into your browser:<br/>'
                +       '<a href="' + signUrl + '" style="color:#3b82f6;">' + signUrl + '</a></p>'
                +     '<div class="doc-section">'
                +       '<div class="doc-label">Document Preview</div>'
                +       docHtml
                +     '</div>'
                +   '</div>'
                +   '<div class="email-footer">'
                +     'DocFlow &middot; Powered by Anara AI &middot; End-to-end encrypted &middot; Legally compliant'
                +   '</div>'
                + '</div></body></html>';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ req.SignerEmail__c });
            mail.setSubject('Action Required: Please sign your ' + contractType + ' — ' + companyName);
            mail.setHtmlBody(emailBody);
            mail.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });

        } catch (Exception e) {
            System.debug('sendSignatureRequest failed: ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // SEND SIGNING COMPLETED EMAIL — WITH FULL SIGNED DOCUMENT
    //
    // Called by submitSignature() after the signature is stamped in.
    // signedDocHtml = full professional document HTML with the actual
    // signature rendered in the Employee / Party A signature box.
    // The signer receives this in their confirmation email so they can
    // see exactly what they signed, including their signature.
    // ══════════════════════════════════════════════════════════════════
    public static void sendSigningCompletedEmail(
        String signerEmail,
        String signerName,
        Id requestId,
        String signedDocHtml
    ) {
        try {
            if (String.isBlank(signerEmail)) return;

            String completedTime = DateTime.now().format('MMM d, yyyy h:mm a');
            String refId         = 'REQ-' + String.valueOf(requestId).right(6).toUpperCase();

            String docSection = String.isNotBlank(signedDocHtml)
                ? '<div style="margin-top:28px;border-top:2px solid #d1fae5;padding-top:20px;">'
                  + '<div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;'
                  + 'font-family:Arial,sans-serif;font-weight:600;margin-bottom:12px;">Your Signed Document</div>'
                  + signedDocHtml
                  + '</div>'
                : '';

            String emailBody =
                '<!DOCTYPE html><html><head><meta charset="UTF-8"/>'
                + '<style>'
                + 'body{margin:0;padding:0;background:#e8ecf0;font-family:Georgia,serif;}'
                + '.wrap{max-width:920px;margin:0 auto;padding:24px 16px;}'
                + '.banner{background:linear-gradient(135deg,#064e3b,#059669);border-radius:12px 12px 0 0;padding:28px 36px;text-align:center;}'
                + '.check{font-size:52px;color:#fff;display:block;margin-bottom:8px;}'
                + '.banner h1{margin:0;font-size:20px;font-weight:400;color:#fff;font-family:Arial,sans-serif;}'
                + '.body{background:#fff;padding:28px 36px;border:1px solid #e2e8f0;border-top:none;}'
                + '.body p{font-size:14px;line-height:1.8;color:#334155;margin:0 0 16px;font-family:Arial,sans-serif;}'
                + '.detail-row{display:flex;justify-content:space-between;padding:10px 0;'
                + 'border-bottom:1px solid #f1f5f9;font-size:13px;font-family:Arial,sans-serif;}'
                + '.detail-label{color:#94a3b8;}'
                + '.detail-val{color:#0f172a;font-weight:600;}'
                + '.footer{background:#f8fafc;border:1px solid #e2e8f0;border-radius:0 0 12px 12px;'
                + 'padding:14px 36px;font-size:11px;color:#94a3b8;font-family:Arial,sans-serif;text-align:center;}'
                + '</style></head><body>'
                + '<div class="wrap">'
                +   '<div class="banner"><span class="check">&#10003;</span>'
                +     '<h1>Your signature has been recorded</h1></div>'
                +   '<div class="body">'
                +     '<p>Hello <strong>' + (signerName != null ? signerName : 'Signer') + '</strong>,</p>'
                +     '<p>Your electronic signature has been successfully submitted and recorded. '
                +       'The document is now legally binding. A secure copy has been stored.</p>'
                +     '<div class="detail-row">'
                +       '<span class="detail-label">Signed by</span>'
                +       '<span class="detail-val">' + (signerName != null ? signerName : '—') + '</span>'
                +     '</div>'
                +     '<div class="detail-row">'
                +       '<span class="detail-label">Reference</span>'
                +       '<span class="detail-val">' + refId + '</span>'
                +     '</div>'
                +     '<div class="detail-row">'
                +       '<span class="detail-label">Timestamp</span>'
                +       '<span class="detail-val">' + completedTime + '</span>'
                +     '</div>'
                // Full signed document embedded in email body
                +     docSection
                +     '<br/><p style="font-size:12px;color:#94a3b8;font-family:Arial,sans-serif;">'
                +       'If you did not sign this document, contact your administrator immediately.</p>'
                +   '</div>'
                +   '<div class="footer">Powered by DocFlow &middot; End-to-end encrypted &middot; Legally compliant</div>'
                + '</div></body></html>';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ signerEmail });
            mail.setSubject('Signature Confirmed — Your signed document is enclosed');
            mail.setHtmlBody(emailBody);
            mail.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });

        } catch (Exception e) {
            System.debug('sendSigningCompletedEmail failed: ' + e.getMessage());
        }
    }

    // Legacy overload — keeps backward compatibility if called without signedDocHtml
    public static void sendSigningCompletedEmail(
        String signerEmail,
        String signerName,
        Id requestId
    ) {
        sendSigningCompletedEmail(signerEmail, signerName, requestId, '');
    }

    // ══════════════════════════════════════════════════════════════════
    // PUBLIC PROFESSIONAL DOCUMENT HTML BUILDER
    //
    // NOW PUBLIC so SignatureRequestController.submitSignature() can call it.
    // Previously private — this was the missing link causing both bugs.
    //
    // Builds the same full professional document that the signer sees in
    // the Review Document step (signaturePad LWC Step 2). Structure:
    //   Letterhead (company + doc reference + template name + region badges)
    //   Parties table (Employee / Company)
    //   Dates bar (Effective / Expiry / Type / Jurisdiction)
    //   Preamble
    //   1. Data Protection & Compliance (apexClauseHtml injected here)
    //   2. Terms & Conditions
    //   3. Execution & Signatures
    //      → Employee box contains: SIGNATURE_BLOCK_EMPLOYEE placeholder
    //        submitSignature() replaces this with the actual signature.
    //   Footer
    // ══════════════════════════════════════════════════════════════════
    public static String buildProfessionalDocHtml(
        DocumentLifecycleConfiguration__c doc,
        String apexClauseHtml,
        Id requestId
    ) {
        if (doc == null) {
            return '<p style="color:#64748b;padding:20px;text-align:center;">'
                + 'Document details not available.</p>';
        }

        // ── Field values ─────────────────────────────────────────────
        String employeeName    = doc.Employee_Name__c    != null ? doc.Employee_Name__c    : '';
        String companyName     = doc.Company_Name__c     != null ? doc.Company_Name__c     : '';
        String position        = doc.Position__c         != null ? doc.Position__c         : '';
        String department      = doc.Department__c       != null ? doc.Department__c       : '';
        String address         = doc.Address__c          != null ? doc.Address__c          : '';
        String additionalNotes = doc.Additional_Notes__c != null ? doc.Additional_Notes__c : '';
        String tplRegion       = doc.Region__c           != null ? doc.Region__c           : '';
        String tplRole         = doc.Role__c             != null ? doc.Role__c             : '';
        String tplContractType = doc.Contract_Type__c    != null ? doc.Contract_Type__c    : '';

        // Extract template name from Name ("TemplateName - Jan 1, 2026, 12:00 PM")
        String  nameStr = doc.Name != null ? doc.Name : '';
        Integer dashIdx = nameStr.lastIndexOf(' - ');
        String  tplName = dashIdx > 0 ? nameStr.substring(0, dashIdx) : nameStr;

        // Compliance act
        String complianceAct = 'Global Standards';
        if      (tplRegion == 'EU (European Union)') complianceAct = 'GDPR';
        else if (tplRegion == 'North America')        complianceAct = 'ESIGN';
        else if (tplRegion == 'APAC')                 complianceAct = 'IT Act 2000';
        else if (tplRegion == 'UK')                   complianceAct = 'UK GDPR';

        // Dates
        String today              = DateTime.now().format('MMMM d, yyyy');
        String effectiveFormatted = doc.Effective_Date__c != null ? doc.Effective_Date__c.format() : '—';
        String expiryFormatted    = doc.Expiry_Date__c    != null ? doc.Expiry_Date__c.format()    : '—';
        String docRef             = 'CONF-' + (requestId != null
            ? String.valueOf(requestId).right(4).toUpperCase()
            : String.valueOf(doc.Id).right(4).toUpperCase());

        // Computed text blocks
        String introSentence = 'This '
            + (String.isNotBlank(tplContractType) ? tplContractType : 'Agreement')
            + ' ("Agreement") is entered into between '
            + (String.isNotBlank(employeeName) ? employeeName : '___')
            + ' ("Employee") and the Company ("'
            + (String.isNotBlank(companyName) ? companyName : '___') + '"). '
            + 'This Agreement defines the terms and conditions of employment.';

        String termsText = (String.isNotBlank(employeeName) ? employeeName : 'The employee')
            + ' must comply with '
            + (String.isNotBlank(tplRegion) ? tplRegion : 'applicable')
            + ' regulations and company policies. They are responsible for team governance, '
            + 'compliance enforcement, and reporting obligations.';

        String apexSection = String.isNotBlank(apexClauseHtml)
            ? apexClauseHtml
            : '<p style="color:#94a3b8;font-style:italic;">Standard employment terms apply '
              + 'as per the selected template and jurisdiction.</p>';

        // Optional inline divs
        String deptDiv    = String.isNotBlank(department)
            ? '<div style="font-size:12px;color:#64748b;font-family:Arial,sans-serif;">' + department + '</div>'
            : '';
        String addressDiv = String.isNotBlank(address)
            ? '<div style="font-size:11px;color:#94a3b8;font-family:Arial,sans-serif;margin-top:6px;">' + address + '</div>'
            : '';
        String notesDiv   = String.isNotBlank(additionalNotes)
            ? '<div style="margin-top:12px;padding-top:12px;border-top:1px dashed #e2e8f0;">'
              + '<div style="font-size:11px;text-transform:uppercase;letter-spacing:1px;color:#94a3b8;'
              + 'font-family:Arial,sans-serif;margin-bottom:6px;">Additional Notes / Special Clauses</div>'
              + '<p style="font-size:13px;line-height:1.75;color:#475569;margin:0;">' + additionalNotes + '</p>'
              + '</div>'
            : '';

        return
            // ─── Root wrapper ────────────────────────────────────────────────
            '<div style="width:100%;max-width:860px;margin:0 auto;background:#ffffff;'
            + 'font-family:Georgia,serif;color:#1a1a2e;'
            + 'box-shadow:0 0 40px rgba(0,0,0,0.15);box-sizing:border-box;padding:0;">'

            // ─── LETTERHEAD ──────────────────────────────────────────────────
            + '<div style="background:linear-gradient(135deg,#0f172a 0%,#1e3a5f 60%,#1e40af 100%);'
            +   'padding:36px 48px 28px;position:relative;overflow:hidden;">'
            +   '<div style="position:absolute;top:-40px;right:-40px;width:180px;height:180px;'
            +     'border-radius:50%;background:rgba(255,255,255,0.04);"></div>'
            +   '<div style="display:flex;justify-content:space-between;align-items:flex-start;'
            +     'position:relative;z-index:1;">'
            +     '<div>'
            +       '<div style="font-size:22px;font-weight:700;color:#ffffff;letter-spacing:1px;'
            +         'font-family:Arial,sans-serif;margin-bottom:4px;">' + companyName + '</div>'
            +       '<div style="font-size:11px;color:rgba(255,255,255,0.55);letter-spacing:2px;'
            +         'text-transform:uppercase;font-family:Arial,sans-serif;">' + tplContractType + '</div>'
            +     '</div>'
            +     '<div style="text-align:right;">'
            +       '<div style="font-size:10px;color:rgba(255,255,255,0.45);font-family:Arial,sans-serif;'
            +         'letter-spacing:1px;text-transform:uppercase;margin-bottom:4px;">Document Reference</div>'
            +       '<div style="font-size:13px;color:#93c5fd;font-family:Courier New,monospace;'
            +         'font-weight:700;letter-spacing:1px;">' + docRef + '</div>'
            +       '<div style="font-size:10px;color:rgba(255,255,255,0.45);font-family:Arial,sans-serif;'
            +         'margin-top:6px;">' + today + '</div>'
            +     '</div>'
            +   '</div>'
            +   '<div style="margin-top:24px;border-top:1px solid rgba(255,255,255,0.12);'
            +     'padding-top:20px;position:relative;z-index:1;">'
            +     '<div style="font-size:26px;font-weight:400;color:#ffffff;letter-spacing:0.5px;'
            +       'font-family:Georgia,serif;line-height:1.2;">' + tplName + '</div>'
            +     '<div style="margin-top:8px;display:flex;gap:16px;flex-wrap:wrap;">'
            +       '<span style="background:rgba(255,255,255,0.1);border:1px solid rgba(255,255,255,0.15);'
            +         'color:rgba(255,255,255,0.75);padding:3px 12px;border-radius:20px;'
            +         'font-size:10.5px;font-family:Arial,sans-serif;">'
            +         (String.isNotBlank(tplRegion) ? tplRegion : 'Global') + '</span>'
            +       '<span style="background:rgba(99,179,237,0.15);border:1px solid rgba(99,179,237,0.25);'
            +         'color:#93c5fd;padding:3px 12px;border-radius:20px;'
            +         'font-size:10.5px;font-family:Arial,sans-serif;">' + complianceAct + '</span>'
            +       '<span style="background:rgba(52,211,153,0.12);border:1px solid rgba(52,211,153,0.2);'
            +         'color:#6ee7b7;padding:3px 12px;border-radius:20px;'
            +         'font-size:10.5px;font-family:Arial,sans-serif;">'
            +         (String.isNotBlank(tplRole) ? tplRole : 'Professional') + '</span>'
            +     '</div>'
            +   '</div>'
            + '</div>'

            // ─── BODY ────────────────────────────────────────────────────────
            + '<div style="padding:40px 48px;">'

            // Parties
            + '<div style="margin-bottom:32px;">'
            +   '<div style="display:flex;gap:8px;align-items:center;margin-bottom:16px;">'
            +     '<div style="width:3px;height:20px;background:linear-gradient(#1e40af,#3b82f6);border-radius:2px;"></div>'
            +     '<div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;'
            +       'color:#64748b;font-family:Arial,sans-serif;font-weight:600;">'
            +       'Parties to this Agreement</div>'
            +   '</div>'
            +   '<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">'
            +     '<div style="border:1px solid #e2e8f0;border-radius:10px;padding:18px 20px;background:#f8fafc;">'
            +       '<div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;'
            +         'color:#94a3b8;font-family:Arial,sans-serif;margin-bottom:8px;">Employee / Party A</div>'
            +       '<div style="font-size:15px;font-weight:700;color:#0f172a;margin-bottom:4px;">' + employeeName + '</div>'
            +       '<div style="font-size:12px;color:#64748b;font-family:Arial,sans-serif;">'
            +         (String.isNotBlank(position) ? position : tplRole) + '</div>'
            +       deptDiv + addressDiv
            +     '</div>'
            +     '<div style="border:1px solid #e2e8f0;border-radius:10px;padding:18px 20px;background:#f8fafc;">'
            +       '<div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;'
            +         'color:#94a3b8;font-family:Arial,sans-serif;margin-bottom:8px;">Company / Party B</div>'
            +       '<div style="font-size:15px;font-weight:700;color:#0f172a;margin-bottom:4px;">' + companyName + '</div>'
            +       '<div style="font-size:12px;color:#64748b;font-family:Arial,sans-serif;">'
            +         'Employer / Authorised Representative</div>'
            +     '</div>'
            +   '</div>'
            + '</div>'

            // Dates bar
            + '<div style="background:linear-gradient(135deg,#eff6ff,#f0fdf4);border:1px solid #bfdbfe;'
            +   'border-radius:10px;padding:16px 24px;margin-bottom:28px;'
            +   'display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;">'
            +   '<div>'
            +     '<div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;'
            +       'color:#3b82f6;font-family:Arial,sans-serif;margin-bottom:4px;">Effective Date</div>'
            +     '<div style="font-size:14px;font-weight:700;color:#1e3a5f;">' + effectiveFormatted + '</div>'
            +   '</div>'
            +   '<div style="width:1px;height:32px;background:#bfdbfe;"></div>'
            +   '<div>'
            +     '<div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;'
            +       'color:#3b82f6;font-family:Arial,sans-serif;margin-bottom:4px;">Expiry / End Date</div>'
            +     '<div style="font-size:14px;font-weight:700;color:#1e3a5f;">' + expiryFormatted + '</div>'
            +   '</div>'
            +   '<div style="width:1px;height:32px;background:#bfdbfe;"></div>'
            +   '<div>'
            +     '<div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;'
            +       'color:#3b82f6;font-family:Arial,sans-serif;margin-bottom:4px;">Document Type</div>'
            +     '<div style="font-size:14px;font-weight:700;color:#1e3a5f;">'
            +       (String.isNotBlank(tplContractType) ? tplContractType : 'Agreement') + '</div>'
            +   '</div>'
            +   '<div style="width:1px;height:32px;background:#bfdbfe;"></div>'
            +   '<div>'
            +     '<div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;'
            +       'color:#3b82f6;font-family:Arial,sans-serif;margin-bottom:4px;">Jurisdiction</div>'
            +     '<div style="font-size:14px;font-weight:700;color:#1e3a5f;">'
            +       (String.isNotBlank(tplRegion) ? tplRegion : 'Global') + '</div>'
            +   '</div>'
            + '</div>'

            // Preamble
            + '<div style="margin-bottom:28px;">'
            +   '<div style="display:flex;gap:8px;align-items:center;margin-bottom:12px;">'
            +     '<div style="width:3px;height:20px;background:linear-gradient(#1e40af,#3b82f6);border-radius:2px;"></div>'
            +     '<div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;'
            +       'color:#64748b;font-family:Arial,sans-serif;font-weight:600;">Preamble</div>'
            +   '</div>'
            +   '<p style="font-size:13.5px;line-height:1.8;color:#334155;margin:0;">' + introSentence + '</p>'
            + '</div>'

            // Section 1 — Compliance + Apex clauses
            + '<div style="background:#fafafa;border:1px solid #e2e8f0;border-left:3px solid #3b82f6;'
            +   'border-radius:0 8px 8px 0;padding:18px 22px;margin-bottom:28px;">'
            +   '<div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#3b82f6;'
            +     'font-family:Arial,sans-serif;font-weight:600;margin-bottom:10px;">'
            +     '1. Data Protection &amp; Compliance — ' + complianceAct + '</div>'
            +   apexSection
            + '</div>'

            // Section 2 — Terms & Conditions
            + '<div style="margin-bottom:28px;">'
            +   '<div style="display:flex;gap:8px;align-items:center;margin-bottom:12px;">'
            +     '<div style="width:3px;height:20px;background:linear-gradient(#1e40af,#3b82f6);border-radius:2px;"></div>'
            +     '<div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;'
            +       'color:#64748b;font-family:Arial,sans-serif;font-weight:600;">2. Terms &amp; Conditions</div>'
            +   '</div>'
            +   '<div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:16px 20px;">'
            +     '<p style="font-size:13px;line-height:1.8;color:#475569;margin:0 0 8px;">' + termsText + '</p>'
            +     notesDiv
            +   '</div>'
            + '</div>'

            // Section 3 — Signatures
            // ★ SIGNATURE_BLOCK_EMPLOYEE lives here — submitSignature() replaces it
            + '<div style="margin-bottom:16px;">'
            +   '<div style="display:flex;gap:8px;align-items:center;margin-bottom:20px;">'
            +     '<div style="width:3px;height:20px;background:linear-gradient(#1e40af,#3b82f6);border-radius:2px;"></div>'
            +     '<div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;'
            +       'color:#64748b;font-family:Arial,sans-serif;font-weight:600;">'
            +       '3. Execution &amp; Signatures</div>'
            +   '</div>'
            +   '<div style="display:grid;grid-template-columns:1fr 1fr;gap:32px;">'
            // Employee / Party A signature box
            +     '<div style="border:1px solid #e2e8f0;border-radius:10px;padding:20px 22px;background:#f8fafc;">'
            +       '<div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;'
            +         'color:#94a3b8;font-family:Arial,sans-serif;margin-bottom:12px;">Employee / Party A</div>'
            // ★ SIGNATURE_BLOCK_EMPLOYEE placeholder — replaced with actual signature after signing
            +       '<div style="border-bottom:1.5px solid #334155;margin-bottom:10px;min-height:56px;'
            +         'display:flex;align-items:flex-end;padding-bottom:4px;">'
            +         'SIGNATURE_BLOCK_EMPLOYEE'
            +       '</div>'
            +       '<div style="font-size:12px;color:#64748b;font-family:Arial,sans-serif;line-height:1.8;">'
            +         '<div>Name: <strong style="color:#0f172a;">' + employeeName + '</strong></div>'
            +         '<div>Title: ' + (String.isNotBlank(position) ? position : '___________________________') + '</div>'
            +         '<div>Date: ' + DateTime.now().format('MMMM d, yyyy') + '</div>'
            +       '</div>'
            +     '</div>'
            // Company / Party B signature box
            +     '<div style="border:1px solid #e2e8f0;border-radius:10px;padding:20px 22px;background:#f8fafc;">'
            +       '<div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;'
            +         'color:#94a3b8;font-family:Arial,sans-serif;margin-bottom:12px;">'
            +         'Authorised Representative / Party B</div>'
            +       '<div style="border-bottom:1.5px solid #334155;margin-bottom:10px;min-height:56px;"></div>'
            +       '<div style="font-size:12px;color:#64748b;font-family:Arial,sans-serif;line-height:1.8;">'
            +         '<div>Name: ___________________________</div>'
            +         '<div>Title: ___________________________</div>'
            +         '<div>Date: ___________________________</div>'
            +       '</div>'
            +     '</div>'
            +   '</div>'
            + '</div>'

            + '</div>' // end body

            // ─── FOOTER ──────────────────────────────────────────────────────
            + '<div style="border-top:1px solid #e2e8f0;padding:14px 48px;'
            +   'display:flex;justify-content:space-between;align-items:center;background:#f8fafc;">'
            +   '<div style="font-size:10px;color:#94a3b8;font-family:Arial,sans-serif;">'
            +     companyName + ' &middot; ' + tplName + ' &middot; Ref: ' + docRef + '</div>'
            +   '<div style="font-size:10px;color:#94a3b8;font-family:Arial,sans-serif;">'
            +     'Generated ' + today + ' &middot; Legally compliant &middot; ' + complianceAct + '</div>'
            +   '<div style="font-size:10px;color:#94a3b8;font-family:Arial,sans-serif;">Page 1 of 1</div>'
            + '</div>'

            + '</div>'; // end root
    }
}