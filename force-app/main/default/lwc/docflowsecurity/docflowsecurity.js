// docflowsecurity.js
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSecurityDashboardData from '@salesforce/apex/FraudDetectionRulesEngine.getSecurityDashboardData';

export default class Docflowsecurity extends LightningElement {

    @track isLoading       = false;
    @track rawRecords      = [];

    // ── Summary counts ────────────────────────────────────
    @track lowRiskCount    = 0;
    @track highRiskCount   = 0;
    @track lowRiskPercent  = 0;
    @track totalRecords    = 0;

    @track tableRows = [];

    connectedCallback() {
        this.loadData();
    }

    // ══════════════════════════════════════════════════════
    // LOAD DATA
    // ══════════════════════════════════════════════════════
    loadData() {
        this.isLoading = true;
        getSecurityDashboardData()
            .then(data => {
                this.isLoading  = false;
                this.rawRecords = data || [];
                this._buildDashboard();
            })
            .catch(err => {
                this.isLoading = false;
                this._toast('Error', err?.body?.message || 'Failed to load security data', 'error');
            });
    }

    // ══════════════════════════════════════════════════════
    // BUILD DASHBOARD FROM RAW RECORDS
    // ══════════════════════════════════════════════════════
    _buildDashboard() {
        const records = this.rawRecords;
        let low = 0, high = 0;

        records.forEach(r => {
            const level = (r.Fraud_Risk_Level__c || '').toUpperCase();
            if (level === 'HIGH' || level === 'CRITICAL') {
                high++;
            } else {
                low++;
            }
        });

        const total = records.length;
        this.lowRiskCount   = low;
        this.highRiskCount  = high;
        this.totalRecords   = total;
        this.lowRiskPercent = total > 0 ? Math.round((low / total) * 100) : 0;

        // Build table rows from ALL records
        this.tableRows = records.map(r => this._buildRow(r));
    }

    _buildRow(r) {
        const level    = (r.Fraud_Risk_Level__c || '').toUpperCase();
        const score    = r.Fraud_Score__c != null ? r.Fraud_Score__c : 0;
        const rulesRan = r.Fraud_Rules_To_Run__c || '';
        const details  = r.Fraud_Analysis_Details__c || '';

        // ── Time to sign ──────────────────────────────────
        let timeToSign = '—';
        const secs = r.Time_To_Complete_Seconds__c;
        if (secs != null) {
            if (secs < 60) {
                timeToSign = Math.round(secs) + 's';
            } else {
                const m = Math.floor(secs / 60);
                const s = Math.round(secs % 60);
                timeToSign = m + 'm ' + s + 's';
            }
        }

        // ── IP display ────────────────────────────────────
        const ipVal     = (rulesRan.includes('IP_ANOMALY') && r.IPAddress__c) ? r.IPAddress__c : '—';
        const ipFlagged = rulesRan.includes('IP_ANOMALY') && details.toUpperCase().includes('IP');

        // ── Location display ──────────────────────────────
        let locationVal = '—';
        let locationFlagged = false;
        if (rulesRan.includes('LOCATION_ANOMALY') && r.SigningLocation__c) {
            const parts = [r.IP_City__c, r.IP_Region_Name__c, r.IP_Country_Code__c].filter(Boolean);
            locationVal     = parts.length > 0 ? parts.join(', ') : r.SigningLocation__c;
            locationFlagged = details.toLowerCase().includes('location') || details.toLowerCase().includes('travel');
        }

        // ── Time flagged ──────────────────────────────────
        const timeFlagged = rulesRan.includes('BEHAVIORAL_ANOMALY') && secs != null && secs < 10;

        // ── Fraud analysis text ───────────────────────────
        let analysisText = 'No anomalies detected';
        if (details && details !== 'No fraud rules were selected to run.') {
            const cleaned = details
                .split('; ')
                .map(d => d.replace(/^CRITICAL RISK:\s*/i, '').trim())
                .filter(Boolean)
                .join(' · ');
            if (cleaned) analysisText = cleaned;
        }

        // ── Document name ─────────────────────────────────
        const docName = (r.Document_Lifecycle_Configuration__r && r.Document_Lifecycle_Configuration__r.Name)
            ? r.Document_Lifecycle_Configuration__r.Name
            : '—';

        // ── Risk level classification ─────────────────────
        const isHigh   = level === 'HIGH' || level === 'CRITICAL';
        const isMedium = level === 'MEDIUM';

        return {
            id:            r.Id,
            signerName:    r.SignerName__c  || 'Unknown',
            signerEmail:   r.SignerEmail__c || '',
            docName:       docName,
            ip:            ipVal,
            location:      locationVal,
            timeToSign:    timeToSign,
            riskScore:     score,
            riskLevel:     isHigh ? (level === 'CRITICAL' ? 'Critical' : 'High') : (isMedium ? 'Medium' : 'Low'),
            fraudAnalysis: analysisText,

            // CSS classes
            rowClass:      isHigh ? 'ds-row ds-row-high' : 'ds-row',
            ipClass:       ipFlagged       ? 'ds-cell-flagged' : '',
            locationClass: locationFlagged ? 'ds-cell-flagged' : '',
            timeClass:     timeFlagged     ? 'ds-cell-flagged' : '',
            scoreClass:    isHigh ? 'ds-score ds-score-high' : (isMedium ? 'ds-score ds-score-medium' : 'ds-score ds-score-low'),
            badgeClass:    isHigh ? 'ds-badge ds-badge-high' : (isMedium ? 'ds-badge ds-badge-medium' : 'ds-badge ds-badge-low'),
            analysisClass: (analysisText !== 'No anomalies detected') ? 'ds-analysis-flagged' : 'ds-analysis-ok',
        };
    }

    // ══════════════════════════════════════════════════════
    get hasRecords() { return this.tableRows.length > 0; }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}