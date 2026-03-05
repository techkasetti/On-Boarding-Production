// docflowApp.js
import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

export default class DocflowApp extends LightningElement {

    @track requestIdFromUrl = null;

    @wire(CurrentPageReference)
    getStateParameters(ref) {
        if (ref?.state?.c__requestId) {
            this.requestIdFromUrl = ref.state.c__requestId;
            this.currentSection   = 'signature';
            this._bumpKey('signature');
        }
    }

    @track dashboard          = { totalDocuments: 0, pending: 0, completed: 0 };
    @track showTemplateEditor = false;
    @track selectedTemplate   = {};

    @track _keys = {
        dashboard:          0,
        templates:          0,
        create:             0,
        documents:          0,
        audit:              0,
        security:           0,
        signature:          0,
        approvedCandidates: 0,
    };

    @track currentSection     = 'dashboard';
    @track selectedDocumentId = null;

    // ── Candidate passed from approvedCandidates → create doc ──────────────
    @track selectedCandidateId   = '';
    @track selectedCandidateName = '';

    @track showDocModal  = false;
    @track modalDocument = {};
    @track showToast     = false;
    @track toastMessage  = '';
    @track toastType     = 'success';

    @track pendingCount = 3;
    @track userInitials = 'JD';

    // ── KEY GETTERS ────────────────────────────────────────────────────────
    get keyDashboard()          { return 'dashboard-'          + this._keys.dashboard; }
    get keyTemplates()          { return 'templates-'          + this._keys.templates; }
    get keyCreate()             { return 'create-'             + this._keys.create; }
    get keyDocuments()          { return 'documents-'          + this._keys.documents; }
    get keyAudit()              { return 'audit-'              + this._keys.audit; }
    get keySecurity()           { return 'security-'           + this._keys.security; }
    get keySignature()          { return 'signature-'          + this._keys.signature; }
    get keyApprovedCandidates() { return 'approvedCandidates-' + this._keys.approvedCandidates; }

    _bumpKey(section) {
        this._keys = { ...this._keys, [section]: this._keys[section] + 1 };
    }

    // ── NAV TABS ───────────────────────────────────────────────────────────
    get navTabs() {
        return [
            { id: 'dashboard',          label: 'Dashboard'          },
            { id: 'templates',          label: 'Templates'          },
            { id: 'approvedCandidates', label: 'Cleared Candidates' },
            { id: 'create',             label: 'Create Doc'         },
            { id: 'documents',          label: 'Documents'          },
            { id: 'audit',              label: 'Audit Trail'        },
            { id: 'security',           label: 'Security'           },
            { id: 'signature',          label: 'Signatures'         },
        ].map(t => ({
            ...t,
            cssClass: `nav-tab${this.currentSection === t.id ? ' active' : ''}`
        }));
    }

    // ── SECTION VISIBILITY ─────────────────────────────────────────────────
    get isDashboard()          { return this.currentSection === 'dashboard'; }
    get isTemplates()          { return this.currentSection === 'templates'; }
    get isCreate()             { return this.currentSection === 'create'; }
    get isDocuments()          { return this.currentSection === 'documents'; }
    get isSignature()          { return this.currentSection === 'signature'; }
    get isSecurity()           { return this.currentSection === 'security'; }
    get isAudit()              { return this.currentSection === 'audit'; }
    get isApprovedCandidates() { return this.currentSection === 'approvedCandidates'; }

    get mainClass()  { return this.showTemplateEditor ? 'df-main no-scroll' : 'df-main'; }
    get toastClass() { return `df-toast df-toast-${this.toastType}${this.showToast ? ' show' : ''}`; }

    // ── NAVIGATION ─────────────────────────────────────────────────────────
    handleNavTab(event) {
        this._navigateTo(event.currentTarget.dataset.section);
    }

    handleSidebarNav(event) {
        this._navigateTo(event.currentTarget.dataset.section);
    }

    handleNewDocument() {
        // Clear any previous candidate context when opening fresh
        this.selectedCandidateId   = '';
        this.selectedCandidateName = '';
        this._navigateTo('create');
    }

    _navigateTo(section) {
        this._bumpKey(section);
        this.currentSection = section;
    }

    /**
     * Fired by child components via: dispatchEvent(new CustomEvent('navigatesection', { bubbles, composed, detail }))
     * approvedCandidates passes: { section: 'create', candidateId: '...', candidateName: '...' }
     */
    handleChildNavigate(event) {
        const { section, documentId, candidateId, candidateName } = event.detail;

        if (documentId) this.selectedDocumentId = documentId;

        // Store candidate info BEFORE navigating so Create Doc gets it on mount
        this.selectedCandidateId   = candidateId   || '';
        this.selectedCandidateName = candidateName || '';

        console.log('[docflowApp] navigating to:', section,
                    '| candidateId:', this.selectedCandidateId,
                    '| candidateName:', this.selectedCandidateName);

        this._navigateTo(section);
    }

    handleDocumentSelected(event) {
        this.selectedDocumentId = event.detail.documentId;
    }

    // ── TEMPLATE EDITOR ────────────────────────────────────────────────────
    openTemplateEditor(event) {
        this.selectedTemplate   = JSON.parse(JSON.stringify(event.detail.template || {}));
        this.showTemplateEditor = true;
    }

    closeTemplateEditor() {
        this.showTemplateEditor = false;
        this._bumpKey('templates');
    }

    // ── MODAL / TOAST ──────────────────────────────────────────────────────
    closeModal()               { this.showDocModal = false; }
    stopPropagation(event)     { event.stopPropagation(); }
    handleModalOverlayClick(e) { if (e.target === e.currentTarget) this.closeModal(); }

    showSuccessToast(msg) {
        this.toastMessage = msg; this.toastType = 'success'; this.showToast = true;
        setTimeout(() => { this.showToast = false; }, 3500);
    }
    showErrorToast(msg) {
        this.toastMessage = msg; this.toastType = 'error'; this.showToast = true;
        setTimeout(() => { this.showToast = false; }, 4000);
    }
    closeToast() { this.showToast = false; }
}