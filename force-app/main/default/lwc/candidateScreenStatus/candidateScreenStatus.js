// import { LightningElement, api, wire, track } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import { refreshApex } from '@salesforce/apex';

// import getCandidateStatus from '@salesforce/apex/CandidateStatusController.getCandidateStatus';
// import rerunScreening from '@salesforce/apex/CandidateStatusController.rerunScreening';

// export default class CandidateScreenStatus extends LightningElement {
//     @api recordId;
//     @track isRunning = false; // To control the button's disabled state

//     // Private property to hold the result from the wire service
//     _wiredStatusResult;

//     @wire(getCandidateStatus, { candidateId: '$recordId' })
//     wiredStatus(result) {
//         this._wiredStatusResult = result; // Store the raw wire result

//         if (result.data) {
//             // Process the results to add the correct CSS class for the lightning-badge
//             let processedResults = result.data.results.map(res => {
//                 let outcomeClass = 'slds-badge'; // Default badge style

//                 switch (res.outcome) {
//                     case 'Pass':
//                         outcomeClass += ' slds-badge_lightest slds-theme_success';
//                         break;
//                     case 'Fail':
//                         outcomeClass += ' slds-badge_lightest slds-theme_error';
//                         break;
//                     case 'Review':
//                         outcomeClass += ' slds-badge_lightest slds-theme_warning';
//                         break;
//                     default:
//                         break;
//                 }

//                 // Return a new object with the original properties plus the new one
//                 return { ...res, outcomeClass };
//             });

//             // Create a new data structure to avoid mutating the wire service's cache
//             const updatedData = { ...result.data, results: processedResults };
//             this._wiredStatusResult = { ...result, data: updatedData };
//         }
//     }

//     // --- Rerun button: now also refreshes immediately ---
//     async handleRerun() {
//         this.isRunning = true;
//         this._showToast('In Progress', 'Re-running screening in the background...', 'info');

//         try {
//             // Call the Apex method to start the queueable job
//             await rerunScreening({ candidateId: this.recordId });

//             // Immediately refresh the wired data (no waiting)
//             this.handleRefresh();

//             this._showToast(
//                 'Success',
//                 'Screening process has been started and results are refreshing.',
//                 'success'
//             );
//         } catch (error) {
//             this._showToast(
//                 'Error',
//                 'Failed to start screening process: ' + this._extractError(error),
//                 'error'
//             );
//         } finally {
//             // Re-enable the button once the callout is complete
//             this.isRunning = false;
//         }
//     }

//     // Keep the refresh logic, just no separate button in the UI
//     handleRefresh() {
//         return refreshApex(this._wiredStatusResult);
//     }

//     // --- Getters for the template ---

//     get data() {
//         return this._wiredStatusResult && this._wiredStatusResult.data;
//     }

//     get error() {
//         return this._wiredStatusResult && this._wiredStatusResult.error;
//     }

//     get hasResults() {
//         return this.data && this.data.results && this.data.results.length > 0;
//     }

//     // --- Private helper methods ---

//     _showToast(title, message, variant) {
//         this.dispatchEvent(
//             new ShowToastEvent({
//                 title,
//                 message,
//                 variant
//             })
//         );
//     }

//     _extractError(error) {
//         if (error && error.body && error.body.message) {
//             return error.body.message;
//         }
//         return 'An unknown error occurred.';
//     }
// }
///////////////////////////////////////////////////////////////////////////////////////////
// import { LightningElement, api, wire, track } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import { refreshApex } from '@salesforce/apex';
// import getCandidateStatus from '@salesforce/apex/CandidateStatusController.getCandidateStatus';
// import rerunScreening from '@salesforce/apex/CandidateStatusController.rerunScreening';

// export default class CandidateScreenStatus extends LightningElement {
//     @api recordId;
//     @track isRunning = false;
//     @track data; // FIXED: Use tracked property instead of modifying wired result
//     @track error;
    
//     _wiredStatusResult; // Store wired result reference

//     @wire(getCandidateStatus, { candidateId: '$recordId' })
//     wiredStatus(result) {
//         this._wiredStatusResult = result;

//         if (result.data) {
//             // FIXED: Create new object instead of modifying wired result
//             const processedResults = result.data.results.map(res => {
//                 let outcomeClass = 'slds-badge';
//                 let rowClass = '';

//                 switch (res.outcome) {
//                     case 'Pass':
//                         outcomeClass += ' slds-badge_lightest slds-theme_success';
//                         break;
//                     case 'Fail':
//                         outcomeClass += ' slds-badge_lightest slds-theme_error';
//                         rowClass = 'slds-hint-parent';
//                         break;
//                     case 'Review':
//                         outcomeClass += ' slds-badge_lightest slds-theme_warning';
//                         break;
//                     default:
//                         break;
//                 }

//                 return { ...res, outcomeClass, rowClass };
//             });

//             // FIXED: Assign to tracked property
//             this.data = { 
//                 ...result.data, 
//                 results: processedResults 
//             };
//             this.error = undefined;
//         } else if (result.error) {
//             this.error = result.error;
//             this.data = undefined;
//         }
//     }

//     async handleRerun() {
//         this.isRunning = true;
//         this._showToast('In Progress', 'Re-running screening...', 'info');

//         try {
//             await rerunScreening({ candidateId: this.recordId });
            
//             // Refresh the wired data
//             await this.handleRefresh();
            
//             this._showToast('Success', 'Screening process started', 'success');
//         } catch (error) {
//             console.error('Error rerunning screening:', error);
//             this._showToast('Error', 'Failed to start screening: ' + this._extractError(error), 'error');
//         } finally {
//             this.isRunning = false;
//         }
//     }

//     async handleRefresh() {
//         try {
//             await refreshApex(this._wiredStatusResult);
//         } catch (error) {
//             console.error('Error refreshing data:', error);
//         }
//     }

//     get hasResults() {
//         return this.data && this.data.results && this.data.results.length > 0;
//     }

//     get hasOverrides() {
//         return this.data && this.data.overrides && this.data.overrides.length > 0;
//     }

//     get statusBadgeClass() {
//         if (!this.data) return 'slds-badge';
//         switch (this.data.status) {
//             case 'Passed':
//                 return 'slds-badge slds-theme_success';
//             case 'Failed':
//                 return 'slds-badge slds-theme_error';
//             case 'Manual Review':
//                 return 'slds-badge slds-theme_warning';
//             default:
//                 return 'slds-badge';
//         }
//     }

//     _showToast(title, message, variant) {
//         this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
//     }

//     _extractError(error) {
//         if (error && error.body && error.body.message) {
//             return error.body.message;
//         }
//         return 'An unknown error occurred';
//     }
// }
// candidateScreenStatus.js - UPDATED WITH JOB TITLE FIX AND CONFIDENCE TOOLTIP
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Traditional screening
import getCandidateStatus from '@salesforce/apex/CandidateStatusController.getCandidateStatus';
import rerunScreening from '@salesforce/apex/CandidateStatusController.rerunScreening';

// AI screening
import runAIScreeningForCandidate from '@salesforce/apex/AIScreeningController.runAIScreeningForCandidate';
import getLatestAIResult from '@salesforce/apex/AIScreeningController.getLatestAIResult';

export default class CandidateScreenStatus extends LightningElement {
    @api recordId;
    
    @track isRunning = false;
    @track isAIRunning = false;
    @track error;
    @track dataLoaded = false;
    @track activeTab = 'rules'; // Default to rules tab
    @track lastScreeningDate = null;
    
    // Traditional screening data
    @track candidateName = '';
    @track jobTitle = '';
    @track traditionalScore = 0;
    @track traditionalStatus = 'Not Screened';
    @track totalRules = 0;
    @track rulesPassed = 0;
    @track rulesFailed = 0;
    @track rulesReview = 0;
    @track ruleResults = [];
    @track routingInfo = null;
    
    // AI screening data
    @track aiResult = null;
    @track aiScore = 0;
    @track aiRecommendation = '';
    @track aiConfidence = '';
    @track aiQuickSummary = '';
    @track aiFullAnalysis = '';
    @track aiStrengths = [];
    @track aiConcerns = [];
    
    @track showConfidenceModal = false; // 🔥 NEW: Modal state
    
    _wiredStatusResult;
    _wiredAIResult;

    // Wire traditional screening data
    @wire(getCandidateStatus, { candidateId: '$recordId' })
    wiredStatus(result) {
        this._wiredStatusResult = result;
        
        if (result.data) {
            const data = result.data;
            
            this.candidateName = data.name || '';
            this.jobTitle = data.jobTitle || 'Not Assigned'; // 🔥 FIX: Get actual job title from data
            this.traditionalStatus = data.status || 'Not Screened';
            this.totalRules = data.totalRules || 0;
            this.rulesPassed = data.rulesPassed || 0;
            this.rulesFailed = data.rulesFailed || 0;
            this.rulesReview = data.rulesReview || 0;
            this.lastScreeningDate = data.lastScreeningDate;
            
            // Calculate traditional score
            if (this.totalRules > 0) {
                this.traditionalScore = Math.round((this.rulesPassed / this.totalRules) * 100);
            }
            
            // Process rule results with ACTION BADGE CLASSES
            if (data.results) {
                this.ruleResults = data.results.map(res => {
                    // Determine row class for visual emphasis
                    let rowClass = '';
                    if (res.outcome === 'Fail') {
                        rowClass = 'result-row-fail';
                    } else if (res.outcome === 'Review') {
                        rowClass = 'result-row-review';
                    }
                    
                    // 🔥 FIX: Determine action badge styling
                    let actionBadgeClass = 'action-badge ';
                    let actionLabel = res.action || '';
                    
                    if (res.action) {
                        const actionLower = res.action.toLowerCase();
                        
                        if (actionLower.includes('reject')) {
                            actionBadgeClass += 'action-badge-reject';
                            actionLabel = 'Auto Reject';
                        } else if (actionLower.includes('review') || actionLower.includes('flag')) {
                            actionBadgeClass += 'action-badge-review';
                            actionLabel = 'Flag For Review';
                        } else if (actionLower.includes('approve')) {
                            actionBadgeClass += 'action-badge-approve';
                            actionLabel = 'Approve';
                        } else if (actionLower.includes('route')) {
                            actionBadgeClass += 'action-badge-route';
                            actionLabel = 'Route to Queue';
                        } else {
                            actionBadgeClass += 'action-badge-default';
                            // Format CamelCase to readable text
                            actionLabel = res.action.replace(/([A-Z])/g, ' $1').trim();
                        }
                    }
                    
                    return {
                        ...res,
                        rowClass: rowClass,
                        outcomeClass: this.getOutcomeBadgeClass(res.outcome),
                        actionBadgeClass: actionBadgeClass,
                        actionLabel: actionLabel
                    };
                });
            }
            
            // Routing info
            if (data.routingInfo) {
                this.routingInfo = {
                    path: data.routingInfo.journeyPath,
                    queue: data.routingInfo.queue,
                    level: data.routingInfo.escalationLevel
                };
            }
            
            this.dataLoaded = true;
            this.error = undefined;
            
        } else if (result.error) {
            this.error = result.error;
            this.dataLoaded = false;
        }
    }

    // Wire AI screening data
    @wire(getLatestAIResult, { candidateId: '$recordId' })
    wiredAIResult(result) {
        this._wiredAIResult = result;
        
        if (result.data) {
            this.aiResult = result.data;
            this.processAIData(result.data);
        } else if (result.error) {
            console.error('Error loading AI result:', result.error);
            this.aiResult = null;
        }
    }

    // Process AI data
    processAIData(data) {
        this.aiScore = Math.round(data.Overall_Score__c || 0);
        this.aiRecommendation = data.Recommendation__c || '';
        this.aiConfidence = data.Confidence_Level__c || '';
        this.aiQuickSummary = data.Quick_Summary__c || '';
        this.aiFullAnalysis = data.Full_Analysis__c || '';
        
        // Parse strengths
        try {
            const strengthsArray = JSON.parse(data.Strengths__c || '[]');
            this.aiStrengths = strengthsArray.slice(0, 5); // Top 5
        } catch (e) {
            this.aiStrengths = [];
        }
        
        // Parse concerns
        try {
            const concernsArray = JSON.parse(data.Concerns__c || '[]');
            this.aiConcerns = concernsArray.slice(0, 5); // Top 5
        } catch (e) {
            this.aiConcerns = [];
        }
    }

    // Run traditional screening
    async handleRerun() {
        this.isRunning = true;
        this.showToast('In Progress', 'Re-running screening...', 'info');

        try {
            await rerunScreening({ candidateId: this.recordId });
            await this.handleRefresh();
            this.showToast('Success', 'Screening process started', 'success');
        } catch (error) {
            console.error('Error rerunning screening:', error);
            this.showToast('Error', 'Failed to start screening: ' + this.extractError(error), 'error');
        } finally {
            this.isRunning = false;
        }
    }

    // Run AI screening
    async handleRunAIScreening() {
        this.isAIRunning = true;
        this.showToast('AI Analysis', 'Running AI-powered screening...', 'info');

        try {
            const result = await runAIScreeningForCandidate({ candidateId: this.recordId });
            
            if (result.success) {
                this.showToast('Success', 'AI screening completed', 'success');
                
                // Refresh both data sources
                await Promise.all([
                    refreshApex(this._wiredAIResult),
                    this.handleRefresh()
                ]);
                
                // Switch to AI tab
                this.activeTab = 'ai';
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error running AI screening:', error);
            this.showToast('Error', 'AI screening failed: ' + this.extractError(error), 'error');
        } finally {
            this.isAIRunning = false;
        }
    }

    // Refresh all data
    async handleRefresh() {
        try {
            await Promise.all([
                refreshApex(this._wiredStatusResult),
                refreshApex(this._wiredAIResult)
            ]);
            this.showToast('Success', 'Data refreshed', 'success');
        } catch (error) {
            console.error('Error refreshing data:', error);
        }
    }

    // Tab change handler
    handleTabChange(event) {
        this.activeTab = event.target.value;
    }
    
    // 🔥 NEW: Confidence info modal handlers
    handleShowConfidenceInfo(event) {
        event.preventDefault();
        this.showConfidenceModal = true;
    }
    
    handleCloseConfidenceInfo() {
        this.showConfidenceModal = false;
    }

    // Computed properties
    get hasAIResult() {
        return this.aiResult !== null;
    }

    get hasRuleResults() {
        return this.ruleResults && this.ruleResults.length > 0;
    }

    get hasRouting() {
        return this.routingInfo !== null;
    }

    get routingPath() {
        return this.routingInfo ? this.routingInfo.path : '';
    }

    get routingQueue() {
        return this.routingInfo ? this.routingInfo.queue : '';
    }

    get routingLevel() {
        return this.routingInfo ? this.routingInfo.level : '';
    }
    
    get traditionalBadgeClass() {
        if (this.traditionalScore >= 80) return 'slds-badge slds-theme_success score-badge-excellent';
        if (this.traditionalScore >= 60) return 'slds-badge slds-theme_warning score-badge-good';
        if (this.traditionalScore >= 40) return 'slds-badge slds-theme_warning score-badge-fair';
        return 'slds-badge slds-theme_error score-badge-poor';
    }

    get aiRecommendationBadgeClass() {
        const rec = this.aiRecommendation;
        if (rec === 'STRONGLY_RECOMMEND') {
            return 'slds-badge ai-badge-strong-recommend';
        }
        if (rec === 'RECOMMEND') {
            return 'slds-badge ai-badge-recommend';
        }
        if (rec === 'NEUTRAL') {
            return 'slds-badge ai-badge-neutral';
        }
        if (rec === 'NOT_RECOMMEND') {
            return 'slds-badge ai-badge-not-recommend';
        }
        if (rec === 'STRONGLY_NOT_RECOMMEND') {
            return 'slds-badge ai-badge-reject';
        }
        return 'slds-badge';
    }

    get aiRecommendationLabel() {
        const labels = {
            'STRONGLY_RECOMMEND': 'STRONG RECOMMEND',
            'RECOMMEND': 'RECOMMEND',
            'NEUTRAL': 'NEUTRAL',
            'NOT_RECOMMEND': 'NOT RECOMMEND',
            'STRONGLY_NOT_RECOMMEND': 'STRONGLY NOT RECOMMEND'
        };
        return labels[this.aiRecommendation] || this.aiRecommendation;
    }
    
    // Helper methods
    getOutcomeBadgeClass(outcome) {
        const classes = {
            'Pass': 'outcome-badge outcome-badge-pass',
            'Fail': 'outcome-badge outcome-badge-fail',
            'Review': 'outcome-badge outcome-badge-review'
        };
        return classes[outcome] || 'slds-badge';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'An unknown error occurred';
    }
}