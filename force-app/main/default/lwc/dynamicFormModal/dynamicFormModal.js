// dynamicFormModal.js - AGGRESSIVE Z-INDEX FIX WITH MUTATION OBSERVER
import { LightningElement, api, track, wire } from 'lwc';
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
    
    // INLINE NOTIFICATION PROPERTIES
    @track showNotification = false;
    @track notificationTitle = '';
    @track notificationMessage = '';
    @track notificationVariant = 'info';
    notificationTimeout;
    
    wiredDocumentsResult;
    mutationObserver = null;

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
        
        // Start monitoring for upload modals
        this.startMonitoringForUploadModal();
        
        console.log('Modal opened successfully');
    }

    handleClose() {
        console.log('=== Modal Closed by User ===');
        this.closeModal();
    }

    closeModal() {
        console.log('🔒 Closing modal and clearing state');
        
        // Stop monitoring
        this.stopMonitoringForUploadModal();
        
        this.isOpen = false;
        this.recordId = null;
        this.objectApiName = '';
        this.recordType = '';
        this.existingDocuments = [];
        console.log('✅ Modal state cleared');
    }

    async handleSuccess(event) {
    console.log('=== Record Saved Successfully ===');
    console.log('Record ID:', event.detail.id);
    
    const savedRecordId = event.detail.id;
    const isNewRecord = !this.recordId;
    
    const config = this.typeConfig[this.recordType];
    const actionText = isNewRecord ? 'added' : 'updated';
    
    // ✅ CRITICAL: For new licenses, update recordId and keep modal open for upload
    if (this.isLicense && isNewRecord) {
        console.log('📌 New License saved - updating recordId and keeping modal open for upload');
        
        this.recordId = savedRecordId;
        this.modalTitle = `Edit ${config.title}`;
        
        this.displayNotification(
            'Success',
            `${config.title} saved! You can now upload documents.`,
            'success'
        );
        
        // Load documents (will be empty initially)
        await this.loadDocuments();
        
        console.log('✅ Modal kept open for document upload');
        return; // Keep modal open
    }
    
    // For all other cases, close modal
    this.displayNotification(
        'Success',
        `${config.title} ${actionText} successfully`,
        'success'
    );
    
    console.log('📌 Closing modal after save');
    this.closeModal();
    
    this.dispatchEvent(new CustomEvent('save', {
        detail: {
            recordId: savedRecordId,
            recordType: this.recordType,
            action: isNewRecord ? 'create' : 'update'
        },
        bubbles: true,
        composed: true
    }));
    
    console.log('✅ Save event dispatched to parent');
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
        
        this.displayNotification('Error', errorMessage, 'error');
    }

    // ========================================
    // 🔥 AGGRESSIVE FIX: MUTATION OBSERVER
    // ========================================
    
    connectedCallback() {
        console.log('🔌 Component connected');
    }

    disconnectedCallback() {
        console.log('🔌 Component disconnected');
        this.stopMonitoringForUploadModal();
    }

    renderedCallback() {
        if (this.isOpen) {
            // Apply z-index fix immediately on each render
            this.forceUploadModalZIndex();
        }
    }

    /**
     * Start monitoring DOM for upload modal appearance
     */
    startMonitoringForUploadModal() {
        console.log('👁️ Starting mutation observer for upload modal');
        
        // Stop any existing observer
        this.stopMonitoringForUploadModal();
        
        // Create mutation observer to watch for new modals
        this.mutationObserver = new MutationObserver((mutations) => {
            this.forceUploadModalZIndex();
        });
        
        // Observe the entire document body for modal additions
        this.mutationObserver.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['class', 'style']
        });
        
        // Also run the fix immediately
        this.forceUploadModalZIndex();
    }

    /**
     * Stop mutation observer
     */
    stopMonitoringForUploadModal() {
        if (this.mutationObserver) {
            console.log('🛑 Stopping mutation observer');
            this.mutationObserver.disconnect();
            this.mutationObserver = null;
        }
    }

    /**
     * 🔥 AGGRESSIVE: Force upload modal to highest z-index
     */
    forceUploadModalZIndex() {
        try {
            // Find our edit modal first and set it lower
            const ourModal = this.template.querySelector('.modal-container');
            const ourBackdrop = this.template.querySelector('.modal-backdrop');
            
            if (ourModal) {
                ourModal.style.zIndex = '8001';
                console.log('📌 Set our edit modal to z-index: 8001');
            }
            
            if (ourBackdrop) {
                ourBackdrop.style.zIndex = '8000';
                console.log('📌 Set our backdrop to z-index: 8000');
            }
            
            // Find ALL modals in the entire document
            const allModals = document.querySelectorAll('section[role="dialog"].slds-modal');
            const allBackdrops = document.querySelectorAll('.slds-backdrop');
            
            console.log(`🔍 Found ${allModals.length} total modals in DOM`);
            
            allModals.forEach((modal, index) => {
                // Skip our own modal
                if (modal.classList.contains('modal-container')) {
                    console.log(`   ⏭️ Modal ${index}: Skipping (our edit modal)`);
                    return;
                }
                
                // Check if this is an upload modal
                const modalHeader = modal.querySelector('.slds-modal__header h2, .slds-modal__title');
                const headerText = modalHeader ? modalHeader.textContent : '';
                
                console.log(`   🔍 Modal ${index}: "${headerText}"`);
                
                // If it contains "Upload Files" or "Done" button, it's the upload modal
                if (headerText.includes('Upload Files') || headerText.includes('Upload')) {
                    console.log(`   🎯 FOUND UPLOAD MODAL! Setting to z-index: 20004`);
                    modal.style.setProperty('z-index', '20004', 'important');
                    modal.style.setProperty('position', 'fixed', 'important');
                    
                    // 🔥 NEW: Reduce modal width
                    const modalContainer = modal.querySelector('.slds-modal__container');
                    if (modalContainer) {
                        modalContainer.style.setProperty('max-width', '40rem', 'important');
                        modalContainer.style.setProperty('width', '90%', 'important');
                        console.log(`   📏 Reduced upload modal width to 40rem`);
                    }
                    
                    // Find its backdrop
                    allBackdrops.forEach(backdrop => {
                        if (!backdrop.classList.contains('modal-backdrop')) {
                            backdrop.style.setProperty('z-index', '20003', 'important');
                            backdrop.style.setProperty('position', 'fixed', 'important');
                            console.log(`   🎯 Set upload backdrop to z-index: 20003`);
                        }
                    });
                }
            });
            
            // Also target by DOM traversal - find modals that are children of body
            const bodyChildren = Array.from(document.body.children);
            bodyChildren.forEach(child => {
                if (child.tagName === 'SECTION' && child.getAttribute('role') === 'dialog') {
                    if (!child.classList.contains('modal-container')) {
                        console.log('🎯 Found modal as direct body child - setting high z-index');
                        child.style.setProperty('z-index', '20005', 'important');
                        child.style.setProperty('position', 'fixed', 'important');
                        
                        // Reduce width for this modal too
                        const container = child.querySelector('.slds-modal__container');
                        if (container) {
                            container.style.setProperty('max-width', '40rem', 'important');
                            container.style.setProperty('width', '90%', 'important');
                            console.log(`   📏 Reduced modal width to 40rem`);
                        }
                    }
                }
            });
            
        } catch (error) {
            console.error('❌ Error in forceUploadModalZIndex:', error);
        }
    }

    async handleLicenseUploadFinished(event) {
        console.log('=== License Document Upload Finished ===');
        const uploadedFiles = event.detail.files;
        
        if (!uploadedFiles || uploadedFiles.length === 0) {
            console.log('No files uploaded');
            return;
        }
        
        console.log(`✅ ${uploadedFiles.length} document(s) uploaded`);
        
        uploadedFiles.forEach(file => {
            console.log('   - ' + file.name);
        });
        
        this.displayNotification(
            'Success',
            `${uploadedFiles.length} document(s) uploaded successfully!`,
            'success'
        );
        
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
            
            this.displayNotification(
                'Success',
                'Document deleted successfully',
                'success'
            );
            
            await this.loadDocuments();
            
        } catch (error) {
            console.error('❌ Error deleting document:', error);
            
            this.displayNotification(
                'Error',
                'Failed to delete document: ' + (error.body?.message || error.message),
                'error'
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

    // ========================================
    // INLINE NOTIFICATION METHODS
    // ========================================
    displayNotification(title, message, variant) {
        if (this.notificationTimeout) {
            clearTimeout(this.notificationTimeout);
        }
        
        this.notificationTitle = title;
        this.notificationMessage = message;
        this.notificationVariant = variant;
        this.showNotification = true;
        
        console.log(`📢 Notification: ${title} - ${message} (${variant})`);
        
        this.notificationTimeout = setTimeout(() => {
            this.closeNotification();
        }, 3000);
    }

    closeNotification() {
        this.showNotification = false;
        if (this.notificationTimeout) {
            clearTimeout(this.notificationTimeout);
        }
    }

    get notificationClass() {
        const baseClass = 'custom-notification slds-notify slds-notify_alert';
        const variantClass = `slds-theme_${this.notificationVariant}`;
        return `${baseClass} ${variantClass}`;
    }

    get notificationIcon() {
        const iconMap = {
            'success': 'utility:success',
            'error': 'utility:error',
            'warning': 'utility:warning',
            'info': 'utility:info'
        };
        return iconMap[this.notificationVariant] || 'utility:info';
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