import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getCandidateStatus from '@salesforce/apex/CandidateStatusController.getCandidateStatus';
import rerunScreening from '@salesforce/apex/CandidateStatusController.rerunScreening';

export default class CandidateScreenStatus extends LightningElement {
    @api recordId;
    @track isRunning = false; // To control the button's disabled state

    // Private property to hold the result from the wire service
    _wiredStatusResult;

    @wire(getCandidateStatus, { candidateId: '$recordId' })
    wiredStatus(result) {
        this._wiredStatusResult = result; // Store the raw wire result

        if (result.data) {
            // Process the results to add the correct CSS class for the lightning-badge
            let processedResults = result.data.results.map(res => {
                let outcomeClass = 'slds-badge'; // Default badge style

                switch (res.outcome) {
                    case 'Pass':
                        outcomeClass += ' slds-badge_lightest slds-theme_success';
                        break;
                    case 'Fail':
                        outcomeClass += ' slds-badge_lightest slds-theme_error';
                        break;
                    case 'Review':
                        outcomeClass += ' slds-badge_lightest slds-theme_warning';
                        break;
                    default:
                        break;
                }

                // Return a new object with the original properties plus the new one
                return { ...res, outcomeClass };
            });

            // Create a new data structure to avoid mutating the wire service's cache
            const updatedData = { ...result.data, results: processedResults };
            this._wiredStatusResult = { ...result, data: updatedData };
        }
    }

    // --- Rerun button: now also refreshes immediately ---
    async handleRerun() {
        this.isRunning = true;
        this._showToast('In Progress', 'Re-running screening in the background...', 'info');

        try {
            // Call the Apex method to start the queueable job
            await rerunScreening({ candidateId: this.recordId });

            // Immediately refresh the wired data (no waiting)
            this.handleRefresh();

            this._showToast(
                'Success',
                'Screening process has been started and results are refreshing.',
                'success'
            );
        } catch (error) {
            this._showToast(
                'Error',
                'Failed to start screening process: ' + this._extractError(error),
                'error'
            );
        } finally {
            // Re-enable the button once the callout is complete
            this.isRunning = false;
        }
    }

    // Keep the refresh logic, just no separate button in the UI
    handleRefresh() {
        return refreshApex(this._wiredStatusResult);
    }

    // --- Getters for the template ---

    get data() {
        return this._wiredStatusResult && this._wiredStatusResult.data;
    }

    get error() {
        return this._wiredStatusResult && this._wiredStatusResult.error;
    }

    get hasResults() {
        return this.data && this.data.results && this.data.results.length > 0;
    }

    // --- Private helper methods ---

    _showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    _extractError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'An unknown error occurred.';
    }
}
