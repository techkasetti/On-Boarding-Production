import { LightningElement, api, wire, track } from 'lwc';
import getCandidateComplianceSummary from '@salesforce/apex/CandidateComplianceSummaryController.getCandidateComplianceSummary';

export default class CandidateMedicalComplianceSummary extends LightningElement {
    @api recordId;

    @track summary;
    @track error;
    @track selectedDomain;

    isLoading = true;

    @wire(getCandidateComplianceSummary, { candidateId: '$recordId' })
    wiredSummary({ data, error }) {
        this.isLoading = false;
        if (data) {
            // Deep clone the data to make it mutable
            let processedSummary = JSON.parse(JSON.stringify(data));

            // Add the statusClass property to each domain for the template
            if (processedSummary.domains) {
                processedSummary.domains.forEach(domain => {
                    domain.statusClass = this._getDomainStatusClass(domain.status);
                });
            }

            this.summary = processedSummary;
            this.error = undefined;
            this.selectedDomain = null;
        } else if (error) {
            this.error = error;
            this.summary = undefined;
            this.selectedDomain = null;
        }
    }

    get overallStatusClass() {
        if (!this.summary) {
            return 'slds-badge';
        }

        switch (this.summary.overallStatus) {
            case 'Compliant':
                return 'slds-badge slds-theme_success';
            case 'At Risk':
                return 'slds-badge slds-theme_warning';
            case 'Blocked':
                return 'slds-badge slds-theme_error';
            default:
                return 'slds-badge';
        }
    }

    get overallStatusIcon() {
        if (!this.summary) {
            return 'utility:info';
        }
        
        switch (this.summary.overallStatus) {
            case 'Compliant':
                return 'utility:success';
            case 'At Risk':
                return 'utility:warning';
            case 'Blocked':
                return 'utility:error';
            default:
                return 'utility:info';
        }
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }

        if (this.error.body) {
            if (Array.isArray(this.error.body)) {
                return this.error.body.map((e) => e.message).join(', ');
            }
            if (this.error.body.message) {
                return this.error.body.message;
            }
        }
        
        if (this.error.message) {
            return this.error.message;
        }
        
        return 'Unknown error';
    }

    handleTileClick(event) {
        const apiName = event.currentTarget.dataset.domain;
        if (!this.summary || !this.summary.domains) {
            this.selectedDomain = null;
            return;
        }

        let found = null;
        for (let i = 0; i < this.summary.domains.length; i++) {
            const d = this.summary.domains[i];
            if (d.apiName === apiName) {
                found = d;
                break;
            }
        }
        this.selectedDomain = found;
    }
    
    _getDomainStatusClass(status) {
        switch (status) {
            case 'Compliant':
                return 'slds-badge slds-theme_success';
            case 'At Risk':
                return 'slds-badge slds-theme_warning';
            case 'Blocked':
                return 'slds-badge slds-theme_error';
            case 'Not Started':
                return 'slds-badge slds-theme_default';
            default:
                return 'slds-badge';
        }
    }
}