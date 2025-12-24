import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getJobPostings from '@salesforce/apex/JobPostingController.getJobPostings';
import { refreshApex } from '@salesforce/apex';

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
            // Filter only Active/Open status jobs
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
        
        // Replace multiple spaces with single space
        let formatted = description.replace(/\s+/g, ' ').trim();
        
        // Handle section headers with asterisks
        formatted = formatted.replace(/\*\s*Education:/gi, '||SECTION||📚 Education:||');
        formatted = formatted.replace(/\*\s*Responsibilities:/gi, '||SECTION||💼 Responsibilities:||');
        formatted = formatted.replace(/\*\s*Skills:/gi, '||SECTION||⚡ Skills:||');
        formatted = formatted.replace(/\*\s*Requirements:/gi, '||SECTION||✓ Requirements:||');
        formatted = formatted.replace(/\*\s*Qualifications:/gi, '||SECTION||🎓 Qualifications:||');
        formatted = formatted.replace(/\*\s*Benefits:/gi, '||SECTION||🎁 Benefits:||');
        formatted = formatted.replace(/\*\s*About:/gi, '||SECTION||ℹ️ About:||');
        
        // Handle existing emoji format
        formatted = formatted.replace(/📚 Education:/gi, '||SECTION||📚 Education:||');
        formatted = formatted.replace(/💼 Responsibilities:/gi, '||SECTION||💼 Responsibilities:||');
        formatted = formatted.replace(/⚡ Skills:/gi, '||SECTION||⚡ Skills:||');
        formatted = formatted.replace(/✓ Requirements:/gi, '||SECTION||✓ Requirements:||');
        formatted = formatted.replace(/🎓 Qualifications:/gi, '||SECTION||🎓 Qualifications:||');
        formatted = formatted.replace(/🎁 Benefits:/gi, '||SECTION||🎁 Benefits:||');
        formatted = formatted.replace(/ℹ️ About:/gi, '||SECTION||ℹ️ About:||');
        
        // Handle dash format
        formatted = formatted.replace(/- Education:/gi, '||SECTION||📚 Education:||');
        formatted = formatted.replace(/- Responsibilities:/gi, '||SECTION||💼 Responsibilities:||');
        formatted = formatted.replace(/- Skills:/gi, '||SECTION||⚡ Skills:||');
        formatted = formatted.replace(/- Requirements:/gi, '||SECTION||✓ Requirements:||');
        formatted = formatted.replace(/- Qualifications:/gi, '||SECTION||🎓 Qualifications:||');
        formatted = formatted.replace(/- Benefits:/gi, '||SECTION||🎁 Benefits:||');
        formatted = formatted.replace(/- About:/gi, '||SECTION||ℹ️ About:||');
        
        // Split by sections
        const sections = formatted.split('||SECTION||').filter(s => s.trim());
        
        let result = '';
        sections.forEach(section => {
            if (section.includes('||')) {
                // This is a section header
                const header = section.replace(/\|\|/g, '');
                const parts = header.split(':');
                if (parts.length >= 2) {
                    const headerText = parts[0] + ':';
                    const content = parts.slice(1).join(':').trim();
                    
                    result += `<div class="section-header">${headerText}</div>`;
                    
                    if (content) {
                        // Split content by comma or semicolon
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
        
        // Remove HTML tags and special characters for preview
        let preview = description.replace(/\s+/g, ' ').trim();
        preview = preview.replace(/📚|💼|⚡|✓|🎓|🎁|ℹ️/g, '');
        preview = preview.replace(/- Education:|Education:|Responsibilities:|Skills:|Requirements:|Qualifications:|Benefits:|About:/gi, '');
        preview = preview.replace(/;\s+/g, ', ');
        preview = preview.replace(/\s+-\s+/g, ', ');
        
        // Truncate to ~150 characters
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
        
        // Clear input fields
        const inputs = this.template.querySelectorAll('lightning-input');
        inputs.forEach(input => {
            input.value = '';
        });

        // Reset comboboxes
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
            
            // Use setTimeout to ensure DOM is ready
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
        const jobId = event.currentTarget.dataset.id;
        const jobName = this.jobs.find(job => job.Id === jobId)?.Name;
        
        // Close modal if open
        this.handleCloseModal();
        
        // Show a toast message
        const toastEvent = new ShowToastEvent({
            title: 'Application Started',
            message: `You are applying for ${jobName}`,
            variant: 'info',
            mode: 'dismissable'
        });
        this.dispatchEvent(toastEvent);
        
        // Navigate to the job posting record page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: jobId,
                objectApiName: 'Job_Posting__c',
                actionName: 'view'
            }
        });
    }

    handleApplyFromModal() {
        if (this.selectedJob) {
            const event = {
                currentTarget: {
                    dataset: {
                        id: this.selectedJob.Id
                    }
                }
            };
            this.handleApply(event);
        }
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