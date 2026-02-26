// dynamicFormModal.js
// FIX: Uses a _bypassDupCheck flag so after Apex confirms no duplicate,
// the form re-submits naturally without corrupting any field values.
// DATE VALIDATION FIX: Validates end date >= start date for Work Experience,
// License (issue/expiry), and Internship before allowing save.

import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLicenseDocuments   from '@salesforce/apex/CandidateProfileController.getLicenseDocuments';
import deleteLicenseDocument from '@salesforce/apex/CandidateProfileController.deleteLicenseDocument';
import checkDuplicate        from '@salesforce/apex/CandidateProfileController.checkDuplicate';
import { refreshApex } from '@salesforce/apex';

const CURRENT_YEAR     = new Date().getFullYear();
const MIN_VALID_YEAR   = 1950;
const MIN_DEGREE_YEARS = 3;

export default class DynamicFormModal extends NavigationMixin(LightningElement) {
    @api candidateId;

    @track isOpen          = false;
    @track isLoading       = false;
    @track isSaving        = false;
    @track recordId        = null;
    @track objectApiName   = '';
    @track recordType      = '';
    @track modalTitle      = '';
    @track existingDocuments = [];

    // Education year custom inputs (avoids comma formatting from lightning-input-field)
    @track startYearValue      = '';
    @track endYearValue        = '';
    @track startYearError      = '';
    @track endYearError        = '';
    @track yearValidationError = '';

    // Duplicate error banner
    @track duplicateError = '';

    // ── Date validation errors (for Work Experience, License, Internship)
    @track dateValidationError = '';

    // Notification
    @track showNotification    = false;
    @track notificationTitle   = '';
    @track notificationMessage = '';
    @track notificationVariant = 'info';
    notificationTimeout;

    // ── Bypass flag: set to true after Apex confirms no duplicate.
    // When onsubmit fires again (via form.submit()), we skip validation
    // and let Salesforce save naturally.
    _bypassDupCheck = false;

    wiredDocumentsResult;
    mutationObserver = null;

    typeConfig = {
        workExperience : { objectApiName: 'Work_Experience__c',       title: 'Work Experience' },
        education      : { objectApiName: 'Education__c',             title: 'Education' },
        license        : { objectApiName: 'License_Certification__c', title: 'License/Certification' },
        clinicalSkill  : { objectApiName: 'Clinical_Skill__c',        title: 'Clinical Skill' },
        technicalSkill : { objectApiName: 'Technical_Skill__c',       title: 'Technical Skill' },
        procedure      : { objectApiName: 'Procedure__c',             title: 'Procedure' },
        internship     : { objectApiName: 'Internship__c',            title: 'Internship' },
        research       : { objectApiName: 'Research_Publication__c',  title: 'Research/Publication' },
        membership     : { objectApiName: 'Membership__c',            title: 'Professional Membership' }
    };

    // ======================================================================
    // WIRE
    // ======================================================================
    @wire(getLicenseDocuments, { licenseId: '' })
    wiredDocuments(result) {
        this.wiredDocumentsResult = result;
        if (result.data && this.isLicense) {
            this.existingDocuments = result.data.map(doc => ({
                ...doc,
                iconName     : this.getFileIcon(doc.FileExtension),
                formattedDate: this.formatDate(doc.CreatedDate)
            }));
        }
    }

    // ======================================================================
    // PUBLIC: open modal
    // ======================================================================
    @api
    openModal(type, recordId = null, recordData = null) {
        const config = this.typeConfig[type];
        if (!config) { console.error('Unknown record type:', type); return; }

        this.recordType      = type;
        this.recordId        = recordId;
        this.objectApiName   = config.objectApiName;
        this.modalTitle      = recordId ? `Edit ${config.title}` : `New ${config.title}`;
        this.duplicateError  = '';
        this.dateValidationError = '';
        this.isSaving        = false;
        this._bypassDupCheck = false;

        // Pre-populate year fields when editing education (strip locale comma formatting)
        if (type === 'education' && recordData) {
            this.startYearValue = recordData.Start_Year__c ? String(parseInt(recordData.Start_Year__c, 10)) : '';
            this.endYearValue   = recordData.End_Year__c   ? String(parseInt(recordData.End_Year__c,   10)) : '';
        } else {
            this.startYearValue = '';
            this.endYearValue   = '';
        }

        this.startYearError      = '';
        this.endYearError        = '';
        this.yearValidationError = '';
        this.isOpen              = true;

        if (this.isLicense && recordId) this.loadDocuments();
        this.startMonitoringForUploadModal();
    }

    // ======================================================================
    // FORM SUBMIT HANDLER
    //
    // Pass 1 (user clicks Save):
    //   → event.preventDefault() stops the save
    //   → runs year validation (education only)
    //   → runs date range validation (workExperience, license, internship)
    //   → calls Apex checkDuplicate
    //   → if clean: sets _bypassDupCheck = true, calls form.submit()
    //
    // Pass 2 (triggered by form.submit() after Apex confirmed clean):
    //   → _bypassDupCheck is true → reset flag → return WITHOUT preventDefault
    //   → Salesforce saves normally with all original field values intact
    // ======================================================================
    handleFormSubmit(event) {
        // ── Pass 2: bypass active, let Salesforce save naturally ──────────
        if (this._bypassDupCheck) {
            this._bypassDupCheck = false;
            this.isSaving        = false;
            return;
        }

        // ── Pass 1: intercept and validate ────────────────────────────────
        event.preventDefault();

        if (this.isSaving) return;

        this.duplicateError      = '';
        this.dateValidationError = '';

        const submittedFields = event.detail.fields || {};

        // 1. Year validation for education
        if (this.isEducation) {
            if (!this.validateEducationYears()) {
                this.displayNotification('Validation Error', 'Please fix the year errors before saving.', 'error');
                return;
            }
        }

        // 2. Date range validation for Work Experience, License, Internship
        if (this.isWorkExperience || this.isLicense || this.isInternship) {
            const dateError = this.validateDateRange(submittedFields);
            if (dateError) {
                this.dateValidationError = dateError;
                this.displayNotification('Validation Error', dateError, 'error');
                return;
            }
        }

        // 3. Extract key fields for Apex duplicate check
        const keyFields = this.extractKeyFields(submittedFields);

        this.isSaving = true;
        this.runDuplicateCheck(keyFields);
    }

    // ======================================================================
    // DATE RANGE VALIDATION
    // Returns an error string if invalid, or empty string if valid.
    // ======================================================================
    validateDateRange(fields) {
        let startDateStr = '';
        let endDateStr   = '';
        let startLabel   = 'Start Date';
        let endLabel     = 'End Date';

        if (this.isWorkExperience || this.isInternship) {
            startDateStr = this.extractDateValue(fields, 'Start_Date__c');
            endDateStr   = this.extractDateValue(fields, 'End_Date__c');
            startLabel   = 'Start Date';
            endLabel     = 'End Date';
        } else if (this.isLicense) {
            startDateStr = this.extractDateValue(fields, 'Issue_Date__c');
            endDateStr   = this.extractDateValue(fields, 'Expiry_Date__c');
            startLabel   = 'Issue Date';
            endLabel     = 'Expiry Date';
        }

        // If either date is missing, no range validation needed
        if (!startDateStr || !endDateStr) return '';

        const startDate = new Date(startDateStr);
        const endDate   = new Date(endDateStr);

        if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) return '';

        if (endDate < startDate) {
            return `${endLabel} (${this.formatDateForDisplay(endDate)}) cannot be before ${startLabel} (${this.formatDateForDisplay(startDate)}).`;
        }

        return '';
    }

    // Safely extract a date string from submitted fields
    extractDateValue(fields, fieldName) {
        const raw = fields[fieldName];
        if (!raw) return '';
        // lightning-record-edit-form may wrap values as { value, displayValue }
        if (typeof raw === 'object' && 'value' in raw) return raw.value || '';
        return String(raw);
    }

    formatDateForDisplay(date) {
        try {
            return date.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
        } catch (e) {
            return date.toString();
        }
    }

    // ======================================================================
    // DUPLICATE CHECK + RE-SUBMIT
    // ======================================================================
    async runDuplicateCheck(keyFields) {
        try {
            const dupMessage = await checkDuplicate({
                candidateId : this.candidateId,
                recordType  : this.recordType,
                fieldsJson  : JSON.stringify(keyFields),
                excludeId   : this.recordId || ''
            });

            if (dupMessage) {
                this.duplicateError = dupMessage;
                this.displayNotification('Duplicate Found', dupMessage, 'warning');
                this.isSaving = false;
                return;
            }

            // No duplicate — re-submit the form naturally
            this._bypassDupCheck = true;
            this.isSaving        = true;

            const form = this.template.querySelector('lightning-record-edit-form');
            if (!form) { this.isSaving = false; return; }

            if (this.isEducation) {
                // Update the hidden lightning-input-field year elements in the DOM
                // so that form.submit() (no args) picks up all field values naturally,
                // including Institution__c, Degree__c, Details__c, and Candidate__c.
                this.setHiddenYearFields();
            }
            form.submit();

        } catch (err) {
            console.error('Duplicate check error:', err);
            this._bypassDupCheck = true;
            this.isSaving        = true;
            const form = this.template.querySelector('lightning-record-edit-form');
            if (form) {
                if (this.isEducation) this.setHiddenYearFields();
                form.submit();
            } else {
                this.isSaving = false;
            }
        }
    }

    // Sets year values on the hidden lightning-input-field elements so that
    // form.submit() (with no args) will include them in the save payload.
    setHiddenYearFields() {
        try {
            if (this.startYearValue) {
                const startField = this.template.querySelector('lightning-input-field[field-name="Start_Year__c"]');
                if (startField) startField.value = parseInt(this.startYearValue, 10);
            }
            if (this.endYearValue) {
                const endField = this.template.querySelector('lightning-input-field[field-name="End_Year__c"]');
                if (endField) endField.value = parseInt(this.endYearValue, 10);
            }
        } catch (e) { console.error('setHiddenYearFields error:', e); }
    }

    /**
     */
    extractKeyFields(fields) {
        const result = {};
        const keys   = [
            'Name', 'Role__c', 'Organization__c',
            'Institution__c', 'Degree__c',
            'Title__c', 'Organization_Name__c'
        ];
        keys.forEach(k => {
            if (fields[k] !== undefined && fields[k] !== null) {
                const raw = fields[k];
                result[k] = (raw && typeof raw === 'object' && 'value' in raw)
                    ? raw.value
                    : raw;
            }
        });
        return result;
    }

    // ======================================================================
    // EDUCATION YEAR HANDLERS
    // ======================================================================
    handleYearKeyPress(event) {
        const c = event.which || event.keyCode;
        if (c < 48 || c > 57) event.preventDefault();
    }

    handleStartYearChange(event) {
        const raw = event.target.value.replace(/[^0-9]/g, '').substring(0, 4);
        this.startYearValue      = raw;
        event.target.value       = raw;
        this.startYearError      = '';
        this.yearValidationError = '';
        this.validateYearsLive();
    }

    handleEndYearChange(event) {
        const raw = event.target.value.replace(/[^0-9]/g, '').substring(0, 4);
        this.endYearValue        = raw;
        event.target.value       = raw;
        this.endYearError        = '';
        this.yearValidationError = '';
        this.validateYearsLive();
    }

    validateYearsLive() {
        if (this.startYearValue.length !== 4 || this.endYearValue.length !== 4) return;
        const s = parseInt(this.startYearValue, 10);
        const e = parseInt(this.endYearValue, 10);
        if (e < s) {
            this.yearValidationError = `End year (${e}) cannot be before start year (${s}).`;
        } else if ((e - s) < MIN_DEGREE_YEARS) {
            this.yearValidationError = `Degree must be at least ${MIN_DEGREE_YEARS} years. Current: ${e - s} year(s).`;
        } else {
            this.yearValidationError = '';
        }
    }

    validateEducationYears() {
        let ok = true;
        this.startYearError      = '';
        this.endYearError        = '';
        this.yearValidationError = '';

        if (!this.startYearValue) {
            this.startYearError = 'Start Year is required.';
            ok = false;
        } else if (this.startYearValue.length !== 4) {
            this.startYearError = 'Enter a valid 4-digit year (e.g. 2018).';
            ok = false;
        } else {
            const s = parseInt(this.startYearValue, 10);
            if (isNaN(s) || s < MIN_VALID_YEAR || s > CURRENT_YEAR) {
                this.startYearError = `Start Year must be between ${MIN_VALID_YEAR} and ${CURRENT_YEAR}.`;
                ok = false;
            }
        }

        if (this.endYearValue) {
            if (this.endYearValue.length !== 4) {
                this.endYearError = 'Enter a valid 4-digit year (e.g. 2022).';
                ok = false;
            } else {
                const e = parseInt(this.endYearValue, 10);
                if (isNaN(e) || e < MIN_VALID_YEAR || e > CURRENT_YEAR + 10) {
                    this.endYearError = 'End Year must be a valid year.';
                    ok = false;
                } else if (ok) {
                    const s = parseInt(this.startYearValue, 10);
                    if (e < s) {
                        this.yearValidationError = `End year (${e}) cannot be before start year (${s}).`;
                        ok = false;
                    } else if ((e - s) < MIN_DEGREE_YEARS) {
                        this.yearValidationError = `Degree must be at least ${MIN_DEGREE_YEARS} years. You entered ${e - s} year(s) (${s}–${e}).`;
                        ok = false;
                    }
                }
            }
        }
        return ok;
    }

    // ======================================================================
    // COMPUTED PROPERTIES
    // ======================================================================
    get startYearInputClass()    { return `slds-input${this.startYearError ? ' input-error' : ''}`; }
    get endYearInputClass()      { return `slds-input${this.endYearError   ? ' input-error' : ''}`; }
    get hasDuplicateError()      { return !!this.duplicateError; }
    get hasDateValidationError() { return !!this.dateValidationError; }
    get saveButtonLabel()        { return this.isSaving ? 'Saving...' : 'Save'; }
    get isSaveDisabled()         { return this.isSaving; }

    get showDurationHint() {
        if (this.startYearValue.length !== 4 || this.endYearValue.length !== 4) return false;
        const s = parseInt(this.startYearValue, 10);
        const e = parseInt(this.endYearValue, 10);
        return !isNaN(s) && !isNaN(e) && e >= s;
    }

    get durationDisplay() {
        if (!this.showDurationHint) return '';
        const s = parseInt(this.startYearValue, 10);
        const e = parseInt(this.endYearValue, 10);
        const d = e - s;
        return `${d} year${d !== 1 ? 's' : ''} (${s}–${e})`;
    }

    get notificationClass() {
        return `custom-notification slds-notify slds-notify_alert slds-theme_${this.notificationVariant}`;
    }
    get notificationIcon() {
        return {
            success : 'utility:success',
            error   : 'utility:error',
            warning : 'utility:warning',
            info    : 'utility:info'
        }[this.notificationVariant] || 'utility:info';
    }

    get isWorkExperience() { return this.recordType === 'workExperience'; }
    get isEducation()      { return this.recordType === 'education'; }
    get isLicense()        { return this.recordType === 'license'; }
    get isClinicalSkill()  { return this.recordType === 'clinicalSkill'; }
    get isTechnicalSkill() { return this.recordType === 'technicalSkill'; }
    get isProcedure()      { return this.recordType === 'procedure'; }
    get isInternship()     { return this.recordType === 'internship'; }
    get isResearch()       { return this.recordType === 'research'; }
    get isMembership()     { return this.recordType === 'membership'; }
    get hasExistingDocuments() { return this.existingDocuments && this.existingDocuments.length > 0; }

    // ======================================================================
    // MODAL LIFECYCLE
    // ======================================================================
    handleClose() { this.closeModal(); }

    closeModal() {
        this.stopMonitoringForUploadModal();
        this.isOpen              = false;
        this.recordId            = null;
        this.objectApiName       = '';
        this.recordType          = '';
        this.existingDocuments   = [];
        this.startYearValue      = '';
        this.endYearValue        = '';
        this.startYearError      = '';
        this.endYearError        = '';
        this.yearValidationError = '';
        this.duplicateError      = '';
        this.dateValidationError = '';
        this.isSaving            = false;
        this._bypassDupCheck     = false;
    }

    async handleSuccess(event) {
        this.isSaving        = false;
        this._bypassDupCheck = false;

        const savedId = event.detail.id;
        const isNew   = !this.recordId;
        const config  = this.typeConfig[this.recordType];

        // For a new License: keep modal open so user can upload documents
        if (this.isLicense && isNew) {
            this.recordId   = savedId;
            this.modalTitle = `Edit ${config.title}`;
            this.displayNotification('Success', `${config.title} saved! You can now upload documents.`, 'success');
            await this.loadDocuments();
            return;
        }

        this.displayNotification('Success', `${config.title} ${isNew ? 'added' : 'updated'} successfully`, 'success');
        this.closeModal();

        this.dispatchEvent(new CustomEvent('save', {
            detail  : {
                recordId  : savedId,
                recordType: this.recordType,
                action    : isNew ? 'create' : 'update'
            },
            bubbles : true,
            composed: true
        }));
    }

    handleError(event) {
        this.isSaving        = false;
        this._bypassDupCheck = false;
        const msg = event.detail?.detail || event.detail?.message || 'An error occurred while saving';
        this.displayNotification('Error', msg, 'error');
    }

    // ======================================================================
    // INLINE NOTIFICATION
    // ======================================================================
    displayNotification(title, message, variant) {
        if (this.notificationTimeout) clearTimeout(this.notificationTimeout);
        this.notificationTitle   = title;
        this.notificationMessage = message;
        this.notificationVariant = variant;
        this.showNotification    = true;
        this.notificationTimeout = setTimeout(() => this.closeNotification(), 6000);
    }

    closeNotification() {
        this.showNotification = false;
        if (this.notificationTimeout) clearTimeout(this.notificationTimeout);
    }

    // ======================================================================
    // LICENSE DOCUMENT HANDLERS
    // ======================================================================
    async handleLicenseUploadFinished(event) {
        const files = event.detail.files;
        if (!files || files.length === 0) return;
        this.displayNotification('Success', `${files.length} document(s) uploaded successfully!`, 'success');
        await this.delay(1500);
        await this.loadDocuments();
    }

    async handleDeleteDocument(event) {
        event.stopPropagation();
        event.preventDefault();
        const documentId = event.currentTarget.dataset.docId;
        if (!documentId || !confirm('Are you sure you want to delete this document?')) return;
        try {
            await deleteLicenseDocument({ documentId });
            this.displayNotification('Success', 'Document deleted successfully', 'success');
            await this.loadDocuments();
        } catch (err) {
            this.displayNotification('Error', 'Failed to delete: ' + (err.body?.message || err.message), 'error');
        }
    }

    async loadDocuments() {
        if (!this.recordId || !this.isLicense) return;
        try { await refreshApex(this.wiredDocumentsResult); } catch (e) { console.error(e); }
    }

    // ======================================================================
    // MUTATION OBSERVER — keeps upload modal z-index correct
    // ======================================================================
    connectedCallback() {}
    disconnectedCallback() { this.stopMonitoringForUploadModal(); }
    renderedCallback() { if (this.isOpen) this.forceUploadModalZIndex(); }

    startMonitoringForUploadModal() {
        this.stopMonitoringForUploadModal();
        this.mutationObserver = new MutationObserver(() => this.forceUploadModalZIndex());
        this.mutationObserver.observe(document.body, {
            childList      : true,
            subtree        : true,
            attributes     : true,
            attributeFilter: ['class', 'style']
        });
        this.forceUploadModalZIndex();
    }

    stopMonitoringForUploadModal() {
        if (this.mutationObserver) {
            this.mutationObserver.disconnect();
            this.mutationObserver = null;
        }
    }

    forceUploadModalZIndex() {
        try {
            const ourModal    = this.template.querySelector('.modal-container');
            const ourBackdrop = this.template.querySelector('.modal-backdrop');
            if (ourModal)    ourModal.style.zIndex    = '8001';
            if (ourBackdrop) ourBackdrop.style.zIndex = '8000';

            document.querySelectorAll('section[role="dialog"].slds-modal').forEach(modal => {
                if (modal.classList.contains('modal-container')) return;
                const hdr = modal.querySelector('.slds-modal__header h2, .slds-modal__title');
                if (hdr && hdr.textContent.includes('Upload')) {
                    modal.style.setProperty('z-index', '20004', 'important');
                    const ctr = modal.querySelector('.slds-modal__container');
                    if (ctr) {
                        ctr.style.setProperty('max-width', '40rem', 'important');
                        ctr.style.setProperty('width', '90%', 'important');
                    }
                    document.querySelectorAll('.slds-backdrop').forEach(bd => {
                        if (!bd.classList.contains('modal-backdrop')) {
                            bd.style.setProperty('z-index', '20003', 'important');
                        }
                    });
                }
            });
        } catch (e) { console.error(e); }
    }

    // ======================================================================
    // UTILITIES
    // ======================================================================
    getFileIcon(ext) {
        return {
            pdf  : 'doctype:pdf',
            doc  : 'doctype:word',
            docx : 'doctype:word',
            jpg  : 'doctype:image',
            jpeg : 'doctype:image',
            png  : 'doctype:image'
        }[(ext || '').toLowerCase()] || 'doctype:attachment';
    }

    formatDate(dateValue) {
        if (!dateValue) return '';
        try {
            return new Date(dateValue).toLocaleDateString('en-US', {
                year : 'numeric',
                month: 'short',
                day  : 'numeric'
            });
        } catch (e) { return ''; }
    }

    delay(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }
}