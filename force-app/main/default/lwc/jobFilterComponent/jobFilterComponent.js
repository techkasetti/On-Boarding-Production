import { LightningElement, track, wire } from 'lwc';
import getJobPostings from '@salesforce/apex/JobPostingController.getJobPostings';
import { refreshApex } from '@salesforce/apex';

export default class JobFilterComponent extends LightningElement {
    @track keyword = '';
    @track location = '';
    @track datePosted = 'all';
    @track experienceLevel = 'all';
    @track showFilters = false;
    @track jobs = [];
    @track isLoading = false;
    @track error;

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
            this.jobs = result.data.map(job => ({
                ...job,
                timeAgo: this.calculateTimeAgo(job.CreatedDate)
            }));
            this.error = undefined;
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error;
            this.jobs = [];
            this.isLoading = false;
        }
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

    handleApply(event) {
        const jobId = event.currentTarget.dataset.id;
        // Add your apply logic here
        console.log('Apply to job:', jobId);
        // You can navigate to a record page or open a modal
    }

    handleSave(event) {
        const jobId = event.currentTarget.dataset.id;
        // Add your save logic here
        console.log('Save job:', jobId);
        // You can create a saved job record or add to favorites
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