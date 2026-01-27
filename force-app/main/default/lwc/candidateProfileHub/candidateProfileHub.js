 // candidateProfileHub.js
// import { LightningElement, track } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import getProfileData from '@salesforce/apex/CandidateProfileController.getProfileData';

// export default class CandidateProfileHub extends LightningElement {
//     @track candidateIdInput = '';
//     @track error;
//     @track isLoading = false;
//     @track showProfile = false;
    
//     profileData;

//     handleIdChange(event) {
//         this.candidateIdInput = event.target.value;
//         this.error = undefined;
//     }

//     async handleLoadProfile() {
//         if (!this.candidateIdInput || this.candidateIdInput.trim() === '') {
//             this.error = { body: { message: 'Please enter a valid Candidate ID.' } };
//             return;
//         }

//         await this.loadProfileData();
//     }

//     handleReset() {
//         this.showProfile = false;
//         this.profileData = undefined;
//         this.candidateIdInput = '';
//         this.error = undefined;
//         this.isLoading = false;
//     }

//     async loadProfileData() {
//         this.isLoading = true;
//         this.error = undefined;
//         this.profileData = undefined;

//         try {
//             const data = await getProfileData({ candidateId: this.candidateIdInput });
            
//             // Format the data for display
//             this.profileData = this.formatProfileData(data);
//             this.showProfile = true;
            
//             console.log('Profile data loaded successfully', this.profileData);
            
//         } catch (error) {
//             this.error = error;
//             this.showProfile = false;
//             console.error('Profile Load Error:', JSON.parse(JSON.stringify(error)));
            
//             this.showToast(
//                 'Error Loading Profile',
//                 error.body?.message || 'Failed to load profile data',
//                 'error'
//             );
            
//         } finally {
//             this.isLoading = false;
//         }
//     }

//     async refreshProfileData() {
//         console.log('Refreshing profile data...');
        
//         this.isLoading = true;
        
//         try {
//             const data = await getProfileData({ candidateId: this.candidateIdInput });
//             this.profileData = this.formatProfileData(data);
            
//             console.log('Profile data refreshed successfully');
            
//             this.showProfile = false;
//             await new Promise(resolve => setTimeout(resolve, 0));
//             this.showProfile = true;
            
//         } catch (error) {
//             console.error('Refresh Error:', JSON.parse(JSON.stringify(error)));
            
//             this.showToast(
//                 'Refresh Error',
//                 'Failed to refresh profile data',
//                 'error'
//             );
            
//         } finally {
//             this.isLoading = false;
//         }
//     }

//     /**
//      * Format profile data with calculated duration strings
//      */
//     formatProfileData(data) {
//         const formatted = JSON.parse(JSON.stringify(data));

//         // Format work experiences with duration
//         if (formatted.workExperiences) {
//             formatted.workExperiences = formatted.workExperiences.map(work => ({
//                 ...work,
//                 durationDisplay: this.formatWorkDuration(work)
//             }));
//         }

//         // Format educations with year range
//         if (formatted.educations) {
//             formatted.educations = formatted.educations.map(edu => ({
//                 ...edu,
//                 durationDisplay: this.formatEducationDuration(edu)
//             }));
//         }

//         // Format licenses with dates
//         if (formatted.licenses) {
//             formatted.licenses = formatted.licenses.map(license => ({
//                 ...license,
//                 dateDisplay: this.formatLicenseDates(license)
//             }));
//         }

//         // Format internships with duration
//         if (formatted.internships) {
//             formatted.internships = formatted.internships.map(intern => ({
//                 ...intern,
//                 durationDisplay: this.formatInternshipDuration(intern)
//             }));
//         }

//         // Format research with publication date
//         if (formatted.researchPublications) {
//             formatted.researchPublications = formatted.researchPublications.map(research => ({
//                 ...research,
//                 dateDisplay: this.formatPublicationDate(research)
//             }));
//         }

//         // Format memberships with member since date
//         if (formatted.memberships) {
//             formatted.memberships = formatted.memberships.map(member => ({
//                 ...member,
//                 dateDisplay: this.formatMemberSinceDate(member)
//             }));
//         }

//         return formatted;
//     }

//     /**
//      * Format work experience duration
//      */
//     formatWorkDuration(work) {
//         if (!work.Start_Date__c) {
//             return '';
//         }

//         const startDate = new Date(work.Start_Date__c);
//         const startStr = this.formatDate(startDate);

//         if (work.Is_Current__c) {
//             return `${startStr} - Present`;
//         }

//         if (work.End_Date__c) {
//             const endDate = new Date(work.End_Date__c);
//             const endStr = this.formatDate(endDate);
//             return `${startStr} - ${endStr}`;
//         }

//         return startStr;
//     }

//     /**
//      * Format education duration from years
//      */
//     formatEducationDuration(edu) {
//         if (!edu.Start_Year__c) {
//             return '';
//         }

//         if (edu.End_Year__c) {
//             return `${edu.Start_Year__c} - ${edu.End_Year__c}`;
//         }

//         return String(edu.Start_Year__c);
//     }

//     /**
//      * Format license dates
//      */
//     formatLicenseDates(license) {
//         const parts = [];

//         if (license.Issue_Date__c) {
//             const issueDate = new Date(license.Issue_Date__c);
//             parts.push(`Issued: ${this.formatDate(issueDate)}`);
//         }

//         if (license.Expiry_Date__c) {
//             const expiryDate = new Date(license.Expiry_Date__c);
//             parts.push(`Expires: ${this.formatDate(expiryDate)}`);
//         }

//         return parts.join(' | ');
//     }

//     /**
//      * Format internship duration
//      */
//     formatInternshipDuration(intern) {
//         if (!intern.Start_Date__c) {
//             return '';
//         }

//         const startDate = new Date(intern.Start_Date__c);
//         const startStr = this.formatDate(startDate);

//         if (intern.End_Date__c) {
//             const endDate = new Date(intern.End_Date__c);
//             const endStr = this.formatDate(endDate);
//             return `${startStr} - ${endStr}`;
//         }

//         return startStr;
//     }

//     /**
//      * Format publication date
//      */
//     formatPublicationDate(research) {
//         if (!research.Publication_Date__c) {
//             return '';
//         }

//         const pubDate = new Date(research.Publication_Date__c);
//         return `Published: ${this.formatDate(pubDate)}`;
//     }

//     /**
//      * Format member since date
//      */
//     formatMemberSinceDate(member) {
//         if (!member.Member_Since__c) {
//             return '';
//         }

//         const sinceDate = new Date(member.Member_Since__c);
//         return `Member since: ${this.formatDate(sinceDate)}`;
//     }

//     /**
//      * Format date to readable string
//      */
//     formatDate(date) {
//         const options = { year: 'numeric', month: 'short', day: 'numeric' };
//         return date.toLocaleDateString('en-US', options);
//     }

//     // Add New Handlers
//     handleAddWorkExperience() {
//         this.openModal('workExperience');
//     }

//     handleAddEducation() {
//         this.openModal('education');
//     }

//     handleAddLicense() {
//         this.openModal('license');
//     }

//     handleAddClinicalSkill() {
//         this.openModal('clinicalSkill');
//     }

//     handleAddTechnicalSkill() {
//         this.openModal('technicalSkill');
//     }

//     handleAddProcedure() {
//         this.openModal('procedure');
//     }

//     handleAddInternship() {
//         this.openModal('internship');
//     }

//     handleAddResearch() {
//         this.openModal('research');
//     }

//     handleAddMembership() {
//         this.openModal('membership');
//     }

//     // Edit Handlers
//     handleEditWorkExperience(event) {
//         const recordId = event.detail.recordId;
//         const record = this.profileData.workExperiences.find(w => w.Id === recordId);
//         this.openModal('workExperience', recordId, record);
//     }

//     handleEditEducation(event) {
//         const recordId = event.detail.recordId;
//         const record = this.profileData.educations.find(e => e.Id === recordId);
//         this.openModal('education', recordId, record);
//     }

//     handleEditLicense(event) {
//         const recordId = event.currentTarget.dataset.id;
//         const record = this.profileData.licenses.find(l => l.Id === recordId);
//         this.openModal('license', recordId, record);
//     }

//     handleEditClinicalSkill(event) {
//         const recordId = event.currentTarget.dataset.id;
//         const record = this.profileData.clinicalSkills.find(s => s.Id === recordId);
//         this.openModal('clinicalSkill', recordId, record);
//     }

//     handleEditTechnicalSkill(event) {
//         const recordId = event.currentTarget.dataset.id;
//         const record = this.profileData.technicalSkills.find(s => s.Id === recordId);
//         this.openModal('technicalSkill', recordId, record);
//     }

//     handleEditProcedure(event) {
//         const recordId = event.currentTarget.dataset.id;
//         const record = this.profileData.procedures.find(p => p.Id === recordId);
//         this.openModal('procedure', recordId, record);
//     }

//     handleEditInternship(event) {
//         const recordId = event.detail.recordId;
//         const record = this.profileData.internships.find(i => i.Id === recordId);
//         this.openModal('internship', recordId, record);
//     }

//     handleEditResearch(event) {
//         const recordId = event.detail.recordId;
//         const record = this.profileData.researchPublications.find(r => r.Id === recordId);
//         this.openModal('research', recordId, record);
//     }

//     handleEditMembership(event) {
//         const recordId = event.currentTarget.dataset.id;
//         const record = this.profileData.memberships.find(m => m.Id === recordId);
//         this.openModal('membership', recordId, record);
//     }

//     openModal(type, recordId = null, recordData = null) {
//         const modal = this.template.querySelector('c-dynamic-form-modal');
//         if (modal) {
//             modal.openModal(type, recordId, recordData);
//         }
//     }

//     async handleModalSave(event) {
//         console.log('Save event received:', event.detail);
        
//         const { recordType, recordId, action } = event.detail;
        
//         const actionText = action === 'create' ? 'added' : 'updated';
//         const typeText = this.getRecordTypeLabel(recordType);
        
//         this.showToast(
//             'Success!',
//             `${typeText} ${actionText} successfully`,
//             'success'
//         );
        
//         await this.refreshProfileData();
        
//         console.log('Profile refreshed after save');
//     }

//     getRecordTypeLabel(recordType) {
//         const typeMap = {
//             'workExperience': 'Work Experience',
//             'education': 'Education',
//             'license': 'License/Certification',
//             'clinicalSkill': 'Clinical Skill',
//             'technicalSkill': 'Technical Skill',
//             'procedure': 'Procedure',
//             'internship': 'Internship',
//             'research': 'Research/Publication',
//             'membership': 'Professional Membership'
//         };
//         return typeMap[recordType] || 'Record';
//     }

//     get completenessPercentage() {
//         if (!this.profileData) return 0;
        
//         let totalSections = 5;
//         let completedSections = 0;

//         if (this.profileData.candidate?.Email__c) completedSections++;
//         if (this.hasWorkExperience) completedSections++;
//         if (this.hasEducation) completedSections++;
//         if (this.hasLicenses) completedSections++;
//         if (this.hasClinicalSkills || this.hasTechnicalSkills) completedSections++;

//         return Math.round((completedSections / totalSections) * 100);
//     }

//     get completenessStyle() {
//         return `width: ${this.completenessPercentage}%`;
//     }

//     get errorText() {
//         if (this.error) {
//             return this.error.body?.message || this.error.message || 'An unknown error occurred. Please try again.';
//         }
//         return '';
//     }

//     get hasWorkExperience() {
//         return this.profileData?.workExperiences?.length > 0;
//     }

//     get hasEducation() {
//         return this.profileData?.educations?.length > 0;
//     }

//     get hasLicenses() {
//         return this.profileData?.licenses?.length > 0;
//     }

//     get hasClinicalSkills() {
//         return this.profileData?.clinicalSkills?.length > 0;
//     }

//     get hasTechnicalSkills() {
//         return this.profileData?.technicalSkills?.length > 0;
//     }

//     get hasProcedures() {
//         return this.profileData?.procedures?.length > 0;
//     }

//     get hasInternships() {
//         return this.profileData?.internships?.length > 0;
//     }

//     get hasResearchPublications() {
//         return this.profileData?.researchPublications?.length > 0;
//     }

//     get hasMemberships() {
//         return this.profileData?.memberships?.length > 0;
//     }

//     showToast(title, message, variant) {
//         this.dispatchEvent(
//             new ShowToastEvent({
//                 title: title,
//                 message: message,
//                 variant: variant,
//                 mode: 'dismissable'
//             })
//         );
//     }
// }


// candidateProfileHub.js

// import { LightningElement, track, api } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import getProfileData from '@salesforce/apex/CandidateProfileController.getProfileData';

// export default class CandidateProfileHub extends LightningElement {
//     _candidateId;
    
//     @track error;
//     @track isLoading = false;
//     @track showProfile = false;
    
//     profileData;

//     // Watch for changes to candidateId prop
//     @api
//     get candidateId() {
//         return this._candidateId;
//     }
    
//     set candidateId(value) {
//         console.log('=== Candidate ID Setter Called ===');
//         console.log('Previous value:', this._candidateId);
//         console.log('New value:', value);
        
//         this._candidateId = value;
        
//         // Auto-load profile when candidateId is set or changed
//         if (value && value !== '') {
//             console.log('Triggering loadProfileData for candidate:', value);
//             // Use setTimeout to ensure the component is fully rendered
//             setTimeout(() => {
//                 this.loadProfileData();
//             }, 100);
//         }
//     }

//     get currentCandidateId() {
//         return this._candidateId;
//     }

//     async loadProfileData() {
//         console.log('=== loadProfileData Called ===');
//         console.log('Current candidate ID:', this._candidateId);
        
//         if (!this._candidateId) {
//             console.error('No candidate ID provided');
//             this.error = { body: { message: 'Candidate ID is required to load profile.' } };
//             return;
//         }

//         this.isLoading = true;
//         this.error = undefined;
//         this.profileData = undefined;
//         this.showProfile = false;

//         try {
//             console.log('Fetching profile data for candidate:', this._candidateId);
//             const data = await getProfileData({ candidateId: this._candidateId });
            
//             console.log('Profile data received:', data);
            
//             // Format the data for display
//             this.profileData = this.formatProfileData(data);
//             this.showProfile = true;
            
//             console.log('Profile data loaded successfully');
//             console.log('showProfile set to:', this.showProfile);
            
//         } catch (error) {
//             this.error = error;
//             this.showProfile = false;
//             console.error('Profile Load Error:', JSON.parse(JSON.stringify(error)));
            
//             this.showToast(
//                 'Error Loading Profile',
//                 error.body?.message || 'Failed to load profile data',
//                 'error'
//             );
            
//         } finally {
//             this.isLoading = false;
//             console.log('=== loadProfileData Completed ===');
//         }
//     }

//     async refreshProfileData() {
//         console.log('Refreshing profile data...');
        
//         this.isLoading = true;
        
//         try {
//             const data = await getProfileData({ candidateId: this._candidateId });
//             this.profileData = this.formatProfileData(data);
            
//             console.log('Profile data refreshed successfully');
            
//             this.showProfile = false;
//             await new Promise(resolve => setTimeout(resolve, 0));
//             this.showProfile = true;
            
//         } catch (error) {
//             console.error('Refresh Error:', JSON.parse(JSON.stringify(error)));
            
//             this.showToast(
//                 'Refresh Error',
//                 'Failed to refresh profile data',
//                 'error'
//             );
            
//         } finally {
//             this.isLoading = false;
//         }
//     }
import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProfileData from '@salesforce/apex/CandidateProfileController.getProfileData';
import getCandidateResumeInfo from '@salesforce/apex/CandidateProfileController.getCandidateResumeInfo';
import fetchResumePreviewV2 from '@salesforce/apex/OnboardingOrchestratorV2.fetchResumePreviewV2';
import persistStructuredResumeData from '@salesforce/apex/OnboardingOrchestratorV2.persistStructuredResumeData';

/**
 * candidateProfileHub
 * UPDATED: Uses lightning-file-upload (same as chatFirstRegistration)
 * Triggers: ContentDocumentLinkTrigger → CandidateTrigger → S3UploadQueueable → S3Uploader
 */
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
    
    @api
    get candidateId() {
        return this._candidateId;
    }
    
    set candidateId(value) {
        console.log('=== Candidate ID Setter ===');
        console.log('New value:', value);
        
        this._candidateId = value;
        
        if (value) {
            setTimeout(() => {
                this.loadProfileData();
                this.loadResumeInfo();
            }, 100);
        }
    }
    
    get currentCandidateId() {
        return this._candidateId;
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
            console.log('✅ Resume info loaded, AI parsing:', this.useAiParsing);
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
    // RESUME UPLOAD - SAME AS chatFirstRegistration
    // ========================================
    
    handleUploadResume() {
        this.showResumeUpload = true;
    }
    
    handleChangeResume() {
        this.showResumeUpload = true;
    }
    
    handleCancelUpload() {
        this.showResumeUpload = false;
    }
    
    /**
     * CRITICAL: Uses lightning-file-upload (same as chatFirstRegistration)
     * Automatically triggers: ContentDocumentLinkTrigger → S3 upload
     */
    async handleUploadFinished(event) {
        console.log('=== Upload Finished (chatFirstRegistration flow) ===');
        
        const uploadedFiles = event.detail.files;
        if (!uploadedFiles || uploadedFiles.length === 0) {
            this.showResumeUpload = false;
            return;
        }
        
        console.log('✅ File uploaded to Salesforce');
        console.log('✅ Triggers will fire automatically');
        
        this.isProcessingResume = true;
        this.uploadMessage = 'Resume uploaded! Processing in background...';
        this.showToast('Success', 'Resume uploaded. S3 upload processing in background.', 'success');
        
        // Wait for S3 upload (background job takes ~10 seconds)
        await this.delay(10000);
        
        // AI Processing (if enabled)
        if (this.useAiParsing) {
            try {
                console.log('AI Parsing enabled - processing resume');
                this.uploadMessage = 'Processing with AI...';
                await this.processWithAI();
                this.showToast('Success', 'Resume processed and profile updated!', 'success');
            } catch (error) {
                console.error('AI processing error:', error);
                this.showToast('Warning', 'Resume uploaded but AI processing failed.', 'warning');
            }
        }
        
        // Refresh
        this.isProcessingResume = false;
        this.showResumeUpload = false;
        await this.loadResumeInfo();
        await this.loadProfileData();
    }
    
    async processWithAI() {
        await this.delay(5000); // Extra wait for S3 URL
        const jsonString = await fetchResumePreviewV2({ candidateId: this._candidateId });
        
        if (!jsonString || jsonString.trim() === '') {
            throw new Error('AI service returned empty response');
        }
        
        const parsedData = JSON.parse(jsonString);
        const dataWithId = { candidateId: this._candidateId, ...parsedData };
        await persistStructuredResumeData({ jsonData: JSON.stringify(dataWithId) });
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
        if (!edu.Start_Year__c) return '';
        if (edu.End_Year__c) return `${edu.Start_Year__c} - ${edu.End_Year__c}`;
        return String(edu.Start_Year__c);
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
    // ADD/EDIT HANDLERS
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
    
    openModal(type, recordId = null, recordData = null) {
        const modal = this.template.querySelector('c-dynamic-form-modal');
        if (modal) {
            modal.openModal(type, recordId, recordData);
        }
    }
    
    async handleModalSave(event) {
        const { recordType, action } = event.detail;
        const actionText = action === 'create' ? 'added' : 'updated';
        const typeText = this.getRecordTypeLabel(recordType);
        this.showToast('Success!', `${typeText} ${actionText} successfully`, 'success');
        await this.refreshProfileData();
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
    
    get completenessPercentage() {
        if (!this.profileData) return 0;
        let totalSections = 9;
        let completedSections = 0;
        if (this.profileData.candidate?.Email__c) completedSections++;
        if (this.hasWorkExperience) completedSections++;
        if (this.hasEducation) completedSections++;
        if (this.hasLicenses) completedSections++;
        if (this.hasClinicalSkills) completedSections++;
        if (this.hasTechnicalSkills) completedSections++;
        if (this.hasProcedures) completedSections++;
        if (this.hasInternships) completedSections++;
        if (this.hasResearchPublications) completedSections++;
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
    
    // ========================================
    // UTILITIES
    // ========================================
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'dismissable' }));
    }
    
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}