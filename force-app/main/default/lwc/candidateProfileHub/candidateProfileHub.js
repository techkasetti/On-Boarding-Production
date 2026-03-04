// candidateProfileHub.js

import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getProfileData from '@salesforce/apex/CandidateProfileController.getProfileData';
import getCandidateResumeInfo from '@salesforce/apex/CandidateProfileController.getCandidateResumeInfo';
import resetResumeStatus from '@salesforce/apex/CandidateProfileController.resetResumeStatus';
import deleteRecord from '@salesforce/apex/CandidateProfileController.deleteRecord';
import persistStructuredResumeData from '@salesforce/apex/OnboardingOrchestratorV2.persistStructuredResumeData';
import getAllJobPostings from '@salesforce/apex/CandidateJobMatcherController.getAllJobPostings';
import getAiMatchedJobs from '@salesforce/apex/CandidateJobMatcherController.getAiMatchedJobs';

export default class CandidateProfileHub extends LightningElement {
    _candidateId;
    
    @track error;
    @track isLoading = false;
    @track showProfile = false;
    
    profileData;
    
    // Resume properties
    @track hasResume = false;
    @track resumeFileName = '';
    @track resumeUploadDate = '';
    @track s3ResumeUrl = '';
    @track useAiParsing = false;
    
    // Upload UI properties  
    @track showResumeUpload = false;
    @track isProcessingResume = false;
    @track uploadMessage = '';
    @track resumeStatusWasReset = false;
    
    // Modal and analyzing states
    @track showPreviewModal = false;
    @track isAnalyzingResume = false;

    // AI job matcher states
    @track activeJobView = 'all';
    @track allJobs = [];
    @track matchedJobs = [];
    @track isLoadingAllJobs = false;
    @track isLoadingMatchedJobs = false;
    @track jobsError = '';
    hasLoadedMatchedJobs = false;
    
    @api
    get candidateId() {
        return this._candidateId;
    }
    
    set candidateId(value) {
        console.log('=== Candidate ID Setter ===');
        console.log('Previous value:', this._candidateId);
        console.log('New value:', value);
        
        this._candidateId = value;
        
        if (value) {
<<<<<<< Updated upstream
<<<<<<< Updated upstream
            setTimeout(() => {
                this.loadProfileData();
                this.loadResumeInfo();
            }, 100);
=======
=======
>>>>>>> Stashed changes
            this.showResumeUpload = false;
            this.showPhotoUpload = false;
            this.showPreviewModal = false;
            this.activeJobView = 'all';
            this.hasLoadedMatchedJobs = false;
            this.matchedJobs = [];
            this.jobsError = '';
            this.loadProfileData();
            this.loadResumeInfo();
            this.loadPhotoInfo();
            this.loadAllJobPostings();
<<<<<<< Updated upstream
>>>>>>> Stashed changes
=======
>>>>>>> Stashed changes
        }
    }
    
    get currentCandidateId() {
        const id = this._candidateId;
        console.log('📌 currentCandidateId getter called, returning:', id);
        if (!id) {
            console.error('❌ WARNING: currentCandidateId is null/undefined!');
        }
        return id;
    }
    
    // ========================================
    // DATA LOADING
    // ========================================
    
    async loadProfileData() {
        if (!this._candidateId) {
            this.error = { body: { message: 'Candidate ID required' } };
            return;
        }
        
        this.isLoading = true;
        this.error = undefined;
        this.profileData = undefined;
        this.showProfile = false;
        
        try {
            const data = await getProfileData({ candidateId: this._candidateId });
            this.profileData = this.formatProfileData(data);
            this.showProfile = true;
        } catch (error) {
            this.error = error;
            this.showProfile = false;
            this.showToast('Error Loading Profile', error.body?.message || 'Failed to load profile data', 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    async loadResumeInfo() {
        if (!this._candidateId) return;
        
        try {
            const resumeInfo = await getCandidateResumeInfo({ candidateId: this._candidateId });
            this.hasResume = resumeInfo.hasResume || false;
            this.resumeFileName = resumeInfo.fileName || '';
            this.resumeUploadDate = resumeInfo.uploadDate || '';
            this.s3ResumeUrl = resumeInfo.s3Url || '';
            this.useAiParsing = resumeInfo.useAiParsing === true;
            console.log('✅ Resume info loaded:');
            console.log('   - Has Resume:', this.hasResume);
            console.log('   - File Name:', this.resumeFileName);
            console.log('   - S3 URL:', this.s3ResumeUrl);
            console.log('   - AI Parsing:', this.useAiParsing);
        } catch (error) {
            console.error('Error loading resume info:', error);
        }
    }
    
    async refreshProfileData() {
        if (!this._candidateId) return;
        
        this.isLoading = true;
        try {
            const data = await getProfileData({ candidateId: this._candidateId });
            this.profileData = this.formatProfileData(data);
            this.showProfile = false;
            await this.delay(50);
            this.showProfile = true;
        } catch (error) {
            this.showToast('Error', 'Failed to refresh profile', 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    // ========================================
    // RESUME UPLOAD - WITH MODAL
    // ========================================
    
    async handleUploadResume() {
        console.log('=== 🚀 handleUploadResume Called ===');
        console.log('Candidate ID (_candidateId):', this._candidateId);
        console.log('Candidate ID (getter):', this.currentCandidateId);
        
        if (!this._candidateId) {
            console.error('❌ CRITICAL ERROR: Candidate ID is null or undefined!');
            this.showToast('Error', 'Candidate ID is missing. Cannot upload resume. Please refresh the page.', 'error');
            return;
        }
        
        try {
            console.log('⏳ Resetting Resume_Status__c to false...');
            await resetResumeStatus({ candidateId: this._candidateId });
            console.log('✅ Resume_Status__c reset to false before upload');
            this.resumeStatusWasReset = true;
        } catch (error) {
            console.error('❌ Error resetting resume status:', error);
            this.resumeStatusWasReset = false;
        }
        
        this.showResumeUpload = true;
        console.log('✅ Upload UI displayed');
        
        await this.delay(100);
        console.log('🔄 Component re-rendered, record-id should be:', this._candidateId);
    }
    
    async handleChangeResume() {
        console.log('=== 🔄 handleChangeResume Called ===');
        console.log('Candidate ID (_candidateId):', this._candidateId);
        console.log('Candidate ID (getter):', this.currentCandidateId);
        
        if (!this._candidateId) {
            console.error('❌ CRITICAL ERROR: Candidate ID is null or undefined!');
            this.showToast('Error', 'Candidate ID is missing. Cannot change resume. Please refresh the page.', 'error');
            return;
        }
        
        try {
            console.log('⏳ Resetting Resume_Status__c to false...');
            await resetResumeStatus({ candidateId: this._candidateId });
            console.log('✅ Resume_Status__c reset to false before replacing resume');
            this.resumeStatusWasReset = true;
        } catch (error) {
            console.error('❌ Error resetting resume status:', error);
            this.resumeStatusWasReset = false;
        }
        
        this.showResumeUpload = true;
        console.log('✅ Upload UI displayed');
        
        await this.delay(100);
        console.log('🔄 Component re-rendered, record-id should be:', this._candidateId);
    }
    
    handleCancelUpload() {
        console.log('=== ❌ Upload Cancelled ===');
        this.showResumeUpload = false;
        this.resumeStatusWasReset = false;
    }
<<<<<<< Updated upstream
=======

    handleUploadPhoto() {
        this.showPhotoUpload = true;
    }

    handleChangePhoto() {
        this.showPhotoUpload = true;
    }

    handleCancelPhotoUpload() {
        this.showPhotoUpload = false;
    }

    async handlePhotoUploadFinished(event) {
        if (!this._candidateId) {
            this.showPhotoUpload = false;
            this.showToast('Error', 'Candidate ID is missing. Please refresh and try again.', 'error');
            return;
        }

        const uploadedFiles = event.detail.files;

        if (!uploadedFiles || uploadedFiles.length === 0) {
            this.showPhotoUpload = false;
            return;
        }

        try {
            const uploaded = uploadedFiles[0];
            const fileName = (uploaded.name || '').toLowerCase();
            const isImage = ['.jpg', '.jpeg', '.png', '.webp', '.gif'].some(ext => fileName.endsWith(ext));
            if (!isImage) {
                this.showPhotoUpload = false;
                this.showToast('Error', 'Only JPG, JPEG, PNG, WEBP, and GIF files are allowed.', 'error');
                return;
            }

            await setCandidateProfilePhoto({
                candidateId: this._candidateId,
                contentDocumentId: uploaded.documentId
            });

            this.showPhotoUpload = false;
            await this.loadPhotoInfo();
            this.showToast('Success', 'Profile photo updated successfully', 'success');
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to update profile photo', 'error');
        }
    }

    async loadAllJobPostings() {
        this.isLoadingAllJobs = true;
        this.jobsError = '';
        try {
            const rows = await getAllJobPostings();
            this.allJobs = (rows || []).map((job) => this.toJobCard(job));
        } catch (error) {
            this.jobsError = error?.body?.message || error?.message || 'Failed to load job postings.';
            this.allJobs = [];
        } finally {
            this.isLoadingAllJobs = false;
        }
    }

    async loadMatchedJobs(forceReload = false) {
        if (!this._candidateId) return;
        if (this.hasLoadedMatchedJobs && !forceReload) return;

        this.isLoadingMatchedJobs = true;
        this.jobsError = '';
        try {
            const rows = await getAiMatchedJobs({ candidateId: this._candidateId, maxResults: 25 });
            this.matchedJobs = (rows || []).map((row) => this.toMatchedJobCard(row));
            this.hasLoadedMatchedJobs = true;
        } catch (error) {
            this.jobsError = error?.body?.message || error?.message || 'Failed to load AI matched jobs.';
            this.matchedJobs = [];
        } finally {
            this.isLoadingMatchedJobs = false;
        }
    }

    async handleJobViewChange(event) {
        const selected = event.currentTarget?.dataset?.view;
        if (!selected || selected === this.activeJobView) return;
        this.activeJobView = selected;
        if (selected === 'matched') {
            await this.loadMatchedJobs();
        }
    }

    toJobCard(job) {
        return {
            ...job,
            title: job.Job_Title__c || job.Name || 'Untitled Job',
            locationText: this.formatJobLocation(job),
            experienceText: this.formatJobExperience(job),
            statusText: job.Job_Status__c || 'Not specified'
        };
    }

    toMatchedJobCard(row) {
        const card = this.toJobCard(row.jobPosting || {});
        return {
            ...card,
            matchScore: row.matchScore,
            scoreLabel: row.scoreLabel || 'Match',
            reasons: row.reasons || [],
            hasReasons: (row.reasons || []).length > 0
        };
    }

    formatJobLocation(job) {
        const parts = [job.City__c, job.State__c, job.Country__c].filter(Boolean);
        return parts.length > 0 ? parts.join(', ') : 'Location not specified';
    }

    formatJobExperience(job) {
        const min = job.Min_Experience_Years__c;
        const max = job.Max_Experience_Years__c;
        if (min != null && max != null) return `${min}-${max} years`;
        if (min != null) return `${min}+ years`;
        if (max != null) return `Up to ${max} years`;
        return 'Experience not specified';
    }

    async handleRemovePhoto() {
        if (!this._candidateId) {
            this.showToast('Error', 'Candidate ID is missing. Please refresh and try again.', 'error');
            return;
        }

        const confirmed = await LightningConfirm.open({
            message: 'Remove current profile photo?',
            label: 'Confirm Remove',
            variant: 'headerless'
        });
        if (!confirmed) return;

        try {
            await deleteCandidatePhoto({ candidateId: this._candidateId });
            await this.loadPhotoInfo();
            this.showPhotoUpload = false;
            this.showToast('Success', 'Profile photo removed', 'success');
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to remove profile photo', 'error');
        }
    }
>>>>>>> Stashed changes
    
    // /**
    //  * Shows modal with spinner immediately during S3 upload
    //  */
    // async handleUploadFinished(event) {
    //     console.log('=== 📤 Upload Finished Event ===');
        
    //     const uploadedFiles = event.detail.files;
    //     console.log('Uploaded Files:', uploadedFiles);
        
    //     if (!uploadedFiles || uploadedFiles.length === 0) {
    //         console.log('⚠️ No files uploaded');
    //         this.showResumeUpload = false;
    //         this.resumeStatusWasReset = false;
    //         return;
    //     }
        
    //     const uploadedFile = uploadedFiles[0];
    //     console.log('✅ File uploaded:', uploadedFile.name);
        
    //     this.resumeStatusWasReset = false;
        
    //     if (this.useAiParsing) {
    //         console.log('🤖 AI Parsing enabled - opening modal immediately');
            
    //         // Close upload UI
    //         this.showResumeUpload = false;
            
    //         // Open modal with analyzing spinner IMMEDIATELY
    //         this.showPreviewModal = true;
    //         this.isAnalyzingResume = true;
            
    //         // Wait for S3 upload (15 seconds) - spinner shows during this time
    //         console.log('⏳ Waiting 15 seconds for S3 upload (spinner showing)...');
    //         await this.delay(15000);
            
    //         console.log('✅ S3 upload complete. Loading resume info...');
    //         await this.loadResumeInfo();
            
    //         // Add 3 more seconds for "AI analysis"
    //         console.log('⏳ Simulating AI analysis (3 seconds)...');
    //         await this.delay(3000);
            
    //         // Hide spinner, show preview component
    //         this.isAnalyzingResume = false;
    //         console.log('✅ AI analysis complete, showing preview');
            
    //     } else {
    //         console.log('ℹ️ AI Parsing disabled - showing inline processing');
    //         this.isProcessingResume = true;
    //         this.uploadMessage = 'Resume uploaded! Processing in background...';
            
    //         // Wait for S3 upload
    //         console.log('⏳ Waiting 15 seconds for S3 upload...');
    //         await this.delay(15000);
            
    //         console.log('✅ S3 upload complete');
    //         this.isProcessingResume = false;
    //         this.showResumeUpload = false;
    //         this.showToast('Success', 'Resume uploaded successfully!', 'success');
    //         await this.loadResumeInfo();
    //         await this.loadProfileData();
    //     }
    // }
    async handleUploadFinished(event) {
    console.log('=== 📤 Upload Finished Event ===');
    
    const uploadedFiles = event.detail.files;
    console.log('Uploaded Files:', uploadedFiles);
    
    if (!uploadedFiles || uploadedFiles.length === 0) {
        console.log('⚠️ No files uploaded');
        this.showResumeUpload = false;
        this.resumeStatusWasReset = false;
        return;
    }
    
    const uploadedFile = uploadedFiles[0];
    console.log('✅ File uploaded:', uploadedFile.name);
    
    this.resumeStatusWasReset = false;
    
    if (this.useAiParsing) {
        console.log('🤖 AI Parsing enabled - opening modal for S3 upload + analysis');
        
        // Close upload UI
        this.showResumeUpload = false;
        
        // Open modal with analyzing spinner IMMEDIATELY
        this.showPreviewModal = true;
        this.isAnalyzingResume = true;
        
        // Wait for S3 upload (15 seconds) - spinner shows during this time
        console.log('⏳ Waiting 15 seconds for S3 upload (spinner showing)...');
        await this.delay(15000);
        
        console.log('✅ S3 upload complete. Loading resume info...');
        await this.loadResumeInfo();
        
        // Add 3 more seconds for "AI analysis"
        console.log('⏳ Simulating AI analysis (3 seconds)...');
        await this.delay(3000);
        
        // Hide spinner, show preview component
        this.isAnalyzingResume = false;
        console.log('✅ AI analysis complete, showing preview');
        
    } else {
        console.log('ℹ️ AI Parsing disabled - file uploaded to Salesforce only (no S3)');
        
        // 🔥 FIX: No S3 upload when AI parsing is disabled
        // File is already in Salesforce - just refresh immediately
        
        // Hide upload UI
        this.showResumeUpload = false;
        
        // 🔥 FIX: Small delay to let Salesforce process the ContentVersion
        console.log('⏳ Waiting 2 seconds for Salesforce to process file...');
        await this.delay(2000);
        
        // 🔥 FIX: Refresh resume info to show the new file
        console.log('🔄 Refreshing resume info...');
        await this.loadResumeInfo();
        
        // Show success message
        this.showToast('Success', 'Resume uploaded successfully!', 'success');
        
        console.log('✅ Resume displayed in UI');
    }
}
    /**
     * Close preview modal
     */
    handleClosePreviewModal() {
        console.log('=== ❌ Closing Preview Modal ===');
        this.showPreviewModal = false;
        this.isAnalyzingResume = false;
    }
    
    /**
     * Close modal after confirmation
     */
    async handleResumeConfirmed(event) {
        console.log('=== ✅ Resume Confirmed ===');
        const detail = event.detail;
        console.log('Received data:', detail);
        
        // 🔥 FIX: Close modal immediately after confirmation
        this.showPreviewModal = false;
        this.isAnalyzingResume = false;
        
        this.isLoading = true;
        
        try {
            console.log('💾 Saving structured resume data...');
            await persistStructuredResumeData({ jsonData: JSON.stringify(detail) });
            
            console.log('✅ Resume data persisted successfully');
            this.showToast('Success', 'Resume processed and profile updated!', 'success');
            
            console.log('🔄 Refreshing profile data...');
            await this.loadResumeInfo();
            await this.loadProfileData();
            console.log('✅ Profile refreshed');
            
        } catch (error) {
            console.error('❌ Error saving resume data:', error);
            this.showToast('Error', 'Failed to save resume data: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    /**
     * Close modal on cancel
     */
    handleResumeCancelled() {
        console.log('=== ❌ Resume Preview Cancelled ===');
        
        // 🔥 FIX: Close modal when user cancels
        this.showPreviewModal = false;
        this.isAnalyzingResume = false;
        
        this.showToast('Info', 'You can upload another resume when ready.', 'info');
    }
    
    // ========================================
    // DELETE HANDLERS
    // ========================================
    
    async handleDeleteWorkExperience(event) {
        await this.handleDeleteRecord(event, 'workExperience', 'Work Experience');
    }
    
    async handleDeleteEducation(event) {
        await this.handleDeleteRecord(event, 'education', 'Education');
    }
    
    async handleDeleteLicense(event) {
        const recordId = event.currentTarget.dataset.id;
        await this.handleDeleteRecordById(recordId, 'license', 'License/Certification');
    }
    
    async handleDeleteClinicalSkill(event) {
        event.stopPropagation();
        const recordId = event.currentTarget.dataset.id;
        await this.handleDeleteRecordById(recordId, 'clinicalSkill', 'Clinical Skill');
    }
    
    async handleDeleteTechnicalSkill(event) {
        event.stopPropagation();
        const recordId = event.currentTarget.dataset.id;
        await this.handleDeleteRecordById(recordId, 'technicalSkill', 'Technical Skill');
    }
    
    async handleDeleteProcedure(event) {
        const recordId = event.currentTarget.dataset.id;
        await this.handleDeleteRecordById(recordId, 'procedure', 'Procedure');
    }
    
    async handleDeleteInternship(event) {
        await this.handleDeleteRecord(event, 'internship', 'Internship');
    }
    
    async handleDeleteResearch(event) {
        await this.handleDeleteRecord(event, 'research', 'Research/Publication');
    }
    
    async handleDeleteMembership(event) {
        const recordId = event.currentTarget.dataset.id;
        await this.handleDeleteRecordById(recordId, 'membership', 'Professional Membership');
    }
    
    async handleDeleteRecord(event, recordType, recordLabel) {
        const recordId = event.detail.recordId;
        await this.handleDeleteRecordById(recordId, recordType, recordLabel);
    }
    
    async handleDeleteRecordById(recordId, recordType, recordLabel) {
        console.log('=== Delete Record ===');
        console.log('Record ID:', recordId);
        console.log('Record Type:', recordType);
        
        if (!recordId) {
            console.error('No record ID provided');
            return;
        }
        
        const confirmed = await LightningConfirm.open({
            message: `Are you sure you want to delete this ${recordLabel}?`,
            label: `Delete ${recordLabel}`,
            variant: 'headerless'
        });

        if (!confirmed) {
            console.log('Delete cancelled by user');
            return;
        }
        
        this.isLoading = true;
        
        try {
            console.log('Deleting record...');
            await deleteRecord({ recordId: recordId, recordType: recordType });
            
            console.log('✅ Record deleted successfully');
            this.showToast('Success!', `${recordLabel} deleted successfully`, 'success');
            await this.refreshProfileData();
            
        } catch (error) {
            console.error('❌ Error deleting record:', error);
            this.showToast('Error', 'Failed to delete record: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    // ========================================
    // DATA FORMATTING
    // ========================================
    
    formatProfileData(data) {
        const formatted = JSON.parse(JSON.stringify(data));
        
        if (formatted.workExperiences) {
            formatted.workExperiences = formatted.workExperiences.map(work => ({
                ...work,
                durationDisplay: this.formatWorkDuration(work)
            }));
        }
        
        if (formatted.educations) {
            formatted.educations = formatted.educations.map(edu => ({
                ...edu,
                durationDisplay: this.formatEducationDuration(edu)
            }));
        }
        
        if (formatted.licenses) {
            formatted.licenses = formatted.licenses.map(license => ({
                ...license,
                dateDisplay: this.formatLicenseDates(license)
            }));
        }
        
        if (formatted.internships) {
            formatted.internships = formatted.internships.map(intern => ({
                ...intern,
                durationDisplay: this.formatInternshipDuration(intern)
            }));
        }
        
        if (formatted.researchPublications) {
            formatted.researchPublications = formatted.researchPublications.map(research => ({
                ...research,
                dateDisplay: this.formatPublicationDate(research)
            }));
        }
        
        if (formatted.memberships) {
            formatted.memberships = formatted.memberships.map(member => ({
                ...member,
                dateDisplay: this.formatMemberSinceDate(member)
            }));
        }
        
        return formatted;
    }
    
    formatWorkDuration(work) {
        if (!work.Start_Date__c) return '';
        const startDate = new Date(work.Start_Date__c);
        const startStr = this.formatDate(startDate);
        if (work.Is_Current__c) return `${startStr} - Present`;
        if (work.End_Date__c) {
            return `${startStr} - ${this.formatDate(new Date(work.End_Date__c))}`;
        }
        return startStr;
    }
    
    formatEducationDuration(edu) {
        // parseInt removes any comma formatting Salesforce adds to Number fields
        const startYear = edu.Start_Year__c ? parseInt(edu.Start_Year__c, 10) : null;
        const endYear = edu.End_Year__c ? parseInt(edu.End_Year__c, 10) : null;
        if (!startYear) return '';
        if (endYear) return `${startYear} - ${endYear}`;
        return String(startYear);
    }

    formatLicenseDates(license) {
        const parts = [];
        if (license.Issue_Date__c) {
            parts.push(`Issued: ${this.formatDate(new Date(license.Issue_Date__c))}`);
        }
        if (license.Expiry_Date__c) {
            parts.push(`Expires: ${this.formatDate(new Date(license.Expiry_Date__c))}`);
        }
        return parts.join(' | ');
    }
    
    formatInternshipDuration(intern) {
        if (!intern.Start_Date__c) return '';
        const startStr = this.formatDate(new Date(intern.Start_Date__c));
        if (intern.End_Date__c) {
            return `${startStr} - ${this.formatDate(new Date(intern.End_Date__c))}`;
        }
        return startStr;
    }
    
    formatPublicationDate(research) {
        if (!research.Publication_Date__c) return '';
        return `Published: ${this.formatDate(new Date(research.Publication_Date__c))}`;
    }
    
    formatMemberSinceDate(member) {
        if (!member.Member_Since__c) return '';
        return `Member since: ${this.formatDate(new Date(member.Member_Since__c))}`;
    }
    
    formatDate(date) {
        const options = { year: 'numeric', month: 'short', day: 'numeric' };
        return date.toLocaleDateString('en-US', options);
    }
    
    // ========================================
    // ADD/EDIT HANDLERS - WITH MODAL MANAGEMENT
    // ========================================
    
    handleAddWorkExperience() { this.openModal('workExperience'); }
    handleAddEducation() { this.openModal('education'); }
    handleAddLicense() { this.openModal('license'); }
    handleAddClinicalSkill() { this.openModal('clinicalSkill'); }
    handleAddTechnicalSkill() { this.openModal('technicalSkill'); }
    handleAddProcedure() { this.openModal('procedure'); }
    handleAddInternship() { this.openModal('internship'); }
    handleAddResearch() { this.openModal('research'); }
    handleAddMembership() { this.openModal('membership'); }
    
    handleEditWorkExperience(event) {
        const recordId = event.detail.recordId;
        const record = this.profileData.workExperiences.find(w => w.Id === recordId);
        this.openModal('workExperience', recordId, record);
    }
   
    handleEditEducation(event) {
    const recordId = event.detail.recordId;
    // Find the full record so year values can be pre-populated in the modal
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
    
    handleEditProcedure(event) {
        const recordId = event.currentTarget.dataset.id;
        const record = this.profileData.procedures.find(p => p.Id === recordId);
        this.openModal('procedure', recordId, record);
    }
    
    handleEditInternship(event) {
        const recordId = event.detail.recordId;
        const record = this.profileData.internships.find(i => i.Id === recordId);
        this.openModal('internship', recordId, record);
    }
    
    handleEditResearch(event) {
        const recordId = event.detail.recordId;
        const record = this.profileData.researchPublications.find(r => r.Id === recordId);
        this.openModal('research', recordId, record);
    }
    
    handleEditMembership(event) {
        const recordId = event.currentTarget.dataset.id;
        const record = this.profileData.memberships.find(m => m.Id === recordId);
        this.openModal('membership', recordId, record);
    }
    
    /**
     * Opens the dynamic form modal
     */
    openModal(type, recordId = null, recordData = null) {
        console.log('=== 🎯 Opening Modal ===');
        console.log('Type:', type);
        console.log('Record ID:', recordId);
        console.log('Record Data:', recordData);
        
        const modal = this.template.querySelector('c-dynamic-form-modal');
        if (modal) {
            modal.openModal(type, recordId, recordData);
        } else {
            console.error('❌ Dynamic form modal not found in template');
        }
    }
    
    /**
     * 🔥 FIX: Handle modal save - closes modal and refreshes data
     */
    async handleModalSave(event) {
        console.log('=== 💾 Modal Save Event Received ===');
        
        const { recordType, action } = event.detail;
        const actionText = action === 'create' ? 'added' : 'updated';
        const typeText = this.getRecordTypeLabel(recordType);
        
        console.log(`✅ ${typeText} ${actionText} successfully`);
        
        // 🔥 FIX: Modal is already closed by the child component
        // We just need to refresh the data here
        
        this.showToast('Success!', `${typeText} ${actionText} successfully`, 'success');
        await this.refreshProfileData();
        
        console.log('✅ Profile data refreshed after save');
    }
    
    getRecordTypeLabel(recordType) {
        const typeMap = {
            'workExperience': 'Work Experience',
            'education': 'Education',
            'license': 'License/Certification',
            'clinicalSkill': 'Clinical Skill',
            'technicalSkill': 'Technical Skill',
            'procedure': 'Procedure',
            'internship': 'Internship',
            'research': 'Research/Publication',
            'membership': 'Professional Membership'
        };
        return typeMap[recordType] || 'Record';
    }
    
    // ========================================
    // COMPUTED PROPERTIES
    // ========================================
    
    // get completenessPercentage() {
    //     if (!this.profileData) return 0;
    //     let totalSections = 9;
    //     let completedSections = 0;
    //     if (this.profileData.candidate?.Email__c) completedSections++;
    //     if (this.hasWorkExperience) completedSections++;
    //     if (this.hasEducation) completedSections++;
    //     if (this.hasLicenses) completedSections++;
    //     if (this.hasClinicalSkills) completedSections++;
    //     if (this.hasTechnicalSkills) completedSections++;
    //     if (this.hasProcedures) completedSections++;
    //     if (this.hasInternships) completedSections++;
    //     if (this.hasResearchPublications) completedSections++;
    //     return Math.round((completedSections / totalSections) * 100);
    // }
    get completenessPercentage() {
    if (!this.profileData) return 0;
    
    let totalSections = 8;
    let completedSections = 0;
    
    // 1. Basic Info
    if (this.profileData.candidate?.Email__c && 
        this.profileData.candidate?.Phone__c && 
        this.profileData.candidate?.Location__c) {
        completedSections++;
    }
    
    // 2. Resume
    if (this.hasResume) {
        completedSections++;
    }
    
    // 3. Education
    if (this.hasEducation) {
        completedSections++;
    }
    
    // 4. Work Experience
    if (this.hasWorkExperience) {
        completedSections++;
    }
    
    // 5. Clinical Skills
    if (this.hasClinicalSkills) {
        completedSections++;
    }
    
    // 6. Technical Skills
    if (this.hasTechnicalSkills) {
        completedSections++;
    }
    
    // 7. Licenses/Certifications
    if (this.hasLicenses) {
        completedSections++;
    }
    
    // 8. Procedures
    if (this.hasProcedures) {
        completedSections++;
    }
    
    return Math.round((completedSections / totalSections) * 100);
}
    get completenessStyle() {
        return `width: ${this.completenessPercentage}%`;
    }
    
    get errorText() {
        return this.error?.body?.message || this.error?.message || 'An error occurred';
    }
    
    get hasWorkExperience() { return this.profileData?.workExperiences?.length > 0; }
    get hasEducation() { return this.profileData?.educations?.length > 0; }
    get hasLicenses() { return this.profileData?.licenses?.length > 0; }
    get hasClinicalSkills() { return this.profileData?.clinicalSkills?.length > 0; }
    get hasTechnicalSkills() { return this.profileData?.technicalSkills?.length > 0; }
    get hasProcedures() { return this.profileData?.procedures?.length > 0; }
    get hasInternships() { return this.profileData?.internships?.length > 0; }
    get hasResearchPublications() { return this.profileData?.researchPublications?.length > 0; }
    get hasMemberships() { return this.profileData?.memberships?.length > 0; }
    get isAllJobsView() { return this.activeJobView === 'all'; }
    get isMatchedJobsView() { return this.activeJobView === 'matched'; }
    get allJobsButtonVariant() { return this.isAllJobsView ? 'brand' : 'neutral'; }
    get matchedJobsButtonVariant() { return this.isMatchedJobsView ? 'brand' : 'neutral'; }
    get hasAllJobs() { return this.allJobs.length > 0; }
    get hasMatchedJobs() { return this.matchedJobs.length > 0; }
    
    // ========================================
    // UTILITIES
    // ========================================
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ 
            title, 
            message, 
            variant, 
            mode: 'dismissable' 
        }));
    }
    
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
<<<<<<< Updated upstream
}
<<<<<<< Updated upstream
=======
}

>>>>>>> Stashed changes
=======

>>>>>>> Stashed changes
