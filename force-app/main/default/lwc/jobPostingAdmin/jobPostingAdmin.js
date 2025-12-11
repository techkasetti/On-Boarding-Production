import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getJobPostings from '@salesforce/apex/JobPostingAdminController.getJobPostings';
import saveJobPostings from '@salesforce/apex/JobPostingAdminController.saveJobPostings';
import deleteJobPosting from '@salesforce/apex/JobPostingAdminController.deleteJobPosting';
import getPicklistValues from '@salesforce/apex/JobPostingAdminController.getPicklistValues';

const actions = [
    { label: 'Edit', name: 'edit' },
    { label: 'Delete', name: 'delete' },
];

export default class JobPostingAdmin extends LightningElement {
    @track jobPostings = [];
    @track columns = [];
    isModalOpen = false;
    modalTitle = '';
    @track currentJob = {};
    @track statusOptions = [];

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        try {
            // 1. First, fetch the picklist options
            const picklistData = await getPicklistValues();
            this.statusOptions = picklistData;

            // 2. Now that we have options, define the columns
            this.columns = [
                { label: 'Job Posting Name', fieldName: 'Name', type: 'text', wrapText: true },
                { label: 'Location', fieldName: 'Location__c', type: 'text' },
                // Read-only column to show the current status
                { label: 'Current Status', fieldName: 'Status__c', type: 'text' },
                // Editable picklist column to change the status
                {
                    label: 'Edit Status',
                    fieldName: 'EditStatus__c', // This field only exists in our JS data
                    type: 'picklist',
                    editable: true,
                    typeAttributes: {
                        placeholder: 'Change status...',
                        options: this.statusOptions,
                        value: { fieldName: 'EditStatus__c' }, // Bind to our temporary field
                        context: { fieldName: 'Id' }
                    }
                },
                {
                    type: 'action',
                    typeAttributes: { rowActions: actions }
                }
            ];

            // 3. Finally, fetch the job posting records
            const jobData = await getJobPostings();
            // Map the data, creating a temporary 'EditStatus__c' field for our editable column
            this.jobPostings = jobData.map(record => ({
                ...record,
                EditStatus__c: record.Status__c
            }));

        } catch (error) {
            this.showToast('Error Loading Data', error.body ? error.body.message : error.message, 'error');
        }
    }

    // Handles saving inline edits from the datatable
    async handleDatatableSave(event) {
        const draftValues = event.detail.draftValues;

        // The draft values will reference 'EditStatus__c'. We need to map this back
        // to the real database field 'Status__c' before sending it to Apex.
        const recordsToSave = draftValues.map(draft => {
            const record = { Id: draft.Id };
            if (draft.EditStatus__c !== undefined) {
                record.Status__c = draft.EditStatus__c;
            }
            return record;
        });

        // Filter out any objects that didn't have the status changed
        const filteredRecords = recordsToSave.filter(rec => Object.keys(rec).length > 1);
        if (filteredRecords.length === 0) {
            return; // Nothing to save
        }

        try {
            await saveJobPostings({ jobPostings: filteredRecords });
            this.showToast('Success', 'Job Postings updated successfully.', 'success');

            // Clear draft values and refresh all data to show changes
            this.template.querySelector('lightning-datatable').draftValues = [];
            await this.loadData();
        } catch (error) {
            this.showToast('Error Updating', error.body ? error.body.message : error.message, 'error');
        }
    }

    // --- Other methods (no changes) ---

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
            this.showToast('Error Saving', error.body ? error.body.message : error.message, 'error');
        }
    }

    async handleDelete(jobId) {
        try {
            await deleteJobPosting({ jobPostingId: jobId });
            this.showToast('Success', 'Job Posting deleted successfully.', 'success');
            await this.loadData();
        } catch (error) {
            this.showToast('Error Deleting', error.body ? error.body.message : error.message, 'error');
        }
    }

    closeModal() {
        this.isModalOpen = false;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(event);
    }
}
