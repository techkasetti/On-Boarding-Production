import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getJobApplications from '@salesforce/apex/MedicalRecruitmentController.getJobApplications';

export default class ApplicationsList extends LightningElement {
    @api jobId;
    @api jobTitle;
    
    @track applications = [];
    @track isLoading = false;

    get hasApplications() {
        return this.applications && this.applications.length > 0;
    }

    get cardTitle() {
        return this.jobTitle || 'Selected Job';
    }

    get applicationCount() {
        return this.applications ? this.applications.length : 0;
    }

    connectedCallback() {
        if (this.jobId) {
            this.loadApplications();
        }
    }

    @api
    refreshApplications() {
        this.loadApplications();
    }

    loadApplications() {
        this.isLoading = true;

        getJobApplications({ jobPostingId: this.jobId })
            .then(result => {
                this.applications = result.map(app => ({
                    ...app,
                    statusPillClass: this.getStatusPillClass(app.status),
                    initials: this.getInitials(app.candidateName)
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Error loading applications', 'error');
                console.error('Error:', error);
            });
    }

    handleRowAction(event) {
        const appId = event.currentTarget.dataset.appId;
        
        // Fire event to parent component
        const selectedEvent = new CustomEvent('candidateselected', {
            detail: { applicationId: appId }
        });
        this.dispatchEvent(selectedEvent);
    }

    getInitials(name) {
        if (!name) return '?';
        const parts = name.trim().split(' ');
        if (parts.length >= 2) {
            return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
        }
        return name.substring(0, 2).toUpperCase();
    }

    getStatusPillClass(status) {
        const s = status?.toLowerCase() || '';
        
        if (s.includes('passed') || s.includes('cleared') || s.includes('verified') || 
            s.includes('approved') || s.includes('active') || s.includes('accepted')) {
            return 'status-pill-premium success';
        } else if (s.includes('failed') || s.includes('rejected') || s.includes('expired') || 
                   s.includes('suspended') || s.includes('declined')) {
            return 'status-pill-premium error';
        } else if (s.includes('pending') || s.includes('progress') || s.includes('scheduled')) {
            return 'status-pill-premium warning';
        } else if (s.includes('received') || s.includes('new')) {
            return 'status-pill-premium info';
        }
        
        return 'status-pill-premium default';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}