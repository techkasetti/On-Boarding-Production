import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getJobPostings from '@salesforce/apex/JobPostingAdminController.getJobPostings';
import saveJobPostings from '@salesforce/apex/JobPostingAdminController.saveJobPostings';
import deleteJobPosting from '@salesforce/apex/JobPostingAdminController.deleteJobPosting';
import getPicklistValues from '@salesforce/apex/JobPostingAdminController.getPicklistValues';

const actions = [
    { label: 'Edit', name: 'edit' },
    { label: 'Delete', name: 'delete' }
];

export default class JobPostingAdmin extends LightningElement {
    @track jobPostings = [];
    @track columns = [];
    @track currentJob = {};
    @track statusOptions = [];

    isModalOpen = false;
    modalTitle = '';

    connectedCallback() {
        this.loadData();
    }

    /* ----------------------------------------------------
       Load Picklist + Columns + Job Records (in order)
    -----------------------------------------------------*/
    async loadData() {
        try {
            // 1️⃣ Get picklist values first
            const picklistData = await getPicklistValues();
            this.statusOptions = picklistData;

            // 2️⃣ Construct columns AFTER picklist values load
            this.columns = [
                { label: 'Job Posting Name', fieldName: 'Name', type: 'text', wrapText: true },
                { label: 'Location', fieldName: 'Location__c', type: 'text' },

                // Read-only current status
                { label: 'Status', fieldName: 'Status__c', type: 'text' },
                
                { type: 'action', typeAttributes: { rowActions: actions } }
            ];

            // 3️⃣ Now load job records and inject EditStatus__c
            const jobData = await getJobPostings();
            this.jobPostings = jobData.map(record => ({
                ...record,
                EditStatus__c: record.Status__c       // default value for editing
            }));

        } catch (error) {
            this.showToast(
                'Error Loading Data',
                error.body ? error.body.message : error.message,
                'error'
            );
        }
    }

    /* ----------------------------------------------------
       Datatable Inline Save
    -----------------------------------------------------*/
    async handleDatatableSave(event) {
        const draftValues = event.detail.draftValues;

        const recordsToSave = draftValues.map(draft => {
            const rec = { Id: draft.Id };

            // Map temporary edit field back to real API field
            if (draft.EditStatus__c !== undefined) {
                rec.Status__c = draft.EditStatus__c;
            }

            return rec;
        });

        // Only save records that actually changed
        const filteredRecords = recordsToSave.filter(r => Object.keys(r).length > 1);

        if (filteredRecords.length === 0) {
            this.template.querySelector('lightning-datatable').draftValues = [];
            return;
        }

        try {
            await saveJobPostings({ jobPostings: filteredRecords });
            this.showToast('Success', 'Job Postings updated successfully.', 'success');

            this.template.querySelector('lightning-datatable').draftValues = [];
            await this.loadData(); // refresh all data

        } catch (error) {
            this.showToast(
                'Error Updating',
                error.body ? error.body.message : error.message,
                'error'
            );
        }
    }

    /* ----------------------------------------------------
       Modal: New / Edit
    -----------------------------------------------------*/
    handleNew() {
        this.modalTitle = 'New Job Posting';
        this.currentJob = {};
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
            this.handleDelete(row.Id);
        }
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        this.currentJob[field] = event.target.value;
    }

    async handleSave() {
        if (!this.currentJob.Name) {
            this.showToast('Validation Error', 'Job Posting Name is required.', 'error');
            return;
        }

        try {
            await saveJobPostings({ jobPostings: [this.currentJob] });
            this.showToast('Success', 'Job Posting saved successfully.', 'success');

            this.closeModal();
            await this.loadData();

        } catch (error) {
            this.showToast(
                'Error Saving',
                error.body ? error.body.message : error.message,
                'error'
            );
        }
    }

    /* ----------------------------------------------------
       Delete Record
    -----------------------------------------------------*/
    async handleDelete(jobId) {
        try {
            await deleteJobPosting({ jobPostingId: jobId });
            this.showToast('Success', 'Job Posting deleted successfully.', 'success');
            await this.loadData();
        } catch (error) {
            this.showToast(
                'Error Deleting',
                error.body ? error.body.message : error.message,
                'error'
            );
        }
    }

    /* ----------------------------------------------------
       Helpers
    -----------------------------------------------------*/
    closeModal() {
        this.isModalOpen = false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}
