// jobPostingConsole.js - 
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import createJobFromNLP from '@salesforce/apex/JobPostingAdminController.createJobFromNLP';
import createJobsFromCSV from '@salesforce/apex/JobPostingAdminController.createJobsFromCSV';

export default class JobPostingConsole extends NavigationMixin(LightningElement) {
    @track activeTab = 'nlp';
    @track nlpInput = '';
    @track fileName = '';
    @track csvContent = '';
    @track isProcessing = false;

    get characterCount() {
        return this.nlpInput ? this.nlpInput.length : 0;
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
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
        
        try {
            const jobId = await createJobFromNLP({ userInput: this.nlpInput });
            
            // Show success with action button
            this.showSuccessWithAction(
                'Job posting created successfully! Click "Back to Admin" to view it in the admin page.',
                'View in Admin',
                () => this.navigateToAdmin()
            );
            
            this.nlpInput = '';
            
            // DON'T auto-navigate - let user click the button or "Back to Admin"
            // This prevents the "Page doesn't exist" error
            
        } catch (error) {
            this.showError('Error creating job posting: ' + this.getErrorMessage(error));
        } finally {
            this.isProcessing = false;
        }
    }

    handleClear() {
        this.nlpInput = '';
    }

    handleCSVUpload(event) {
        const file = event.target.files[0];
        if (file) {
            this.fileName = file.name;
            
            const reader = new FileReader();
            reader.onload = (e) => {
                this.csvContent = e.target.result;
                this.showSuccess('File loaded: ' + this.fileName);
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
        
        const rows = this.csvContent.split('\n').filter(row => row.trim().length > 0);
        const dataRowCount = rows.length - 1;
        
        console.log(`CSV contains ${dataRowCount} data rows`);
        
        const MAX_ROWS = 50;
        if (dataRowCount > MAX_ROWS) {
            this.showError(
                `CSV contains ${dataRowCount} jobs, but maximum is ${MAX_ROWS} per upload. ` +
                `Please split your CSV into multiple files and upload separately.`
            );
            return;
        }
        
        if (dataRowCount > 20) {
            const estimatedMinutes = Math.ceil(dataRowCount * 3 / 60);
            const proceed = confirm(
                `⚠️ Large Upload Warning\n\n` +
                `You're uploading ${dataRowCount} jobs.\n\n` +
                `Estimated processing time: ${estimatedMinutes} minute(s)\n\n` +
                `Do not close or refresh the page.\n\n` +
                `Do you want to continue?`
            );
            if (!proceed) {
                return;
            }
        }
        
        this.isProcessing = true;
        const startTime = Date.now();
        
        try {
            console.log('Starting CSV processing...');
            const result = await createJobsFromCSV({ csvContent: this.csvContent });
            
            const elapsedSeconds = Math.round((Date.now() - startTime) / 1000);
            console.log(`CSV processing completed in ${elapsedSeconds} seconds`);
            
            if (result && result.success) {
                if (result.errors && result.errors.length > 0) {
                    const errorCount = result.errors.length;
                    const totalAttempted = result.count + errorCount;
                    
                    console.warn('Errors during CSV processing:', result.errors);
                    
                    this.showWarningWithAction(
                        `Created ${result.count} of ${totalAttempted} jobs. ${errorCount} had errors. Click "Back to Admin" to view created jobs.`,
                        'View in Admin',
                        () => this.navigateToAdmin()
                    );
                } else {
                    this.showSuccessWithAction(
                        `Successfully created ${result.count} job posting(s) in ${elapsedSeconds} seconds! Click "Back to Admin" to view them.`,
                        'View in Admin',
                        () => this.navigateToAdmin()
                    );
                }
                
                this.fileName = '';
                this.csvContent = '';
                
                const fileInput = this.template.querySelector('input[type="file"]');
                if (fileInput) {
                    fileInput.value = '';
                }
                
                // DON'T auto-navigate - let user click the button
                
            } else {
                this.showError('Error processing CSV file. Please check the file format and try again.');
            }
            
        } catch (error) {
            const elapsedSeconds = Math.round((Date.now() - startTime) / 1000);
            console.error('CSV processing failed after ' + elapsedSeconds + ' seconds:', error);
            
            let errorMessage = this.getErrorMessage(error);
            
            if (errorMessage.includes('Apex CPU time limit exceeded')) {
                this.showError(
                    'Processing timeout: Your CSV has too many jobs. ' +
                    'Please split it into smaller files (max 30 jobs per file) and try again.'
                );
            } else if (errorMessage.includes('Too many callouts')) {
                this.showError(
                    'API limit exceeded: Maximum 50 jobs per upload. ' +
                    'Please split your CSV into smaller files and try again.'
                );
            } else {
                this.showError('Error processing CSV: ' + errorMessage);
            }
        } finally {
            this.isProcessing = false;
        }
    }

handleDownloadSample() {
    const csvRows = [
        [
            'Job Title', 'Category', 'Role Type', 'Department', 'Employment Type',
            'Shift Type', 'Min Experience', 'Max Experience', 'Start Date', 'End Date',
            'Facility Name', 'City', 'State', 'Country', 'Credentialing Required',
            'Privilege Scope', 'Description'
        ],
        [
            'Duty Doctor - Emergency', 'Medical', 'Doctor', 'Emergency', 'Full-time',
            'Rotational', '2', '10', '2026-02-01', '2026-12-31',
            'City General Hospital', 'Chennai', 'Tamil Nadu', 'India', 'TRUE',
            'Emergency OPD - Stabilization & Basic Procedures',
            'Emergency duty doctor responsible for triage stabilization and patient management. EDUCATION: MBBS degree required. LICENSES: Valid Medical Council Registration from Tamil Nadu Medical Council required. CERTIFICATIONS: BLS and ACLS certifications mandatory. SKILLS: Patient Assessment at Advanced level - Emergency Management at Advanced level required. PROCEDURES: Must be able to perform IV Cannulation and Wound Suturing. COMPLIANCE: HIPAA compliance mandatory.'
        ],
        [
            'ICU Staff Nurse', 'Medical', 'Nurse', 'ICU', 'Full-time',
            'Night', '3', '8', '2026-03-01', '2026-12-31',
            'Apollo Hospital', 'Mumbai', 'Maharashtra', 'India', 'TRUE',
            'Critical Care Nursing - Ventilator Management',
            'Provide comprehensive patient care in intensive care unit. EDUCATION: BSc Nursing or GNM required. LICENSES: Valid Nursing Council Registration from Maharashtra Nursing Council. CERTIFICATIONS: BLS - ACLS - and Critical Care Nursing certification mandatory. SKILLS: Ventilator Management at Advanced level - Critical Care Monitoring at Advanced level. PROCEDURES: Central Line Care - Arterial Line Management. COMPLIANCE: HIPAA and Infection Control Protocol compliance required.'
        ]
    ];

    // Build CSV string — wrap every field in double quotes and escape any internal quotes
    const csvString = csvRows.map(row =>
        row.map(field => {
            // Escape double quotes inside field by doubling them
            const escaped = String(field).replace(/"/g, '""');
            return `"${escaped}"`;
        }).join(',')
    ).join('\r\n');

    // Use data URI instead of Blob URL (works inside Salesforce CSP)
    const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvString);

    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', 'enhanced_medical_jobs_sample.csv');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Sample CSV Downloaded',
            message: 'Contains 2 example jobs with comprehensive descriptions. Maximum 50 jobs per upload.',
            variant: 'info'
        })
    );
}
    /**
     * Navigate back to Admin Tab
     */
    navigateToAdmin() {
        
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: {
                    apiName: 'JobPostingAdmin' 
                }
            });
        } catch (error) {
            console.error('Navigation error:', error);
            // Fallback: Show message if navigation fails
            this.showError('Unable to navigate. Please use the tab menu to go to Job Posting Admin.');
        }
    }

    showSuccess(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: message,
                variant: 'success'
            })
        );
    }

    showSuccessWithAction(message, actionLabel, actionHandler) {
        const toast = new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success',
            mode: 'sticky'
        });
        this.dispatchEvent(toast);
        
        
    }

    showError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error',
                mode: 'sticky'
            })
        );
    }

    showWarning(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Warning',
                message: message,
                variant: 'warning',
                mode: 'sticky'
            })
        );
    }

    showWarningWithAction(message, actionLabel, actionHandler) {
        const toast = new ShowToastEvent({
            title: 'Warning',
            message: message,
            variant: 'warning',
            mode: 'sticky'
        });
        this.dispatchEvent(toast);
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