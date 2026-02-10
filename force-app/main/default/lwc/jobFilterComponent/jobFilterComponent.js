// jobFilterComponent.js - FIXED VERSION WITH PROPER REACTIVE UPDATES

import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getJobPostings from '@salesforce/apex/JobPostingController.getJobPostings';
import getJobDetails from '@salesforce/apex/JobPostingController.getJobDetails';
import isGuestUser from '@salesforce/apex/JobPostingController.isGuestUser';
import getCandidateIdForCurrentUser from '@salesforce/apex/JobPostingController.getCandidateIdForCurrentUser';
import createJobApplication from '@salesforce/apex/JobPostingController.createJobApplication';
import getCandidateApplications from '@salesforce/apex/JobPostingController.getCandidateApplications';
import { refreshApex } from '@salesforce/apex';
import checkCandidateEligibility from '@salesforce/apex/JobPostingController.checkCandidateEligibility';

export default class JobFilterComponent extends NavigationMixin(LightningElement) {
    @track keyword = '';
    @track location = '';
    @track datePosted = 'all';
    @track experienceLevel = 'all';
    @track showFilters = false;
    @track jobs = [];
    @track isLoading = false;
    @track error;
    @track selectedJob = null;
    @track jobRequirements = null;
    @track showJobModal = false;
    @track isGuest = true;
    @track showProfileMenu = false;
    @track showProfileView = false;
    @track showAppliedJobsView = false;
    @track candidateId = null;
    @track candidateName = 'User';
    @track appliedJobs = [];
    @track isLoadingApplications = false;
    @track isJobAlreadyApplied = false;
    
    appliedJobIds = new Set();

    // NOTIFICATION PROPERTIES
    @track showNotification = false;
    @track notificationTitle = '';
    @track notificationMessage = '';
    @track notificationVariant = 'info';
    notificationTimeout;

    wiredJobsResult;

    datePostedOptions = [
        { label: 'Any Time', value: 'all' },
        { label: 'Past 24 hours', value: '24h' },
        { label: 'Past Week', value: 'week' },
        { label: 'Past Month', value: 'month' }
    ];

    experienceLevelOptions = [
        { label: 'All Levels', value: 'all' },
        { label: '0-2 Years', value: '1' },
        { label: '2-5 Years', value: '3' },
        { label: '5-10 Years', value: '7' },
        { label: '10+ Years', value: '10' }
    ];

    connectedCallback() {
        this.checkUserLoginStatus();
        document.addEventListener('click', this.handleClickOutside.bind(this));
        
        this.checkForLoginSuccess();
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleClickOutside.bind(this));
    }

    checkForLoginSuccess() {
        const urlParams = new URLSearchParams(window.location.search);
        const loginSuccess = urlParams.get('loginSuccess');
        
        if (loginSuccess === 'true') {
            this.displayNotification(
                'Welcome Back!',
                'You have successfully logged in',
                'success'
            );
            
            window.history.replaceState({}, document.title, window.location.pathname);
        }
    }

    async checkUserLoginStatus() {
        try {
            const result = await isGuestUser();
            this.isGuest = result;
            
            if (!this.isGuest) {
                await this.loadCandidateData();
                await this.loadAppliedJobs();
                
                // ✅ CRITICAL: Refresh wired jobs after loading applied jobs
                console.log('🔄 Refreshing wired jobs with loaded appliedJobIds:', Array.from(this.appliedJobIds));
                await refreshApex(this.wiredJobsResult);
            }
        } catch (error) {
            console.error('Error checking user status:', error);
            this.isGuest = true;
        }
    }

    async loadCandidateData() {
        try {
            const result = await getCandidateIdForCurrentUser();
            
            if (result && result.candidateId) {
                this.candidateId = result.candidateId;
                this.candidateName = result.candidateName || 'User';
            } else {
                this.showToast('Profile Error', 'No candidate profile found for your account.', 'warning');
            }
        } catch (error) {
            console.error('Error loading candidate data:', error);
            this.showToast('Profile Error', 'Unable to load your profile.', 'error');
        }
    }

    @wire(getJobPostings, { 
        keyword: '$keyword', 
        location: '$location', 
        datePosted: '$datePosted', 
        experienceLevel: '$experienceLevel' 
    })
    wiredJobs(result) {
        this.wiredJobsResult = result;
        this.isLoading = true;
        if (result.data) {
            const jobsData = result.data.jobs || [];
            
            console.log('📊 Wired jobs loaded');
            console.log('   appliedJobIds Set size:', this.appliedJobIds.size);
            console.log('   appliedJobIds contents:', [...this.appliedJobIds]);
            
            this.jobs = jobsData.map(job => {
                const isApplied = this.appliedJobIds.has(job.Id);
                console.log(`   Job "${job.Job_Title__c}" (${job.Id}): isAlreadyApplied = ${isApplied}`);
                
                return {
                    ...job,
                    timeAgo: this.calculateTimeAgo(job.CreatedDate),
                    descriptionPreview: this.getDescriptionPreview(job.Description__c),
                    locationDisplay: this.formatLocation(job),
                    experienceDisplay: this.formatExperienceRange(job),
                    employmentShiftDisplay: this.formatEmploymentShift(job),
                    isAlreadyApplied: isApplied
                };
            });
            
            this.error = undefined;
            this.isLoading = false;
            
            console.log('✅ Jobs array updated, total jobs:', this.jobs.length);
            console.log('   Jobs with isAlreadyApplied=true:', this.jobs.filter(j => j.isAlreadyApplied).length);
        } else if (result.error) {
            this.error = result.error;
            this.jobs = [];
            this.isLoading = false;
        }
    }

    formatEmploymentShift(job) {
        let parts = [];
        if (job.Employment_Type__c) parts.push(job.Employment_Type__c);
        if (job.Shift_Type__c) parts.push(job.Shift_Type__c);
        return parts.join(' • ') || '';
    }

    formatExperienceRange(job) {
        if (job.Min_Experience_Years__c != null && job.Max_Experience_Years__c != null) {
            return `${job.Min_Experience_Years__c}-${job.Max_Experience_Years__c} years`;
        } else if (job.Min_Experience_Years__c != null) {
            return `${job.Min_Experience_Years__c}+ years`;
        }
        return null;
    }

    formatLocation(job) {
        let parts = [];
        if (job.Facility_Name__c) parts.push(job.Facility_Name__c);
        if (job.City__c) parts.push(job.City__c);
        if (job.State__c) parts.push(job.State__c);
        return parts.join(', ') || 'Location not specified';
    }

    getDescriptionPreview(description) {
        if (!description) return '';
        
        let preview = description.replace(/\s+/g, ' ').trim();
        
        if (preview.length > 150) {
            preview = preview.substring(0, 150).trim() + '...';
        }
        
        return preview;
    }

    get jobCount() {
        return this.jobs.length;
    }

    get hasJobs() {
        return this.jobs && this.jobs.length > 0;
    }

    get noJobsFound() {
        return !this.isLoading && this.jobs.length === 0;
    }

    get hasEducationRequirements() {
        return this.jobRequirements?.educationRequirements?.length > 0;
    }

    get hasLicenseRequirements() {
        return this.jobRequirements?.licenseRequirements?.length > 0;
    }

    get hasCertificationRequirements() {
        return this.jobRequirements?.certificationRequirements?.length > 0;
    }

    get hasClinicalSkills() {
        return this.jobRequirements?.clinicalSkills?.length > 0;
    }

    get hasProcedures() {
        return this.jobRequirements?.procedures?.length > 0;
    }

    get hasComplianceRequirements() {
        return this.jobRequirements?.complianceRequirements?.length > 0;
    }

    get appliedJobsCount() {
        return this.appliedJobs?.length || 0;
    }

    get hasApplications() {
        return this.appliedJobs && this.appliedJobs.length > 0;
    }

    get noApplicationsFound() {
        return !this.isLoadingApplications && (!this.appliedJobs || this.appliedJobs.length === 0);
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

    handleKeywordChange(event) {
        this.keyword = event.target.value;
    }

    handleLocationChange(event) {
        this.location = event.target.value;
    }

    handleDatePostedChange(event) {
        this.datePosted = event.detail.value;
    }

    handleExperienceLevelChange(event) {
        this.experienceLevel = event.detail.value;
    }

    toggleFilters() {
        this.showFilters = !this.showFilters;
    }

    clearFilters() {
        this.keyword = '';
        this.location = '';
        this.datePosted = 'all';
        this.experienceLevel = 'all';
        
        const inputs = this.template.querySelectorAll('lightning-input');
        inputs.forEach(input => {
            input.value = '';
        });

        const comboboxes = this.template.querySelectorAll('lightning-combobox');
        comboboxes.forEach(combobox => {
            if (combobox.name === 'datePosted') {
                combobox.value = 'all';
            } else if (combobox.name === 'experienceLevel') {
                combobox.value = 'all';
            }
        });
    }

    async handleJobClick(event) {
        event.preventDefault();
        const jobId = event.currentTarget.dataset.id;
        
        this.isLoading = true;
        
        try {
            const result = await getJobDetails({ jobId: jobId });
            
            this.selectedJob = {
                ...result.job,
                timeAgo: this.calculateTimeAgo(result.job.CreatedDate),
                locationDisplay: this.formatLocation(result.job),
                experienceDisplay: this.formatExperienceRange(result.job)
            };
            
            this.jobRequirements = {
                educationRequirements: result.educationRequirements || [],
                licenseRequirements: result.licenseRequirements || [],
                certificationRequirements: result.certificationRequirements || [],
                clinicalSkills: result.clinicalSkills || [],
                procedures: result.procedures || [],
                complianceRequirements: result.complianceRequirements || []
            };
            
            this.isJobAlreadyApplied = this.appliedJobIds.has(jobId);
            
            this.showJobModal = true;
            
        } catch (error) {
            console.error('Error loading job details:', error);
            this.showToast('Error', 'Failed to load job details', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCloseModal() {
        this.showJobModal = false;
        this.selectedJob = null;
        this.jobRequirements = null;
        this.isJobAlreadyApplied = false;
    }

    async handleApply(event) {
        event.preventDefault();
        
        const jobId = event.currentTarget.dataset.id;
        const jobName = this.jobs.find(job => job.Id === jobId)?.Job_Title__c;
        
        this.handleCloseModal();
        
        if (!this.isGuest && this.appliedJobIds.has(jobId)) {
            this.displayNotification(
                'Already Applied',
                'You have already applied for this position',
                'info'
            );
            return;
        }
        
        if (this.isGuest) {
            sessionStorage.setItem('pendingJobApplication', jobId);
            sessionStorage.setItem('pendingJobName', jobName);
            
            this.displayNotification(
                'Login Required',
                'Please login or register to apply for this position',
                'warning'
            );
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Login Required',
                message: 'Please login or register to apply for this position',
                variant: 'warning',
                mode: 'sticky'
            }));
            
            setTimeout(() => {
                window.location.href = '/candidate/login';
            }, 1500);
        } else {
            this.isLoading = true;
            
            try {
                const eligibility = await checkCandidateEligibility({ candidateId: this.candidateId });
                
                console.log('Eligibility check:', eligibility);
                
                if (!eligibility.eligible) {
                    const completeness = eligibility.completeness || 0;
                    
                    let message = `Your profile is ${completeness}% complete. To apply for jobs, you need:\n\n`;
                    
                    if (!eligibility.hasResume) {
                        message += '✗ Resume uploaded\n';
                    }
                    if (!eligibility.hasEducation) {
                        message += '✗ At least one Education entry\n';
                    }
                    if (!eligibility.hasSkills) {
                        message += '✗ At least one Clinical Skill\n';
                    }
                    if (completeness < 75) {
                        message += `✗ ${75 - completeness}% more profile completion\n`;
                    }
                    
                    message += '\nPlease complete your profile to apply for jobs.';
                    
                    this.displayNotification(
                        'Profile Incomplete',
                        'Please complete your profile before applying',
                        'warning'
                    );
                    
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Profile Incomplete',
                        message: message,
                        variant: 'warning',
                        mode: 'sticky'
                    }));
                    
                    this.showProfileView = true;
                    this.showAppliedJobsView = false;
                    
                    this.isLoading = false;
                    return;
                }
                
                const result = await createJobApplication({ 
                    jobPostingId: jobId, 
                    candidateId: this.candidateId 
                });
                
                if (result.success) {
                    console.log('✅ Application created successfully');
                    
                    // ✅ STEP 1: Add to Set
                    this.appliedJobIds.add(jobId);
                    console.log('✅ Added to appliedJobIds Set:', Array.from(this.appliedJobIds));
                    
                    // ✅ STEP 2: Force reactive update by creating NEW array with spread operator
                    this.jobs = [...this.jobs].map(job => {
                        if (job.Id === jobId) {
                            console.log('✅ Marking job as applied:', job.Job_Title__c);
                            return { ...job, isAlreadyApplied: true };
                        }
                        return job;
                    });
                    
                    console.log('✅ Jobs array recreated with new reference');
                    
                    this.displayNotification(
                        'Application Submitted!',
                        result.message,
                        'success'
                    );
                    
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: result.message,
                        variant: 'success',
                        mode: 'dismissable'
                    }));
                    
                    // ✅ STEP 3: Reload applied jobs in background
                    await this.loadAppliedJobs();
                    
                    console.log('✅ UI should now show "Already Applied" badge');
                    
                } else {
                    if (result.existingStatus) {
                        console.log('⚠️ Application already exists');
                        
                        // Update UI for existing application
                        this.appliedJobIds.add(jobId);
                        
                        // ✅ Force reactive update with NEW array
                        this.jobs = [...this.jobs].map(job => {
                            if (job.Id === jobId) {
                                return { ...job, isAlreadyApplied: true };
                            }
                            return job;
                        });
                        
                        this.displayNotification(
                            'Already Applied',
                            'You have already applied for this position',
                            'info'
                        );
                        
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Already Applied',
                            message: result.message,
                            variant: 'info',
                            mode: 'dismissable'
                        }));
                        
                    } else {
                        this.displayNotification(
                            'Application Error',
                            result.message,
                            'error'
                        );
                        
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Application Error',
                            message: result.message,
                            variant: 'error',
                            mode: 'sticky'
                        }));
                    }
                }
                
            } catch (error) {
                console.error('Application error:', error);
                
                this.displayNotification(
                    'Error',
                    'Failed to submit application',
                    'error'
                );
                
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to submit application: ' + (error.body?.message || error.message),
                    variant: 'error',
                    mode: 'sticky'
                }));
            } finally {
                this.isLoading = false;
            }
        }
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    handleApplyFromModal() {
        if (this.selectedJob) {
            const event = {
                currentTarget: {
                    dataset: {
                        id: this.selectedJob.Id
                    }
                },
                preventDefault: () => {}
            };
            this.handleApply(event);
        }
    }

    handleLoginClick() {
        window.location.href = '/candidate/login';
    }

    toggleProfileMenu(event) {
        event.stopPropagation();
        this.showProfileMenu = !this.showProfileMenu;
    }

    handleClickOutside(event) {
        const profileDropdown = this.template.querySelector('.profile-dropdown');
        const profileMenu = this.template.querySelector('.profile-menu');
        
        if (profileDropdown && profileMenu) {
            if (!profileDropdown.contains(event.target) && !profileMenu.contains(event.target)) {
                this.showProfileMenu = false;
            }
        }
    }

    handleViewProfile() {
        this.showProfileMenu = false;
        
        if (!this.candidateId) {
            this.showToast('Error', 'Unable to load profile. Please refresh the page.', 'error');
            return;
        }
        
        this.showProfileView = true;
        this.showAppliedJobsView = false;
    }

    async handleViewAppliedJobs() {
        this.showProfileMenu = false;
        
        if (!this.candidateId) {
            this.showToast('Error', 'Unable to load applications. Please refresh the page.', 'error');
            return;
        }
        
        this.showAppliedJobsView = true;
        this.showProfileView = false;
        await this.loadAppliedJobs();
    }

    async loadAppliedJobs() {
        this.isLoadingApplications = true;
        
        try {
            console.log('🔄 Loading applied jobs for candidate:', this.candidateId);
            
            const applications = await getCandidateApplications({ candidateId: this.candidateId });
            
            console.log('✅ Received applications:', applications.length);
            
            this.appliedJobs = applications.map(app => ({
                ...app,
                locationDisplay: this.formatApplicationLocation(app),
                applicationDateDisplay: this.formatApplicationDate(app.Application_Date__c),
                statusBadgeClass: this.getStatusBadgeClass(app.Status__c)
            }));
            
            // ✅ CRITICAL: Extract job IDs and create Set
            const jobIds = applications.map(app => app.Job_Posting__c);
            console.log('📋 Job IDs from applications:', jobIds);
            
            this.appliedJobIds = new Set(jobIds);
            
            console.log('✅ appliedJobIds Set created');
            console.log('   Set size:', this.appliedJobIds.size);
            console.log('   Set contents:', [...this.appliedJobIds]);
            
            // ✅ CRITICAL: Force reactive update by creating NEW array
            if (this.jobs && this.jobs.length > 0) {
                console.log('🔄 Updating existing jobs array with applied status');
                
                this.jobs = [...this.jobs].map(job => {
                    const isApplied = this.appliedJobIds.has(job.Id);
                    if (isApplied) {
                        console.log(`   ✅ Marking job "${job.Job_Title__c}" as applied`);
                    }
                    return {
                        ...job,
                        isAlreadyApplied: isApplied
                    };
                });
                
                console.log('✅ Jobs array updated');
                console.log('   Total jobs:', this.jobs.length);
                console.log('   Jobs marked as applied:', this.jobs.filter(j => j.isAlreadyApplied).length);
            } else {
                console.log('⚠️ No jobs loaded yet, will be updated when jobs wire fires');
            }
            
        } catch (error) {
            console.error('❌ Error loading applications:', error);
            this.showToast('Error', 'Failed to load applications', 'error');
            this.appliedJobs = [];
            this.appliedJobIds = new Set();
        } finally {
            this.isLoadingApplications = false;
        }
    }

    formatApplicationLocation(app) {
        let parts = [];
        if (app.Job_Posting__r?.Facility_Name__c) parts.push(app.Job_Posting__r.Facility_Name__c);
        if (app.Job_Posting__r?.City__c) parts.push(app.Job_Posting__r.City__c);
        if (app.Job_Posting__r?.State__c) parts.push(app.Job_Posting__r.State__c);
        return parts.join(', ') || 'Location not specified';
    }

    formatApplicationDate(dateValue) {
        if (!dateValue) return '';
        const date = new Date(dateValue);
        return date.toLocaleDateString('en-US', { 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric' 
        });
    }

    getStatusBadgeClass(status) {
        const baseClass = 'status-badge';
        const statusMap = {
            'Application Received': 'status-application-received',
            'Eligibility Check In Progress': 'status-eligibility-progress',
            'Eligibility Failed': 'status-eligibility-failed',
            'Eligibility Passed': 'status-eligibility-passed',
            'License Verification Pending': 'status-license-pending',
            'License Verified': 'status-license-verified',
            'License Issue / Expired': 'status-license-issue',
            'Clinical Assessment Scheduled': 'status-clinical-scheduled',
            'Clinical Assessment Failed': 'status-clinical-failed',
            'Clinical Assessment Passed': 'status-clinical-passed',
            'Interview Scheduled': 'status-interview-scheduled',
            'Interview Rejected': 'status-interview-rejected',
            'Interview Cleared': 'status-interview-cleared',
            'Background Check In Progress': 'status-background-progress',
            'Background Check Failed': 'status-background-failed',
            'Background Check Cleared': 'status-background-cleared',
            'Drug Screening Pending': 'status-drug-pending',
            'Offer Released': 'status-offer-released',
            'Offer Accepted': 'status-offer-accepted',
            'Offer Declined': 'status-offer-declined',
            'Credentialing In Progress': 'status-credentialing-progress',
            'Privileges Approved': 'status-privileges-approved',
            'Privileges Limited': 'status-privileges-limited',
            'Medical Onboarding In Progress': 'status-onboarding-progress',
            'Mandatory Training Pending': 'status-training-pending',
            'Onboarding Completed': 'status-onboarding-completed',
            'Active – Allowed to Practice': 'status-active-full',
            'Active – Restricted Scope': 'status-active-restricted',
            'On Hold (Compliance Issue)': 'status-on-hold',
            'Suspended': 'status-suspended',
            'License Expired – Auto Blocked': 'status-license-expired',
            'Terminated / Offboarded': 'status-terminated'
        };
        return `${baseClass} ${statusMap[status] || 'status-default'}`;
    }

    async handleViewJobFromApplication(event) {
        console.log('=== View Job Details Clicked ===');
        console.log('Event:', event);
        console.log('Current Target:', event.currentTarget);
        console.log('Dataset:', event.currentTarget.dataset);
        
        let jobId = event.currentTarget.dataset.jobId || 
                    event.currentTarget.getAttribute('data-job-id') ||
                    event.detail?.jobId;
        
        console.log('Job ID extracted:', jobId);
        
        if (!jobId) {
            console.error('❌ No job ID found');
            console.error('Available dataset keys:', Object.keys(event.currentTarget.dataset));
            
            this.displayNotification(
                'Error',
                'Unable to load job details. Job ID not found.',
                'error'
            );
            
            this.showToast('Error', 'Unable to load job details', 'error');
            return;
        }
        
        this.isLoading = true;
        
        try {
            console.log('📞 Calling getJobDetails with jobId:', jobId);
            
            const result = await getJobDetails({ jobId: jobId });
            
            console.log('✅ Job details received:', result);
            
            this.selectedJob = {
                ...result.job,
                timeAgo: this.calculateTimeAgo(result.job.CreatedDate),
                locationDisplay: this.formatLocation(result.job),
                experienceDisplay: this.formatExperienceRange(result.job)
            };
            
            this.jobRequirements = {
                educationRequirements: result.educationRequirements || [],
                licenseRequirements: result.licenseRequirements || [],
                certificationRequirements: result.certificationRequirements || [],
                clinicalSkills: result.clinicalSkills || [],
                procedures: result.procedures || [],
                complianceRequirements: result.complianceRequirements || []
            };
            
            this.isJobAlreadyApplied = true;
            
            this.showJobModal = true;
            
            console.log('✅ Job modal opened successfully');
            
        } catch (error) {
            console.error('❌ Error loading job details:', error);
            console.error('Error status:', error.status);
            console.error('Error body:', error.body);
            
            let errorMessage = 'Failed to load job details';
            
            if (error.body && error.body.message) {
                errorMessage = error.body.message;
            } else if (error.message) {
                errorMessage = error.message;
            }
            
            this.displayNotification(
                'Error',
                errorMessage,
                'error'
            );
            
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToJobs() {
        this.showProfileView = false;
        this.showAppliedJobsView = false;
    }

    handleLogout() {
        this.showProfileMenu = false;
        
        this.displayNotification(
            'Logging Out',
            'You have been logged out successfully',
            'success'
        );
        
        this.showToast('Logging Out', 'You have been logged out successfully', 'success');
        
        setTimeout(() => {
            window.location.href = '/candidate/secur/logout.jsp';
        }, 1000);
    }

    // ========================================
    // NOTIFICATION METHODS
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
        }, 5000);
    }

    closeNotification() {
        this.showNotification = false;
        if (this.notificationTimeout) {
            clearTimeout(this.notificationTimeout);
        }
    }

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

    calculateTimeAgo(createdDate) {
        const now = new Date();
        const posted = new Date(createdDate);
        const daysSince = Math.floor((now - posted) / (1000 * 60 * 60 * 24));
        
        if (daysSince === 0) return 'Today';
        if (daysSince === 1) return '1 day ago';
        if (daysSince < 7) return `${daysSince} days ago`;
        if (daysSince < 30) return `${Math.floor(daysSince / 7)} weeks ago`;
        return `${Math.floor(daysSince / 30)} months ago`;
    }

    handleRefresh() {
        return refreshApex(this.wiredJobsResult);
    }
}