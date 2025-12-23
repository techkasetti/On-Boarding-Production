// candidateProfileHub.js
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProfileData from '@salesforce/apex/CandidateProfileController.getProfileData';

export default class CandidateProfileHub extends LightningElement {
    @track candidateIdInput = '';
    @track profileData;
    @track error;
    @track isLoading = false;
    @track showProfile = false;

    // ========================================================
    // TASK 2: Initial Load Handlers
    // ========================================================
    
    handleIdChange(event) {
        this.candidateIdInput = event.target.value;
        this.error = undefined;
    }

    async handleLoadProfile() {
        if (!this.candidateIdInput || this.candidateIdInput.trim() === '') {
            this.error = { body: { message: 'Please enter a valid Candidate ID.' } };
            return;
        }

        await this.loadProfileData();
    }

    handleReset() {
        this.showProfile = false;
        this.profileData = undefined;
        this.candidateIdInput = '';
        this.error = undefined;
        this.isLoading = false;
    }

    // ========================================================
    // TASK 2 & 6: Data Loading and Refresh
    // ========================================================

    /**
     * Load profile data from Apex
     * Used for initial load and refresh after saves
     */
    async loadProfileData() {
        this.isLoading = true;
        this.error = undefined;
        this.profileData = undefined;

        try {
            const data = await getProfileData({ candidateId: this.candidateIdInput });
            this.profileData = data;
            this.showProfile = true;
            
            console.log('Profile data loaded successfully');
            
        } catch (error) {
            this.error = error;
            this.showProfile = false;
            console.error('Profile Load Error:', JSON.parse(JSON.stringify(error)));
            
            // Show error toast
            this.showToast(
                'Error Loading Profile',
                error.body?.message || 'Failed to load profile data',
                'error'
            );
            
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * TASK 6: Refresh profile data without full page reload
     * Called after successful save operations
     */
    async refreshProfileData() {
        console.log('Refreshing profile data...');
        
        this.isLoading = true;
        
        try {
            // Re-fetch data from server
            const data = await getProfileData({ candidateId: this.candidateIdInput });
            
            // Update local data reactively
            this.profileData = data;
            
            console.log('Profile data refreshed successfully');
            
        } catch (error) {
            console.error('Refresh Error:', JSON.parse(JSON.stringify(error)));
            
            // Show error but don't change view
            this.showToast(
                'Refresh Error',
                'Failed to refresh profile data',
                'error'
            );
            
        } finally {
            this.isLoading = false;
        }
    }

    // ========================================================
    // TASK 4: Add New Record Handlers
    // ========================================================

    handleAddWorkExperience() {
        this.openModal('workExperience');
    }

    handleAddEducation() {
        this.openModal('education');
    }

    handleAddLicense() {
        this.openModal('license');
    }

    handleAddClinicalSkill() {
        this.openModal('clinicalSkill');
    }

    handleAddTechnicalSkill() {
        this.openModal('technicalSkill');
    }

    // ========================================================
    // TASK 4: Edit Record Handlers
    // ========================================================

    handleEditWorkExperience(event) {
        const recordId = event.detail.recordId;
        const record = this.profileData.workExperiences.find(w => w.Id === recordId);
        this.openModal('workExperience', recordId, record);
    }

    handleEditEducation(event) {
        const recordId = event.detail.recordId;
        const record = this.profileData.educations.find(e => e.Id === recordId);
        this.openModal('education', recordId, record);
    }

    handleEditLicense(event) {
        const recordId = event.currentTarget.dataset.id;
        const record = this.profileData.licenses.find(l => l.Id === recordId);
        this.openModal('license', recordId, record);
    }

    handleEditClinicalSkill(event) {
        const recordId = event.currentTarget.dataset.id;
        const record = this.profileData.clinicalSkills.find(s => s.Id === recordId);
        this.openModal('clinicalSkill', recordId, record);
    }

    handleEditTechnicalSkill(event) {
        const recordId = event.currentTarget.dataset.id;
        const record = this.profileData.technicalSkills.find(s => s.Id === recordId);
        this.openModal('technicalSkill', recordId, record);
    }

    // ========================================================
    // TASK 4: Modal Management
    // ========================================================

    /**
     * Open the dynamic modal with record type and data
     */
    openModal(type, recordId = null, recordData = null) {
        const modal = this.template.querySelector('c-dynamic-form-modal');
        if (modal) {
            modal.openModal(type, recordId, recordData);
        }
    }

    // ========================================================
    // TASK 6: Event-Driven Communication
    // ========================================================

    /**
     * TASK 6: Handle save event from modal
     * This is the key event handler that enables refresh without page reload
     * 
     * Event flow:
     * 1. User clicks Save in modal
     * 2. Modal calls Apex to save data
     * 3. Modal fires 'save' event with details
     * 4. This handler catches the event
     * 5. Refreshes profile data from server
     * 6. UI updates automatically (reactive)
     */
    async handleModalSave(event) {
        console.log('Save event received:', event.detail);
        
        const { recordType, recordId, action } = event.detail;
        
        // Show notification
        const actionText = action === 'create' ? 'added' : 'updated';
        const typeText = this.getRecordTypeLabel(recordType);
        
        this.showToast(
            'Success!',
            `${typeText} ${actionText} successfully`,
            'success'
        );
        
        // TASK 6: Refresh data without page reload
        await this.refreshProfileData();
        
        console.log('Profile refreshed after save');
    }

    /**
     * Get human-readable label for record type
     */
    getRecordTypeLabel(recordType) {
        const typeMap = {
            'workExperience': 'Work Experience',
            'education': 'Education',
            'license': 'License/Certification',
            'clinicalSkill': 'Clinical Skill',
            'technicalSkill': 'Technical Skill'
        };
        return typeMap[recordType] || 'Record';
    }

    // ========================================================
    // TASK 2: Computed Properties
    // ========================================================

    /**
     * Calculate profile completeness percentage
     */
    get completenessPercentage() {
        if (!this.profileData) return 0;
        
        let totalSections = 5;
        let completedSections = 0;

        if (this.profileData.candidate?.Email__c) completedSections++;
        if (this.hasWorkExperience) completedSections++;
        if (this.hasEducation) completedSections++;
        if (this.hasLicenses) completedSections++;
        if (this.hasClinicalSkills || this.hasTechnicalSkills) completedSections++;

        return Math.round((completedSections / totalSections) * 100);
    }

    get completenessStyle() {
        return `width: ${this.completenessPercentage}%`;
    }

    get errorText() {
        if (this.error) {
            return this.error.body?.message || this.error.message || 'An unknown error occurred. Please try again.';
        }
        return '';
    }

    get hasWorkExperience() {
        return this.profileData?.workExperiences?.length > 0;
    }

    get hasEducation() {
        return this.profileData?.educations?.length > 0;
    }

    get hasLicenses() {
        return this.profileData?.licenses?.length > 0;
    }

    get hasClinicalSkills() {
        return this.profileData?.clinicalSkills?.length > 0;
    }

    get hasTechnicalSkills() {
        return this.profileData?.technicalSkills?.length > 0;
    }

    // ========================================================
    // Utility Methods
    // ========================================================

    /**
     * Show toast notification
     */
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
                mode: 'dismissable'
            })
        );
    }
}