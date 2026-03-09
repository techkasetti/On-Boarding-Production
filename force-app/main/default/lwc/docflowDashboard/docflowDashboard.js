// docflowDashboard.js
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDashboardData from '@salesforce/apex/DocflowDashboardController.getDashboardData';

export default class DocflowDashboard extends LightningElement {

    @track isLoading = false;

    // Summary cards
    @track totalDocs            = 0;
    @track docsThisMonth        = 0;
    @track signedCount          = 0;
    @track signedThisMonth      = 0;
    @track pendingCount         = 0;
    @track expiringSoon         = 0;
    @track declinedExpiredCount = 0;
    @track declinedVsLastMonth  = 0;

    // Panels
    @track recentDocs    = [];
    @track expiringDocs  = [];
    @track recentSigners = [];

    // Fraud
    @track fraudLow  = 0;
    @track fraudHigh = 0;

    connectedCallback() { this.loadAll(); }

    loadAll() {
        this.isLoading = true;
        getDashboardData()
            .then(data => {
                this.isLoading = false;
                this._process(data);
            })
            .catch(err => {
                this.isLoading = false;
                console.error('[DocflowDashboard] error:', err);
                this._toast('Dashboard Error', err?.body?.message || 'Failed to load dashboard', 'error');
            });
    }

    _process(data) {
        const docs     = data.documents   || [];
        const requests = data.sigRequests || [];

        const now       = new Date();
        const thisMonth = now.getMonth();
        const thisYear  = now.getFullYear();

        // ── Summary counts ───────────────────────────────
        this.totalDocs     = docs.length;
        this.docsThisMonth = docs.filter(d => {
            const c = new Date(d.CreatedDate);
            return c.getMonth() === thisMonth && c.getFullYear() === thisYear;
        }).length;

        const signedReqs = requests.filter(r =>
            (r.Status__c || '').toUpperCase() === 'SIGNED'
        );
        this.signedCount     = signedReqs.length;
        this.signedThisMonth = signedReqs.filter(r => {
            const c = new Date(r.CompletedDate__c || r.CreatedDate);
            return c.getMonth() === thisMonth && c.getFullYear() === thisYear;
        }).length;

        const pendingReqs = requests.filter(r => {
            const s = (r.Status__c || '').toUpperCase();
            return s === 'PENDING' || s === 'SENT';
        });
        this.pendingCount = pendingReqs.length;

        const in30 = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
        const expiringList = docs.filter(d =>
            d.Expiry_Date__c &&
            new Date(d.Expiry_Date__c) >= now &&
            new Date(d.Expiry_Date__c) <= in30
        );
        this.expiringSoon = expiringList.length;

        const declinedReqs = requests.filter(r => {
            const s = (r.Status__c || '').toUpperCase();
            return s === 'DECLINED' || s === 'EXPIRED';
        });
        const expiredDocs = docs.filter(d =>
            d.Expiry_Date__c &&
            new Date(d.Expiry_Date__c) < now &&
            !signedReqs.find(r => r.Document_Lifecycle_Configuration__c === d.Id)
        );
        this.declinedExpiredCount = declinedReqs.length + expiredDocs.length;
        this.declinedVsLastMonth  = 5;

        // ── Fraud ─────────────────────────────────────────
        this.fraudLow = signedReqs.filter(r => {
            const l = (r.Fraud_Risk_Level__c || '').toUpperCase();
            return l === 'LOW' || l === '' || l === 'NOT ANALYZED';
        }).length;
        this.fraudHigh = signedReqs.filter(r => {
            const l = (r.Fraud_Risk_Level__c || '').toUpperCase();
            return l === 'HIGH' || l === 'CRITICAL';
        }).length;

        // ── Recent Documents table ────────────────────────
        // For each doc, find its matching signed/pending request
        this.recentDocs = docs.slice(0, 10).map(d => {
            const docStatus = (d.Status__c || '').toUpperCase();

            // Find the most recent signature request for this doc
            const matchedReq = requests
                .filter(r => r.Document_Lifecycle_Configuration__c === d.Id)
                .sort((a, b) => new Date(b.CreatedDate) - new Date(a.CreatedDate))[0];

            const isSigned  = matchedReq && (matchedReq.Status__c || '').toUpperCase() === 'SIGNED';
            const isPending = matchedReq && ((matchedReq.Status__c || '').toUpperCase() === 'PENDING' || (matchedReq.Status__c || '').toUpperCase() === 'SENT');

            // Status label and class
            let statusLabel = 'Generated';
            let statusClass = 'dfd-status-badge dfd-status-generated';
            if (isSigned) {
                statusLabel = 'Signed';
                statusClass = 'dfd-status-badge dfd-status-signed';
            } else if (isPending) {
                statusLabel = 'Pending';
                statusClass = 'dfd-status-badge dfd-status-pending';
            } else if (docStatus === 'SIGNED') {
                statusLabel = 'Signed';
                statusClass = 'dfd-status-badge dfd-status-signed';
            } else if (docStatus === 'SENT') {
                statusLabel = 'Sent';
                statusClass = 'dfd-status-badge dfd-status-pending';
            }

            // Format dates
            const fmtDate = dt => dt
                ? new Date(dt).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
                : '—';

            // Short doc ref from ID
            const ref = 'CONF-' + (d.Id || '').slice(-4).toUpperCase();

            return {
                id:           d.Id,
                name:         d.Name || '—',
                ref:          ref,
                employee:     d.Employee_Name__c || '—',
                contractType: d.Contract_Type__c || d.ContractType__c || '—',
                createdFmt:   fmtDate(d.CreatedDate),
                statusLabel:  statusLabel,
                statusClass:  statusClass,
                signerName:   matchedReq ? (matchedReq.SignerName__c || matchedReq.SignerEmail__c || '—') : '—',
                signedOnFmt:  (isSigned && matchedReq.CompletedDate__c) ? fmtDate(matchedReq.CompletedDate__c) : '—',
                rowClass:     isSigned ? 'dfd-doc-row dfd-row-signed' : 'dfd-doc-row',
            };
        });

        // ── Expiring docs ─────────────────────────────────
        this.expiringDocs = expiringList.slice(0, 5).map(d => {
            const expDate  = new Date(d.Expiry_Date__c);
            const daysLeft = Math.ceil((expDate - now) / (1000 * 60 * 60 * 24));
            return {
                id:           d.Id,
                name:         d.Name || '—',
                employee:     d.Employee_Name__c || '—',
                contractType: d.Contract_Type__c || d.ContractType__c || '—',
                daysLabel:    daysLeft <= 7 ? daysLeft + 'd left' : daysLeft + ' days',
                daysClass:    daysLeft <= 7 ? 'dfd-days-urgent' : 'dfd-days-warn',
            };
        });

        // ── Recent signers ────────────────────────────────
        this.recentSigners = signedReqs.slice(0, 5).map(r => {
            const name     = r.SignerName__c || 'Unknown';
            const initials = name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
            const method   = r.SignatureMethod__c || '—';
            return {
                id:          r.Id,
                name:        name,
                email:       r.SignerEmail__c || '',
                initials:    initials,
                method:      method,
                methodClass: method === 'Draw'
                    ? 'dfd-method-badge dfd-method-draw'
                    : method === 'Type'
                        ? 'dfd-method-badge dfd-method-type'
                        : 'dfd-method-badge dfd-method-upload',
            };
        });
    }

    _timeAgo(date) {
        const diff = Math.floor((new Date() - date) / 1000);
        if (diff < 60)    return diff + 's ago';
        if (diff < 3600)  return Math.floor(diff / 60) + 'm ago';
        if (diff < 86400) return Math.floor(diff / 3600) + 'h ago';
        return Math.floor(diff / 86400) + 'd ago';
    }

    get hasRecentDocs()    { return this.recentDocs.length > 0; }
    get hasExpiring()      { return this.expiringDocs.length > 0; }
    get hasSigners()       { return this.recentSigners.length > 0; }
    get hasCriticalFraud() { return this.fraudHigh > 0; }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}