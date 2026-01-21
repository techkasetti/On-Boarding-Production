import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import createJobFromNLP from '@salesforce/apex/JobPostingController.createJobFromNLP';
import createJobsFromCSV from '@salesforce/apex/JobPostingController.createJobsFromCSV';
import getRecentJobPostings from '@salesforce/apex/JobPostingController.getRecentJobPostings';
import updateJobPosting from '@salesforce/apex/JobPostingController.updateJobPosting';

export default class JobPostingConsole extends NavigationMixin(LightningElement) {
    @track activeTab = 'nlp';
    @track nlpInput = '';
    @track fileName = '';
    @track csvContent = '';
    @track isProcessing = false;
    @track successMessage = '';
    @track errorMessage = '';
    @track jobPostings = [];
    @track showViewModal = false;
    @track showEditModal = false;
    @track selectedJob = null;
    
    // Edit form fields
    @track editName = '';
    @track editCategory = '';
    @track editLocation = '';
    @track editExperienceLevel = '';
    @track editSpecialization = '';
    @track editStatus = '';
    @track editStartDate = '';
    @track editEndDate = '';
    @track editDescription = '';

    wiredJobPostingsResult;

    @wire(getRecentJobPostings)
    wiredJobPostings(result) {
        this.wiredJobPostingsResult = result;
        if (result.data) {
            this.jobPostings = result.data.map(job => ({
                ...job,
                isActive: job.Status__c === 'Open',
                isClosed: job.Status__c === 'Closed'
            }));
        } else if (result.error) {
            this.showError('Error loading job postings: ' + this.getErrorMessage(result.error));
        }
    }

    get hasJobPostings() {
        return this.jobPostings && this.jobPostings.length > 0;
    }

    get characterCount() {
        return this.nlpInput ? this.nlpInput.length : 0;
    }

    get recentPostingsLabel() {
        return `Recent Postings (${this.jobPostings.length})`;
    }

    get categoryOptions() {
        return [
            { label: 'Medical', value: 'Medical' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get experienceLevelOptions() {
        return [
            { label: 'Entry Level', value: 'Entry Level' },
            { label: 'Mid-Level', value: 'Mid-Level' },
            { label: 'Senior Level', value: 'Senior Level' },
            { label: 'Executive', value: 'Executive' }
        ];
    }

    get specializationOptions() {
        return [
            { label: 'None', value: '' },
            { label: 'Psychiatrist', value: 'Psychiatrist' },
            { label: 'Dermatologist', value: 'Dermatologist' },
            { label: 'Cardiologist', value: 'Cardiologist' },
            { label: 'General Nurse', value: 'General Nurse' },
            { label: 'Radiologist', value: 'Radiologist' }
        ];
    }

    get statusOptions() {
        return [
            { label: 'Open', value: 'Open' },
            { label: 'Closed', value: 'Closed' }
        ];
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
        this.clearMessages();
    }

    handleNLPInputChange(event) {
        this.nlpInput = event.target.value;
    }

    handleKeyDown(event) {
        if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
            event.preventDefault();
            this.handleNLPSubmit();
        }
    }

    async handleNLPSubmit() {
        if (!this.nlpInput || !this.nlpInput.trim()) {
            this.showError('Please enter a job description');
            return;
        }
        
        this.isProcessing = true;
        this.clearMessages();
        
        try {
            const jobId = await createJobFromNLP({ userInput: this.nlpInput });
            this.showSuccess('Job posting created successfully!');
            this.nlpInput = '';
            
            await refreshApex(this.wiredJobPostingsResult);
            
            setTimeout(() => {
                this.activeTab = 'recent';
            }, 1500);
            
        } catch (error) {
            this.showError('Error creating job posting: ' + this.getErrorMessage(error));
        } finally {
            this.isProcessing = false;
        }
    }

    handleClear() {
        this.nlpInput = '';
        this.clearMessages();
    }

    handleCSVUpload(event) {
        const file = event.target.files[0];
        if (file) {
            this.fileName = file.name;
            
            // Read file content
            const reader = new FileReader();
            reader.onload = (e) => {
                this.csvContent = e.target.result;
                // No need to show success message here - the file-selected-box will display it
            };
            reader.onerror = (error) => {
                this.showError('Error reading file: ' + error);
            };
            reader.readAsText(file);
        }
    }

    async handleCSVSubmit() {
    if (!this.fileName) {
        this.showError('Please upload a CSV file first');
        return;
    }
    
    if (!this.csvContent || this.csvContent.trim().length === 0) {
        this.showError('CSV file is empty. Please upload a valid file.');
        return;
    }
    
    this.isProcessing = true;
    this.clearMessages();
    
    try {
        console.log('Submitting CSV. Content length:', this.csvContent.length);
        
        const result = await createJobsFromCSV({ csvContent: this.csvContent });
        
        console.log('CSV processing result:', result);
        
        if (result && result.success) {
            this.showSuccess(`Successfully created ${result.count} job posting(s)!`);
            
            // Clear the file input
            this.fileName = '';
            this.csvContent = '';
            
            // Reset the file upload component
            const fileInput = this.template.querySelector('lightning-file-upload');
            if (fileInput) {
                fileInput.value = null;
            }
            
            await refreshApex(this.wiredJobPostingsResult);
            
            setTimeout(() => {
                this.activeTab = 'recent';
            }, 1500);
        } else {
            this.showError('Error processing CSV file. Please check the file format.');
        }
        
    } catch (error) {
        console.error('CSV processing error:', error);
        
        // Extract meaningful error message
        let errorMessage = 'Error processing CSV';
        
        if (error.body && error.body.message) {
            errorMessage = error.body.message;
        } else if (error.message) {
            errorMessage = error.message;
        }
        
        // Make error message more user-friendly
        if (errorMessage.includes('No valid job postings found')) {
            errorMessage = 'No valid job postings found in CSV. Please ensure:\n' +
                          '1. Headers match the required format\n' +
                          '2. At least Job Title is provided for each row\n' +
                          '3. Dates are in YYYY-MM-DD format';
        }
        
        this.showError(errorMessage);
    } finally {
        this.isProcessing = false;
    }
}
    handleDownloadSample() {
        const csvContent = 'Job Title,Category,Location,Experience Level,Start Date,End Date,Status,Description\n' +
            '"Senior Cardiologist","Healthcare","San Francisco","Senior Level",2026-02-01,2026-04-30,Open,"Provide comprehensive cardiac care and perform diagnostic procedures"\n' +
            '"ICU Nurse","Healthcare","New York","Mid Level",2026-03-01,2026-05-01,Open,"Provide patient care in intensive care unit"\n' +
            '"Clinical Psychiatrist","Healthcare","Remote","Executive",2026-02-15,2026-04-15,Open,"Provide mental health care and therapy"\n' +
            '"Marketing Manager","Marketing","Boston","Mid Level",2026-03-01,2026-05-01,Open,"Lead digital marketing campaigns and strategy"';
        
        const blob = new Blob([csvContent], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = 'sample_job_postings.csv';
        link.click();
        window.URL.revokeObjectURL(url);
    }

    handleView(event) {
        const jobId = event.target.dataset.id;
        this.selectedJob = this.jobPostings.find(job => job.Id === jobId);
        this.showViewModal = true;
    }

    handleCloseViewModal() {
        this.showViewModal = false;
        this.selectedJob = null;
    }

    handleEdit(event) {
        const jobId = event.target.dataset.id;
        this.selectedJob = this.jobPostings.find(job => job.Id === jobId);
        
        // Populate edit form fields
        this.editName = this.selectedJob.Name || '';
        this.editCategory = this.selectedJob.Category__c || '';
        this.editLocation = this.selectedJob.Location__c || '';
        this.editExperienceLevel = this.selectedJob.Experience_Level__c || '';
        this.editSpecialization = this.selectedJob.Specialization__c || '';
        this.editStatus = this.selectedJob.Status__c || '';
        this.editStartDate = this.selectedJob.Start_Date__c || '';
        this.editEndDate = this.selectedJob.End_Date__c || '';
        this.editDescription = this.selectedJob.Description__c || '';
        
        // Close view modal if open
        this.showViewModal = false;
        
        // Open edit modal
        this.showEditModal = true;
    }

    handleCloseEditModal() {
        this.showEditModal = false;
        this.selectedJob = null;
    }

    handleEditFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        
        switch(field) {
            case 'name':
                this.editName = value;
                break;
            case 'category':
                this.editCategory = value;
                break;
            case 'location':
                this.editLocation = value;
                break;
            case 'experienceLevel':
                this.editExperienceLevel = value;
                break;
            case 'specialization':
                this.editSpecialization = value;
                break;
            case 'status':
                this.editStatus = value;
                break;
            case 'startDate':
                this.editStartDate = value;
                break;
            case 'endDate':
                this.editEndDate = value;
                break;
            case 'description':
                this.editDescription = value;
                break;
        }
    }

    async handleSaveEdit() {
        this.isProcessing = true;
        this.clearMessages();
        
        try {
            const jobData = {
                Id: this.selectedJob.Id,
                Name: this.editName,
                Category__c: this.editCategory,
                Location__c: this.editLocation,
                Experience_Level__c: this.editExperienceLevel,
                Specialization__c: this.editSpecialization,
                Status__c: this.editStatus,
                Start_Date__c: this.editStartDate,
                End_Date__c: this.editEndDate,
                Description__c: this.editDescription
            };
            
            await updateJobPosting({ jobData: JSON.stringify(jobData) });
            
            this.showSuccess('Job posting updated successfully!');
            this.showEditModal = false;
            this.selectedJob = null;
            
            await refreshApex(this.wiredJobPostingsResult);
            
        } catch (error) {
            this.showError('Error updating job posting: ' + this.getErrorMessage(error));
        } finally {
            this.isProcessing = false;
        }
    }
    
    get formattedStartDate() {
        if (this.selectedJob && this.selectedJob.Start_Date__c) {
            return new Date(this.selectedJob.Start_Date__c).toLocaleDateString();
        }
        return 'Not specified';
    }
    
    get formattedEndDate() {
        if (this.selectedJob && this.selectedJob.End_Date__c) {
            return new Date(this.selectedJob.End_Date__c).toLocaleDateString();
        }
        return 'Not specified';
    }

    showSuccess(message) {
        this.successMessage = message;
        this.errorMessage = '';
        
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: message,
                variant: 'success'
            })
        );
        
        setTimeout(() => {
            this.successMessage = '';
        }, 5000);
    }

    showError(message) {
        this.errorMessage = message;
        this.successMessage = '';
        
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error'
            })
        );
        
        setTimeout(() => {
            this.errorMessage = '';
        }, 5000);
    }

    clearMessages() {
        this.successMessage = '';
        this.errorMessage = '';
    }

    getErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        } else if (error.message) {
            return error.message;
        } else if (typeof error === 'string') {
            return error;
        }
        return 'An unknown error occurred';
    }
}