import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { CurrentPageReference } from 'lightning/navigation';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import CLINICAL_ASSESSMENT_OBJECT from '@salesforce/schema/Clinical_Assessment__c';
import ASSESSMENT_TYPE_FIELD from '@salesforce/schema/Clinical_Assessment__c.Assessment_Type__c';
import DEPARTMENT_FIELD from '@salesforce/schema/Clinical_Assessment__c.Department__c';
import ROLE_TYPE_FIELD from '@salesforce/schema/Clinical_Assessment__c.Role_Type__c';
import STATUS_FIELD from '@salesforce/schema/Clinical_Assessment__c.Status__c';                         

import getAssessments from '@salesforce/apex/ClinicalAssessmentController.getAssessments';
import saveAssessment from '@salesforce/apex/ClinicalAssessmentController.saveAssessment';
import appendAssessmentFileIds from '@salesforce/apex/ClinicalAssessmentController.appendAssessmentFileIds';
import getAssessmentFiles from '@salesforce/apex/ClinicalAssessmentController.getAssessmentFiles';
import getAssessmentContext from '@salesforce/apex/ClinicalAssessmentController.getAssessmentContext';

export default class ClinicalAssessmentsManager extends LightningElement {
    _recordId;
    _candidateId;
    _applicationId;
    candidateContextId;
    applicationContextId;
    currentPageRef;

    @track assessments = [];
    @track displayAssessments = [];
    @track formModel = this.getEmptyForm();

    isLoading = true;
    isSaving = false;
    isModalOpen = false;
    isEditMode = false;
    sortDirection = 'desc';

    assessmentTypeOptions = [];
    departmentOptions = [];
    roleTypeOptions = [];
    statusOptions = [];
    acceptedFormats = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.png', '.jpg', '.jpeg', '.gif', '.mp4', '.mov', '.avi', '.mkv', '.webm'];
    @track assessmentFiles = [];
    isFilesLoading = false;
    applicationDefaults;

    wiredAssessmentsResult;

    connectedCallback() {
        if (!this.candidateContextId && !this._recordId && !this.applicationContextId) {
            const params = new URLSearchParams(window.location.search);
            const urlCandidateId =
                params.get('c__candidateId') ||
                params.get('candidateId') ||
                params.get('c__recordId') ||
                params.get('recordId');
            const urlApplicationId =
                params.get('c__applicationId') ||
                params.get('applicationId');
            if (urlCandidateId) {
                this.candidateContextId = urlCandidateId;
                this.syncFormCandidateId();
            }
            if (urlApplicationId) {
                this.applicationContextId = urlApplicationId;
                this.syncFormApplicationId();
                this.loadAssessmentContext();
            }
        }
    }

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.candidateContextId = value;
            this.syncFormCandidateId();
        }
    }

    @api
    get candidateId() {
        return this._candidateId;
    }

    set candidateId(value) {
        this._candidateId = value;
        if (value) {
            this.candidateContextId = value;
            this.syncFormCandidateId();
        }
    }

    @api
    get applicationId() {
        return this._applicationId;
    }

    set applicationId(value) {
        this._applicationId = value;
        if (value) {
            this.applicationContextId = value;
            this.syncFormApplicationId();
            this.loadAssessmentContext();
        }
    }

    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        this.currentPageRef = pageRef;
        const applicationIdFromState = this.resolveApplicationId();
        if (applicationIdFromState && !this._applicationId && !this.applicationContextId) {
            this.applicationContextId = applicationIdFromState;
            this.syncFormApplicationId();
            this.loadAssessmentContext();
        }

        const candidateIdFromState = this.resolveCandidateId();
        if (candidateIdFromState && !this._recordId && !this._candidateId && !this.candidateContextId) {
            this.candidateContextId = candidateIdFromState;
            this.syncFormCandidateId();
        }
    }

    @wire(getObjectInfo, { objectApiName: CLINICAL_ASSESSMENT_OBJECT })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: ASSESSMENT_TYPE_FIELD
    })
    wiredAssessmentTypePicklist({ data }) {
        if (data) {
            this.assessmentTypeOptions = data.values;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: DEPARTMENT_FIELD
    })
    wiredDepartmentPicklist({ data }) {
        if (data) {
            this.departmentOptions = data.values;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: ROLE_TYPE_FIELD
    })
    wiredRoleTypePicklist({ data }) {
        if (data) {
            this.roleTypeOptions = data.values;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: STATUS_FIELD
    })
    wiredStatusPicklist({ data }) {
        if (data) {
            this.statusOptions = data.values;
        }
    }

    @wire(getAssessments, { candidateId: '$candidateContextId', applicationId: '$applicationContextId' })
    wiredAssessments(result) {
        this.wiredAssessmentsResult = result;
        this.isLoading = false;

        if (result.data) {
            this.assessments = result.data.map((row) => this.decorateAssessment(row));
            if (!this.applicationContextId && this.assessments.length > 0 && this.assessments[0].jobApplicationId) {
                this.applicationContextId = this.assessments[0].jobApplicationId;
                this.syncFormApplicationId();
            }
            if (!this.candidateContextId && this.assessments.length > 0 && this.assessments[0].candidateId) {
                this.candidateContextId = this.assessments[0].candidateId;
                this.syncFormCandidateId();
            }
            this.applySort();
        } else if (result.error) {
            this.assessments = [];
            this.displayAssessments = [];
            this.showToast('Error', this.reduceError(result.error), 'error');
        }
    }

    get hasAssessments() {
        return this.displayAssessments.length > 0;
    }

    get modalTitle() {
        return this.isEditMode ? 'Edit Clinical Assessment' : 'New Clinical Assessment';
    }

    get saveButtonLabel() {
        return this.isSaving ? 'Saving...' : 'Save';
    }

    get assessmentDateSortIcon() {
        return this.sortDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    handleNewAssessment() {
        this.isEditMode = false;
        this.formModel = {
            ...this.getEmptyForm(),
            department: this.applicationDefaults?.department || null,
            roleType: this.applicationDefaults?.roleType || null
        };
        this.assessmentFiles = [];
        this.isModalOpen = true;
    }

    handleEditAssessment(event) {
        const assessmentId = event.currentTarget.dataset.id;
        const target = this.assessments.find((row) => row.id === assessmentId);
        if (!target) {
            return;
        }

        this.isEditMode = true;
        this.formModel = {
            id: target.id,
            assessmentDate: target.assessmentDate,
            assessmentType: target.assessmentType,
            assessorNotes: target.assessorNotes,
            attemptNumber: target.attemptNumber,
            candidateId: target.candidateId,
            department: target.department,
            roleType: target.roleType,
            status: target.status,
            submittedDate: target.submittedDate,
            uploadedFileIds: target.uploadedFileIds,
            jobApplicationId: target.jobApplicationId
        };
        this.loadAssessmentFiles(target.id);
        this.isModalOpen = true;
    }

    async handleRefresh() {
        if (!this.wiredAssessmentsResult) {
            return;
        }
        this.isLoading = true;
        try {
            await refreshApex(this.wiredAssessmentsResult);
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleAssessmentDateSort() {
        this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.applySort();
    }

    handleModalClose() {
        this.isModalOpen = false;
        this.isSaving = false;
        this.assessmentFiles = [];
        this.isFilesLoading = false;
    }

    handleFieldChange(event) {
        const fieldName = event.target.dataset.field;
        if (!fieldName) {
            return;
        }
        this.formModel = {
            ...this.formModel,
            [fieldName]: event.detail.value
        };
    }

    async handleSave() {
        if (!this.validateForm()) {
            return;
        }

        const candidateIdForSave = this.resolveCandidateId();
        const applicationIdForSave = this.resolveApplicationId();
        if (!applicationIdForSave) {
            this.showToast('Error', 'Job Application Id is required. Open from a Job Application context.', 'error');
            return;
        }
        this.applicationContextId = applicationIdForSave;
        this.syncFormApplicationId();
        this.syncFromDefaultsIfCreate();

        const resolvedCandidateId = candidateIdForSave || this.applicationDefaults?.candidateId;
        if (resolvedCandidateId) {
            this.candidateContextId = resolvedCandidateId;
            this.syncFormCandidateId();
        }

        this.isSaving = true;
        const payload = {
            id: this.formModel.id,
            assessmentDate: this.formModel.assessmentDate,
            assessmentType: this.formModel.assessmentType,
            assessorNotes: this.formModel.assessorNotes,
            attemptNumber: this.formModel.attemptNumber,
            candidateId: resolvedCandidateId,
            jobApplicationId: applicationIdForSave,
            department: this.formModel.department,
            roleType: this.formModel.roleType,
            status: this.formModel.status,
            submittedDate: this.formModel.submittedDate,
            uploadedFileIds: this.formModel.uploadedFileIds
        };

        try {
            await saveAssessment({ recordWrapperJson: JSON.stringify(payload) });
            this.isModalOpen = false;
            await refreshApex(this.wiredAssessmentsResult);
            this.showToast(
                'Success',
                this.isEditMode ? 'Assessment updated successfully.' : 'Assessment created successfully.',
                'success'
            );
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    validateForm() {
        const controls = this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea');
        let isValid = true;
        controls.forEach((control) => {
            if (!control.checkValidity()) {
                control.reportValidity();
                isValid = false;
            }
        });
        return isValid;
    }

    applySort() {
        const sorted = [...this.assessments].sort((a, b) => {
            const first = a.assessmentDate ? new Date(a.assessmentDate).getTime() : 0;
            const second = b.assessmentDate ? new Date(b.assessmentDate).getTime() : 0;
            return this.sortDirection === 'asc' ? first - second : second - first;
        });
        this.displayAssessments = sorted;
    }

    decorateAssessment(row) {
        const fileCount = this.getUploadedFileCount(row.uploadedFileIds);
        return {
            ...row,
            statusLabel: row.status || 'Not Set',
            statusClass: this.getStatusClass(row.status),
            uploadedFileCount: fileCount
        };
    }

    getStatusClass(status) {
        const normalizedStatus = (status || '').toLowerCase();
        if (normalizedStatus.includes('complete') || normalizedStatus.includes('pass')) {
            return 'slds-badge slds-theme_success';
        }
        if (normalizedStatus.includes('progress') || normalizedStatus.includes('pending')) {
            return 'slds-badge slds-theme_warning';
        }
        if (normalizedStatus.includes('fail') || normalizedStatus.includes('reject') || normalizedStatus.includes('cancel')) {
            return 'slds-badge slds-theme_error';
        }
        return 'slds-badge slds-theme_info';
    }

    getEmptyForm() {
        return {
            id: null,
            assessmentDate: null,
            assessmentType: null,
            assessorNotes: null,
            attemptNumber: 1,
            candidateId: this.effectiveCandidateId,
            jobApplicationId: this.effectiveApplicationId,
            department: null,
            roleType: null,
            status: null,
            submittedDate: null,
            uploadedFileIds: null
        };
    }

    get hasExistingFiles() {
        return this.getUploadedFileCount(this.formModel.uploadedFileIds) > 0;
    }

    get existingFilesLabel() {
        const fileCount = this.getUploadedFileCount(this.formModel.uploadedFileIds);
        return fileCount === 1 ? '1 file uploaded' : `${fileCount} files uploaded`;
    }

    getUploadedFileCount(uploadedFileIds) {
        if (!uploadedFileIds) {
            return 0;
        }
        return uploadedFileIds
            .split(',')
            .map((idValue) => idValue.trim())
            .filter((idValue) => idValue.length > 0).length;
    }

    get hasAssessmentFiles() {
        return this.assessmentFiles.length > 0;
    }

    get isDepartmentRoleLocked() {
        return !this.isEditMode && !!this.effectiveApplicationId;
    }

    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files || [];
        if (!this.formModel.id || uploadedFiles.length === 0) {
            return;
        }

        const documentIds = uploadedFiles
            .map((fileItem) => fileItem.documentId)
            .filter((fileId) => !!fileId);

        if (documentIds.length === 0) {
            return;
        }

        try {
            await appendAssessmentFileIds({
                assessmentId: this.formModel.id,
                contentDocumentIds: documentIds
            });
            await refreshApex(this.wiredAssessmentsResult);
            await this.loadAssessmentFiles(this.formModel.id);

            const refreshedRow = this.assessments.find((row) => row.id === this.formModel.id);
            if (refreshedRow) {
                this.formModel = {
                    ...this.formModel,
                    uploadedFileIds: refreshedRow.uploadedFileIds
                };
            }

            this.showToast('Success', 'Files uploaded successfully.', 'success');
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    async loadAssessmentFiles(assessmentId) {
        if (!assessmentId) {
            this.assessmentFiles = [];
            return;
        }
        this.isFilesLoading = true;
        try {
            const files = await getAssessmentFiles({ assessmentId });
            this.assessmentFiles = (files || []).map((fileRow) => ({
                ...fileRow,
                key: fileRow.contentDocumentId
            }));
        } catch (error) {
            this.assessmentFiles = [];
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isFilesLoading = false;
        }
    }

    get effectiveCandidateId() {
        return this.resolveCandidateId();
    }

    get effectiveApplicationId() {
        return this.resolveApplicationId();
    }

    syncFormCandidateId() {
        const candidateId = this.candidateContextId || this._candidateId || this._recordId;
        if (candidateId) {
            this.formModel = {
                ...this.formModel,
                candidateId
            };
        }
    }

    syncFormApplicationId() {
        const applicationId = this.applicationContextId || this._applicationId;
        if (applicationId) {
            this.formModel = {
                ...this.formModel,
                jobApplicationId: applicationId
            };
        }
    }

    syncFromDefaultsIfCreate() {
        if (!this.isEditMode && this.applicationDefaults) {
            this.formModel = {
                ...this.formModel,
                department: this.applicationDefaults.department || this.formModel.department,
                roleType: this.applicationDefaults.roleType || this.formModel.roleType
            };
        }
    }

    resolveCandidateId() {
        const pageState = this.currentPageRef?.state || {};
        const pageAttributes = this.currentPageRef?.attributes || {};
        const params = new URLSearchParams(window.location.search);
        const fromWindowHref = new URL(window.location.href).searchParams;

        return (
            this.candidateContextId ||
            this._candidateId ||
            this._recordId ||
            this.formModel?.candidateId ||
            pageState.c__candidateId ||
            pageState.candidateId ||
            pageState.c__recordId ||
            pageState.recordId ||
            pageAttributes.recordId ||
            params.get('c__candidateId') ||
            params.get('candidateId') ||
            params.get('c__recordId') ||
            params.get('recordId') ||
            fromWindowHref.get('c__candidateId') ||
            fromWindowHref.get('candidateId') ||
            fromWindowHref.get('c__recordId') ||
            fromWindowHref.get('recordId') ||
            (this.assessments.length > 0 ? this.assessments[0].candidateId : null)
        );
    }

    resolveApplicationId() {
        const pageState = this.currentPageRef?.state || {};
        const params = new URLSearchParams(window.location.search);
        const fromWindowHref = new URL(window.location.href).searchParams;

        return (
            this.applicationContextId ||
            this._applicationId ||
            this.formModel?.jobApplicationId ||
            pageState.c__applicationId ||
            pageState.applicationId ||
            params.get('c__applicationId') ||
            params.get('applicationId') ||
            fromWindowHref.get('c__applicationId') ||
            fromWindowHref.get('applicationId') ||
            (this.assessments.length > 0 ? this.assessments[0].jobApplicationId : null)
        );
    }

    async loadAssessmentContext() {
        const applicationId = this.resolveApplicationId();
        if (!applicationId) {
            return;
        }
        try {
            const context = await getAssessmentContext({ applicationId });
            this.applicationDefaults = context;
            if (context?.candidateId && !this.candidateContextId) {
                this.candidateContextId = context.candidateId;
                this.syncFormCandidateId();
            }
            this.syncFromDefaultsIfCreate();
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    reduceError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (error.message) {
            return error.message;
        }
        return 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}