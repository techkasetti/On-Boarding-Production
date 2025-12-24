import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getJobPostings from '@salesforce/apex/JobPostingAdminController.getJobPostings';
import saveJobPostings from '@salesforce/apex/JobPostingAdminController.saveJobPostings';
import deleteJobPosting from '@salesforce/apex/JobPostingAdminController.deleteJobPosting';
import getPicklistValues from '@salesforce/apex/JobPostingAdminController.getPicklistValues';

const actions = [
    { label: 'Edit', name: 'edit', iconName: 'utility:edit' },
    { label: 'Delete', name: 'delete', iconName: 'utility:delete' }
];

export default class JobPostingAdmin extends LightningElement {
    @track jobPostings = [];
    @track filteredJobPostings = [];
    @track columns = [];
    @track currentJob = {};
    @track statusOptions = [];
    @track categoryOptions = [];
    @track experienceOptions = [];
    @track specializationOptions = [];

    isModalOpen = false;
    isDeleteModalOpen = false;
    modalTitle = '';
    searchKey = '';
    isLoading = false;
    jobToDelete = null;

    get totalJobs() {
        return this.filteredJobPostings.length;
    }

    get hasJobs() {
        return this.filteredJobPostings.length > 0;
    }

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this.isLoading = true;
        try {
            // Load all picklist values
            const [statusData, categoryData, experienceData, specializationData] = await Promise.all([
                getPicklistValues({ fieldName: 'Status__c' }),
                getPicklistValues({ fieldName: 'Category__c' }),
                getPicklistValues({ fieldName: 'Experience_Level__c' }),
                getPicklistValues({ fieldName: 'Specialization__c' })
            ]);

            this.statusOptions = statusData;
            this.categoryOptions = categoryData;
            this.experienceOptions = experienceData;
            this.specializationOptions = specializationData;

            // Define columns
            this.columns = [
                { 
                    label: 'Job Title', 
                    fieldName: 'Name', 
                    type: 'text', 
                    wrapText: true,
                    cellAttributes: { class: 'slds-text-title_bold' }
                },
                { 
                    label: 'Category', 
                    fieldName: 'Category__c', 
                    type: 'text'
                },
                { 
                    label: 'Location', 
                    fieldName: 'Location__c', 
                    type: 'text'
                },
                { 
                    label: 'Experience', 
                    fieldName: 'Experience_Level__c', 
                    type: 'text'
                },
                { 
                    label: 'Status', 
                    fieldName: 'Status__c', 
                    type: 'text',
                    cellAttributes: { 
                        class: { fieldName: 'statusClass' }
                    }
                },
                { 
                    type: 'action', 
                    typeAttributes: { rowActions: actions }
                }
            ];

            // Load job records
            const jobData = await getJobPostings();
            this.jobPostings = jobData.map(record => ({
                ...record,
                statusClass: this.getStatusClass(record.Status__c)
            }));
            this.filteredJobPostings = [...this.jobPostings];

        } catch (error) {
            this.showToast(
                'Error Loading Data',
                error.body ? error.body.message : error.message,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    getStatusClass(status) {
        const statusMap = {
            'Active': 'status-active',
            'Inactive': 'status-inactive',
            'Draft': 'status-draft',
            'Closed': 'status-closed'
        };
        return statusMap[status] || '';
    }

    handleSearch(event) {
        this.searchKey = event.target.value.toLowerCase();
        
        if (!this.searchKey) {
            this.filteredJobPostings = [...this.jobPostings];
            return;
        }

        this.filteredJobPostings = this.jobPostings.filter(job => {
            return (
                (job.Name && job.Name.toLowerCase().includes(this.searchKey)) ||
                (job.Category__c && job.Category__c.toLowerCase().includes(this.searchKey)) ||
                (job.Location__c && job.Location__c.toLowerCase().includes(this.searchKey)) ||
                (job.Status__c && job.Status__c.toLowerCase().includes(this.searchKey))
            );
        });
    }

    handleNew() {
        this.modalTitle = 'Create New Job Posting';
        this.currentJob = {
            Status__c: 'Draft'
        };
        this.isModalOpen = true;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit') {
            this.modalTitle = 'Edit Job Posting';
            this.currentJob = { ...row };
            this.isModalOpen = true;
        } else if (actionName === 'delete') {
            this.jobToDelete = row;
            this.isDeleteModalOpen = true;
        }
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        this.currentJob[field] = event.target.value;
    }

    async handleSave() {
        // Validation
        if (!this.currentJob.Name) {
            this.showToast('Validation Error', 'Job Posting Name is required.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            await saveJobPostings({ jobPostings: [this.currentJob] });
            this.showToast(
                'Success', 
                this.currentJob.Id ? 'Job Posting updated successfully.' : 'Job Posting created successfully.', 
                'success'
            );

            this.closeModal();
            await this.loadData();

        } catch (error) {
            this.showToast(
                'Error Saving',
                error.body ? error.body.message : error.message,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async confirmDelete() {
        if (!this.jobToDelete) return;

        this.isLoading = true;
        try {
            await deleteJobPosting({ jobPostingId: this.jobToDelete.Id });
            this.showToast('Success', 'Job Posting deleted successfully.', 'success');
            this.closeDeleteModal();
            await this.loadData();
        } catch (error) {
            this.showToast(
                'Error Deleting',
                error.body ? error.body.message : error.message,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    closeModal() {
        this.isModalOpen = false;
        this.currentJob = {};
    }

    closeDeleteModal() {
        this.isDeleteModalOpen = false;
        this.jobToDelete = null;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}