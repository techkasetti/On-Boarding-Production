// docflowTemplates.js
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocumentTemplates from '@salesforce/apex/DocumentGenerationController.getDocumentTemplates';
import saveTemplate from '@salesforce/apex/DocumentGenerationController.saveTemplate';

const JURISDICTIONS = ['US-CA', 'US-NY', 'EU-DE', 'EU-FR', 'UK', 'SG', 'AU'];

const REGION_JUR_MAP = {
    'EU (European Union)': ['EU-DE', 'EU-FR'],
    'North America':       ['US-CA', 'US-NY'],
    'APAC':                ['SG', 'AU'],
    'UK':                  ['UK'],
    'LATAM':               [],
    'Global':              ['US-CA', 'US-NY', 'EU-DE', 'EU-FR', 'UK', 'SG', 'AU'],
};

// Tag color mapping by value
const TAG_COLOR_MAP = {
    // Regions → blue shades
    'EU (European Union)': 'tag-blue',
    'North America':        'tag-blue',
    'APAC':                 'tag-blue',
    'UK':                   'tag-blue',
    'LATAM':                'tag-blue',
    'Global':               'tag-blue',
    'US-CA':                'tag-blue',
    'US-NY':                'tag-blue',
    'EU-DE':                'tag-teal',
    'EU-FR':                'tag-teal',
    // Roles → purple/amber
    'HR':                   'tag-amber',
    'Legal':                'tag-purple',
    'Finance':              'tag-green',
    'Sales':                'tag-orange',
    'Employee':             'tag-purple',
    'Contractor':           'tag-amber',
    'Manager':              'tag-purple',
    'Director':             'tag-amber',
    // Contract types
    'NDA':                  'tag-purple',
    'Employment Agreement': 'tag-teal',
    'Statement of work':    'tag-orange',
    'Vendor Agreement':     'tag-green',
};

function getTagClass(label) {
    return `tl-tag ${TAG_COLOR_MAP[label] || 'tag-grey'}`;
}

export default class DocflowTemplates extends LightningElement {

    // ── State ───────────────────────────────────────────
    @track isLoading           = false;
    @track isSaving            = false;
    @track templates           = [];
    @track filteredTemplates   = [];
    @track selectedTemplateId  = null;
    @track showNewTemplateModal = false;

    // Filters
    @track _searchText   = '';
    @track _regionFilter = 'All';
    @track _roleFilter   = 'All Roles';

    // New template form
    @track newTemplate = {
        sobjectType:      'DocumentTemplate__c',
        Name:             '',
        Region1__c:       '',
        Role__c:          '',
        Contract_Type__c: '',
        Body__c:          '',
        IsActive__c:      true,
        Version__c:       1
    };

    // ── Chips ────────────────────────────────────────────
    get regionChips() {
        return ['All', 'US', 'EU', 'UK', 'APAC', 'LATAM', 'Global'].map(v => ({
            value: v,
            label: v,
            cssClass: `tl-chip${this._regionFilter === v ? ' tl-chip-active' : ''}`
        }));
    }

    get roleChips() {
        return ['All Roles', 'HR', 'Legal', 'Finance', 'Sales'].map(v => ({
            value: v,
            label: v,
            cssClass: `tl-chip${this._roleFilter === v ? ' tl-chip-active' : ''}`
        }));
    }

    // ── Derived ──────────────────────────────────────────
    get selectedTemplateName() {
        if (!this.selectedTemplateId) return 'None';
        const t = this.templates.find(x => x.id === this.selectedTemplateId);
        return t ? t.name : 'None';
    }

    get hasNoResults() {
        return !this.isLoading && this.filteredTemplates.length === 0;
    }

    get matrixRows() {
        return this.filteredTemplates.map(tpl => ({
            templateName: tpl.name,
            cells: JURISDICTIONS.map(jur => {
                const covered = REGION_JUR_MAP[tpl.region] || [];
                const isFull  = covered.includes(jur);
                return { jur, isFull, isPartial: false };
            })
        }));
    }

    // ── Lifecycle ────────────────────────────────────────
    connectedCallback() {
        this.loadTemplates();
    }

    // ── Load ─────────────────────────────────────────────
    loadTemplates() {
        this.isLoading = true;
        getDocumentTemplates()
            .then(data => {
                this._buildTemplates(data);
                this.isLoading = false;
            })
            .catch(err => {
                this.isLoading = false;
                this._toast('Error loading templates', err?.body?.message || 'Unknown error', 'error');
            });
    }

    _buildTemplates(data) {
        this.templates = data.map(t => ({
            id:                   t.Id,
            name:                 t.Name,
            region:               t.Region1__c  || '',
            role:                 t.Role__c     || '',
            contractType:         t.Contract_Type__c || '',
            isActive:             t.IsActive__c,
            lastUpdatedFormatted: this._formatDate(t.LastModifiedDate || new Date()),
            variableCount:        this._countVars(t.Body__c),
            tags: this._buildTags(t),
        }));
        this._applyFilters();

        if (this.templates.length && !this.selectedTemplateId) {
            this.selectedTemplateId = this.templates[0].id;
        }
    }

    _buildTags(t) {
        const tags = [];

        // Jurisdiction tags (US-CA, EU-DE etc) derived from region
        const jurs = REGION_JUR_MAP[t.Region1__c] || [];
        jurs.forEach(j => tags.push({ label: j, cssClass: getTagClass(j) }));

        // Role tag
        if (t.Role__c) tags.push({ label: t.Role__c, cssClass: getTagClass(t.Role__c) });

        return tags;
    }

    _countVars(body) {
        if (!body) return 0;
        const m = body.match(/\{\{[^}]+\}\}/g);
        return m ? m.length : 0;
    }

    _formatDate(dateVal) {
        if (!dateVal) return '';
        const d = new Date(dateVal);
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }

    // ── Filter ───────────────────────────────────────────
    _applyFilters() {
        let list = [...this.templates];

        if (this._searchText) {
            const q = this._searchText.toLowerCase();
            list = list.filter(t =>
                t.name.toLowerCase().includes(q) ||
                t.region.toLowerCase().includes(q) ||
                t.contractType.toLowerCase().includes(q) ||
                t.role.toLowerCase().includes(q)
            );
        }

        if (this._regionFilter !== 'All') {
            list = list.filter(t =>
                t.region.toUpperCase().includes(this._regionFilter.toUpperCase()) ||
                (this._regionFilter === 'EU' && t.region.includes('European Union'))
            );
        }

        if (this._roleFilter !== 'All Roles') {
            list = list.filter(t =>
                t.role === this._roleFilter
            );
        }

        this.filteredTemplates = list.map(t => ({
            ...t,
            isSelected: t.id === this.selectedTemplateId,
            cssClass: `tl-card${t.id === this.selectedTemplateId ? ' tl-card-selected' : ''}`
        }));
    }

    // ── Handlers ─────────────────────────────────────────
    handleSearchInput(event) {
        this._searchText = event.target.value;
        this._applyFilters();
    }

    handleRegionChip(event) {
        this._regionFilter = event.currentTarget.dataset.value;
        this._applyFilters();
    }

    handleRoleChip(event) {
        this._roleFilter = event.currentTarget.dataset.value;
        this._applyFilters();
    }

    handleSelectTemplate(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this.selectedTemplateId = id;
        this._applyFilters();

        this.dispatchEvent(new CustomEvent('templateselect', { detail: { templateId: id } }));
    }

    // ── New Template Modal ────────────────────────────────
    handleNewTemplate() {
        // Reset form
        this.newTemplate = {
            sobjectType:      'DocumentTemplate__c',
            Name:             '',
            Region1__c:       '',
            Role__c:          '',
            Contract_Type__c: '',
            Body__c:          '',
            IsActive__c:      true,
            Version__c:       1
        };
        this.showNewTemplateModal = true;
    }

    handleNewTemplateField(event) {
        const field = event.currentTarget.dataset.field;
        this.newTemplate = { ...this.newTemplate, [field]: event.target.value };
    }

    handleNewTemplateToggle(event) {
        const field = event.currentTarget.dataset.field;
        this.newTemplate = { ...this.newTemplate, [field]: event.target.checked };
    }

    handleCancelNew() {
        this.showNewTemplateModal = false;
    }

    handleModalOverlayClick() {
        this.showNewTemplateModal = false;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleSaveNew() {
        if (!this.newTemplate.Name) {
            this._toast('Validation Error', 'Template Name is required.', 'error');
            return;
        }

        this.isSaving = true;

        saveTemplate({ templateRecord: this.newTemplate })
            .then(() => {
                this.isSaving = false;
                this.showNewTemplateModal = false;
                this._toast('Success', 'Template created successfully!', 'success');
                this.loadTemplates();
            })
            .catch(err => {
                this.isSaving = false;
                this._toast('Save Failed', err?.body?.message || 'Unknown error', 'error');
            });
    }

    // ── Toast helper ─────────────────────────────────────
    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}