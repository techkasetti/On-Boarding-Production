import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getJobPostings from '@salesforce/apex/MedicalRecruitmentController.getJobPostings';

export default class JobPostingsList extends LightningElement {
    @track searchKey = '';
    @track jobPostings = [];
    @track selectedApplicationId;
    @track showModal = false;
    @track isLoading = false;

    @track showDocflowApp = false;
    @track docflowApplicationId = null;
    
    wiredJobsResult;

    get hasJobs() {
        return this.jobPostings && this.jobPostings.length > 0;
    }

    connectedCallback() {
        this.isLoading = true;
    }

    @wire(getJobPostings, { searchKey: '$searchKey' })
    wiredJobs(result) {
        this.wiredJobsResult = result;
        if (result.data) {
            // Map data and add isExpanded property + unique expandedKey
            this.jobPostings = result.data.map(job => {
                return {
                    Id: job.Id,
                    Job_Title__c: job.Job_Title__c,
                    Department__c: job.Department__c,
                    Role_Type__c: job.Role_Type__c,
                    Location__c: job.Location__c,
                    Employment_Type__c: job.Employment_Type__c,
                    Number_of_Positions__c: job.Number_of_Positions__c,
                    isExpanded: false,
                    expandedKey: job.Id + '-expanded',
                    cardClass: 'job-card-container',
                    expandIcon: 'utility:chevrondown'
                };
            });
            this.isLoading = false;
            console.log('Jobs loaded:', this.jobPostings.length);
        } else if (result.error) {
            this.isLoading = false;
            this.jobPostings = [];
            this.showToast('Error', 'Error loading job postings', 'error');
            console.error('Error loading jobs:', result.error);
        }
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        this.isLoading = true;
    }

    handleRefresh() {
        this.searchKey = '';
        // Collapse all rows
        this.jobPostings = this.jobPostings.map(job => ({
            ...job,
            isExpanded: false
        }));
        this.isLoading = true;
        refreshApex(this.wiredJobsResult);
        this.showToast('Success', 'Job postings refreshed', 'success');
    }

    handleJobClick(event) {
        const clickedJobId = event.currentTarget.dataset.jobId;
        console.log('Job clicked:', clickedJobId);
        
        // Toggle expansion: collapse all others, expand clicked one
        this.jobPostings = this.jobPostings.map(job => {
            if (job.Id === clickedJobId) {
                const willBeExpanded = !job.isExpanded;
                return { 
                    ...job, 
                    isExpanded: willBeExpanded,
                    expandedKey: job.Id + '-expanded',
                    cardClass: willBeExpanded ? 'job-card-container selected' : 'job-card-container',
                    expandIcon: willBeExpanded ? 'utility:chevronup' : 'utility:chevrondown'
                };
            } else {
                return { 
                    ...job, 
                    isExpanded: false,
                    expandedKey: job.Id + '-expanded',
                    cardClass: 'job-card-container',
                    expandIcon: 'utility:chevrondown'
                };
            }
        });
    }

    // Handle event from child component when candidate is clicked
    handleCandidateSelected(event) {
        this.selectedApplicationId = event.detail.applicationId;
        this.showModal = true;
    }

    // Handle event from modal when closed
    handleCloseModal() {
        this.showModal = false;
        this.selectedApplicationId = null;
    }

    // Handle event from modal when status is updated
    handleStatusUpdate(event) {
        // Find the expanded job and refresh its child component
        const expandedJob = this.jobPostings.find(job => job.isExpanded);
        if (expandedJob) {
            const applicationsListComp = this.template.querySelector(`c-applications-list[job-id="${expandedJob.Id}"]`);
            if (applicationsListComp) {
                applicationsListComp.refreshApplications();
            }
        }
    }

     handleOpenDocflow(event) {
        console.log('Opening DocflowApp:', event.detail.applicationId);
        this.docflowApplicationId = event.detail.applicationId;
        // this.showCandidateModal = false;
                    // this.showDocflowApp = true;  
    window.open('/lightning/cmp/c__docflowApp', '_blank');

    }
    
    // ADD THIS METHOD:
    handleCloseDocflow() {
        console.log('Closing DocflowApp');
        this.showDocflowApp = false;
        this.docflowApplicationId = null;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}