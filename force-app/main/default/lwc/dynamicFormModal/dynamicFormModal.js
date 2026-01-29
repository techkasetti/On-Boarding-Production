// // dynamicFormModal.js
// import { LightningElement, api, track } from 'lwc';
// import saveRecord from '@salesforce/apex/CandidateProfileController.saveRecord';

// export default class DynamicFormModal extends LightningElement {
//     @api candidateId;
//     @track isOpen = false;
//     @track isLoading = false;
//     @track errorMessage = '';
//     @track formData = {};
    
//     recordType = '';
//     recordId = null;
//     isEditMode = false;

//     // Picklist options
//     licenseTypeOptions = [
//         { label: 'License', value: 'License' },
//         { label: 'Certification', value: 'Certification' },
//         { label: 'Registration', value: 'Registration' },
//         { label: 'Other', value: 'Other' }
//     ];

//     clinicalSkillTypeOptions = [
//         { label: 'Clinical', value: 'Clinical' },
//         { label: 'Diagnostic', value: 'Diagnostic' },
//         { label: 'Therapeutic', value: 'Therapeutic' },
//         { label: 'Emergency', value: 'Emergency' },
//         { label: 'Soft Skill', value: 'Soft Skill' },
//         { label: 'Other', value: 'Other' }
//     ];

//     technicalSkillCategoryOptions = [
//         { label: 'EMR/EHR', value: 'EMR/EHR' },
//         { label: 'PACS', value: 'PACS' },
//         { label: 'Office Software', value: 'Office Software' },
//         { label: 'Hospital Information Systems', value: 'Hospital Information Systems' },
//         { label: 'Medical Imaging', value: 'Medical Imaging' },
//         { label: 'Laboratory Systems', value: 'Laboratory Systems' },
//         { label: 'Other', value: 'Other' }
//     ];

//     procedureCategoryOptions = [
//         { label: 'Minor', value: 'Minor' },
//         { label: 'Emergency', value: 'Emergency' },
//         { label: 'Diagnostic', value: 'Diagnostic' },
//         { label: 'Therapeutic', value: 'Therapeutic' },
//         { label: 'Life Support', value: 'Life Support' },
//         { label: 'Other', value: 'Other' }
//     ];

//     researchTypeOptions = [
//         { label: 'Poster', value: 'Poster' },
//         { label: 'Case Study', value: 'Case Study' },
//         { label: 'CME', value: 'CME' },
//         { label: 'Conference', value: 'Conference' },
//         { label: 'Journal Article', value: 'Journal Article' },
//         { label: 'Research Paper', value: 'Research Paper' },
//         { label: 'Other', value: 'Other' }
//     ];

//     @api
//     openModal(type, recordId = null, recordData = null) {
//         this.recordType = type;
//         this.recordId = recordId;
//         this.isEditMode = recordId != null;
//         this.isOpen = true;
//         this.errorMessage = '';
        
//         if (this.isEditMode && recordData) {
//             this.formData = { ...recordData };
//             // Convert dates if needed
//             this.formatDatesForEdit(recordData);
//         } else {
//             this.formData = this.getEmptyFormData(type);
//         }
//     }

//     formatDatesForEdit(recordData) {
//         // Ensure date fields are in YYYY-MM-DD format for lightning-input type="date"
//         const dateFields = ['Start_Date__c', 'End_Date__c', 'Issue_Date__c', 'Expiry_Date__c', 'Publication_Date__c', 'Member_Since__c'];
//         dateFields.forEach(field => {
//             if (recordData[field]) {
//                 this.formData[field] = recordData[field];
//             }
//         });

//         // Convert year fields to plain numbers (no formatting)
//         if (recordData.Start_Year__c) {
//             this.formData.Start_Year__c = String(Math.floor(recordData.Start_Year__c));
//         }
//         if (recordData.End_Year__c) {
//             this.formData.End_Year__c = String(Math.floor(recordData.End_Year__c));
//         }
//     }

//     getEmptyFormData(type) {
//         const baseData = { Candidate__c: this.candidateId };
        
//         switch(type) {
//             case 'workExperience':
//                 return { 
//                     ...baseData, 
//                     Role__c: '', 
//                     Organization__c: '', 
//                     Start_Date__c: '',
//                     End_Date__c: '',
//                     Is_Current__c: false,
//                     Responsibilities__c: '' 
//                 };
//             case 'education':
//                 return { 
//                     ...baseData, 
//                     Institution__c: '', 
//                     Degree__c: '', 
//                     Start_Year__c: '',
//                     End_Year__c: '',
//                     Details__c: '' 
//                 };
//             case 'license':
//                 return { 
//                     ...baseData, 
//                     Name: '', 
//                     Type__c: '',
//                     Issue_Date__c: '',
//                     Expiry_Date__c: '',
//                     Notes__c: '' 
//                 };
//             case 'clinicalSkill':
//                 return { 
//                     ...baseData, 
//                     Name: '', 
//                     Skill_Type__c: '', 
//                     Description__c: '' 
//                 };
//             case 'technicalSkill':
//                 return { 
//                     ...baseData, 
//                     Name: '', 
//                     Category__c: '', 
//                     Description__c: '' 
//                 };
//             case 'procedure':
//                 return {
//                     ...baseData,
//                     Name: '',
//                     Category__c: '',
//                     Notes__c: ''
//                 };
//             case 'internship':
//                 return {
//                     ...baseData,
//                     Organization__c: '',
//                     Start_Date__c: '',
//                     End_Date__c: ''
//                 };
//             case 'research':
//                 return {
//                     ...baseData,
//                     Title__c: '',
//                     Type__c: '',
//                     Publication_Date__c: '',
//                     Description__c: ''
//                 };
//             case 'membership':
//                 return {
//                     ...baseData,
//                     Organization_Name__c: '',
//                     Membership_Type__c: '',
//                     Member_Id__c: '',
//                     Member_Since__c: ''
//                 };
//             default:
//                 return baseData;
//         }
//     }

//     get modalTitle() {
//         const action = this.isEditMode ? 'Edit' : 'Add New';
//         const typeMap = {
//             'workExperience': 'Work Experience',
//             'education': 'Education',
//             'license': 'License / Certification',
//             'clinicalSkill': 'Clinical Skill',
//             'technicalSkill': 'Technical Skill',
//             'procedure': 'Procedure',
//             'internship': 'Internship',
//             'research': 'Research / Publication',
//             'membership': 'Professional Membership'
//         };
//         return `${action} ${typeMap[this.recordType] || 'Record'}`;
//     }

//     get modalIcon() {
//         const iconMap = {
//             'workExperience': 'standard:work_order',
//             'education': 'standard:education',
//             'license': 'standard:certificate',
//             'clinicalSkill': 'standard:skill',
//             'technicalSkill': 'standard:apex',
//             'procedure': 'standard:service_report',
//             'internship': 'standard:entity',
//             'research': 'standard:article',
//             'membership': 'standard:groups'
//         };
//         return iconMap[this.recordType] || 'standard:record';
//     }

//     get saveButtonLabel() {
//         return this.isEditMode ? 'Save Changes' : 'Add';
//     }

//     get isWorkExperience() { return this.recordType === 'workExperience'; }
//     get isEducation() { return this.recordType === 'education'; }
//     get isLicense() { return this.recordType === 'license'; }
//     get isClinicalSkill() { return this.recordType === 'clinicalSkill'; }
//     get isTechnicalSkill() { return this.recordType === 'technicalSkill'; }
//     get isProcedure() { return this.recordType === 'procedure'; }
//     get isInternship() { return this.recordType === 'internship'; }
//     get isResearch() { return this.recordType === 'research'; }
//     get isMembership() { return this.recordType === 'membership'; }

//     handleFieldChange(event) {
//         const field = event.target.dataset.field;
//         let value = event.target.value;

//         this.formData[field] = value;
        
//         // Clear end date if "Currently Working Here" is checked
//         if (field === 'Is_Current__c' && value === true) {
//             this.formData.End_Date__c = '';
//         }
        
//         if (this.errorMessage) {
//             this.errorMessage = '';
//         }
//     }

//     handleYearChange(event) {
//         const field = event.target.dataset.field;
//         let value = event.target.value;

//         // Remove any non-digit characters
//         value = value.replace(/\D/g, '');

//         // Limit to 4 digits
//         if (value.length > 4) {
//             value = value.substring(0, 4);
//         }

//         // Convert to number for validation
//         const yearNum = value ? parseInt(value, 10) : null;

//         // Validate year range
//         if (yearNum !== null && (yearNum < 1950 || yearNum > 2099)) {
//             event.target.setCustomValidity('Year must be between 1950 and 2099');
//             event.target.reportValidity();
//         } else {
//             event.target.setCustomValidity('');
//         }

//         // Store as number
//         this.formData[field] = yearNum;

//         // Update input value to clean version
//         event.target.value = value;
        
//         if (this.errorMessage) {
//             this.errorMessage = '';
//         }
//     }

//     handleCheckboxChange(event) {
//         const field = event.target.dataset.field;
//         this.formData[field] = event.target.checked;
        
//         // Clear end date if currently working
//         if (field === 'Is_Current__c' && event.target.checked) {
//             this.formData.End_Date__c = '';
//         }
        
//         if (this.errorMessage) {
//             this.errorMessage = '';
//         }
//     }

//     handlePicklistChange(event) {
//         const field = event.target.dataset.field;
//         this.formData[field] = event.detail.value;
        
//         if (this.errorMessage) {
//             this.errorMessage = '';
//         }
//     }

//     handleClose() {
//         this.isOpen = false;
//         this.formData = {};
//         this.errorMessage = '';
//         this.isLoading = false;
        
//         this.dispatchEvent(new CustomEvent('modalclose', {
//             bubbles: true,
//             composed: true
//         }));
//     }

//     async handleSave() {
//         if (!this.validateForm()) {
//             return;
//         }

//         // Additional custom validations
//         if (!this.validateCustomRules()) {
//             return;
//         }

//         this.isLoading = true;
//         this.errorMessage = '';

//         try {
//             const recordToSave = {
//                 ...this.formData,
//                 Id: this.recordId,
//                 Candidate__c: this.candidateId
//             };

//             const savedId = await saveRecord({
//                 recordData: JSON.stringify(recordToSave),
//                 recordType: this.recordType
//             });

//             this.dispatchEvent(new CustomEvent('save', {
//                 detail: { 
//                     recordType: this.recordType,
//                     recordId: savedId,
//                     action: this.isEditMode ? 'update' : 'create'
//                 },
//                 bubbles: true,
//                 composed: true
//             }));

//             this.handleClose();

//         } catch (error) {
//             this.errorMessage = error.body?.message || error.message || 'An error occurred while saving. Please try again.';
//             console.error('Save Error:', JSON.parse(JSON.stringify(error)));
            
//             this.dispatchEvent(new CustomEvent('saveerror', {
//                 detail: { 
//                     error: this.errorMessage,
//                     recordType: this.recordType
//                 },
//                 bubbles: true,
//                 composed: true
//             }));
            
//         } finally {
//             this.isLoading = false;
//         }
//     }

//     validateForm() {
//         const inputs = this.template.querySelectorAll('lightning-input, lightning-textarea, lightning-combobox');
//         let isValid = true;
//         let firstInvalidField = null;

//         inputs.forEach(input => {
//             if (input.required && !input.value) {
//                 input.reportValidity();
//                 isValid = false;
//                 if (!firstInvalidField) {
//                     firstInvalidField = input;
//                 }
//             }
//         });

//         if (!isValid) {
//             this.errorMessage = 'Please fill in all required fields marked with *';
//             if (firstInvalidField) {
//                 firstInvalidField.focus();
//             }
//         }

//         return isValid;
//     }

//     validateCustomRules() {
//         // Validate date ranges for Work Experience
//         if (this.recordType === 'workExperience' && this.formData.Start_Date__c && this.formData.End_Date__c) {
//             if (new Date(this.formData.Start_Date__c) > new Date(this.formData.End_Date__c)) {
//                 this.errorMessage = 'End Date cannot be before Start Date';
//                 return false;
//             }
//         }

//         // Validate year ranges for Education
//         if (this.recordType === 'education' && this.formData.Start_Year__c && this.formData.End_Year__c) {
//             if (this.formData.Start_Year__c > this.formData.End_Year__c) {
//                 this.errorMessage = 'End Year cannot be before Start Year';
//                 return false;
//             }
//         }

//         // Validate date ranges for Internship
//         if (this.recordType === 'internship' && this.formData.Start_Date__c && this.formData.End_Date__c) {
//             if (new Date(this.formData.Start_Date__c) > new Date(this.formData.End_Date__c)) {
//                 this.errorMessage = 'End Date cannot be before Start Date';
//                 return false;
//             }
//         }

//         // Validate expiry date for licenses
//         if (this.recordType === 'license' && this.formData.Issue_Date__c && this.formData.Expiry_Date__c) {
//             if (new Date(this.formData.Issue_Date__c) > new Date(this.formData.Expiry_Date__c)) {
//                 this.errorMessage = 'Expiry Date cannot be before Issue Date';
//                 return false;
//             }
//         }

//         return true;
//     }
// }
// dynamicFormModal.js - FIXED VERSION (No Separate Upload Modal)
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getLicenseDocuments from '@salesforce/apex/CandidateProfileController.getLicenseDocuments';
import deleteLicenseDocument from '@salesforce/apex/CandidateProfileController.deleteLicenseDocument';
import { refreshApex } from '@salesforce/apex';

export default class DynamicFormModal extends NavigationMixin(LightningElement) {
    @api candidateId;
    
    @track isOpen = false;
    @track isLoading = false;
    @track recordId = null;
    @track objectApiName = '';
    @track recordType = '';
    @track modalTitle = '';
    @track existingDocuments = [];
    
    wiredDocumentsResult;

    // Type Configuration
    typeConfig = {
        'workExperience': {
            objectApiName: 'Work_Experience__c',
            title: 'Work Experience'
        },
        'education': {
            objectApiName: 'Education__c',
            title: 'Education'
        },
        'license': {
            objectApiName: 'License_Certification__c',
            title: 'License/Certification'
        },
        'clinicalSkill': {
            objectApiName: 'Clinical_Skill__c',
            title: 'Clinical Skill'
        },
        'technicalSkill': {
            objectApiName: 'Technical_Skill__c',
            title: 'Technical Skill'
        },
        'procedure': {
            objectApiName: 'Procedure__c',
            title: 'Procedure'
        },
        'internship': {
            objectApiName: 'Internship__c',
            title: 'Internship'
        },
        'research': {
            objectApiName: 'Research_Publication__c',
            title: 'Research/Publication'
        },
        'membership': {
            objectApiName: 'Membership__c',
            title: 'Professional Membership'
        }
    };

    @wire(getLicenseDocuments, { licenseId: '$recordId' })
    wiredDocuments(result) {
        this.wiredDocumentsResult = result;
        if (result.data && this.isLicense) {
            console.log('✅ Documents loaded:', result.data);
            this.existingDocuments = result.data.map(doc => ({
                ...doc,
                iconName: this.getFileIcon(doc.FileExtension),
                formattedDate: this.formatDate(doc.CreatedDate)
            }));
        } else if (result.error) {
            console.error('Error loading documents:', result.error);
        }
    }

    @api
    openModal(type, recordId = null, recordData = null) {
        console.log('=== openModal Called ===');
        console.log('Type:', type);
        console.log('Record ID:', recordId);
        console.log('Candidate ID:', this.candidateId);
        
        const config = this.typeConfig[type];
        
        if (!config) {
            console.error('Unknown record type:', type);
            return;
        }
        
        this.recordType = type;
        this.recordId = recordId;
        this.objectApiName = config.objectApiName;
        this.modalTitle = recordId ? `Edit ${config.title}` : `New ${config.title}`;
        
        this.isOpen = true;
        
        // Load documents if editing a license
        if (this.isLicense && recordId) {
            this.loadDocuments();
        }
        
        console.log('Modal opened successfully');
    }

    handleClose() {
        console.log('Modal closed');
        this.isOpen = false;
        this.recordId = null;
        this.objectApiName = '';
        this.recordType = '';
        this.existingDocuments = [];
    }

    async handleSuccess(event) {
        console.log('=== Record Saved Successfully ===');
        console.log('Record ID:', event.detail.id);
        
        const savedRecordId = event.detail.id;
        const isNewRecord = !this.recordId;
        
        // ✅ FIX: Keep modal open after save for licenses
        if (this.isLicense && isNewRecord) {
            // Update the recordId so document upload becomes available
            this.recordId = savedRecordId;
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'License saved! You can now upload documents below.',
                    variant: 'success'
                })
            );
            
            // Don't close modal - let user upload documents
            // Refresh the form to show upload section
            await this.loadDocuments();
            
        } else {
            // Close modal for other record types
            this.isOpen = false;
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Record saved successfully',
                    variant: 'success'
                })
            );
        }
        
        // Notify parent component
        this.dispatchEvent(new CustomEvent('save', {
            detail: {
                recordId: savedRecordId,
                recordType: this.recordType,
                action: isNewRecord ? 'create' : 'update'
            }
        }));
    }

    handleError(event) {
        console.error('=== Save Error ===');
        console.error(event.detail);
        
        let errorMessage = 'An error occurred while saving';
        
        if (event.detail && event.detail.detail) {
            errorMessage = event.detail.detail;
        } else if (event.detail && event.detail.message) {
            errorMessage = event.detail.message;
        }
        
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: errorMessage,
                variant: 'error'
            })
        );
    }

    async handleLicenseUploadFinished(event) {
        console.log('=== License Document Upload Finished ===');
        const uploadedFiles = event.detail.files;
        
        if (!uploadedFiles || uploadedFiles.length === 0) {
            console.log('No files uploaded');
            return;
        }
        
        console.log(`✅ ${uploadedFiles.length} document(s) uploaded`);
        
        // Log each uploaded file
        uploadedFiles.forEach(file => {
            console.log('   - ' + file.name);
        });
        
        // Show success toast
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: `${uploadedFiles.length} document(s) uploaded successfully!`,
                variant: 'success',
                mode: 'dismissable'
            })
        );
        
        // Wait for files to be processed, then refresh documents
        await this.delay(1500);
        await this.loadDocuments();
        
        console.log('✅ Documents refreshed');
    }

    async handleDeleteDocument(event) {
        console.log('=== Delete Document Clicked ===');
        
        event.stopPropagation();
        event.preventDefault();
        
        const documentId = event.currentTarget.dataset.docId;
        console.log('Document ID to delete:', documentId);
        
        if (!documentId) {
            console.error('No document ID found');
            return;
        }
        
        if (!confirm('Are you sure you want to delete this document?')) {
            console.log('Delete cancelled by user');
            return;
        }
        
        try {
            console.log('Deleting document...');
            await deleteLicenseDocument({ documentId: documentId });
            
            console.log('✅ Document deleted successfully');
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Document deleted successfully',
                    variant: 'success'
                })
            );
            
            await this.loadDocuments();
            
        } catch (error) {
            console.error('❌ Error deleting document:', error);
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to delete document: ' + (error.body?.message || error.message),
                    variant: 'error'
                })
            );
        }
    }

    async loadDocuments() {
        if (!this.recordId || !this.isLicense) return;
        
        try {
            await refreshApex(this.wiredDocumentsResult);
        } catch (error) {
            console.error('Error refreshing documents:', error);
        }
    }

    getFileIcon(fileExtension) {
        const ext = fileExtension?.toLowerCase();
        
        const iconMap = {
            'pdf': 'doctype:pdf',
            'doc': 'doctype:word',
            'docx': 'doctype:word',
            'jpg': 'doctype:image',
            'jpeg': 'doctype:image',
            'png': 'doctype:image'
        };
        
        return iconMap[ext] || 'doctype:attachment';
    }

    formatDate(dateValue) {
        if (!dateValue) return '';
        
        try {
            const date = new Date(dateValue);
            const options = { year: 'numeric', month: 'short', day: 'numeric' };
            return date.toLocaleDateString('en-US', options);
        } catch (error) {
            console.error('Error formatting date:', error);
            return '';
        }
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    // Computed properties
    get isWorkExperience() { return this.recordType === 'workExperience'; }
    get isEducation() { return this.recordType === 'education'; }
    get isLicense() { return this.recordType === 'license'; }
    get isClinicalSkill() { return this.recordType === 'clinicalSkill'; }
    get isTechnicalSkill() { return this.recordType === 'technicalSkill'; }
    get isProcedure() { return this.recordType === 'procedure'; }
    get isInternship() { return this.recordType === 'internship'; }
    get isResearch() { return this.recordType === 'research'; }
    get isMembership() { return this.recordType === 'membership'; }
    
    get hasExistingDocuments() {
        return this.existingDocuments && this.existingDocuments.length > 0;
    }
}