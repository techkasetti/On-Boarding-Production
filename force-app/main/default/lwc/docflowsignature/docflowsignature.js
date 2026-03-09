// docflowsignature.js  ── UPDATED
// KEY CHANGE:
//   _doFetch() now uses the stored renderedContent (the professional LWC HTML)
//   from getDocumentData() directly as the document preview, instead of calling
//   _buildDocumentHtml() which produced different output.
//
//   The stored HTML already contains SIGNATURE_BLOCK_EMPLOYEE placeholder so
//   submitSignature() in Apex can replace it correctly.
//
//   _buildDocumentHtml() method is KEPT as a fallback in case stored content is empty.

import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent }       from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import getSignatureRequest  from '@salesforce/apex/SignatureRequestController.getSignatureRequest';
import getDocumentData      from '@salesforce/apex/SignatureRequestController.getDocumentData';
import submitSignature      from '@salesforce/apex/SignatureRequestController.submitSignature';
import logSignatureViewed   from '@salesforce/apex/SignatureRequestController.logSignatureViewed';

export default class Docflowsignature extends LightningElement {

    @api requestId;

    @track resolvedId = null;

    @api
    get recordId() { return this.resolvedId || this.requestId || null; }
    set recordId(val) { if (val) this.resolvedId = val; }

    @track isLoading             = false;
    @track isSubmitting          = false;
    @track isFaceVerified        = false;
    @track documentReviewed      = false;
    @track isSignatureComplete   = false;
    @track documentReadConfirmed = false;
    @track accessDenied          = false;
    @track accessMessage         = '';

    @track signatureRequest   = null;
    @track documentTitle      = '';
    @track signerName         = '';
    @track shortRequestId     = '';
    @track completedTimestamp = '';

    _documentId        = null;
    _candidateId       = null;
    _pendingDocHtml    = null;
    _docInjected       = false;
    _docContentFetched = false;
    _faceContentVersionId = null;

    @track selectedMethod       = 'type';
    @track typedSignature       = '';
    @track uploadedSignatureUrl = '';
    @track uploadedFileId       = '';
    @track agreementAccepted    = false;

    isDrawing     = false;
    canvasContext = null;
    drawnSigData  = '';
    startTime     = null;
    userCoordinates = null;

    connectedCallback() {
        this.startTime = new Date();

        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                pos => { this.userCoordinates = `${pos.coords.latitude},${pos.coords.longitude}`; },
                () => {}
            );
        }

        const href      = window.location.href;
        const allParams = href.includes('?') ? href.split('?').slice(1).join('?') : '';
        const urlParams = new URLSearchParams(allParams.split('#')[0]);
        let   idFromUrl = urlParams.get('c__requestId');

        if (!idFromUrl && href.includes('#')) {
            const hashPart = href.split('#').slice(1).join('#');
            const hashQIdx = hashPart.indexOf('?');
            if (hashQIdx !== -1) {
                idFromUrl = new URLSearchParams(hashPart.substring(hashQIdx + 1)).get('c__requestId');
            }
        }

        if (idFromUrl) {
            this.resolvedId = idFromUrl;
            this.isLoading  = true;
        }
    }

    @wire(CurrentPageReference)
    getStateParameters(ref) {
        if (this.resolvedId) return;
        const idFromWire = ref?.state?.c__requestId;
        if (idFromWire) {
            this.resolvedId = idFromWire;
            this.isLoading  = true;
        }
    }

    @wire(getSignatureRequest, { requestId: '$resolvedId' })
    wiredRequest({ error, data }) {
        if (!this.resolvedId) { this.isLoading = false; return; }

        if (data) {
            this.signatureRequest = data;
            this.signerName       = data.SignerName__c || '';
            this.shortRequestId   = 'REQ-' + (data.Id || '').slice(-6).toUpperCase();
            this._candidateId     = data.Candidate__c || null;
            this._documentId      = data.Document_Lifecycle_Configuration__c || null;

            if (data.Status__c === 'Signed' || data.Status__c === 'Completed') {
                this.isSignatureComplete = true;
                this.isFaceVerified      = true;
                this.documentReviewed    = true;
            }

            logSignatureViewed({ requestId: this.resolvedId }).catch(() => {});
            this.isLoading = false;

        } else if (error) {
            this.isLoading    = false;
            this.accessDenied = true;
            this.accessMessage = error?.body?.message || 'You are not allowed to access this document.';
        }
    }

    renderedCallback() {
        if (this._pendingDocHtml && !this._docInjected) {
            const el = this.template.querySelector('.sp-doc-paper');
            if (el) {
                el.innerHTML         = this._pendingDocHtml;
                this._docInjected    = true;
                this._pendingDocHtml = null;
            }
        }
        if (this.isDrawSignature && !this.canvasContext) {
            this._initCanvas();
        }
    }

    // GETTERS
    get showBlocked()   { return !this.resolvedId; }
    get showComponent() { return !!this.resolvedId && !this.accessDenied; }
    get candidateId()   { return this._candidateId || null; }

    get step1Done() { return this.isFaceVerified; }
    get step2Done() { return this.documentReviewed; }

    get step1Class() { return this._sc(true,                 this.isFaceVerified); }
    get step2Class() { return this._sc(this.isFaceVerified,  this.documentReviewed); }
    get step3Class() { return this._sc(this.documentReviewed,this.isSignatureComplete); }
    get step4Class() { return this._sc(this.isSignatureComplete, false); }
    _sc(a, d) { return d ? 'sp-step sp-step-done' : a ? 'sp-step sp-step-active' : 'sp-step sp-step-todo'; }

    get tabTypeClass()   { return this.selectedMethod === 'type'   ? 'sp-method-tab sp-method-tab-active' : 'sp-method-tab'; }
    get tabDrawClass()   { return this.selectedMethod === 'draw'   ? 'sp-method-tab sp-method-tab-active' : 'sp-method-tab'; }
    get tabUploadClass() { return this.selectedMethod === 'upload' ? 'sp-method-tab sp-method-tab-active' : 'sp-method-tab'; }
    get isTypedSignature()  { return this.selectedMethod === 'type'; }
    get isDrawSignature()   { return this.selectedMethod === 'draw'; }
    get isUploadSignature() { return this.selectedMethod === 'upload'; }
    get isDocContinueDisabled() { return !this.documentReadConfirmed; }

    get isSubmitDisabled() {
        if (this.isSubmitting)                                        return true;
        if (!this.agreementAccepted)                                  return true;
        if (this.isTypedSignature  && !this.typedSignature.trim())    return true;
        if (this.isDrawSignature   && !this.drawnSigData)             return true;
        if (this.isUploadSignature && !this.uploadedSignatureUrl)     return true;
        return false;
    }

    // FACE VERIFICATION
    handleVerificationSuccess(event) {
        const detail = event.detail || {};
        if (detail.faceVerified !== true) return;
        this._faceContentVersionId = detail.faceContentVersionId || null;
        this._fetchDocumentContent(() => {
            this.isFaceVerified = true;
            this._docInjected   = false;
        });
    }

    // FETCH DOCUMENT CONTENT
    _fetchDocumentContent(onComplete) {
        if (this._docContentFetched) { if (onComplete) onComplete(); return; }

        if (!this._documentId) {
            let attempts = 0;
            const poll = setInterval(() => {
                attempts++;
                if (this._documentId) {
                    clearInterval(poll);
                    this._doFetch(onComplete);
                } else if (attempts >= 40) {
                    clearInterval(poll);
                    this._pendingDocHtml = '<p style="padding:32px;color:#ef4444;text-align:center;">Document preview not available.</p>';
                    this._docInjected = false;
                    if (onComplete) onComplete();
                }
            }, 250);
            return;
        }
        this._doFetch(onComplete);
    }

    _doFetch(onComplete) {
        this._docContentFetched = true;
        this.isLoading = true;

        getDocumentData({ documentId: this._documentId })
            .then(result => {
                this.isLoading = false;
                const doc = result?.document || {};
                this.documentTitle =
                    doc.DocumentTitle__c ||
                    doc.Name__c ||
                    doc.Name ||
                    'Document';

                // ★ KEY CHANGE: Use stored renderedContent (the LWC professional HTML)
                //   directly as the document preview. This is the same document the HR
                //   user generated and approved. No rebuilding needed.
                //
                //   Fallback: if stored content is empty (old records), rebuild from
                //   document fields using _buildDocumentHtml() as a safety net.
                const storedHtml = result?.renderedContent || '';

                if (storedHtml && storedHtml.trim().length > 100) {
                    // Use the stored professional HTML as-is
                    this._pendingDocHtml = storedHtml;
                } else {
                    // Fallback for old records that don't have LWC HTML stored
                    console.warn('[docflowsignature] No stored HTML found, using fallback builder');
                    this._pendingDocHtml = this._buildDocumentHtml(doc, storedHtml);
                }

                this._docInjected = false;
                if (onComplete) onComplete();
            })
            .catch(err => {
                this.isLoading = false;
                this._docContentFetched = false;
                this._pendingDocHtml = '<p style="padding:32px;color:#ef4444;text-align:center;font-size:13px;">Could not load document preview: ' +
                    (err?.body?.message || err?.message || 'Unknown error') + '</p>';
                this._docInjected = false;
                if (onComplete) onComplete();
            });
    }

    // DOCUMENT REVIEW
    handleDocReadChange(e) { this.documentReadConfirmed = e.target.checked; }
    handleProceedToSign()  { if (this.documentReadConfirmed) this.documentReviewed = true; }

    // SIGNATURE
    handleMethodTab(e)             { this.selectedMethod = e.currentTarget.dataset.method; this.canvasContext = null; this.drawnSigData = ''; }
    handleTypedSignatureChange(e)  { this.typedSignature = e.target.value; }
    handleAgreementChange(e)       { this.agreementAccepted = e.target.checked; }

    handleUploadFinished(e) {
        const files = e.detail.files;
        if (files?.length > 0) {
            this.uploadedFileId       = files[0].documentId;
            this.uploadedSignatureUrl = files[0].documentId;
        }
    }

    // SUBMIT
    async handleSubmitSignature() {
        if (!this.resolvedId) {
            this._toast('Error', 'Request ID is missing. Please reload the page.', 'error');
            return;
        }

        this.isSubmitting = true;

        let sigData, sigMethod;

        if (this.isTypedSignature) {
            sigData   = this.typedSignature.trim();
            sigMethod = 'Type';
        } else if (this.isDrawSignature) {
            sigData   = this.drawnSigData;
            sigMethod = 'Draw';
        } else if (this.isUploadSignature) {
            sigData   = this.uploadedFileId;
            sigMethod = 'Upload';
        }

        if (!sigData) {
            this.isSubmitting = false;
            this._toast('Error', 'Please provide a signature before submitting.', 'error');
            return;
        }

        const ts  = Math.round((new Date() - this.startTime) / 1000);
        const ip  = await this._getIp();
        const ctx = { timeToSign: ts, location: this.userCoordinates || null, ip: ip || null };

        try {
            const result = await submitSignature({
                requestId:            this.resolvedId,
                signatureData:        sigData,
                signatureMethod:      sigMethod,
                userContextJSON:      JSON.stringify(ctx),
                faceContentVersionId: this._faceContentVersionId || null
            });

            if (result === 'SUCCESS') {
                this.isSignatureComplete = true;
                this.completedTimestamp  = new Date().toLocaleString('en-US', {
                    month: 'short', day: 'numeric', year: 'numeric',
                    hour: '2-digit', minute: '2-digit'
                });
                this._toast('Signed ✓', 'Signature submitted successfully!', 'success');
            } else {
                this._toast('Info', result || 'Unexpected response.', 'info');
            }

        } catch (err) {
            this._toast(
                'Submission Failed',
                err?.body?.message || err?.message || 'An unexpected error occurred.',
                'error'
            );
        } finally {
            this.isSubmitting = false;
        }
    }

    // CANVAS
    _initCanvas() {
        const c = this.template.querySelector('.sp-canvas');
        if (!c) return;
        this.canvasContext = c.getContext('2d');
        this.canvasContext.strokeStyle = '#1e293b';
        this.canvasContext.lineWidth   = 2.5;
        this.canvasContext.lineCap     = 'round';
        this.canvasContext.lineJoin    = 'round';
    }
    startDrawing(e) { e.preventDefault(); this.isDrawing = true; const p = this._cp(e); this.canvasContext.beginPath(); this.canvasContext.moveTo(p.x, p.y); }
    draw(e)         { if (!this.isDrawing) return; e.preventDefault(); const p = this._cp(e); this.canvasContext.lineTo(p.x, p.y); this.canvasContext.stroke(); }
    stopDrawing()   { if (!this.isDrawing) return; this.isDrawing = false; this.canvasContext.closePath(); this.drawnSigData = this.template.querySelector('.sp-canvas').toDataURL('image/png'); }
    handleClearCanvas() { const c = this.template.querySelector('.sp-canvas'); this.canvasContext.clearRect(0, 0, c.width, c.height); this.drawnSigData = ''; }
    _cp(e) { const c = this.template.querySelector('.sp-canvas'); const r = c.getBoundingClientRect(); const s = e.touches ? e.touches[0] : e; return { x: s.clientX - r.left, y: s.clientY - r.top }; }

    // FALLBACK DOCUMENT HTML BUILDER
    // Used only when stored HTML is empty (old records created before this fix).
    // New records will always use the stored LWC HTML from ContentVersion.
    _buildDocumentHtml(doc, clauseHtml) {
        const f = {
            employeeName:    doc.Employee_Name__c    || '',
            companyName:     doc.Company_Name__c     || '',
            position:        doc.Position__c         || '',
            department:      doc.Department__c       || '',
            address:         doc.Address__c          || '',
            additionalNotes: doc.Additional_Notes__c || '',
            effectiveDate:   doc.Effective_Date__c   || '',
            expiryDate:      doc.Expiry_Date__c      || '',
        };

        const tplName = doc.DocumentTitle__c || doc.Name__c || doc.Name || 'Official Agreement';
        const tplR    = doc.Region__c        || '';
        const tplRole = doc.Role__c          || '';
        const tplCT   = doc.Contract_Type__c || '';
        const juris   = doc.Jurisdiction_Label__c || tplR || 'Global Standards';
        const ref     = 'CONF-' + (doc.Id || '').slice(-4).toUpperCase();
        const today   = new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
        const fd      = d => d ? new Date(d + 'T12:00:00').toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' }) : '—';

        const apex = (clauseHtml && clauseHtml.trim())
            ? `<div style="font-size:13px;line-height:1.8;color:#334155;">${clauseHtml.replace(/\n/g, '<br/>')}</div>`
            : '<p style="color:#94a3b8;font-style:italic;">Standard terms apply.</p>';

        return `<div style="width:100%;max-width:860px;margin:0 auto;background:#fff;font-family:'Georgia',serif;color:#1a1a2e;box-shadow:0 0 40px rgba(0,0,0,0.15);box-sizing:border-box;">
<div style="background:linear-gradient(135deg,#0f172a 0%,#1e3a5f 60%,#1e40af 100%);padding:36px 48px 28px;">
  <div style="display:flex;justify-content:space-between;align-items:flex-start;">
    <div>
      <div style="font-size:22px;font-weight:700;color:#fff;letter-spacing:1px;font-family:'Arial',sans-serif;margin-bottom:4px;">${f.companyName || 'Company'}</div>
      <div style="font-size:11px;color:rgba(255,255,255,0.55);letter-spacing:2px;text-transform:uppercase;font-family:'Arial',sans-serif;">${tplCT || 'Official Document'}</div>
    </div>
    <div style="text-align:right;">
      <div style="font-size:10px;color:rgba(255,255,255,0.45);font-family:'Arial',sans-serif;margin-bottom:4px;">Document Reference</div>
      <div style="font-size:13px;color:#93c5fd;font-family:'Courier New',monospace;font-weight:700;">${ref}</div>
      <div style="font-size:10px;color:rgba(255,255,255,0.45);font-family:'Arial',sans-serif;margin-top:6px;">${today}</div>
    </div>
  </div>
  <div style="margin-top:24px;border-top:1px solid rgba(255,255,255,0.12);padding-top:20px;">
    <div style="font-size:26px;font-weight:400;color:#fff;font-family:'Georgia',serif;">${tplName}</div>
    <div style="margin-top:8px;display:flex;gap:12px;flex-wrap:wrap;">
      <span style="background:rgba(255,255,255,0.1);border:1px solid rgba(255,255,255,0.15);color:rgba(255,255,255,0.75);padding:3px 12px;border-radius:20px;font-size:10.5px;font-family:'Arial',sans-serif;">${tplR || 'Global'}</span>
      <span style="background:rgba(99,179,237,0.15);border:1px solid rgba(99,179,237,0.25);color:#93c5fd;padding:3px 12px;border-radius:20px;font-size:10.5px;font-family:'Arial',sans-serif;">${juris}</span>
      <span style="background:rgba(52,211,153,0.12);border:1px solid rgba(52,211,153,0.2);color:#6ee7b7;padding:3px 12px;border-radius:20px;font-size:10.5px;font-family:'Arial',sans-serif;">${tplRole || 'Professional'}</span>
    </div>
  </div>
</div>
<div style="padding:40px 48px;">
  <div style="margin-bottom:32px;">
    <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;font-family:'Arial',sans-serif;font-weight:600;margin-bottom:16px;">Parties to this Agreement</div>
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
  <div style="background:#f0fdf4;border:1px solid #bfdbfe;border-left:3px solid #3b82f6;border-radius:0 8px 8px 0;padding:18px 22px;margin-bottom:28px;">
    <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#3b82f6;font-family:'Arial',sans-serif;font-weight:600;margin-bottom:10px;">1. Terms &amp; Clauses — ${juris}</div>
    ${apex}
  </div>
  <div style="margin-bottom:28px;">
    <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;font-family:'Arial',sans-serif;font-weight:600;margin-bottom:12px;">2. Agreement Details</div>
    <div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:10px;padding:16px 24px;display:flex;justify-content:space-between;flex-wrap:wrap;gap:12px;">
      <div><div style="font-size:10px;text-transform:uppercase;color:#3b82f6;font-family:'Arial',sans-serif;margin-bottom:4px;">Effective Date</div><div style="font-size:14px;font-weight:700;color:#1e3a5f;">${fd(f.effectiveDate)}</div></div>
      <div style="width:1px;background:#bfdbfe;"></div>
      <div><div style="font-size:10px;text-transform:uppercase;color:#3b82f6;font-family:'Arial',sans-serif;margin-bottom:4px;">Expiry Date</div><div style="font-size:14px;font-weight:700;color:#1e3a5f;">${fd(f.expiryDate)}</div></div>
      <div style="width:1px;background:#bfdbfe;"></div>
      <div><div style="font-size:10px;text-transform:uppercase;color:#3b82f6;font-family:'Arial',sans-serif;margin-bottom:4px;">Type</div><div style="font-size:14px;font-weight:700;color:#1e3a5f;">${tplCT || 'Agreement'}</div></div>
      <div style="width:1px;background:#bfdbfe;"></div>
      <div><div style="font-size:10px;text-transform:uppercase;color:#3b82f6;font-family:'Arial',sans-serif;margin-bottom:4px;">Jurisdiction</div><div style="font-size:14px;font-weight:700;color:#1e3a5f;">${juris}</div></div>
    </div>
    ${f.additionalNotes ? `<div style="margin-top:12px;padding:14px 18px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;"><div style="font-size:11px;text-transform:uppercase;letter-spacing:1px;color:#94a3b8;font-family:'Arial',sans-serif;margin-bottom:6px;">Additional Notes</div><p style="font-size:13px;line-height:1.75;color:#475569;margin:0;">${f.additionalNotes}</p></div>` : ''}
  </div>
  <div style="margin-bottom:16px;">
    <div style="font-size:11px;letter-spacing:2px;text-transform:uppercase;color:#64748b;font-family:'Arial',sans-serif;font-weight:600;margin-bottom:20px;">3. Execution &amp; Signatures</div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:32px;">
      <div style="border:1px solid #e2e8f0;border-radius:10px;padding:20px 22px;background:#f8fafc;">
        <div style="font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#94a3b8;font-family:'Arial',sans-serif;margin-bottom:12px;">Employee / Party A</div>
        <div style="border-bottom:1.5px solid #334155;margin-bottom:10px;min-height:56px;display:flex;align-items:flex-end;padding-bottom:4px;">SIGNATURE_BLOCK_EMPLOYEE</div>
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
<div style="border-top:1px solid #e2e8f0;padding:14px 48px;display:flex;justify-content:space-between;background:#f8fafc;">
  <div style="font-size:10px;color:#94a3b8;font-family:'Arial',sans-serif;">${f.companyName || 'Company'} · ${tplName} · Ref: ${ref}</div>
  <div style="font-size:10px;color:#94a3b8;font-family:'Arial',sans-serif;">Generated ${today} · ${juris}</div>
  <div style="font-size:10px;color:#94a3b8;font-family:'Arial',sans-serif;">Page 1 of 1</div>
</div></div>`;
    }

    // UTILITIES
    async _getIp() {
        try { const r = await fetch('https://api.ipify.org?format=json'); const d = await r.json(); return d.ip; }
        catch { return null; }
    }

    _toast(t, m, v) {
        this.dispatchEvent(new ShowToastEvent({ title: t, message: m, variant: v }));
    }
}