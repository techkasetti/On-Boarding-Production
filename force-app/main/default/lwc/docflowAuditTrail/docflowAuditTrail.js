// docflowAuditTrail.js
import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent }               from 'lightning/platformShowToastEvent';
import getAuditTrail         from '@salesforce/apex/AuditTrailManager.getAuditTrail';
import getDocumentsForViewer from '@salesforce/apex/DocumentGenerationController.getDocumentsForViewer';

// ── Icon map ───────────────────────────────────────────────────────────────
const ACTION_MAP = [
    { keys: ['document generated', 'created'],                      cls: 'at-dot-indigo', glyph: '✦' },
    { keys: ['stored in repository', 'document stored', 'storage'], cls: 'at-dot-indigo', glyph: '⬆' },
    { keys: ['signature requested', 'request sent'],                cls: 'at-dot-blue',   glyph: '→' },
    { keys: ['reminder sent', 'signature reminder'],                cls: 'at-dot-blue',   glyph: '⏰' },
    { keys: ['signature viewed', 'document viewed', 'viewed'],     cls: 'at-dot-amber',  glyph: '👁' },
    { keys: ['signature completed', 'signed'],                     cls: 'at-dot-green',  glyph: '✓' },
    { keys: ['uploaded to s3', 'signed document uploaded'],        cls: 'at-dot-green',  glyph: '⬆' },
    { keys: ['downloaded'],                                        cls: 'at-dot-amber',  glyph: '↙' },
    { keys: ['declined'],                                          cls: 'at-dot-red',    glyph: '✕' },
    { keys: ['expired'],                                           cls: 'at-dot-red',    glyph: '⚠' },
    { keys: ['requires review', 'review'],                         cls: 'at-dot-amber',  glyph: '⚠' },
];

function matchAction(action) {
    const a = (action || '').toLowerCase();
    for (const entry of ACTION_MAP) {
        if (entry.keys.some(k => a.includes(k))) return entry;
    }
    return { cls: 'at-dot-indigo', glyph: '·' };
}

export default class DocflowAuditTrail extends LightningElement {

    @api documentId;

    @track isLoading       = true;
    @track documentOptions = [];
    @track auditEvents     = [];
    @track signatories     = [];
    @track shaHash         = '—';

    @track selectedDoc = {
        name:          '—',
        region:        '—',
        compliance:    '—',
        aiModel:       '—',
        signer:        '—',
        status:        '—',
        regionTagCls:  'at-tag at-tag-blue',
        compTagCls:    'at-tag at-tag-teal',
        statusPillCls: 'at-pill at-pill-draft',
    };

    _allEvents     = [];
    _allDocs       = [];
    _selectedDocId = null;

    // ══════════════════════════════════════════════════════
    connectedCallback() {
        this._selectedDocId = this.documentId || null;
        this._loadAll();
    }

    // ── Load everything in parallel ────────────────────────────────────────
    _loadAll() {
        this.isLoading = true;
        Promise.all([
            getDocumentsForViewer(),
            getAuditTrail({ limitCount: 500 }),
        ])
        .then(([docs, events]) => {
            this._allDocs   = docs   || [];
            this._allEvents = events || [];

            // Build dropdown showing Template Name (or doc name) + CONF-XXXX ref
            this.documentOptions = this._allDocs.map((d, i) => {
                const confId    = 'CONF-' + (d.Id || '').slice(-4).toUpperCase();
                // Use Template Name if available, otherwise fall back to doc name
                const tplName   = d.Template_Name__c || d.TemplateName__c || d.DocumentTitle__c || d.Name || 'Untitled';
                const label     = tplName + '  —  ' + confId;
                const isDefault = this._selectedDocId
                    ? d.Id === this._selectedDocId
                    : i === 0;
                return { value: d.Id, label, isDefault };
            });

            // Default selection
            if (!this._selectedDocId && this._allDocs.length) {
                this._selectedDocId = this._allDocs[0].Id;
            }

            if (this._selectedDocId) {
                this._applyDoc(this._selectedDocId);
            } else {
                this.isLoading = false;
            }
        })
        .catch(err => {
            this._toast('Error', err?.body?.message || 'Failed to load data', 'error');
            this.isLoading = false;
        });
    }

    // ── Filter + render events for a specific document ─────────────────────
    _applyDoc(docId) {
        // Populate left panel
        const rawDoc = this._allDocs.find(d => d.Id === docId);
        if (rawDoc) this._buildSelectedDoc(rawDoc);

        // ── KEY FIX: filter using DocumentId__c ──
        // IMPORTANT: getAuditTrail() Apex SELECT must include DocumentId__c and RecordId__c
        // If not, update the SELECT in AuditTrailManager.cls (see AuditTrailManager_fix.apex)
        const filtered = this._allEvents.filter(e => {
            const docMatch    = e.DocumentId__c === docId;
            const recordMatch = e.RecordId__c   === docId;

            // Fallback: search Details__c for the CONF-XXXX reference ID
            const confRef  = 'CONF-' + docId.slice(-4).toUpperCase();
            const detailMatch = (e.Details__c || '').includes(confRef)
                             || (e.Details__c || '').includes(docId);

            return docMatch || recordMatch || detailMatch;
        });

        this.auditEvents = filtered.map((e, i, arr) =>
            this._enrichEvent(e, i === arr.length - 1)
        );

        this._buildSignatories(filtered);
        this.isLoading = false;
    }

    // ── Build left panel doc object ────────────────────────────────────────
    _buildSelectedDoc(d) {
        const status   = d.Status__c || 'Generated';
        const region   = d.Region__c || d.ContractType__c || 'North America';
        const confId   = 'CONF-' + (d.Id || '').slice(-4).toUpperCase();
        const tplName  = d.Template_Name__c || d.TemplateName__c || '';
        // Show "Template Name — CONF-XXXX" as the document display name
        const dispName = tplName ? tplName + '  —  ' + confId : confId;

        this.selectedDoc = {
            name:       dispName,
            region,
            compliance: d.ComplianceStatus__c || 'ESIGN',
            aiModel:    d.AIModel__c || d.Role__c || 'Einstein Intent Detection',
            signer:     d.Employee_Name__c || d.EmployeeName__c || '—',
            status,
            regionTagCls:  'at-tag ' + this._regionCls(region),
            compTagCls:    'at-tag at-tag-teal',
            statusPillCls: 'at-pill ' + this._statusCls(status),
        };

        // Build SHA from doc ID
        this.shaHash = (d.Id || '').slice(0, 8).toLowerCase() +
            'afc000…' + (d.Id || '').slice(-8).toLowerCase();
    }

    // ── Enrich a single event row ──────────────────────────────────────────
    _enrichEvent(e, isLast) {
        const action  = e.Action__c  || '';
        const detail  = e.Details__c || '';
        const matched = matchAction(action);
        const dt      = e.Timestamp__c ? new Date(e.Timestamp__c) : null;
        const actLow  = action.toLowerCase();

        const label = action.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());

        const isReminder = actLow.includes('reminder');

        // Extract IP
        const ipMatch = detail.match(/\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b/);
        const ip      = ipMatch ? ipMatch[1] : null;

        // Build meta line
        const metaParts = [];
        if (ip) metaParts.push('IP: ' + ip);
        const sessionMatch  = detail.match(/session\s*#?([\w-]+)/i);
        if (sessionMatch)  metaParts.push('Session #' + sessionMatch[1]);
        const providerMatch = detail.match(/provider[:\s]+([^\n·,]+)/i);
        if (providerMatch) metaParts.push('Provider: ' + providerMatch[1].trim());
        const browserMatch  = detail.match(/chrome[\s/]+(\d+)/i);
        if (browserMatch)  metaParts.push('Chrome ' + browserMatch[1]);
        // User name from wire result
        if (e['User__r'] && e['User__r']['Name']) {
            metaParts.push('By: ' + e['User__r']['Name']);
        }
        const meta = metaParts.join(' · ');

        // Risk line for signed events
        let riskLine = null;
        if (actLow.includes('signature completed') || actLow.includes('signed')) {
            const timeMatch = detail.match(/time.to.sign[:\s]+([^\n·,]+)/i);
            const riskMatch = detail.match(/risk[:\s]+(\w+)\s*\(?score[:\s]+(\d+)\)?/i);
            if (timeMatch || riskMatch) {
                const rParts = [];
                if (timeMatch) rParts.push('Time-to-sign: ' + timeMatch[1].trim());
                if (riskMatch) rParts.push('Risk: ' + riskMatch[1] + ' (Score: ' + riskMatch[2] + ')');
                riskLine = rParts.join(' · ');
            }
        }

        return {
            id:         e.Id || ('evt-' + Math.random().toString(36).slice(2)),
            label,
            detail,
            meta,
            isLast,
            isReminder,
            riskLine,
            dotCls:  'at-dot ' + matched.cls,
            glyph:   matched.glyph,
            dateStr: dt ? dt.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : '',
            timeStr: dt ? dt.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) : '',
        };
    }

    // ── Build signatories from event details ───────────────────────────────
    _buildSignatories(events) {
        const map = {};
        for (const e of events) {
            const detail = e.Details__c || '';
            const actLow = (e.Action__c || '').toLowerCase();

            // "signed by NAME <email>"
            const signedMatch = detail.match(/signed by\s+([^<\n]+?)\s*<([^>]+)>/i);
            if (signedMatch) {
                const email = signedMatch[2].trim();
                if (!map[email]) map[email] = this._makeSig(signedMatch[1].trim(), email, 'Signed');
            }

            // "Email dispatched to email@domain.com"
            if (actLow.includes('signature requested')) {
                const emailMatch = detail.match(/to\s+([\w.+%-]+@[\w.+-]+\.\w+)/i);
                if (emailMatch) {
                    const email = emailMatch[1].trim();
                    if (!map[email]) map[email] = this._makeSig(email, email, 'Pending');
                }
            }
        }
        this.signatories = Object.values(map);
    }

    _makeSig(name, email, status) {
        const initials = name.split(/[\s@.]/).filter(Boolean)
            .map(n => n[0]).join('').toUpperCase().slice(0, 2) || '?';
        const isSigned = status === 'Signed';
        return {
            id: email, name, email, initials, status,
            avatarCls: 'at-sig-avatar' + (isSigned ? ' at-avatar-signed' : ''),
            pillCls:   'at-pill ' + (isSigned ? 'at-pill-signed' : 'at-pill-pending'),
        };
    }

    // ══════════════════════════════════════════════════════
    // HANDLERS
    // ══════════════════════════════════════════════════════
    handleDocumentSelect(event) {
        const id = event.target.value;
        this._selectedDocId = id;
        this._applyDoc(id);
    }

    handleExportLog() {
        if (!this.auditEvents.length) {
            this._toast('Nothing to export', 'No events for this document.', 'warning');
            return;
        }
        const headers = ['Event', 'Detail', 'Date', 'Time'];
        const rows    = this.auditEvents.map(e =>
            ['"' + e.label + '"',
             '"' + (e.detail || '').replace(/"/g, '""') + '"',
             e.dateStr, e.timeStr].join(',')
        );
        const csv  = [headers.join(','), ...rows].join('\n');
        const blob = new Blob([csv], { type: 'text/csv' });
        const url  = URL.createObjectURL(blob);
        const a    = document.createElement('a');
        a.href     = url;
        a.download = 'audit_' + (this.selectedDoc.name || 'export').replace(/[\s—]+/g, '_') + '.csv';
        a.click();
        URL.revokeObjectURL(url);
    }

    // ══════════════════════════════════════════════════════
    // COMPUTED
    // ══════════════════════════════════════════════════════
    get hasEvents()       { return this.auditEvents.length > 0; }
    get hasSignatories()  { return this.signatories.length > 0; }
    get eventCountLabel() { return this.auditEvents.length + ' event' + (this.auditEvents.length !== 1 ? 's' : ''); }

    // ══════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════
    _statusCls(s) {
        const m = {
            'Signed': 'at-pill-signed', 'SIGNED': 'at-pill-signed',
            'Generated': 'at-pill-signed', 'GENERATED': 'at-pill-signed',
            'COMPLIANT': 'at-pill-signed',
            'Sent': 'at-pill-sent', 'SENT': 'at-pill-sent',
            'Pending': 'at-pill-pending',
            'Draft':   'at-pill-draft',
            'Requires Review': 'at-pill-pending',
        };
        return m[s] || 'at-pill-draft';
    }

    _regionCls(r) {
        if (!r) return 'at-tag-blue';
        const rl = r.toLowerCase();
        if (rl.includes('north') || rl.includes('us'))    return 'at-tag-blue';
        if (rl.includes('eu')    || rl.includes('europe')) return 'at-tag-green';
        if (rl.includes('uk')    || rl.includes('asia'))   return 'at-tag-purple';
        return 'at-tag-blue';
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}