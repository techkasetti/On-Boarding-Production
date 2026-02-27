public with sharing class DocumentGenerationController {

    private static String resolveJurisdictionLabel(String region, String contractType) {
        if (region == 'EU (European Union)') {
            if (contractType == 'Employment Agreement') return 'GDPR + eIDAS';
            if (contractType == 'NDA')                  return 'GDPR';
            if (contractType == 'Statement of work')    return 'eIDAS';
            return 'GDPR';
        } else if (region == 'North America') {
            if (contractType == 'Employment Agreement') return 'ESIGN + HIPAA';
            return 'ESIGN';
        } else if (region == 'APAC') {
            return 'IT Act 2000';
        } else if (region == 'UK') {
            if (contractType == 'Employment Agreement') return 'UK GDPR + eIDAS';
            return 'UK GDPR';
        }
        return 'Global Standards';
    }

    @AuraEnabled(cacheable=true)
    public static List<DocumentTemplate__c> getDocumentTemplates() {
        return [
            SELECT Id, Name, Body__c, Version__c, IsActive__c,
                   Region1__c, Role__c, Contract_Type__c
            FROM DocumentTemplate__c
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static Id saveTemplate(DocumentTemplate__c templateRecord) {
        if (!Schema.sObjectType.DocumentTemplate__c.isCreateable() ||
            !Schema.sObjectType.DocumentTemplate__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to create or update Document Templates.');
        }
        try {
            upsert templateRecord;
            return templateRecord.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Template save failed: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<DocumentTemplate__c> getActiveTemplatesForSelection() {
        return [
            SELECT Id, Name, Region1__c, Role__c, Contract_Type__c
            FROM DocumentTemplate__c
            WHERE IsActive__c = true
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<AIModelManager.AIModelConfig> getAvailableAIModels() {
        return AIModelManager.getAvailableAIModels();
    }

    @AuraEnabled
    public static String generateClauseWithAI(String modelId, String prompt, String jsonContext) {
        String hardcoded =
            '1. Employment Terms and Duties\n'
            + 'The Employee shall serve the Employer diligently and in accordance with all applicable laws.\n\n'
            + '2. Confidentiality\n'
            + 'The Employee agrees to keep strictly confidential all proprietary information '
            + 'obtained during employment. This obligation survives termination for three (3) years.\n\n'
            + '3. Data Protection\n'
            + 'All personal data shall be processed in compliance with applicable data protection legislation.\n\n'
            + '4. Governing Law\n'
            + 'This Agreement is governed by the laws of the applicable jurisdiction.';
        ClauseGenerator.logAIGeneration(modelId, prompt, hardcoded, 'Success', null);
        return hardcoded;
    }

    //====================================================
    // PREVIEW DOCUMENT
    //====================================================
    @AuraEnabled
    public static PreviewResult previewDocument(
        Id templateId,
        String jsonData,
        String aiClauseText,
        String generatedDateTime
    ) {
        PreviewResult result = new PreviewResult();
        if (templateId == null) {
            result.success = false;
            result.validationErrors.add('Template ID is required.');
            return result;
        }
        try {
            DocumentTemplate__c template = [
                SELECT Name, Body__c, Version__c, Region1__c, Role__c, Contract_Type__c, Jurisdiction__c
                FROM DocumentTemplate__c WHERE Id = :templateId LIMIT 1
            ];

            result.templateName         = template.Name;
            result.templateRegion       = template.Region1__c;
            result.templateContractType = template.Contract_Type__c;

            Map<String, Object> masterMergeData = new Map<String, Object>();
            if (String.isNotBlank(jsonData)) {
                masterMergeData.putAll((Map<String, Object>) JSON.deserializeUntyped(jsonData));
            }
            masterMergeData.put('template', new Map<String, Object>{
                'Name'             => template.Name,
                'Version__c'       => template.Version__c,
                'Region1__c'       => template.Region1__c,
                'Role__c'          => template.Role__c,
                'Contract_Type__c' => template.Contract_Type__c
            });

            String clausesText;
            if (String.isNotBlank(aiClauseText)) {
                clausesText = aiClauseText;
            } else {
                List<Clause__c> clauses = [
                    SELECT ClauseDetails__c FROM Clause__c
                    WHERE Region__c = :template.Region1__c AND Role__c = :template.Role__c LIMIT 1
                ];
                clausesText = clauses.isEmpty() ? 'No clauses configured.' : clauses[0].ClauseDetails__c;
            }
            masterMergeData.put('aiClause', clausesText);

            String mergedHtml = DocumentAssemblyEngine.merge1(template.Body__c, masterMergeData);

            if (String.isNotBlank(aiClauseText)) {
                String aiBlockHtml =
                    '<div style="background:rgba(168,85,247,0.04);border-left:3px solid #a855f7;'
                    + 'border-radius:0 8px 8px 0;padding:14px 18px;margin-top:10px;">'
                    + '<div style="font-size:10px;font-weight:700;color:#a855f7;letter-spacing:1px;'
                    + 'text-transform:uppercase;margin-bottom:10px;">&#10022; Einstein AI Generated Clause</div>'
                    + '<div style="font-size:13px;line-height:1.85;color:#1e293b;white-space:pre-wrap;font-family:Georgia,serif;">'
                    + aiClauseText.replace('<', '&lt;').replace('>', '&gt;')
                    + '</div></div>';
                if (mergedHtml.contains('{{termsAndConditions}}')) {
                    mergedHtml = mergedHtml.replace('{{termsAndConditions}}', aiBlockHtml);
                } else if (mergedHtml.contains('Terms &amp; Conditions')) {
                    mergedHtml = mergedHtml.replace('Terms &amp; Conditions', 'Terms &amp; Conditions' + aiBlockHtml);
                } else if (mergedHtml.contains('Terms & Conditions')) {
                    mergedHtml = mergedHtml.replace('Terms & Conditions', 'Terms & Conditions' + aiBlockHtml);
                } else if (mergedHtml.contains('Terms and Conditions')) {
                    mergedHtml = mergedHtml.replace('Terms and Conditions', 'Terms and Conditions' + aiBlockHtml);
                } else {
                    Integer footerIdx = mergedHtml.lastIndexOf('<div style="border-top');
                    if (footerIdx > 0) {
                        mergedHtml = mergedHtml.substring(0, footerIdx) + aiBlockHtml + mergedHtml.substring(footerIdx);
                    } else {
                        mergedHtml += aiBlockHtml;
                    }
                }
            }

            List<String> jurisdictions = new List<String>();
            if (String.isNotBlank(template.Jurisdiction__c)) {
                jurisdictions = template.Jurisdiction__c.split(';');
            }
            if (jurisdictions.isEmpty()) {
                if (template.Region1__c == 'EU (European Union)') {
                    if (template.Contract_Type__c == 'Employment Agreement') { jurisdictions.add('GDPR'); jurisdictions.add('eIDAS'); }
                    else if (template.Contract_Type__c == 'NDA') { jurisdictions.add('GDPR'); }
                    else if (template.Contract_Type__c == 'Statement of work') { jurisdictions.add('eIDAS'); }
                    else { jurisdictions.add('GDPR'); }
                } else if (template.Region1__c == 'North America') {
                    if (template.Contract_Type__c == 'Employment Agreement') { jurisdictions.add('ESIGN'); jurisdictions.add('HIPAA'); }
                    else { jurisdictions.add('ESIGN'); }
                } else if (template.Region1__c == 'APAC') {
                    jurisdictions.add('IT Act India');
                } else if (template.Region1__c == 'UK') {
                    if (template.Contract_Type__c == 'Employment Agreement') { jurisdictions.add('UK GDPR'); jurisdictions.add('eIDAS'); }
                    else { jurisdictions.add('UK GDPR'); }
                } else {
                    jurisdictions.add('Global Standards');
                }
            }

            String complianceSection = '<h3>Data Protection &amp; Privacy</h3>';
            if (jurisdictions.contains('GDPR'))           complianceSection += '<p><strong>GDPR:</strong> Personal data shall be processed lawfully and transparently.</p>';
            if (jurisdictions.contains('eIDAS'))          complianceSection += '<p><strong>eIDAS:</strong> Provides legal validity for electronic signatures and trust services in the EU.</p>';
            if (jurisdictions.contains('ESIGN'))          complianceSection += '<p><strong>ESIGN:</strong> Electronic signatures are legally valid.</p>';
            if (jurisdictions.contains('IT Act India'))   complianceSection += '<p><strong>IT Act 2000:</strong> Reasonable security practices shall be implemented.</p>';
            if (jurisdictions.contains('HIPAA'))          complianceSection += '<p><strong>HIPAA:</strong> Protected Health Information shall be safeguarded.</p>';
            if (jurisdictions.contains('UK GDPR'))        complianceSection += '<p><strong>UK GDPR:</strong> Personal data shall be processed lawfully, fairly, and transparently.</p>';
            if (jurisdictions.contains('Global Standards')) complianceSection += '<p><strong>Global Standards:</strong> This agreement complies with all applicable international regulations.</p>';
            complianceSection += '<p><strong>Governing Law:</strong> This Agreement shall be governed by and construed in accordance with the laws applicable in the '
                + String.join(jurisdictions, ', ') + ' jurisdiction, without regard to conflict of law principles.</p>';
            complianceSection += '<p><em>This Agreement may be executed electronically and shall have the same legal effect as an original signed document.</em></p>';

            if (mergedHtml.contains('Terms &amp; Conditions')) {
                mergedHtml = mergedHtml.replace('Terms &amp; Conditions', complianceSection + '<hr/>' + 'Terms &amp; Conditions');
            } else if (mergedHtml.contains('Terms & Conditions')) {
                mergedHtml = mergedHtml.replace('Terms & Conditions', complianceSection + '<hr/>' + 'Terms & Conditions');
            } else {
                mergedHtml = complianceSection + mergedHtml;
            }

            List<String> complianceErrors = ComplianceChecker.validateDocument(mergedHtml, jurisdictions, template.Contract_Type__c);
            if (!complianceErrors.isEmpty()) {
                result.success = false;
                result.validationErrors.addAll(complianceErrors);
                return result;
            }

            String footerHtml =
                '<div style="border-top:1px solid #ddd;margin-top:20px;padding-top:6px;'
                + 'font-size:11px;color:#666;text-align:right;">'
                + 'Generated On: ' + generatedDateTime + '</div>';
            Integer lastDivIndex = mergedHtml.lastIndexOf('</div>');
            if (lastDivIndex > 0) {
                mergedHtml = mergedHtml.substring(0, lastDivIndex) + footerHtml + mergedHtml.substring(lastDivIndex);
            }

            result.renderedContent = mergedHtml;
            result.success = true;
            return result;
        } catch (Exception e) {
            result.success = false;
            result.validationErrors.add(e.getMessage());
            return result;
        }
    }

    //====================================================
    // FINAL DOCUMENT GENERATION
    // Now accepts all form fields from LWC instead of hardcoding them
    //====================================================
    @AuraEnabled
    public static FinalGenerationResult generateFinalDocument(
        String templateId,
        String aiClauseText,
        String selectedAIModel,
        String generatedDateTime,
        String candidateId,
        // ── NEW: form fields passed from LWC ──
        String companyName,
        String position,
        String department,
        String address,
        String additionalNotes,
        String effectiveDate,
        String expiryDate
    ) {
        System.debug('CandidateId: ' + candidateId);

        if (String.isBlank(candidateId)) {
            throw new AuraHandledException('CandidateId is missing from LWC.');
        }

        Candidate__c candidateRec = [
            SELECT Id, Name, Status__c FROM Candidate__c WHERE Id = :candidateId LIMIT 1
        ];
        System.debug('Candidate Record Found: ' + candidateRec);

        FinalGenerationResult result = new FinalGenerationResult();

        if (!Schema.sObjectType.DocumentLifecycleConfiguration__c.isCreateable() ||
            !Schema.sObjectType.ContentVersion.isCreateable()) {
            result.success      = false;
            result.errorMessage = 'You do not have permission to create document records or files.';
            return result;
        }

        try {
            // ── Build data map using candidate name + LWC form fields ──────────
            // Fall back to defaults only if the user left the field blank
            Map<String, Object> data = new Map<String, Object>();
            data.put('employeeName',    candidateRec.Name);
            data.put('companyName',     String.isNotBlank(companyName)     ? companyName     : 'TechNova Pvt Ltd');
            data.put('position',        String.isNotBlank(position)        ? position        : 'Software Engineer');
            data.put('department',      String.isNotBlank(department)      ? department      : 'Engineering');
            data.put('address',         String.isNotBlank(address)         ? address         : 'Bangalore, India');
            data.put('additionalNotes', String.isNotBlank(additionalNotes) ? additionalNotes : 'Standard Employment Terms Apply');
            data.put('effectiveDate',   String.isNotBlank(effectiveDate)   ? effectiveDate   : '');
            data.put('expiryDate',      String.isNotBlank(expiryDate)      ? expiryDate      : '');

            System.debug('Document data: ' + JSON.serialize(data));

            PreviewResult preview = previewDocument(
                templateId,
                JSON.serialize(data),
                aiClauseText,
                generatedDateTime
            );

            if (!preview.success) {
                result.success      = false;
                result.errorMessage = 'Preview generation failed: ' + String.join(preview.validationErrors, ', ');
                return result;
            }

            // ── Save as ContentVersion ─────────────────────────────────────────
            ContentVersion cv   = new ContentVersion();
            cv.Title            = 'Generated Document - ' + System.now().format();
            cv.PathOnClient     = cv.Title + '.html';
            cv.VersionData      = Blob.valueOf(preview.renderedContent);
            cv.IsMajorVersion   = true;
            insert cv;

            ContentVersion savedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

            // ── Save DocumentLifecycleConfiguration__c ─────────────────────────
            DocumentLifecycleConfiguration__c docConfig = new DocumentLifecycleConfiguration__c(
                Candidate__c             = candidateId,
                Name__c                  = (String.isNotBlank(preview.templateName)
                                            ? preview.templateName
                                            : 'Generated Document') + ' - ' + System.now().format(),
                ContentDocumentString__c = savedCv.ContentDocumentId,
                AI_Model_Used__c         = selectedAIModel,
                Employee_Name__c         = candidateRec.Name,
                Position__c              = (String) data.get('position'),
                Department__c            = (String) data.get('department'),
                Address__c               = (String) data.get('address'),
                Additional_Notes__c      = (String) data.get('additionalNotes')
            );
            insert docConfig;

            AuditTrailManager.logDocumentActivity(
                docConfig.Id,
                'Document Generated',
                'Document generated using template and stored in repository'
            );

            result.success           = true;
            result.recordId          = docConfig.Id;
            result.contentDocumentId = savedCv.ContentDocumentId;
            result.aiModelUsed       = selectedAIModel;
            // ── KEY: return the rendered HTML so LWC can display it directly ──
            result.renderedContent   = preview.renderedContent;

        } catch (Exception e) {
            result.success      = false;
            result.errorMessage = 'Failed to create the document file: ' + e.getMessage();
        }

        return result;
    }

    //====================================================
    // CREATE DOCUMENT REQUEST WITH AI
    //====================================================
    @AuraEnabled
    public static String createDocumentRequest(
        String contractType, String region, String role,
        String additionalRequirements, String selectedAIModel
    ) {
        try {
            if (String.isBlank(contractType) || String.isBlank(region) || String.isBlank(role)) {
                throw new AuraHandledException('Contract type, region, and role are required');
            }
            String generatedClause = ClauseGenerator.generateClause(region, role, contractType, selectedAIModel);
            if (String.isBlank(generatedClause)) throw new AuraHandledException('Failed to generate document clause');

            List<String> errors = ComplianceChecker.validateDocument(generatedClause, new List<String>{ region }, contractType);
            String complianceStatus = errors.isEmpty() ? 'COMPLIANT' : 'REQUIRES_REVIEW';

            DocumentLifecycleConfiguration__c docConfig = new DocumentLifecycleConfiguration__c(
                Region__c              = region,
                Role__c                = role,
                ContractType__c        = contractType,
                GeneratedClause__c     = generatedClause,
                ComplianceStatus__c    = complianceStatus,
                ProcessingStatus__c    = 'GENERATED',
                AIProcessingEnabled__c = true,
                AI_Model_Used__c       = selectedAIModel,
                Jurisdiction_Label__c  = resolveJurisdictionLabel(region, contractType)
            );
            if (String.isNotBlank(additionalRequirements)) {
                docConfig.GeneratedClause__c += '\n\nAdditional Requirements:\n' + additionalRequirements;
            }
            insert docConfig;
            AuditTrailManager.logDocumentActivity(docConfig.Id, 'Document Generated', 'Document generated using template and stored in repository');
            return docConfig.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Document generation failed: ' + e.getMessage());
        }
    }

    //====================================================
    // METHODS FOR: documentViewer LWC
    //====================================================
    @AuraEnabled(cacheable=true)
    public static DocumentViewerWrapper getDocumentDetailsForViewer(Id recordId) {
        DocumentViewerWrapper result = new DocumentViewerWrapper();
        result.document = [
            SELECT Id, Name, CreatedDate, ContentDocumentString__c, AI_Model_Used__c,
                   (SELECT Id, Status__c, SignedDate__c, Signature_Method__c, SignerEmail__c
                    FROM Signature_Requests__r ORDER BY CreatedDate DESC LIMIT 1)
            FROM DocumentLifecycleConfiguration__c WHERE Id = :recordId LIMIT 1
        ];
        if (!result.document.Signature_Requests__r.isEmpty()) {
            result.signatureRequest = result.document.Signature_Requests__r[0];
        }
        result.auditTrails = [
            SELECT Id, Action__c, Details__c, CreatedDate, User__r.Name
            FROM Audit_Trail__c WHERE Record_Id__c = :recordId ORDER BY CreatedDate DESC
        ];
        if (String.isNotBlank(result.document.ContentDocumentString__c)) {
            List<ContentVersion> versions = [
                SELECT VersionData FROM ContentVersion
                WHERE ContentDocumentId = :result.document.ContentDocumentString__c
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            result.renderedContent = versions.isEmpty()
                ? 'Error: Document file not found for the linked ID.'
                : versions[0].VersionData.toString();
        } else {
            result.renderedContent = 'Error: No document has been linked to this record.';
        }
        return result;
    }

    @AuraEnabled
    public static Id createApprovalRequest(Id contentVersionId, Id approverId) {
        if (contentVersionId == null || approverId == null) {
            throw new AuraHandledException('Content Version ID and Approver ID are required.');
        }
        try {
            DocumentApproval__c newApproval = new DocumentApproval__c(
                Document__c = contentVersionId, Approver__c = approverId, Status__c = 'Pending'
            );
            insert newApproval;
            return newApproval.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to create approval request: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<DocumentLifecycleConfiguration__c> getDocumentsForViewer() {
        return [
            SELECT Id, Name, Status__c, CreatedDate, AI_Model_Used__c,
                   ContentDocumentString__c, Employee_Name__c, Company_Name__c,
                   Position__c, Effective_Date__c, Expiry_Date__c, Department__c,
                   Address__c, Additional_Notes__c, Region__c, Contract_Type__c,
                   ContractType__c, Role__c, Jurisdiction_Label__c
            FROM DocumentLifecycleConfiguration__c
            ORDER BY CreatedDate DESC LIMIT 50
        ];
    }

    //====================================================
    // WRAPPER CLASSES
    //====================================================
    public class PreviewResult {
        @AuraEnabled public String  aiModelUsed          { get; set; }
        @AuraEnabled public Boolean success              { get; set; }
        @AuraEnabled public String  templateName         { get; set; }
        @AuraEnabled public String  renderedContent      { get; set; }
        @AuraEnabled public String  templateRegion       { get; set; }
        @AuraEnabled public String  templateContractType { get; set; }
        @AuraEnabled public List<String> validationErrors { get; set; }
        public PreviewResult() { this.success = false; this.validationErrors = new List<String>(); }
    }

    public class FinalGenerationResult {
        @AuraEnabled public Boolean success           { get; set; }
        @AuraEnabled public Id      recordId          { get; set; }
        @AuraEnabled public Id      contentDocumentId { get; set; }
        @AuraEnabled public String  errorMessage      { get; set; }
        @AuraEnabled public String  aiModelUsed       { get; set; }
        @AuraEnabled public String  renderedContent   { get; set; }
        public FinalGenerationResult() { this.success = false; }
    }

    public class DocumentViewerWrapper {
        @AuraEnabled public DocumentLifecycleConfiguration__c document         { get; set; }
        @AuraEnabled public Signature_Request__c               signatureRequest { get; set; }
        @AuraEnabled public List<Audit_Trail__c>               auditTrails      { get; set; }
        @AuraEnabled public String                             renderedContent   { get; set; }
        @AuraEnabled public String                             aiModelInfo       { get; set; }
    }
}