// docflowCreateDoc.js
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveTemplatesForSelection from '@salesforce/apex/DocumentGenerationController.getActiveTemplatesForSelection';
import getAvailableAIModels           from '@salesforce/apex/DocumentGenerationController.getAvailableAIModels';
import generateFinalDocument          from '@salesforce/apex/DocumentGenerationController.generateFinalDocument';
import generateClauseWithAI           from '@salesforce/apex/DocumentGenerationController.generateClauseWithAI';

// NOTE: previewDocument import is intentionally removed.
// The Apex previewDocument returns raw merged template HTML (plain unstyled).
// The professional A4 document is always built by _buildDocumentHtml() in JS.

const PREVIEW_COMPLIANCE = {
    'EU (European Union)': { act: 'GDPR',             text: 'Personal data shall be processed lawfully and transparently.' },
    'North America':        { act: 'ESIGN',            text: 'Electronic signatures are legally valid under the ESIGN Act.' },
    'APAC':                 { act: 'IT Act 2000',      text: 'Reasonable security practices shall be implemented.' },
    'UK':                   { act: 'UK GDPR',          text: 'Personal data shall be processed lawfully, fairly, and transparently.' },
    'Global':               { act: 'Global Standards', text: 'This agreement complies with all applicable international regulations.' },
};

export default class DocflowCreateDoc extends LightningElement {

    @api candidateId   = '';
    @api candidateName = '';

    @track isLoadingTemplates    = false;
    @track isSending             = false;
    @track availableTemplates    = [];
    @track templateSelected      = false;
    @track tplId                 = '';
    @track tplName               = '';
    @track tplRegion             = '';
    @track tplRole               = '';
    @track tplContractType       = '';

    // renderedContent = the professional HTML string, set once in handleGenerate.
    // renderedCallback injects it into .cd-rendered-wrap via el.innerHTML.
    // handleViewDocument injects it into .cd-modal-rendered-wrap.
    // handleDownloadDocument wraps it in a full HTML page.
    @track renderedContent       = '';

    @track isGenerated           = false;
    @track generatedContentDocId = '';
    @track hasError              = false;
    @track errorMessage          = '';
    @track showViewModal         = false;

    @track aiSuggestionEnabled   = false;
    @track availableAIModels     = [];
    @track selectedAIModel       = '';
    @track aiClausePrompt        = '';
    @track isGeneratingClause    = false;
    @track aiGeneratedClause     = '';

    @track formData = {
        employeeName:    '',
        position:        '',
        address:         'Bangalore, India,pune',
        companyName:     'TechNova Pvt Ltd',
        effectiveDate:   new Date().toISOString().split('T')[0],
        expiryDate:      '12/2/2028',
        department:      'computer science',
        additionalNotes: '',
    };

    _htmlInjected         = false;
    _modalHtmlInjected    = false;
    _candidateNameApplied = false;

    connectedCallback() {
        console.log('[CreateDoc] connectedCallback | candidateId:', this.candidateId, '| candidateName:', this.candidateName);
        if (this.candidateName && !this._candidateNameApplied) {
            this.formData = { ...this.formData, employeeName: this.candidateName };
            this._candidateNameApplied = true;
        }
        this.loadTemplates();
        this.loadAIModels();
    }

    loadTemplates() {
        this.isLoadingTemplates = true;
        getActiveTemplatesForSelection()
            .then(data => { this.availableTemplates = data || []; this.isLoadingTemplates = false; })
            .catch(err  => { this.isLoadingTemplates = false; this._toast('Error', err?.body?.message || 'Failed to load templates', 'error'); });
    }

    loadAIModels() {
        getAvailableAIModels()
            .then(data => {
                this.availableAIModels = (data || []).map(m => {
                    const value = m.modelIdentifier || m.modelId || m.id || m.Id || m.model_id || '';
                    const label = m.modelName || m.label || m.name || value || 'Unknown Model';
                    return { ...m, _value: value, _label: label };
                });
                if (this.availableAIModels.length > 0) this.selectedAIModel = this.availableAIModels[0]._value;
            })
            .catch(() => {
                this.selectedAIModel   = 'einstein_intent';
                this.availableAIModels = [{ _value: 'einstein_intent', _label: 'Einstein Intent Detection (Salesforce)' }];
            });
    }

    renderedCallback() {
        // KEY FIX: inject this.renderedContent directly.
        // Do NOT call _buildDocumentHtml() here — that would rebuild from scratch
        // and could differ from what was stored. Use the already-built HTML.
        if (this.renderedContent && !this._htmlInjected) {
            const el = this.template.querySelector('.cd-rendered-wrap');
            if (el) {
                el.innerHTML       = this.renderedContent;   // ← inject stored HTML
                this._htmlInjected = true;
            }
        }
    }

    // ── GETTERS ────────────────────────────────────────────────────────────
    get previewTemplateName() { return this.tplName || 'template name'; }
    get previewEmployeeName() { return this.formData.employeeName || 'employee name'; }
    get hasRenderedContent()  { return !!this.renderedContent; }
    get isNotGenerated()      { return !this.isGenerated; }
    get aiToggleClass()  { return this.aiSuggestionEnabled ? 'cd-ai-toggle cd-ai-toggle-on' : 'cd-ai-toggle cd-ai-toggle-off'; }
    get aiToggleLabel()  { return this.aiSuggestionEnabled ? 'Enabled' : 'Disabled'; }
    get aiModelOptions() { return (this.availableAIModels || []).map(m => ({ label: m._label, value: m._value })); }

    get introSentence() {
        const name    = this.formData.employeeName || '___';
        const company = this.formData.companyName  || '___';
        const type    = this.tplContractType       || 'Agreement';
        const date    = this.formData.effectiveDate
            ? new Date(this.formData.effectiveDate + 'T12:00:00').toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
            : '___';
        let s = `This ${type} ("Agreement") is entered into between ${name} ("Employee") and the Company ("${company}"). This Agreement defines the terms and conditions of employment.`;
        if (this.formData.position || this.formData.department) {
            s += ` ${name} will serve as ${this.formData.position || 'the designated role'}`;
            if (this.formData.department) s += ` in the ${this.formData.department} department`;
            s += `, effective ${date}.`;
        }
        return s;
    }

    get complianceAct()  { return (PREVIEW_COMPLIANCE[this.tplRegion] || PREVIEW_COMPLIANCE['Global']).act; }
    get complianceText() { return (PREVIEW_COMPLIANCE[this.tplRegion] || PREVIEW_COMPLIANCE['Global']).text; }

    get termsText() {
        const name         = this.formData.employeeName || 'The Employee';
        const company      = this.formData.companyName  || 'the Company';
        const region       = this.tplRegion             || 'the applicable jurisdiction';
        const contractType = this.tplContractType       || 'this Agreement';
        const role         = this.tplRole               || '';
        let t = `${name} agrees to comply with all applicable ${region} regulations and the policies of ${company}.`;
        if (role) t += ` As ${role}, ${name} shall fulfil all associated responsibilities and obligations.`;
        t += ` Both parties acknowledge the terms of ${contractType} and agree to be bound by its provisions, including standard employment terms, confidentiality obligations, and intellectual property provisions as defined in the selected template.`;
        return t;
    }

    // ── AI CLAUSE ──────────────────────────────────────────────────────────
    handleAIToggle() {
        this.aiSuggestionEnabled = !this.aiSuggestionEnabled;
        if (this.aiSuggestionEnabled && this.tplRegion) this._autoFillClausePrompt();
        if (!this.aiSuggestionEnabled) this.aiGeneratedClause = '';
    }
    handleAIModelChange(event)      { this.selectedAIModel = event.target.value; }
    handleClausePromptChange(event) { this.aiClausePrompt  = event.target.value; }

    _autoFillClausePrompt() {
        const jurisdiction = (PREVIEW_COMPLIANCE[this.tplRegion] || PREVIEW_COMPLIANCE['Global']).act;
        const type   = this.tplContractType || 'employment agreement';
        const region = this.tplRegion       || 'global';
        const role   = this.tplRole         || '';
        this.aiClausePrompt =
            `Suggest a standard ${role ? role.toLowerCase() + ' ' : ''}clause for a ${region} ` +
            `${type.toLowerCase()} with ${jurisdiction} compliance. Include data protection ` +
            `obligations, electronic signature validity, and governing law provisions.`;
    }

    handleGenerateAIClause() {
        if (!this.aiClausePrompt) { this._toast('Warning', 'Please enter a clause prompt.', 'warning'); return; }
        if (!this.selectedAIModel) this.selectedAIModel = 'einstein_intent';
        this.isGeneratingClause = true;
        this.aiGeneratedClause  = '';
        const jsonContext = JSON.stringify({ region: this.tplRegion, role: this.tplRole, contractType: this.tplContractType, jurisdiction: this.complianceAct });
        generateClauseWithAI({ modelId: this.selectedAIModel, prompt: this.aiClausePrompt, jsonContext })
            .then(result => {
                this.isGeneratingClause = false;
                this.aiGeneratedClause  = result || '';
                this._toast('AI Clause Ready ✓', 'Clause generated — visible in the Terms & Conditions block below.', 'success');
            })
            .catch(err  => {
                this.isGeneratingClause = false;
                this._toast('Error', err?.body?.message || 'Failed to generate AI clause.', 'error');
            });
    }

    // ── FORM HANDLERS ──────────────────────────────────────────────────────
    handleTemplateSelect(event) {
        const id = event.target.value;
        this.tplId           = id;
        this.renderedContent = '';
        this._htmlInjected   = false;
        this.hasError        = false;
        this.isGenerated     = false;
        this.generatedContentDocId = '';
        this.aiGeneratedClause     = '';
        if (id) {
            const tpl = this.availableTemplates.find(t => t.Id === id);
            if (tpl) {
                this.tplName         = tpl.Name;
                this.tplRegion       = tpl.Region1__c       || '';
                this.tplRole         = tpl.Role__c          || '';
                this.tplContractType = tpl.Contract_Type__c || '';
            }
            this.templateSelected = true;
            if (this.aiSuggestionEnabled) this._autoFillClausePrompt();
        } else {
            this.templateSelected = false;
            this.tplName = this.tplRegion = this.tplRole = this.tplContractType = '';
        }
    }

    handleField(event) {
        const { name, value } = event.target;
        this.formData = { ...this.formData, [name]: value };
        this.hasError = false;
    }

    // ── GENERATE DOCUMENT ──────────────────────────────────────────────────
    handleGenerate() {
        if (!this.candidateId) {
            this._toast('Error', 'No candidate selected. Please navigate from the Cleared Candidates tab.', 'error');
            return;
        }
        if (!this.tplId) {
            this._toast('Error', 'Please select a template.', 'error');
            return;
        }

        console.log('[CreateDoc] handleGenerate | candidateId:', this.candidateId);
        console.log('[CreateDoc] formData:', JSON.stringify(this.formData));

        this.isSending = true;
        const clauseText = (this.aiSuggestionEnabled && this.aiGeneratedClause) ? this.aiGeneratedClause : null;

        generateFinalDocument({
            templateId:        this.tplId,
            aiClauseText:      clauseText,
            selectedAIModel:   this.aiSuggestionEnabled ? this.selectedAIModel : null,
            generatedDateTime: this._nowStr(),
            candidateId:       this.candidateId,
            // candidateId:       'a0Ffo000000n4AXEAY',
            // ── Real form field values — Apex no longer uses hardcoded defaults ──
            companyName:       this.formData.companyName     || '',
            position:          this.formData.position        || '',
            department:        this.formData.department      || '',
            address:           this.formData.address         || '',
            additionalNotes:   this.formData.additionalNotes || '',
            effectiveDate:     this.formData.effectiveDate   || '',
            expiryDate:        this.formData.expiryDate      || '',
        })
        .then(result => {
            this.isSending = false;
            if (result.success) {
                this._toast('Success ✓', 'Document generated successfully!', 'success');
                this.isGenerated           = true;
                this.generatedContentDocId = result.contentDocumentId || '';

                // ══ KEY FIX ══════════════════════════════════════════════════
                // Build the professional styled A4 HTML NOW from the current
                // JS state (formData, tplName, tplRegion, aiGeneratedClause…).
                // Store it in this.renderedContent.
                //
                // renderedCallback will inject it into .cd-rendered-wrap.
                // handleViewDocument injects it into .cd-modal-rendered-wrap.
                // handleDownloadDocument wraps it in a full HTML page.
                //
                // Do NOT use result.renderedContent — that is Apex template HTML
                // (plain unstyled compliance text from previewDocument) which is
                // what caused the grey-box-with-plain-text bug in the screenshot.
                // ════════════════════════════════════════════════════════════
                this._htmlInjected      = false;
                this._modalHtmlInjected = false;
                this.renderedContent    = this._buildDocumentHtml();

            } else {
                this._toast('Error', result.errorMessage || 'Generation failed.', 'error');
            }
        })
        .catch(err => {
            this.isSending = false;
            this._toast('Error', err?.body?.message || 'Generation failed.', 'error');
        });
    }

    // ── VIEW MODAL ─────────────────────────────────────────────────────────
    handleViewDocument() {
        if (!this.isGenerated || !this.renderedContent) {
            this._toast('Info', 'Please generate the document first.', 'info');
            return;
        }
        this._modalHtmlInjected = false;
        this.showViewModal = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const el = this.template.querySelector('.cd-modal-rendered-wrap');
            if (el && !this._modalHtmlInjected) {
                el.innerHTML            = this.renderedContent;   // ← professional HTML
                this._modalHtmlInjected = true;
            }
        }, 50);
    }

    handleCloseModal()     { this.showViewModal = false; this._modalHtmlInjected = false; }
    stopPropagation(event) { event.stopPropagation(); }

    // ── DOWNLOAD ───────────────────────────────────────────────────────────
    handleDownloadDocument() {
        if (!this.isGenerated || !this.renderedContent) {
            this._toast('Info', 'Please generate the document first.', 'info');
            return;
        }
        const fileName = (this.tplName || 'Document').replace(/[^a-z0-9_\-\s]/gi, '') +
                         '_' + (this.formData.employeeName || 'Employee').replace(/\s+/g, '_') + '.html';
        const fullHtml = `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"/>
<title>${this.tplName || 'Document'}</title>
<style>
  * { box-sizing:border-box; margin:0; padding:0; }
  body { background:#e8ecf0; padding:32px 16px; font-family:Georgia,serif; }
  @media print { body { background:#fff; padding:0; } }
</style>
</head><body>${this.renderedContent}</body></html>`;
        try {
            const a = document.createElement('a');
            a.href          = 'data:text/html;charset=utf-8,' + encodeURIComponent(fullHtml);
            a.download      = fileName;
            a.style.display = 'none';
            document.body.appendChild(a);
            a.click();
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => document.body.removeChild(a), 200);
        } catch (err) {
            const url = URL.createObjectURL(new Blob([fullHtml], { type: 'text/html' }));
            window.open(url, '_blank');
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => URL.revokeObjectURL(url), 10000);
        }
    }

    // ── PROFESSIONAL A4 DOCUMENT BUILDER ───────────────────────────────────
    // Called once after successful generation → result stored in this.renderedContent.
    // Three consumers: right-panel preview, View modal, Download.
    _buildDocumentHtml() {
        const f = this.formData;
        const effectiveFormatted = f.effectiveDate
            ? new Date(f.effectiveDate + 'T12:00:00').toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })
            : '—';
        const expiryFormatted = f.expiryDate
            ? new Date(f.expiryDate + 'T12:00:00').toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })
            : '—';
        const today      = new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
        const docRef     = 'DOC-' + Date.now().toString(36).toUpperCase().slice(-6);
        const compliance = { act: this.complianceAct, text: this.complianceText };

        const complianceBody = `
            <p style="font-size:13px;line-height:1.8;color:#334155;margin:0 0 8px;">
                <strong>${compliance.act}:</strong> ${compliance.text}
            </p>
            <p style="font-size:13px;line-height:1.8;color:#334155;margin:0 0 8px;">
                <strong>Governing Law:</strong> This Agreement shall be governed by and construed
                in accordance with the laws applicable in the ${this.tplRegion || 'applicable'} jurisdiction,
                without regard to conflict of law principles.
            </p>
            <p style="font-size:12px;line-height:1.7;color:#64748b;font-style:italic;margin:0;">
                This Agreement may be executed electronically and shall have the same legal effect
                as an original signed document pursuant to applicable e-signature legislation.
            </p>`;

        let termsBody;
        if (this.aiSuggestionEnabled && this.aiGeneratedClause) {
            termsBody = `
                <div style="font-size:10px;font-weight:700;color:#a855f7;letter-spacing:1px;
                            text-transform:uppercase;margin-bottom:12px;font-family:Arial,sans-serif;">
                    &#10022; Einstein AI Generated Clause
                </div>
                <div style="font-size:13px;line-height:1.85;color:#1e293b;white-space:pre-wrap;font-family:Georgia,serif;">
                    ${this.aiGeneratedClause.replace(/</g, '&lt;').replace(/>/g, '&gt;')}
                </div>`;
        } else if (this.aiSuggestionEnabled && !this.aiGeneratedClause) {
            termsBody = `<p style="font-size:13px;line-height:1.8;color:#94a3b8;font-style:italic;margin:0;">
                &#10022; Einstein AI clause will appear here after you click "Generate AI Clause" above.</p>`;
        } else {
            termsBody = `<p style="font-size:13px;line-height:1.8;color:#475569;margin:0;">${this.termsText}</p>`;
        }
        if (f.additionalNotes) {
            termsBody += `
                <div style="margin-top:14px;padding-top:14px;border-top:1px dashed #e2e8f0;">
                    <div style="font-size:10px;text-transform:uppercase;letter-spacing:1px;color:#94a3b8;
                                font-family:Arial,sans-serif;margin-bottom:6px;">Additional Notes / Special Clauses</div>
                    <p style="font-size:13px;line-height:1.75;color:#475569;margin:0;">
                        ${f.additionalNotes.replace(/</g, '&lt;').replace(/>/g, '&gt;')}
                    </p>
                </div>`;
        }

        const ta     = this.aiSuggestionEnabled ? '#a855f7'               : '#1e40af';
        const tb     = this.aiSuggestionEnabled ? 'rgba(168,85,247,0.03)' : '#fafafa';
        const tc     = this.aiSuggestionEnabled ? 'rgba(168,85,247,0.2)'  : '#e2e8f0';
        const tl     = this.aiSuggestionEnabled ? '3px solid #a855f7'     : '3px solid #64748b';
        const aiChip = this.aiSuggestionEnabled
            ? `<span style="margin-left:8px;font-size:10px;background:rgba(168,85,247,0.12);color:#a855f7;
                            padding:2px 10px;border-radius:10px;border:1px solid rgba(168,85,247,0.25);
                            font-weight:600;">&#10022; Einstein AI</span>`
            : '';

        return `
<div style="width:210mm;min-height:297mm;margin:0 auto;background:#ffffff;font-family:Georgia,serif;
            color:#1a1a2e;box-shadow:0 0 40px rgba(0,0,0,0.15);box-sizing:border-box;padding:0;position:relative;">

  <!-- LETTERHEAD -->
  <div style="background:linear-gradient(135deg,#0f172a 0%,#1e3a5f 60%,#1e40af 100%);
              padding:36px 48px 28px;position:relative;overflow:hidden;">
    <div style="position:absolute;top:-40px;right:-40px;width:180px;height:180px;
                border-radius:50%;background:rgba(255,255,255,0.04);"></div>
    <div style="display:flex;justify-content:space-between;align-items:flex-start;position:relative;z-index:1;">
      <div>
        <div style="font-size:22px;font-weight:700;color:#ffffff;letter-spacing:1px;
                    font-family:Arial,sans-serif;margin-bottom:4px;">
          ${f.companyName || '(Company Name not provided)'}
        </div>
        <div style="font-size:11px;color:rgba(255,255,255,0.55);letter-spacing:2px;
                    text-transform:uppercase;font-family:Arial,sans-serif;">
          ${this.tplContractType || 'Official Document'}
        </div>
      </div>
      <div style="text-align:right;">
        <div style="font-size:10px;color:rgba(255,255,255,0.45);font-family:Arial,sans-serif;
                    letter-spacing:1px;text-transform:uppercase;margin-bottom:4px;">Document Reference</div>
        <div style="font-size:13px;color:#93c5fd;font-family:Courier New,monospace;font-weight:700;letter-spacing:1px;">${docRef}</div>
        <div style="font-size:10px;color:rgba(255,255,255,0.45);font-family:Arial,sans-serif;margin-top:6px;">${today}</div>
      </div>
    </div>
    <div style="margin-top:24px;border-top:1px solid rgba(255,255,255,0.12);padding-top:20px;position:relative;z-index:1;">
      <div style="font-size:26px;font-weight:400;color:#ffffff;letter-spacing:0.5px;font-family:Georgia,serif;line-height:1.2;">
        ${this.tplName || 'Official Agreement'}
      </div>
      <div style="margin-top:8px;display:flex;gap:16px;flex-wrap:wrap;">
        <span style="background:rgba(255,255,255,0.1);border:1px solid rgba(255,255,255,0.15);color:rgba(255,255,255,0.75);padding:3px 12px;border-radius:20px;font-size:10.5px;font-family:Arial,sans-serif;">${this.tplRegion || 'Global'}</span>
        <span style="background:rgba(99,179,237,0.15);border:1px solid rgba(99,179,237,0.25);color:#93c5fd;padding:3px 12px;border-radius:20px;font-size:10.5px;font-family:Arial,sans-serif;">${compliance.act}</span>
        <span style="background:rgba(52,211,153,0.12);border:1px solid rgba(52,211,153,0.2);color:#6ee7b7;padding:3px 12px;border-radius:20px;font-size:10.5px;font-family:Arial,sans-serif;">${this.tplRole || 'Professional'}</span>
        ${this.aiSuggestionEnabled ? `<span style="background:rgba(168,85,247,0.15);border:1px solid rgba(168,85,247,0.3);color:#c4b5fd;padding:3px 12px;border-radius:20px;font-size:10.5px;font-family:Arial,sans-serif;">&#10022; Einstein AI</span>` : ''}
      </div>
    </div>
  </div>

  <!-- BODY -->
  <div style="padding:40px 48px;">

    <!-- Parties -->
    <div style="margin-bottom:32px;">
      <div style="display:flex;gap:8px;align-items:center;margin-bottom:16px;">
        <div style="width:3px;height:20px;background:linear-gradient(#1e40af,#3b82f6);border-radius:2px;"></div>
        <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;font-family:Arial,sans-serif;font-weight:600;">Parties to this Agreement</div>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
        <div style="border:1px solid #e2e8f0;border-radius:10px;padding:18px 20px;background:#f8fafc;">
          <div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#94a3b8;font-family:Arial,sans-serif;margin-bottom:8px;">Employee / Party A</div>
          <div style="font-size:15px;font-weight:700;color:#0f172a;margin-bottom:4px;">${f.employeeName || '—'}</div>
          <div style="font-size:12px;color:#64748b;font-family:Arial,sans-serif;">${f.position || this.tplRole || '—'}</div>
          ${f.department ? `<div style="font-size:12px;color:#64748b;font-family:Arial,sans-serif;">${f.department}</div>` : ''}
          ${f.address    ? `<div style="font-size:11px;color:#94a3b8;font-family:Arial,sans-serif;margin-top:6px;">${f.address}</div>` : ''}
        </div>
        <div style="border:1px solid #e2e8f0;border-radius:10px;padding:18px 20px;background:#f8fafc;">
          <div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#94a3b8;font-family:Arial,sans-serif;margin-bottom:8px;">Company / Party B</div>
          <div style="font-size:15px;font-weight:700;color:#0f172a;margin-bottom:4px;">${f.companyName || '—'}</div>
          <div style="font-size:12px;color:#64748b;font-family:Arial,sans-serif;">Employer / Authorised Representative</div>
        </div>
      </div>
    </div>

    <!-- Meta bar -->
    <div style="background:linear-gradient(135deg,#eff6ff,#f0fdf4);border:1px solid #bfdbfe;border-radius:10px;padding:16px 24px;margin-bottom:28px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;">
      <div><div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#3b82f6;font-family:Arial,sans-serif;margin-bottom:4px;">Effective Date</div><div style="font-size:14px;font-weight:700;color:#1e3a5f;">${effectiveFormatted}</div></div>
      <div style="width:1px;height:32px;background:#bfdbfe;"></div>
      <div><div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#3b82f6;font-family:Arial,sans-serif;margin-bottom:4px;">Expiry / End Date</div><div style="font-size:14px;font-weight:700;color:#1e3a5f;">${expiryFormatted}</div></div>
      <div style="width:1px;height:32px;background:#bfdbfe;"></div>
      <div><div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#3b82f6;font-family:Arial,sans-serif;margin-bottom:4px;">Document Type</div><div style="font-size:14px;font-weight:700;color:#1e3a5f;">${this.tplContractType || 'Agreement'}</div></div>
      <div style="width:1px;height:32px;background:#bfdbfe;"></div>
      <div><div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#3b82f6;font-family:Arial,sans-serif;margin-bottom:4px;">Jurisdiction</div><div style="font-size:14px;font-weight:700;color:#1e3a5f;">${this.tplRegion || 'Global'}</div></div>
    </div>

    <!-- Preamble -->
    <div style="margin-bottom:28px;">
      <div style="display:flex;gap:8px;align-items:center;margin-bottom:12px;">
        <div style="width:3px;height:20px;background:linear-gradient(#1e40af,#3b82f6);border-radius:2px;"></div>
        <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;font-family:Arial,sans-serif;font-weight:600;">Preamble</div>
      </div>
      <p style="font-size:13.5px;line-height:1.8;color:#334155;margin:0;">${this.introSentence}</p>
    </div>

    <!-- S1: Data Protection -->
    <div style="background:#fafafa;border:1px solid #e2e8f0;border-left:3px solid #1e40af;border-radius:0 8px 8px 0;padding:18px 22px;margin-bottom:28px;">
      <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#1e40af;font-family:Arial,sans-serif;font-weight:700;margin-bottom:12px;">1. Data Protection &amp; Compliance — ${compliance.act}</div>
      ${complianceBody}
    </div>

    <!-- S2: Terms & Conditions -->
    <div style="margin-bottom:28px;">
      <div style="display:flex;gap:8px;align-items:center;margin-bottom:12px;">
        <div style="width:3px;height:20px;background:linear-gradient(${ta},${ta});border-radius:2px;"></div>
        <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;font-family:Arial,sans-serif;font-weight:600;">2. Terms &amp; Conditions${aiChip}</div>
      </div>
      <div style="background:${tb};border:1px solid ${tc};border-left:${tl};border-radius:0 8px 8px 0;padding:18px 22px;">
        ${termsBody}
      </div>
    </div>

    <!-- S3: Signatures -->
    <div style="margin-bottom:16px;">
      <div style="display:flex;gap:8px;align-items:center;margin-bottom:20px;">
        <div style="width:3px;height:20px;background:linear-gradient(#1e40af,#3b82f6);border-radius:2px;"></div>
        <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;font-family:Arial,sans-serif;font-weight:600;">3. Execution &amp; Signatures</div>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:32px;">
        <div style="border:1px solid #e2e8f0;border-radius:10px;padding:20px 22px;background:#f8fafc;">
          <div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#94a3b8;font-family:Arial,sans-serif;margin-bottom:12px;">Employee / Party A</div>
          <div style="border-bottom:1.5px solid #334155;margin-bottom:10px;min-height:42px;"></div>
          <div style="font-size:12px;color:#64748b;font-family:Arial,sans-serif;line-height:1.8;">
            <div>Name: <strong style="color:#0f172a;">${f.employeeName || '___________________________'}</strong></div>
            <div>Title: ${f.position || '___________________________'}</div>
            <div>Date: ___________________________</div>
          </div>
        </div>
        <div style="border:1px solid #e2e8f0;border-radius:10px;padding:20px 22px;background:#f8fafc;">
          <div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#94a3b8;font-family:Arial,sans-serif;margin-bottom:12px;">Authorised Representative / Party B</div>
          <div style="border-bottom:1.5px solid #334155;margin-bottom:10px;min-height:42px;"></div>
          <div style="font-size:12px;color:#64748b;font-family:Arial,sans-serif;line-height:1.8;">
            <div>Name: ___________________________</div>
            <div>Title: ___________________________</div>
            <div>Date: ___________________________</div>
          </div>
        </div>
      </div>
    </div>

  </div>

  <!-- FOOTER -->
  <div style="border-top:1px solid #e2e8f0;padding:14px 48px;display:flex;justify-content:space-between;align-items:center;background:#f8fafc;">
    <div style="font-size:10px;color:#94a3b8;font-family:Arial,sans-serif;">${f.companyName || 'Company'} · ${this.tplName || 'Agreement'} · Ref: ${docRef}</div>
    <div style="font-size:10px;color:#94a3b8;font-family:Arial,sans-serif;">Generated ${today}${this.aiSuggestionEnabled ? ' · &#10022; Einstein AI' : ''} · ${compliance.act}</div>
    <div style="font-size:10px;color:#94a3b8;font-family:Arial,sans-serif;">Page 1 of 1</div>
  </div>

</div>`;
    }

    // ── HELPERS ────────────────────────────────────────────────────────────
    _nowStr() {
        return new Date().toLocaleString('en-US', {
            year: 'numeric', month: 'short', day: 'numeric',
            hour: '2-digit', minute: '2-digit'
        });
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}