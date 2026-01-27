// jobFilterComponent.js
// import { LightningElement, track, wire } from 'lwc';
// import { NavigationMixin } from 'lightning/navigation';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import getJobPostings from '@salesforce/apex/JobPostingController.getJobPostings';
// import isGuestUser from '@salesforce/apex/JobPostingController.isGuestUser';
// import { refreshApex } from '@salesforce/apex';
// import USER_ID from '@salesforce/user/Id';

// export default class JobFilterComponent extends NavigationMixin(LightningElement) {
//     @track keyword = '';
//     @track location = '';
//     @track datePosted = 'all';
//     @track experienceLevel = 'all';
//     @track showFilters = false;
//     @track jobs = [];
//     @track isLoading = false;
//     @track error;
//     @track selectedJob = null;
//     @track showJobModal = false;
//     @track isGuest = false;

//     wiredJobsResult;

//     datePostedOptions = [
//         { label: 'Any Time', value: 'all' },
//         { label: 'Past 24 hours', value: '24h' },
//         { label: 'Past Week', value: 'week' },
//         { label: 'Past Month', value: 'month' }
//     ];

//     experienceLevelOptions = [
//         { label: 'All Levels', value: 'all' },
//         { label: 'Entry Level', value: 'Entry Level' },
//         { label: 'Mid-Level', value: 'Mid-Level' },
//         { label: 'Senior', value: 'Senior' },
//         { label: 'Lead', value: 'Lead' },
//         { label: 'Executive', value: 'Executive' }
//     ];

//     connectedCallback() {
//         // Check if user is guest on component load
//         this.checkUserLoginStatus();
//     }

//     checkUserLoginStatus() {
//         isGuestUser()
//             .then(result => {
//                 this.isGuest = result;
//             })
//             .catch(error => {
//                 console.error('Error checking user status:', error);
//             });
//     }

//     @wire(getJobPostings, { 
//         keyword: '$keyword', 
//         location: '$location', 
//         datePosted: '$datePosted', 
//         experienceLevel: '$experienceLevel' 
//     })
//     wiredJobs(result) {
//         this.wiredJobsResult = result;
//         this.isLoading = true;
//         if (result.data) {
//             const openJobs = result.data.filter(job => 
//                 job.Status__c === 'Active' || job.Status__c === 'Open'
//             );
            
//             this.jobs = openJobs.map(job => ({
//                 ...job,
//                 timeAgo: this.calculateTimeAgo(job.CreatedDate),
//                 Description__c: this.formatDescription(job.Description__c),
//                 descriptionPreview: this.getDescriptionPreview(job.Description__c)
//             }));
//             this.error = undefined;
//             this.isLoading = false;
//         } else if (result.error) {
//             this.error = result.error;
//             this.jobs = [];
//             this.isLoading = false;
//         }
//     }

//     formatDescription(description) {
//         if (!description) return '';
        
//         let formatted = description.replace(/\s+/g, ' ').trim();
        
//         formatted = formatted.replace(/\*\s*Education:/gi, '||SECTION||📚 Education:||');
//         formatted = formatted.replace(/\*\s*Responsibilities:/gi, '||SECTION||💼 Responsibilities:||');
//         formatted = formatted.replace(/\*\s*Skills:/gi, '||SECTION||⚡ Skills:||');
//         formatted = formatted.replace(/\*\s*Requirements:/gi, '||SECTION||✓ Requirements:||');
//         formatted = formatted.replace(/\*\s*Qualifications:/gi, '||SECTION||🎓 Qualifications:||');
//         formatted = formatted.replace(/\*\s*Benefits:/gi, '||SECTION||🎁 Benefits:||');
//         formatted = formatted.replace(/\*\s*About:/gi, '||SECTION||ℹ️ About:||');
        
//         formatted = formatted.replace(/📚 Education:/gi, '||SECTION||📚 Education:||');
//         formatted = formatted.replace(/💼 Responsibilities:/gi, '||SECTION||💼 Responsibilities:||');
//         formatted = formatted.replace(/⚡ Skills:/gi, '||SECTION||⚡ Skills:||');
//         formatted = formatted.replace(/✓ Requirements:/gi, '||SECTION||✓ Requirements:||');
//         formatted = formatted.replace(/🎓 Qualifications:/gi, '||SECTION||🎓 Qualifications:||');
//         formatted = formatted.replace(/🎁 Benefits:/gi, '||SECTION||🎁 Benefits:||');
//         formatted = formatted.replace(/ℹ️ About:/gi, '||SECTION||ℹ️ About:||');
        
//         formatted = formatted.replace(/- Education:/gi, '||SECTION||📚 Education:||');
//         formatted = formatted.replace(/- Responsibilities:/gi, '||SECTION||💼 Responsibilities:||');
//         formatted = formatted.replace(/- Skills:/gi, '||SECTION||⚡ Skills:||');
//         formatted = formatted.replace(/- Requirements:/gi, '||SECTION||✓ Requirements:||');
//         formatted = formatted.replace(/- Qualifications:/gi, '||SECTION||🎓 Qualifications:||');
//         formatted = formatted.replace(/- Benefits:/gi, '||SECTION||🎁 Benefits:||');
//         formatted = formatted.replace(/- About:/gi, '||SECTION||ℹ️ About:||');
        
//         const sections = formatted.split('||SECTION||').filter(s => s.trim());
        
//         let result = '';
//         sections.forEach(section => {
//             if (section.includes('||')) {
//                 const header = section.replace(/\|\|/g, '');
//                 const parts = header.split(':');
//                 if (parts.length >= 2) {
//                     const headerText = parts[0] + ':';
//                     const content = parts.slice(1).join(':').trim();
                    
//                     result += `<div class="section-header">${headerText}</div>`;
                    
//                     if (content) {
//                         const items = content.split(/[,;]/).map(item => item.trim()).filter(item => item);
//                         items.forEach(item => {
//                             result += `<div class="bullet-item">${item}</div>`;
//                         });
//                     }
//                 }
//             }
//         });
        
//         return result;
//     }

//     getDescriptionPreview(description) {
//         if (!description) return '';
        
//         let preview = description.replace(/\s+/g, ' ').trim();
//         preview = preview.replace(/📚|💼|⚡|✓|🎓|🎁|ℹ️/g, '');
//         preview = preview.replace(/- Education:|Education:|Responsibilities:|Skills:|Requirements:|Qualifications:|Benefits:|About:/gi, '');
//         preview = preview.replace(/;\s+/g, ', ');
//         preview = preview.replace(/\s+-\s+/g, ', ');
        
//         if (preview.length > 150) {
//             preview = preview.substring(0, 150).trim() + '...';
//         }
        
//         return preview;
//     }

//     get jobCount() {
//         return this.jobs.length;
//     }

//     get hasJobs() {
//         return this.jobs && this.jobs.length > 0;
//     }

//     get noJobsFound() {
//         return !this.isLoading && this.jobs.length === 0;
//     }

//     handleKeywordChange(event) {
//         this.keyword = event.target.value;
//     }

//     handleLocationChange(event) {
//         this.location = event.target.value;
//     }

//     handleDatePostedChange(event) {
//         this.datePosted = event.detail.value;
//     }

//     handleExperienceLevelChange(event) {
//         this.experienceLevel = event.detail.value;
//     }

//     toggleFilters() {
//         this.showFilters = !this.showFilters;
//     }

//     clearFilters() {
//         this.keyword = '';
//         this.location = '';
//         this.datePosted = 'all';
//         this.experienceLevel = 'all';
        
//         const inputs = this.template.querySelectorAll('lightning-input');
//         inputs.forEach(input => {
//             input.value = '';
//         });

//         const comboboxes = this.template.querySelectorAll('lightning-combobox');
//         comboboxes.forEach(combobox => {
//             if (combobox.name === 'datePosted') {
//                 combobox.value = 'all';
//             } else if (combobox.name === 'experienceLevel') {
//                 combobox.value = 'all';
//             }
//         });
//     }

//     handleJobClick(event) {
//         event.preventDefault();
//         const jobId = event.currentTarget.dataset.id;
//         const job = this.jobs.find(j => j.Id === jobId);
        
//         if (job) {
//             this.selectedJob = job;
//             this.showJobModal = true;
            
//             setTimeout(() => {
//                 this.renderJobDescription();
//             }, 0);
//         }
//     }

//     renderJobDescription() {
//         const descContainer = this.template.querySelector('.job-description-full');
//         if (descContainer && this.selectedJob && this.selectedJob.Description__c) {
//             descContainer.innerHTML = this.selectedJob.Description__c;
//         }
//     }

//     handleCloseModal() {
//         this.showJobModal = false;
//         this.selectedJob = null;
//     }

  

// handleApply(event) {
//     event.preventDefault();
    
//     const jobId = event.currentTarget.dataset.id;
//     const jobName = this.jobs.find(job => job.Id === jobId)?.Name;
    
//     console.log('Apply button clicked for job:', jobId);
    
//     // Close modal if open
//     this.handleCloseModal();
    
//     // Check login status using Apex
//     isGuestUser()
//         .then(isGuest => {
//             console.log('Is guest user:', isGuest);
            
//             if (isGuest) {
//                 console.log('inside if');
//                 console.log(USER_ID);
//                 // User is NOT logged in
//                 sessionStorage.setItem('pendingJobApplication', jobId);
//                 sessionStorage.setItem('pendingJobName', jobName);
                
//                 this.dispatchEvent(new ShowToastEvent({
//                     title: 'Login Required',
//                     message: 'Please login or register to apply for this job',
//                     variant: 'warning',
//                     mode: 'sticky'
//                 }));
                
//                 // Redirect to login page
//                 setTimeout(() => {
//                     window.location.href = '/candidate/login';
//                 }, 1500);
//             } else {
//                 console.log('inside else');
//                 console.log(USER_ID);
//                 // User IS logged in
//                 this.dispatchEvent(new ShowToastEvent({
//                     title: 'Success',
//                     message: `Your application for ${jobName} has been submitted!`,
//                     variant: 'success',
//                     mode: 'dismissable'
//                 }));
                
//                 // Optional: Call Apex method to create application record
//                 // Or redirect to application form page
//                 // For now, just stay on the same page
//             }
//         })
//         .catch(error => {
//             console.error('Error checking user status:', error);
//             this.dispatchEvent(new ShowToastEvent({
//                 title: 'Error',
//                 message: 'Unable to process your application. Please try again.',
//                 variant: 'error',
//                 mode: 'dismissable'
//             }));
//         });
// }

// handleApplyFromModal() {
//     if (this.selectedJob) {
//         const event = {
//             currentTarget: {
//                 dataset: {
//                     id: this.selectedJob.Id
//                 }
//             },
//             preventDefault: () => {}
//         };
//         this.handleApply(event);
//     }
// }

   
//     calculateTimeAgo(createdDate) {
//         const now = new Date();
//         const posted = new Date(createdDate);
//         const daysSince = Math.floor((now - posted) / (1000 * 60 * 60 * 24));
        
//         if (daysSince === 0) return 'Today';
//         if (daysSince === 1) return '1 day ago';
//         if (daysSince < 7) return `${daysSince} days ago`;
//         if (daysSince < 30) return `${Math.floor(daysSince / 7)} weeks ago`;
//         return `${Math.floor(daysSince / 30)} months ago`;
//     }

//     handleRefresh() {
//         return refreshApex(this.wiredJobsResult);
//     }
// }

import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getJobPostings from '@salesforce/apex/JobPostingController.getJobPostings';
import isGuestUser from '@salesforce/apex/JobPostingController.isGuestUser';
import getCandidateIdForCurrentUser from '@salesforce/apex/JobPostingController.getCandidateIdForCurrentUser';
import { refreshApex } from '@salesforce/apex';
import USER_ID from '@salesforce/user/Id';

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
    @track showJobModal = false;
    @track isGuest = true;
    @track showProfileMenu = false;
    @track showProfileView = false;
    @track candidateId = null;
    @track candidateName = 'User';

    wiredJobsResult;

    datePostedOptions = [
        { label: 'Any Time', value: 'all' },
        { label: 'Past 24 hours', value: '24h' },
        { label: 'Past Week', value: 'week' },
        { label: 'Past Month', value: 'month' }
    ];

    experienceLevelOptions = [
        { label: 'All Levels', value: 'all' },
        { label: 'Entry Level', value: 'Entry Level' },
        { label: 'Mid-Level', value: 'Mid-Level' },
        { label: 'Senior', value: 'Senior' },
        { label: 'Lead', value: 'Lead' },
        { label: 'Executive', value: 'Executive' }
    ];

    connectedCallback() {
        this.checkUserLoginStatus();
        document.addEventListener('click', this.handleClickOutside.bind(this));
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleClickOutside.bind(this));
    }

    async checkUserLoginStatus() {
        console.log('=== checkUserLoginStatus Called ===');
        try {
            const result = await isGuestUser();
            console.log('isGuestUser result:', result);
            this.isGuest = result;
            
            if (!this.isGuest) {
                console.log('User is logged in, loading candidate data...');
                await this.loadCandidateData();
            } else {
                console.log('User is guest, skipping candidate data load');
            }
        } catch (error) {
            console.error('Error checking user status:', error);
            console.error('Error details:', JSON.parse(JSON.stringify(error)));
            this.isGuest = true;
        }
        console.log('=== checkUserLoginStatus Completed ===');
        console.log('Final isGuest value:', this.isGuest);
        console.log('Final candidateId value:', this.candidateId);
    }

    async loadCandidateData() {
        console.log('=== loadCandidateData Called ===');
        try {
            const result = await getCandidateIdForCurrentUser();
            
            console.log('Result from getCandidateIdForCurrentUser:', result);
            
            if (result && result.candidateId) {
                this.candidateId = result.candidateId;
                this.candidateName = result.candidateName || 'User';
                console.log('✅ Candidate ID loaded:', this.candidateId);
                console.log('✅ Candidate Name loaded:', this.candidateName);
            } else {
                console.error('❌ No candidate ID found in result');
                console.log('Result object:', result);
                this.showToast('Profile Error', 'No candidate profile found for your account. Please contact administrator.', 'warning');
            }
        } catch (error) {
            console.error('❌ Error loading candidate data:', error);
            console.error('Error details:', JSON.parse(JSON.stringify(error)));
            this.showToast('Profile Error', 'Unable to load your profile. ' + (error.body?.message || error.message), 'error');
        }
        console.log('=== loadCandidateData Completed ===');
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
            const openJobs = result.data.filter(job => 
                job.Status__c === 'Active' || job.Status__c === 'Open'
            );
            
            this.jobs = openJobs.map(job => ({
                ...job,
                timeAgo: this.calculateTimeAgo(job.CreatedDate),
                Description__c: this.formatDescription(job.Description__c),
                descriptionPreview: this.getDescriptionPreview(job.Description__c)
            }));
            this.error = undefined;
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error;
            this.jobs = [];
            this.isLoading = false;
        }
    }

    formatDescription(description) {
        if (!description) return '';
        
        let formatted = description.replace(/\s+/g, ' ').trim();
        
        formatted = formatted.replace(/\*\s*Education:/gi, '||SECTION||📚 Education:||');
        formatted = formatted.replace(/\*\s*Responsibilities:/gi, '||SECTION||💼 Responsibilities:||');
        formatted = formatted.replace(/\*\s*Skills:/gi, '||SECTION||⚡ Skills:||');
        formatted = formatted.replace(/\*\s*Requirements:/gi, '||SECTION||✓ Requirements:||');
        formatted = formatted.replace(/\*\s*Qualifications:/gi, '||SECTION||🎓 Qualifications:||');
        formatted = formatted.replace(/\*\s*Benefits:/gi, '||SECTION||🎁 Benefits:||');
        formatted = formatted.replace(/\*\s*About:/gi, '||SECTION||ℹ️ About:||');
        
        formatted = formatted.replace(/📚 Education:/gi, '||SECTION||📚 Education:||');
        formatted = formatted.replace(/💼 Responsibilities:/gi, '||SECTION||💼 Responsibilities:||');
        formatted = formatted.replace(/⚡ Skills:/gi, '||SECTION||⚡ Skills:||');
        formatted = formatted.replace(/✓ Requirements:/gi, '||SECTION||✓ Requirements:||');
        formatted = formatted.replace(/🎓 Qualifications:/gi, '||SECTION||🎓 Qualifications:||');
        formatted = formatted.replace(/🎁 Benefits:/gi, '||SECTION||🎁 Benefits:||');
        formatted = formatted.replace(/ℹ️ About:/gi, '||SECTION||ℹ️ About:||');
        
        formatted = formatted.replace(/- Education:/gi, '||SECTION||📚 Education:||');
        formatted = formatted.replace(/- Responsibilities:/gi, '||SECTION||💼 Responsibilities:||');
        formatted = formatted.replace(/- Skills:/gi, '||SECTION||⚡ Skills:||');
        formatted = formatted.replace(/- Requirements:/gi, '||SECTION||✓ Requirements:||');
        formatted = formatted.replace(/- Qualifications:/gi, '||SECTION||🎓 Qualifications:||');
        formatted = formatted.replace(/- Benefits:/gi, '||SECTION||🎁 Benefits:||');
        formatted = formatted.replace(/- About:/gi, '||SECTION||ℹ️ About:||');
        
        const sections = formatted.split('||SECTION||').filter(s => s.trim());
        
        let result = '';
        sections.forEach(section => {
            if (section.includes('||')) {
                const header = section.replace(/\|\|/g, '');
                const parts = header.split(':');
                if (parts.length >= 2) {
                    const headerText = parts[0] + ':';
                    const content = parts.slice(1).join(':').trim();
                    
                    result += `<div class="section-header">${headerText}</div>`;
                    
                    if (content) {
                        const items = content.split(/[,;]/).map(item => item.trim()).filter(item => item);
                        items.forEach(item => {
                            result += `<div class="bullet-item">${item}</div>`;
                        });
                    }
                }
            }
        });
        
        return result;
    }

    getDescriptionPreview(description) {
        if (!description) return '';
        
        let preview = description.replace(/\s+/g, ' ').trim();
        preview = preview.replace(/📚|💼|⚡|✓|🎓|🎁|ℹ️/g, '');
        preview = preview.replace(/- Education:|Education:|Responsibilities:|Skills:|Requirements:|Qualifications:|Benefits:|About:/gi, '');
        preview = preview.replace(/;\s+/g, ', ');
        preview = preview.replace(/\s+-\s+/g, ', ');
        
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

    handleJobClick(event) {
        event.preventDefault();
        const jobId = event.currentTarget.dataset.id;
        const job = this.jobs.find(j => j.Id === jobId);
        
        if (job) {
            this.selectedJob = job;
            this.showJobModal = true;
            
            setTimeout(() => {
                this.renderJobDescription();
            }, 0);
        }
    }

    renderJobDescription() {
        const descContainer = this.template.querySelector('.job-description-full');
        if (descContainer && this.selectedJob && this.selectedJob.Description__c) {
            descContainer.innerHTML = this.selectedJob.Description__c;
        }
    }

    handleCloseModal() {
        this.showJobModal = false;
        this.selectedJob = null;
    }

    handleApply(event) {
        event.preventDefault();
        
        const jobId = event.currentTarget.dataset.id;
        const jobName = this.jobs.find(job => job.Id === jobId)?.Name;
        
        this.handleCloseModal();
        
        if (this.isGuest) {
            sessionStorage.setItem('pendingJobApplication', jobId);
            sessionStorage.setItem('pendingJobName', jobName);
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Login Required',
                message: 'Please login or register to apply for this job',
                variant: 'warning',
                mode: 'sticky'
            }));
            
            setTimeout(() => {
                window.location.href = '/candidate/login';
            }, 1500);
        } else {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: `Your application for ${jobName} has been submitted!`,
                variant: 'success',
                mode: 'dismissable'
            }));
        }
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
        console.log('=== handleViewProfile Called ===');
        this.showProfileMenu = false;
        
        if (!this.candidateId) {
            console.error('Candidate ID is missing');
            console.log('Current candidateId value:', this.candidateId);
            this.showToast('Error', 'Unable to load profile. Candidate ID not found. Please refresh the page and try again.', 'error');
            return;
        }
        
        console.log('Opening profile for Candidate ID:', this.candidateId);
        console.log('Setting showProfileView to true');
        this.showProfileView = true;
        
        // Force re-render of profile component
        setTimeout(() => {
            const profileHub = this.template.querySelector('c-candidate-profile-hub');
            console.log('Profile Hub Component:', profileHub);
            if (profileHub) {
                console.log('Profile Hub found, candidateId passed:', this.candidateId);
            } else {
                console.error('Profile Hub component not found in template');
            }
        }, 100);
    }

    handleBackToJobs() {
        this.showProfileView = false;
    }

    handleLogout() {
        this.showProfileMenu = false;
        
        this.showToast('Logging Out', 'You have been logged out successfully', 'success');
        
        setTimeout(() => {
            window.location.href = '/candidate/secur/logout.jsp';
        }, 1000);
    }

    handleRefreshCandidateData() {
        console.log('=== Manual Refresh Candidate Data ===');
        this.showProfileMenu = false;
        this.loadCandidateData();
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