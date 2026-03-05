// docflowDocuments.js
import { LightningElement, track } from 'lwc';
import { NavigationMixin }         from 'lightning/navigation';
import { ShowToastEvent }          from 'lightning/platformShowToastEvent';

import getDocumentsForViewer       from '@salesforce/apex/DocumentGenerationController.getDocumentsForViewer';
import getDocumentDetailsForViewer from '@salesforce/apex/DocumentGenerationController.getDocumentDetailsForViewer';
import initiateSignatureRequest    from '@salesforce/apex/SignatureRequestController.initiateSignatureRequest';
import sendReminderEmail           from '@salesforce/apex/SignatureRequestController.sendReminderEmail';

const STATUS_LABELS = {
    'GENERATED':       'Generated',
    'COMPLIANT':       'Compliant',
    'REQUIRES_REVIEW': 'Requires Review',
    'DRAFT':           'Draft',
    'SENT':            'Sent',
    'SIGNED':          'Signed',
};

// ── Jurisdiction logic lives ONLY in Apex (resolveJurisdictionLabel) ──────────
// JS reads doc.Jurisdiction_Label__c which is stored on the record at generation
// time. No COMPLIANCE map needed here — single source of truth is Apex.
// ─────────────────────────────────────────────────────────────────────────────

export default class DocflowDocuments extends NavigationMixin(LightningElement) {

    @track documents         = [];
    @track filteredDocuments = [];
    @track isLoading         = false;
    @track searchTerm        = '';

    @track showViewModal       = false;
    @track isLoadingView       = false;
    @track viewDocContent      = '';
    @track viewingDocName      = '';
    @track viewingContentDocId = '';
    _viewingDoc                = null;

    @track showSendModal  = false;
    @track isSending      = false;
    @track hasSendError   = false;
    @track sendErrorMsg   = '';
    @track sendingDocId   = '';
    @track sendingDocName = '';
    @track sendingDocTpl  = '';
    @track sendData       = { signerName: '', signerEmail: '' };

    @track showReminderModal = false;
    @track isSendingReminder = false;
    @track reminderDocId     = '';
    @track reminderDocName   = '';

    @track toggleIpAnomaly       = false;
    @track toggleLocationAnomaly = false;
    @track toggleBehavAnomaly    = false;

    connectedCallback() { this.loadDocuments(); }

    // ══════════════════════════════════════════════════════
    // LOAD DOCUMENTS
    // ══════════════════════════════════════════════════════
    loadDocuments() {
        this.isLoading = true;
        getDocumentsForViewer()
            .then(data => {
                this.documents = (data || []).map(d => this._enrichDoc(d));
                this._applyFilters();
                this.isLoading = false;
            })
            .catch(err => {
                this.isLoading = false;
                this._toast('Error', err?.body?.message || 'Failed to load documents', 'error');
            });
    }

    _enrichDoc(d) {
        const status         = (d.Status__c || '').toUpperCase();
        const isSent         = status === 'SENT';
        const isSigned       = status === 'SIGNED';
        const shortId        = 'CONF-' + (d.Id || '').slice(-4).toUpperCase();
        const nameStr        = d.Name || '';
        const dashIdx        = nameStr.lastIndexOf(' - ');
        const templateLabel  = dashIdx > 0 ? nameStr.substring(0, dashIdx) : '';
        const recipientName  = d.Employee_Name__c || '';
        const recipientEmail = d.Employee_Email__c || d.EmployeeEmail__c || '';
        const sentRaw        = d.Last_Sent_Date__c || d.SentDate__c;
        const sentFmt        = sentRaw
            ? new Date(sentRaw).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
            : '';
        return {
            ...d,
            shortId, templateLabel, recipientName, recipientEmail, sentFmt,
            createdFmt:     new Date(d.CreatedDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
            statusLabel:    STATUS_LABELS[status] || d.Status__c || '—',
            statusClass:    this._statusCls(status),
            isSent, isSigned,
            isSentOrSigned: isSent || isSigned,
        };
    }

    _applyFilters() {
        let list = [...this.documents];
        if (this.searchTerm) {
            const q = this.searchTerm.toLowerCase();
            list = list.filter(d =>
                (d.Name          && d.Name.toLowerCase().includes(q))          ||
                (d.recipientName && d.recipientName.toLowerCase().includes(q)) ||
                (d.templateLabel && d.templateLabel.toLowerCase().includes(q))
            );
        }
        this.filteredDocuments = list;
    }

    get isEmpty() { return !this.isLoading && this.filteredDocuments.length === 0; }
    handleSearchChange(event) { this.searchTerm = event.target.value; this._applyFilters(); }

    // ══════════════════════════════════════════════════════
    // FRAUD DETECTION TOGGLES
    // ══════════════════════════════════════════════════════
    get ipToggleClass()       { return this.toggleIpAnomaly       ? 'dd-toggle dd-toggle-on' : 'dd-toggle dd-toggle-off'; }
    get locationToggleClass() { return this.toggleLocationAnomaly ? 'dd-toggle dd-toggle-on' : 'dd-toggle dd-toggle-off'; }
    get behavToggleClass()    { return this.toggleBehavAnomaly    ? 'dd-toggle dd-toggle-on' : 'dd-toggle dd-toggle-off'; }

    handleToggle(event) {
        const key = event.currentTarget.dataset.toggle;
        if (key === 'IP_ANOMALY')         this.toggleIpAnomaly       = !this.toggleIpAnomaly;
        if (key === 'LOCATION_ANOMALY')   this.toggleLocationAnomaly = !this.toggleLocationAnomaly;
        if (key === 'BEHAVIORAL_ANOMALY') this.toggleBehavAnomaly    = !this.toggleBehavAnomaly;
    }

    get _activeToggles() {
        const list = [];
        if (this.toggleIpAnomaly)       list.push('IP_ANOMALY');
        if (this.toggleLocationAnomaly) list.push('LOCATION_ANOMALY');
        if (this.toggleBehavAnomaly)    list.push('BEHAVIORAL_ANOMALY');
        return list;
    }

    // ══════════════════════════════════════════════════════
    // VIEW MODAL
    // ══════════════════════════════════════════════════════
    handleView(event) {
        const id  = event.currentTarget.dataset.id;
        const doc = this.documents.find(d => d.Id === id);
        if (!doc) return;

        this._viewingDoc         = doc;
        this.viewingDocName      = doc.Name;
        this.viewingContentDocId = doc.ContentDocumentString__c || '';
        this.viewDocContent      = ' ';
        this.showViewModal       = true;
        this.isLoadingView       = true;

        getDocumentDetailsForViewer({ recordId: id })
            .then(result => {
                this.isLoadingView  = false;
                const apexHtml      = result?.renderedContent || '';
                this.viewDocContent = apexHtml || ' ';

                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    const el = this.template.querySelector('.dd-modal-doc-wrap');
                    if (el) {
                        // If ContentVersion already contains a full signed document
                        // (has letterhead/signature — stored after signing),
                        // render it directly — DO NOT wrap it again
                        const isFullDoc = apexHtml.includes('SIGNATURE_BLOCK_EMPLOYEE') === false
                            && (apexHtml.includes('Execution') || apexHtml.includes('Party A')
                                || apexHtml.includes('Authorised Representative'));

                        if (isFullDoc) {
                            el.innerHTML = apexHtml;
                        } else {
                            el.innerHTML = this._buildDocumentHtml(apexHtml);
                        }
                    }
                }, 50);
            })
            .catch(err => {
                this.isLoadingView = false;
                this._toast('Error', err?.body?.message || 'Failed to load document', 'error');
            });
    }

    handleCloseModal() {
        this.showViewModal  = false;
        this.viewDocContent = '';
        this._viewingDoc    = null;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const c = this.template.querySelector('.dd-modal-doc-wrap');
            if (c) c.innerHTML = '';
        }, 0);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PROFESSIONAL A4 DOCUMENT BUILDER
    //
    // Jurisdiction badge: reads doc.Jurisdiction_Label__c (stored by Apex).
    // No COMPLIANCE map — Apex is the single source of truth.
    //
    // SIGNATURE PLACEHOLDER: "SIGNATURE_BLOCK_EMPLOYEE" is placed in the
    // Employee signature box. Apex submitSignature replaces this exact string
    // when stamping the signature — keeping the professional layout intact.
    // ══════════════════════════════════════════════════════════════════════════
    _buildDocumentHtml(apexHtml) {
        const doc = this._viewingDoc || {};

        const f = {
            employeeName:    doc.Employee_Name__c   || doc.recipientName || '',
            position:        doc.Position__c         || '',
            address:         doc.Address__c          || '',
            companyName:     doc.Company_Name__c     || '',
            effectiveDate:   doc.Effective_Date__c   || '',
            expiryDate:      doc.Expiry_Date__c      || '',
            department:      doc.Department__c       || '',
            additionalNotes: doc.Additional_Notes__c || '',
        };

        const tplName         = doc.templateLabel    || doc.Name || 'Official Agreement';
        const tplRegion       = doc.Region__c        || '';
        const tplRole         = doc.Role__c          || '';
        const tplContractType = doc.Contract_Type__c || doc.ContractType__c || '';

        // ── Jurisdiction: read from Apex-stored field, no JS map needed ──────
        const jurisdictionAct = doc.Jurisdiction_Label__c || 'Global Standards';
        // ─────────────────────────────────────────────────────────────────────

        const effectiveFormatted = f.effectiveDate
            ? new Date(f.effectiveDate + 'T12:00:00').toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })
            : '—';
        const expiryFormatted = f.expiryDate
            ? new Date(f.expiryDate + 'T12:00:00').toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })
            : '—';

        const today  = new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
        const docRef = doc.shortId || ('CONF-' + (doc.Id || '').slice(-4).toUpperCase());

        let introSentence = `This ${tplContractType || 'Agreement'} ("Agreement") is entered into between ${f.employeeName || '___'} ("Employee") and the Company ("${f.companyName || '___'}"). This Agreement defines the terms and conditions of employment.`;
        if (f.position || f.department) {
            const effDate = f.effectiveDate
                ? new Date(f.effectiveDate + 'T12:00:00').toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
                : '___';
            introSentence += ` ${f.employeeName || '___'} will serve as ${f.position || 'the designated role'}${f.department ? ' in the ' + f.department + ' department' : ''}, effective ${effDate}.`;
        }

        const termsText = `${f.employeeName || 'The employee'} must comply with ${tplRegion || 'applicable'} regulations and company policies. They are responsible for team governance, compliance enforcement, and reporting obligations.`;

        const apexSection = (apexHtml && apexHtml.trim())
            ? apexHtml
            : (doc.GeneratedClause__c && doc.GeneratedClause__c.trim())
                ? `<div style="font-size:13px;line-height:1.8;color:#334155;">${doc.GeneratedClause__c.replace(/\n/g, '<br/>')}</div>`
                : '<p style="color:#94a3b8;font-style:italic;">Standard employment terms apply as per the selected template and jurisdiction.</p>';

        return `
<div style="width:100%;max-width:860px;margin:0 auto;background:#ffffff;font-family:'Georgia',serif;color:#1a1a2e;box-shadow:0 0 40px rgba(0,0,0,0.15);box-sizing:border-box;padding:0;position:relative;">

<!-- LETTERHEAD -->
<div style="background:linear-gradient(135deg,#0f172a 0%,#1e3a5f 60%,#1e40af 100%);padding:36px 48px 28px;position:relative;overflow:hidden;">
    <div style="position:absolute;top:-40px;right:-40px;width:180px;height:180px;border-radius:50%;background:rgba(255,255,255,0.04);"></div>
    <div style="display:flex;justify-content:space-between;align-items:flex-start;position:relative;z-index:1;">
        <div>
            <div style="font-size:22px;font-weight:700;color:#ffffff;letter-spacing:1px;font-family:'Arial',sans-serif;margin-bottom:4px;">${f.companyName || 'Company Name'}</div>
            <div style="font-size:11px;color:rgba(255,255,255,0.55);letter-spacing:2px;text-transform:uppercase;font-family:'Arial',sans-serif;">${tplContractType || 'Official Document'}</div>
        </div>
        <div style="text-align:right;">
            <div style="font-size:10px;color:rgba(255,255,255,0.45);font-family:'Arial',sans-serif;letter-spacing:1px;text-transform:uppercase;margin-bottom:4px;">Document Reference</div>
            <div style="font-size:13px;color:#93c5fd;font-family:'Courier New',monospace;font-weight:700;letter-spacing:1px;">${docRef}</div>
            <div style="font-size:10px;color:rgba(255,255,255,0.45);font-family:'Arial',sans-serif;margin-top:6px;">${today}</div>
        </div>
    </div>
    <div style="margin-top:24px;border-top:1px solid rgba(255,255,255,0.12);padding-top:20px;position:relative;z-index:1;">
        <div style="font-size:26px;font-weight:400;color:#ffffff;letter-spacing:0.5px;font-family:'Georgia',serif;line-height:1.2;">${tplName}</div>
        <div style="margin-top:8px;display:flex;gap:16px;flex-wrap:wrap;">
            <span style="background:rgba(255,255,255,0.1);border:1px solid rgba(255,255,255,0.15);color:rgba(255,255,255,0.75);padding:3px 12px;border-radius:20px;font-size:10.5px;font-family:'Arial',sans-serif;">${tplRegion || 'Global'}</span>
            <span style="background:rgba(99,179,237,0.15);border:1px solid rgba(99,179,237,0.25);color:#93c5fd;padding:3px 12px;border-radius:20px;font-size:10.5px;font-family:'Arial',sans-serif;">${jurisdictionAct}</span>
            <span style="background:rgba(52,211,153,0.12);border:1px solid rgba(52,211,153,0.2);color:#6ee7b7;padding:3px 12px;border-radius:20px;font-size:10.5px;font-family:'Arial',sans-serif;">${tplRole || 'Professional'}</span>
        </div>
    </div>
</div>

<!-- BODY -->
<div style="padding:40px 48px;">

    <!-- PARTIES -->
    <div style="margin-bottom:32px;">
        <div style="display:flex;gap:8px;align-items:center;margin-bottom:16px;">
            <div style="width:3px;height:20px;background:linear-gradient(#1e40af,#3b82f6);border-radius:2px;"></div>
            <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;font-family:'Arial',sans-serif;font-weight:600;">Parties to this Agreement</div>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
            <div style="border:1px solid #e2e8f0;border-radius:10px;padding:18px 20px;background:#f8fafc;">
                <div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#94a3b8;font-family:'Arial',sans-serif;margin-bottom:8px;">Employee / Party A</div>
                <div style="font-size:15px;font-weight:700;color:#0f172a;margin-bottom:4px;">${f.employeeName || '—'}</div>
                <div style="font-size:12px;color:#64748b;font-family:'Arial',sans-serif;">${f.position || tplRole || '—'}</div>
                ${f.department ? `<div style="font-size:12px;color:#64748b;font-family:'Arial',sans-serif;">${f.department}</div>` : ''}
                ${f.address    ? `<div style="font-size:11px;color:#94a3b8;font-family:'Arial',sans-serif;margin-top:6px;">${f.address}</div>` : ''}
            </div>
            <div style="border:1px solid #e2e8f0;border-radius:10px;padding:18px 20px;background:#f8fafc;">
                <div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#94a3b8;font-family:'Arial',sans-serif;margin-bottom:8px;">Company / Party B</div>
                <div style="font-size:15px;font-weight:700;color:#0f172a;margin-bottom:4px;">${f.companyName || '—'}</div>
                <div style="font-size:12px;color:#64748b;font-family:'Arial',sans-serif;">Employer / Authorised Representative</div>
            </div>
        </div>
    </div>

    <!-- DATES BAR -->
    <div style="background:linear-gradient(135deg,#eff6ff,#f0fdf4);border:1px solid #bfdbfe;border-radius:10px;padding:16px 24px;margin-bottom:28px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;">
        <div><div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#3b82f6;font-family:'Arial',sans-serif;margin-bottom:4px;">Effective Date</div><div style="font-size:14px;font-weight:700;color:#1e3a5f;">${effectiveFormatted}</div></div>
        <div style="width:1px;height:32px;background:#bfdbfe;"></div>
        <div><div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#3b82f6;font-family:'Arial',sans-serif;margin-bottom:4px;">Expiry / End Date</div><div style="font-size:14px;font-weight:700;color:#1e3a5f;">${expiryFormatted}</div></div>
        <div style="width:1px;height:32px;background:#bfdbfe;"></div>
        <div><div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#3b82f6;font-family:'Arial',sans-serif;margin-bottom:4px;">Document Type</div><div style="font-size:14px;font-weight:700;color:#1e3a5f;">${tplContractType || 'Agreement'}</div></div>
        <div style="width:1px;height:32px;background:#bfdbfe;"></div>
        <div><div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#3b82f6;font-family:'Arial',sans-serif;margin-bottom:4px;">Jurisdiction</div><div style="font-size:14px;font-weight:700;color:#1e3a5f;">${tplRegion || 'Global'}</div></div>
    </div>

    <!-- PREAMBLE -->
    <div style="margin-bottom:28px;">
        <div style="display:flex;gap:8px;align-items:center;margin-bottom:12px;">
            <div style="width:3px;height:20px;background:linear-gradient(#1e40af,#3b82f6);border-radius:2px;"></div>
            <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;font-family:'Arial',sans-serif;font-weight:600;">Preamble</div>
        </div>
        <p style="font-size:13.5px;line-height:1.8;color:#334155;margin:0;">${introSentence}</p>
    </div>

    <!-- DATA PROTECTION / TEMPLATE BODY -->
    <div style="background:#fafafa;border:1px solid #e2e8f0;border-left:3px solid #3b82f6;border-radius:0 8px 8px 0;padding:18px 22px;margin-bottom:28px;">
        <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#3b82f6;font-family:'Arial',sans-serif;font-weight:600;margin-bottom:10px;">1. Data Protection &amp; Compliance — ${jurisdictionAct}</div>
        ${apexSection}
    </div>

    <!-- TERMS & CONDITIONS -->
    <div style="margin-bottom:28px;">
        <div style="display:flex;gap:8px;align-items:center;margin-bottom:12px;">
            <div style="width:3px;height:20px;background:linear-gradient(#1e40af,#3b82f6);border-radius:2px;"></div>
            <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;font-family:'Arial',sans-serif;font-weight:600;">2. Terms &amp; Conditions</div>
        </div>
        <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:16px 20px;">
            <p style="font-size:13px;line-height:1.8;color:#475569;margin:0 0 8px;">${termsText}</p>
            ${f.additionalNotes ? `<div style="margin-top:12px;padding-top:12px;border-top:1px dashed #e2e8f0;"><div style="font-size:11px;text-transform:uppercase;letter-spacing:1px;color:#94a3b8;font-family:'Arial',sans-serif;margin-bottom:6px;">Additional Notes / Special Clauses</div><p style="font-size:13px;line-height:1.75;color:#475569;margin:0;">${f.additionalNotes}</p></div>` : ''}
        </div>
    </div>

    <!-- SIGNATURES -->
    <div style="margin-bottom:16px;">
        <div style="display:flex;gap:8px;align-items:center;margin-bottom:20px;">
            <div style="width:3px;height:20px;background:linear-gradient(#1e40af,#3b82f6);border-radius:2px;"></div>
            <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;font-family:'Arial',sans-serif;font-weight:600;">3. Execution &amp; Signatures</div>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:32px;">
            <!-- Employee signature box — placeholder replaced by Apex on signing -->
            <div style="border:1px solid #e2e8f0;border-radius:10px;padding:20px 22px;background:#f8fafc;">
                <div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#94a3b8;font-family:'Arial',sans-serif;margin-bottom:12px;">Employee / Party A</div>
                <div style="border-bottom:1.5px solid #334155;margin-bottom:10px;min-height:56px;display:flex;align-items:flex-end;">
                    SIGNATURE_BLOCK_EMPLOYEE
                </div>
                <div style="font-size:12px;color:#64748b;font-family:'Arial',sans-serif;line-height:1.8;">
                    <div>Name: <strong style="color:#0f172a;">${f.employeeName || '___________________________'}</strong></div>
                    <div>Title: ${f.position || '___________________________'}</div>
                    <div>Date: ___________________________</div>
                </div>
            </div>
            <div style="border:1px solid #e2e8f0;border-radius:10px;padding:20px 22px;background:#f8fafc;">
                <div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#94a3b8;font-family:'Arial',sans-serif;margin-bottom:12px;">Authorised Representative / Party B</div>
                <div style="border-bottom:1.5px solid #334155;margin-bottom:10px;min-height:56px;"></div>
                <div style="font-size:12px;color:#64748b;font-family:'Arial',sans-serif;line-height:1.8;">
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
    <div style="font-size:10px;color:#94a3b8;font-family:'Arial',sans-serif;">${f.companyName || 'Company'} · ${tplName} · Ref: ${docRef}</div>
    <div style="font-size:10px;color:#94a3b8;font-family:'Arial',sans-serif;">Generated ${today} · Legally compliant · ${jurisdictionAct}</div>
    <div style="font-size:10px;color:#94a3b8;font-family:'Arial',sans-serif;">Page 1 of 1</div>
</div>

</div>`;
    }

    handleAudit(event) {
        const id = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigatesection', {
            detail: { section: 'audit', documentId: id }
        }));
    }

    // ══════════════════════════════════════════════════════
    // DOWNLOAD
    // ══════════════════════════════════════════════════════
    handleDownload(event) {
        const id  = event.currentTarget.dataset.id;
        const doc = this.documents.find(d => d.Id === id);
        if (!doc) return;
        this._viewingDoc = doc;
        getDocumentDetailsForViewer({ recordId: id })
            .then(result => {
                const apexHtml = result?.renderedContent || '';
                this._downloadHtml(this._buildDocumentHtml(apexHtml), doc.Name);
            })
            .catch(() => {
                const cdid = event.currentTarget.dataset.cdid;
                if (cdid) this._navigateToFile(cdid);
                else this._toast('Error', 'No file linked to this document.', 'error');
            });
    }

    handleDownloadFromModal() {
        if (this._viewingDoc) {
            const apexHtml = this.viewDocContent || '';
            this._downloadHtml(this._buildDocumentHtml(apexHtml), this.viewingDocName);
        }
    }

    _downloadHtml(docInnerHtml, docName) {
        const fileName = (docName || 'Document').replace(/[^a-z0-9_\-\s]/gi, '') + '.html';
        const fullHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <title>${docName || 'Document'}</title>
  <style>* { box-sizing:border-box; margin:0; padding:0; } body { background:#e8ecf0; padding:32px 16px; font-family:Georgia,serif; } @media print { body { background:#fff; padding:0; } }</style>
</head>
<body>${docInnerHtml}</body>
</html>`;
        try {
            const encoded   = 'data:text/html;charset=utf-8,' + encodeURIComponent(fullHtml);
            const a         = document.createElement('a');
            a.href          = encoded;
            a.download      = fileName;
            a.style.display = 'none';
            document.body.appendChild(a);
            a.click();
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => document.body.removeChild(a), 200);
        } catch (e) {
            const blob = new Blob([fullHtml], { type: 'text/html' });
            const url  = URL.createObjectURL(blob);
            window.open(url, '_blank');
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => URL.revokeObjectURL(url), 10000);
        }
    }

    _navigateToFile(contentDocumentId) {
        if (!contentDocumentId) { this._toast('Error', 'No file linked to this document.', 'error'); return; }
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: contentDocumentId },
        });
    }

    // ══════════════════════════════════════════════════════
    // SEND FOR SIGNATURE
    // ══════════════════════════════════════════════════════
    handleSendForSignature(event) {
        const btn = event.currentTarget;
        this.sendingDocId   = btn.dataset.id;
        this.sendingDocName = btn.dataset.name || '';
        this.sendingDocTpl  = btn.dataset.tpl  || '';
        this.sendData       = { signerName: '', signerEmail: '' };
        this.hasSendError   = false;
        this.isSending      = false;
        this.toggleIpAnomaly       = false;
        this.toggleLocationAnomaly = false;
        this.toggleBehavAnomaly    = false;
        this.showSendModal  = true;
    }

    handleCloseSendModal()  { this.showSendModal = false; this.isSending = false; this.hasSendError = false; }

    handleSendField(event) {
        const { name, value } = event.target;
        this.sendData     = { ...this.sendData, [name]: value };
        this.hasSendError = false;
    }

    handleConfirmSend() {
        if (!this.sendData.signerEmail) {
            this.hasSendError = true; this.sendErrorMsg = 'Signer email is required.'; return;
        }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.sendData.signerEmail)) {
            this.hasSendError = true; this.sendErrorMsg = 'Please enter a valid email address.'; return;
        }
        this.isSending = true;
        initiateSignatureRequest({
            documentId:    this.sendingDocId,
            signerEmail:   this.sendData.signerEmail,
            signerName:    this.sendData.signerName || this.sendData.signerEmail,
            activeToggles: this._activeToggles,
        })
        .then(() => {
            this.isSending     = false;
            this.showSendModal = false;
            this._toast('Sent ✓', `Document sent to ${this.sendData.signerEmail} for signature.`, 'success');
            this.documents = this.documents.map(d =>
                d.Id === this.sendingDocId
                    ? { ...d, Status__c: 'SENT', statusLabel: 'Sent', statusClass: this._statusCls('SENT'), isSent: true, isSentOrSigned: true }
                    : d
            );
            this._applyFilters();
        })
        .catch(err => {
            this.isSending    = false;
            this.hasSendError = true;
            this.sendErrorMsg = err?.body?.message || 'Failed to send. Please try again.';
        });
    }

    // ══════════════════════════════════════════════════════
    // REMINDER MODAL
    // ══════════════════════════════════════════════════════
    handleSendReminder(event) {
        const btn = event.currentTarget;
        this.reminderDocId     = btn.dataset.id;
        this.reminderDocName   = btn.dataset.name || 'Document';
        this.isSendingReminder = false;
        this.showReminderModal = true;
    }

    handleCloseReminderModal() { this.showReminderModal = false; this.isSendingReminder = false; }

    handleConfirmReminder() {
        this.isSendingReminder = true;
        sendReminderEmail({ documentId: this.reminderDocId })
            .then(() => {
                this.isSendingReminder = false;
                this.showReminderModal = false;
                this._toast('Reminder Sent ✓', 'Reminder email has been sent to the signer.', 'success');
            })
            .catch(err => {
                this.isSendingReminder = false;
                this._toast('Error', err?.body?.message || 'Failed to send reminder.', 'error');
            });
    }

    // ══════════════════════════════════════════════════════
    // NAVIGATION
    // ══════════════════════════════════════════════════════
    handleNewDocument() {
        this.dispatchEvent(new CustomEvent('navigatesection', { detail: { section: 'create' } }));
    }

    stopProp(event) { event.stopPropagation(); }

    _statusCls(s) {
        const m = {
            'GENERATED':       'dd-status dd-status-green',
            'COMPLIANT':       'dd-status dd-status-green',
            'REQUIRES_REVIEW': 'dd-status dd-status-amber',
            'DRAFT':           'dd-status dd-status-grey',
            'SENT':            'dd-status dd-status-blue',
            'SIGNED':          'dd-status dd-status-teal',
        };
        return m[s] || 'dd-status dd-status-grey';
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}