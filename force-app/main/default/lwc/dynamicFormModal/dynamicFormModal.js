// dynamicFormModal.js
import { LightningElement, api, track } from 'lwc';
import saveRecord from '@salesforce/apex/CandidateProfileController.saveRecord';

export default class DynamicFormModal extends LightningElement {
    @api candidateId;
    @track isOpen = false;
    @track isLoading = false;
    @track errorMessage = '';
    @track formData = {};
    
    recordType = '';
    recordId = null;
    isEditMode = false;

    // Picklist options
    licenseTypeOptions = [
        { label: 'License', value: 'License' },
        { label: 'Certification', value: 'Certification' },
        { label: 'Registration', value: 'Registration' },
        { label: 'Other', value: 'Other' }
    ];

    clinicalSkillTypeOptions = [
        { label: 'Clinical', value: 'Clinical' },
        { label: 'Diagnostic', value: 'Diagnostic' },
        { label: 'Therapeutic', value: 'Therapeutic' },
        { label: 'Emergency', value: 'Emergency' },
        { label: 'Soft Skill', value: 'Soft Skill' },
        { label: 'Other', value: 'Other' }
    ];

    technicalSkillCategoryOptions = [
        { label: 'EMR/EHR', value: 'EMR/EHR' },
        { label: 'PACS', value: 'PACS' },
        { label: 'Office Software', value: 'Office Software' },
        { label: 'Hospital Information Systems', value: 'Hospital Information Systems' },
        { label: 'Medical Imaging', value: 'Medical Imaging' },
        { label: 'Laboratory Systems', value: 'Laboratory Systems' },
        { label: 'Other', value: 'Other' }
    ];

    procedureCategoryOptions = [
        { label: 'Minor', value: 'Minor' },
        { label: 'Emergency', value: 'Emergency' },
        { label: 'Diagnostic', value: 'Diagnostic' },
        { label: 'Therapeutic', value: 'Therapeutic' },
        { label: 'Life Support', value: 'Life Support' },
        { label: 'Other', value: 'Other' }
    ];

    researchTypeOptions = [
        { label: 'Poster', value: 'Poster' },
        { label: 'Case Study', value: 'Case Study' },
        { label: 'CME', value: 'CME' },
        { label: 'Conference', value: 'Conference' },
        { label: 'Journal Article', value: 'Journal Article' },
        { label: 'Research Paper', value: 'Research Paper' },
        { label: 'Other', value: 'Other' }
    ];

    @api
    openModal(type, recordId = null, recordData = null) {
        this.recordType = type;
        this.recordId = recordId;
        this.isEditMode = recordId != null;
        this.isOpen = true;
        this.errorMessage = '';
        
        if (this.isEditMode && recordData) {
            this.formData = { ...recordData };
        } else {
            this.formData = this.getEmptyFormData(type);
        }
    }

    getEmptyFormData(type) {
        const baseData = { Candidate__c: this.candidateId };
        
        switch(type) {
            case 'workExperience':
                return { 
                    ...baseData, 
                    Role__c: '', 
                    Organization__c: '', 
                    Duration_Text__c: '', 
                    Responsibilities__c: '' 
                };
            case 'education':
                return { 
                    ...baseData, 
                    Institution__c: '', 
                    Degree__c: '', 
                    Duration_Text__c: '', 
                    Details__c: '' 
                };
            case 'license':
                return { 
                    ...baseData, 
                    Name: '', 
                    Type__c: '', 
                    Notes__c: '' 
                };
            case 'clinicalSkill':
                return { 
                    ...baseData, 
                    Name: '', 
                    Skill_Type__c: '', 
                    Description__c: '' 
                };
            case 'technicalSkill':
                return { 
                    ...baseData, 
                    Name: '', 
                    Category__c: '', 
                    Description__c: '' 
                };
            case 'procedure':
                return {
                    ...baseData,
                    Name: '',
                    Category__c: '',
                    Notes__c: ''
                };
            case 'internship':
                return {
                    ...baseData,
                    Organization__c: '',
                    Duration_Text__c: ''
                };
            case 'research':
                return {
                    ...baseData,
                    Title__c: '',
                    Type__c: '',
                    Description__c: ''
                };
            case 'membership':
                return {
                    ...baseData,
                    Organization_Name__c: '',
                    Membership_Type__c: '',
                    Member_Id__c: ''
                };
            default:
                return baseData;
        }
    }

    get modalTitle() {
        const action = this.isEditMode ? 'Edit' : 'Add New';
        const typeMap = {
            'workExperience': 'Work Experience',
            'education': 'Education',
            'license': 'License / Certification',
            'clinicalSkill': 'Clinical Skill',
            'technicalSkill': 'Technical Skill',
            'procedure': 'Procedure',
            'internship': 'Internship',
            'research': 'Research / Publication',
            'membership': 'Professional Membership'
        };
        return `${action} ${typeMap[this.recordType] || 'Record'}`;
    }

    get modalIcon() {
        const iconMap = {
            'workExperience': 'standard:work_order',
            'education': 'standard:education',
            'license': 'standard:certificate',
            'clinicalSkill': 'standard:skill',
            'technicalSkill': 'standard:apex',
            'procedure': 'standard:service_report',
            'internship': 'standard:entity',
            'research': 'standard:article',
            'membership': 'standard:groups'
        };
        return iconMap[this.recordType] || 'standard:record';
    }

    get saveButtonLabel() {
        return this.isEditMode ? 'Save Changes' : 'Add';
    }

    get isWorkExperience() { return this.recordType === 'workExperience'; }
    get isEducation() { return this.recordType === 'education'; }
    get isLicense() { return this.recordType === 'license'; }
    get isClinicalSkill() { return this.recordType === 'clinicalSkill'; }
    get isTechnicalSkill() { return this.recordType === 'technicalSkill'; }
    get isProcedure() { return this.recordType === 'procedure'; }
    get isInternship() { return this.recordType === 'internship'; }
    get isResearch() { return this.recordType === 'research'; }
    get isMembership() { return this.recordType === 'membership'; }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.target.value;
        
        if (this.errorMessage) {
            this.errorMessage = '';
        }
    }

    handlePicklistChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.detail.value;
        
        if (this.errorMessage) {
            this.errorMessage = '';
        }
    }

    handleClose() {
        this.isOpen = false;
        this.formData = {};
        this.errorMessage = '';
        this.isLoading = false;
        
        this.dispatchEvent(new CustomEvent('modalclose', {
            bubbles: true,
            composed: true
        }));
    }

    async handleSave() {
        if (!this.validateForm()) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';

        try {
            const recordToSave = {
                ...this.formData,
                Id: this.recordId,
                Candidate__c: this.candidateId
            };

            const savedId = await saveRecord({
                recordData: JSON.stringify(recordToSave),
                recordType: this.recordType
            });

            this.dispatchEvent(new CustomEvent('save', {
                detail: { 
                    recordType: this.recordType,
                    recordId: savedId,
                    action: this.isEditMode ? 'update' : 'create'
                },
                bubbles: true,
                composed: true
            }));

            this.handleClose();

        } catch (error) {
            this.errorMessage = error.body?.message || error.message || 'An error occurred while saving. Please try again.';
            console.error('Save Error:', JSON.parse(JSON.stringify(error)));
            
            this.dispatchEvent(new CustomEvent('saveerror', {
                detail: { 
                    error: this.errorMessage,
                    recordType: this.recordType
                },
                bubbles: true,
                composed: true
            }));
            
        } finally {
            this.isLoading = false;
        }
    }

    validateForm() {
        const inputs = this.template.querySelectorAll('lightning-input, lightning-textarea, lightning-combobox');
        let isValid = true;
        let firstInvalidField = null;

        inputs.forEach(input => {
            if (input.required && !input.value) {
                input.reportValidity();
                isValid = false;
                if (!firstInvalidField) {
                    firstInvalidField = input;
                }
            }
        });

        if (!isValid) {
            this.errorMessage = 'Please fill in all required fields marked with *';
            if (firstInvalidField) {
                firstInvalidField.focus();
            }
        }

        return isValid;
    }
}