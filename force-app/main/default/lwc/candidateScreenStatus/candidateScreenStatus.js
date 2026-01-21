
// // candidateScreenStatus.js - UPDATED WITH JOB TITLE FIX AND CONFIDENCE TOOLTIP
// import { LightningElement, api, wire, track } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// import { refreshApex } from '@salesforce/apex';

// // Traditional screening
// import getCandidateStatus from '@salesforce/apex/CandidateStatusController.getCandidateStatus';
// import rerunScreening from '@salesforce/apex/CandidateStatusController.rerunScreening';

// // AI screening
// import runAIScreeningForCandidate from '@salesforce/apex/AIScreeningController.runAIScreeningForCandidate';
// import getLatestAIResult from '@salesforce/apex/AIScreeningController.getLatestAIResult';

// export default class CandidateScreenStatus extends LightningElement {
//     @api recordId;
    
//     @track isRunning = false;
//     @track isAIRunning = false;
//     @track error;
//     @track dataLoaded = false;
//     @track activeTab = 'rules'; // Default to rules tab
//     @track lastScreeningDate = null;
    
//     // Traditional screening data
//     @track candidateName = '';
//     @track jobTitle = '';
//     @track traditionalScore = 0;
//     @track traditionalStatus = 'Not Screened';
//     @track totalRules = 0;
//     @track rulesPassed = 0;
//     @track rulesFailed = 0;
//     @track rulesReview = 0;
//     @track ruleResults = [];
//     @track routingInfo = null;
    
//     // AI screening data
//     @track aiResult = null;
//     @track aiScore = 0;
//     @track aiRecommendation = '';
//     @track aiConfidence = '';
//     @track aiQuickSummary = '';
//     @track aiFullAnalysis = '';
//     @track aiStrengths = [];
//     @track aiConcerns = [];
    
//     @track showConfidenceModal = false; // 🔥 NEW: Modal state
    
//     _wiredStatusResult;
//     _wiredAIResult;

//     // Wire traditional screening data
//     @wire(getCandidateStatus, { candidateId: '$recordId' })
//     wiredStatus(result) {
//         this._wiredStatusResult = result;
        
//         if (result.data) {
//             const data = result.data;
            
//             this.candidateName = data.name || '';
//             this.jobTitle = data.jobTitle || 'Not Assigned'; // 🔥 FIX: Get actual job title from data
//             this.traditionalStatus = data.status || 'Not Screened';
//             this.totalRules = data.totalRules || 0;
//             this.rulesPassed = data.rulesPassed || 0;
//             this.rulesFailed = data.rulesFailed || 0;
//             this.rulesReview = data.rulesReview || 0;
//             this.lastScreeningDate = data.lastScreeningDate;
            
//             // Calculate traditional score
//             if (this.totalRules > 0) {
//                 this.traditionalScore = Math.round((this.rulesPassed / this.totalRules) * 100);
//             }
            
//             // Process rule results with ACTION BADGE CLASSES
//             if (data.results) {
//                 this.ruleResults = data.results.map(res => {
//                     // Determine row class for visual emphasis
//                     let rowClass = '';
//                     if (res.outcome === 'Fail') {
//                         rowClass = 'result-row-fail';
//                     } else if (res.outcome === 'Review') {
//                         rowClass = 'result-row-review';
//                     }
                    
//                     // 🔥 FIX: Determine action badge styling
//                     let actionBadgeClass = 'action-badge ';
//                     let actionLabel = res.action || '';
                    
//                     if (res.action) {
//                         const actionLower = res.action.toLowerCase();
                        
//                         if (actionLower.includes('reject')) {
//                             actionBadgeClass += 'action-badge-reject';
//                             actionLabel = 'Auto Reject';
//                         } else if (actionLower.includes('review') || actionLower.includes('flag')) {
//                             actionBadgeClass += 'action-badge-review';
//                             actionLabel = 'Flag For Review';
//                         } else if (actionLower.includes('approve')) {
//                             actionBadgeClass += 'action-badge-approve';
//                             actionLabel = 'Approve';
//                         } else if (actionLower.includes('route')) {
//                             actionBadgeClass += 'action-badge-route';
//                             actionLabel = 'Route to Queue';
//                         } else {
//                             actionBadgeClass += 'action-badge-default';
//                             // Format CamelCase to readable text
//                             actionLabel = res.action.replace(/([A-Z])/g, ' $1').trim();
//                         }
//                     }
                    
//                     return {
//                         ...res,
//                         rowClass: rowClass,
//                         outcomeClass: this.getOutcomeBadgeClass(res.outcome),
//                         actionBadgeClass: actionBadgeClass,
//                         actionLabel: actionLabel
//                     };
//                 });
//             }
            
//             // Routing info
//             if (data.routingInfo) {
//                 this.routingInfo = {
//                     path: data.routingInfo.journeyPath,
//                     queue: data.routingInfo.queue,
//                     level: data.routingInfo.escalationLevel
//                 };
//             }
            
//             this.dataLoaded = true;
//             this.error = undefined;
            
//         } else if (result.error) {
//             this.error = result.error;
//             this.dataLoaded = false;
//         }
//     }

//     // Wire AI screening data
//     @wire(getLatestAIResult, { candidateId: '$recordId' })
//     wiredAIResult(result) {
//         this._wiredAIResult = result;
        
//         if (result.data) {
//             this.aiResult = result.data;
//             this.processAIData(result.data);
//         } else if (result.error) {
//             console.error('Error loading AI result:', result.error);
//             this.aiResult = null;
//         }
//     }

//     // Process AI data
//     processAIData(data) {
//         this.aiScore = Math.round(data.Overall_Score__c || 0);
//         this.aiRecommendation = data.Recommendation__c || '';
//         this.aiConfidence = data.Confidence_Level__c || '';
//         this.aiQuickSummary = data.Quick_Summary__c || '';
//         this.aiFullAnalysis = data.Full_Analysis__c || '';
        
//         // Parse strengths
//         try {
//             const strengthsArray = JSON.parse(data.Strengths__c || '[]');
//             this.aiStrengths = strengthsArray.slice(0, 5); // Top 5
//         } catch (e) {
//             this.aiStrengths = [];
//         }
        
//         // Parse concerns
//         try {
//             const concernsArray = JSON.parse(data.Concerns__c || '[]');
//             this.aiConcerns = concernsArray.slice(0, 5); // Top 5
//         } catch (e) {
//             this.aiConcerns = [];
//         }
//     }

//     // Run traditional screening
//     async handleRerun() {
//         this.isRunning = true;
//         this.showToast('In Progress', 'Re-running screening...', 'info');

//         try {
//             await rerunScreening({ candidateId: this.recordId });
//             await this.handleRefresh();
//             this.showToast('Success', 'Screening process started', 'success');
//         } catch (error) {
//             console.error('Error rerunning screening:', error);
//             this.showToast('Error', 'Failed to start screening: ' + this.extractError(error), 'error');
//         } finally {
//             this.isRunning = false;
//         }
//     }

//     // Run AI screening
//     async handleRunAIScreening() {
//         this.isAIRunning = true;
//         this.showToast('AI Analysis', 'Running AI-powered screening...', 'info');

//         try {
//             const result = await runAIScreeningForCandidate({ candidateId: this.recordId });
            
//             if (result.success) {
//                 this.showToast('Success', 'AI screening completed', 'success');
                
//                 // Refresh both data sources
//                 await Promise.all([
//                     refreshApex(this._wiredAIResult),
//                     this.handleRefresh()
//                 ]);
                
//                 // Switch to AI tab
//                 this.activeTab = 'ai';
//             } else {
//                 this.showToast('Error', result.message, 'error');
//             }
//         } catch (error) {
//             console.error('Error running AI screening:', error);
//             this.showToast('Error', 'AI screening failed: ' + this.extractError(error), 'error');
//         } finally {
//             this.isAIRunning = false;
//         }
//     }

//     // Refresh all data
//     async handleRefresh() {
//         try {
//             await Promise.all([
//                 refreshApex(this._wiredStatusResult),
//                 refreshApex(this._wiredAIResult)
//             ]);
//             this.showToast('Success', 'Data refreshed', 'success');
//         } catch (error) {
//             console.error('Error refreshing data:', error);
//         }
//     }

//     // Tab change handler
//     handleTabChange(event) {
//         this.activeTab = event.target.value;
//     }
    
//     // 🔥 NEW: Confidence info modal handlers
//     handleShowConfidenceInfo(event) {
//         event.preventDefault();
//         this.showConfidenceModal = true;
//     }
    
//     handleCloseConfidenceInfo() {
//         this.showConfidenceModal = false;
//     }

//     // Computed properties
//     get hasAIResult() {
//         return this.aiResult !== null;
//     }

//     get hasRuleResults() {
//         return this.ruleResults && this.ruleResults.length > 0;
//     }

//     get hasRouting() {
//         return this.routingInfo !== null;
//     }

//     get routingPath() {
//         return this.routingInfo ? this.routingInfo.path : '';
//     }

//     get routingQueue() {
//         return this.routingInfo ? this.routingInfo.queue : '';
//     }

//     get routingLevel() {
//         return this.routingInfo ? this.routingInfo.level : '';
//     }
    
//     get traditionalBadgeClass() {
//         if (this.traditionalScore >= 80) return 'slds-badge slds-theme_success score-badge-excellent';
//         if (this.traditionalScore >= 60) return 'slds-badge slds-theme_warning score-badge-good';
//         if (this.traditionalScore >= 40) return 'slds-badge slds-theme_warning score-badge-fair';
//         return 'slds-badge slds-theme_error score-badge-poor';
//     }

//     get aiRecommendationBadgeClass() {
//         const rec = this.aiRecommendation;
//         if (rec === 'STRONGLY_RECOMMEND') {
//             return 'slds-badge ai-badge-strong-recommend';
//         }
//         if (rec === 'RECOMMEND') {
//             return 'slds-badge ai-badge-recommend';
//         }
//         if (rec === 'NEUTRAL') {
//             return 'slds-badge ai-badge-neutral';
//         }
//         if (rec === 'NOT_RECOMMEND') {
//             return 'slds-badge ai-badge-not-recommend';
//         }
//         if (rec === 'STRONGLY_NOT_RECOMMEND') {
//             return 'slds-badge ai-badge-reject';
//         }
//         return 'slds-badge';
//     }

//     get aiRecommendationLabel() {
//         const labels = {
//             'STRONGLY_RECOMMEND': 'STRONG RECOMMEND',
//             'RECOMMEND': 'RECOMMEND',
//             'NEUTRAL': 'NEUTRAL',
//             'NOT_RECOMMEND': 'NOT RECOMMEND',
//             'STRONGLY_NOT_RECOMMEND': 'STRONGLY NOT RECOMMEND'
//         };
//         return labels[this.aiRecommendation] || this.aiRecommendation;
//     }
    
//     // Helper methods
//     getOutcomeBadgeClass(outcome) {
//         const classes = {
//             'Pass': 'outcome-badge outcome-badge-pass',
//             'Fail': 'outcome-badge outcome-badge-fail',
//             'Review': 'outcome-badge outcome-badge-review'
//         };
//         return classes[outcome] || 'slds-badge';
//     }

//     showToast(title, message, variant) {
//         this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
//     }

//     extractError(error) {
//         if (error && error.body && error.body.message) {
//             return error.body.message;
//         }
//         return 'An unknown error occurred';
//     }
// }
// candidateScreenStatus.js - WITH MANUAL OVERRIDE FUNCTIONALITY
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Traditional screening
import getCandidateStatus from '@salesforce/apex/CandidateStatusController.getCandidateStatus';
import rerunScreening from '@salesforce/apex/CandidateStatusController.rerunScreening';

// AI screening
import runAIScreeningForCandidate from '@salesforce/apex/AIScreeningController.runAIScreeningForCandidate';
import getLatestAIResult from '@salesforce/apex/AIScreeningController.getLatestAIResult';

// 🔥 NEW: Manual Override imports
import createManualOverride from '@salesforce/apex/ScreeningController.createManualOverride';
import getOverridesForCandidate from '@salesforce/apex/ScreeningController.getOverridesForCandidate';

export default class CandidateScreenStatus extends LightningElement {
    @api recordId;
    
    @track isRunning = false;
    @track isAIRunning = false;
    @track error;
    @track dataLoaded = false;
    @track activeTab = 'rules';
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
    
    @track showConfidenceModal = false;
    
    // 🔥 NEW: Manual Override data
    @track showOverrideModal = false;
    @track isSubmittingOverride = false;
    @track overrideableRules = [];
    @track existingOverrides = [];
    @track selectedOverrideRule = {};
    @track overrideForm = {
        newOutcome: '',
        overrideType: '',
        overrideReason: ''
    };
    
    _wiredStatusResult;
    _wiredAIResult;
    _allScreeningResults = []; // Store ALL results for override processing

    // Wire traditional screening data
    @wire(getCandidateStatus, { candidateId: '$recordId' })
    wiredStatus(result) {
        this._wiredStatusResult = result;
        
        if (result.data) {
            const data = result.data;
            
            this.candidateName = data.name || '';
            this.jobTitle = data.jobTitle || 'Not Assigned';
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
            
            // Process rule results
            if (data.results) {
                this._allScreeningResults = data.results; // Store for override processing
                
                this.ruleResults = data.results.map(res => {
                    let rowClass = '';
                    if (res.outcome === 'Fail') {
                        rowClass = 'result-row-fail';
                    } else if (res.outcome === 'Review') {
                        rowClass = 'result-row-review';
                    }
                    
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
                
                // 🔥 NEW: Process overrideable rules
                this.processOverrideableRules(data.results);
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
            
            // Load existing overrides
            this.loadExistingOverrides();
            
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

    // 🔥 NEW: Load existing overrides
    async loadExistingOverrides() {
        try {
            const overrides = await getOverridesForCandidate({ candidateId: this.recordId });
            
            this.existingOverrides = overrides.map(ov => {
                return {
                    overrideId: ov.overrideId,
                    ruleName: ov.ruleName,
                    originalOutcome: ov.originalOutcome,
                    newOutcome: ov.newOutcome,
                    reason: ov.overrideReason,
                    approvalStatus: ov.approvalStatus,
                    overrideBy: ov.overrideBy,
                    overrideDate: ov.overrideDate,
                    originalOutcomeClass: this.getOutcomeBadgeClass(ov.originalOutcome),
                    newOutcomeClass: this.getOutcomeBadgeClass(ov.newOutcome),
                    statusBadgeClass: this.getApprovalStatusClass(ov.approvalStatus)
                };
            });
        } catch (error) {
            console.error('Error loading overrides:', error);
        }
    }

   
processOverrideableRules(results) {
    // Filter rules that:
    // 1. Are Fail or Review
    // 2. Have Allow_Manual_Override__c = true
    // 3. Have not already been overridden
    
    this.overrideableRules = results
        .filter(res => {
            // ✅ CRITICAL FIX: Check if rule allows manual override
            return (res.outcome === 'Fail' || res.outcome === 'Review') 
                   && res.allowManualOverride === true  // ✅ NEW CONDITION
                   && !res.overrideApplied;  // Don't show already overridden rules
        })
        .map(res => {
            const cardClass = res.outcome === 'Fail' 
                ? 'override-card override-card-fail' 
                : 'override-card override-card-review';
            
            return {
                resultId: res.resultId || null,
                ruleId: res.ruleId || null,
                ruleName: res.ruleName,
                category: res.ruleCategory,
                outcome: res.outcome,
                details: res.details,
                outcomeClass: this.getOutcomeBadgeClass(res.outcome),
                cardClass: cardClass,
                buttonLabel: 'Override Result',
                alreadyOverridden: false,
                allowManualOverride: res.allowManualOverride, // Store for reference
                _rawData: res
            };
        });
    
    console.log('Overrideable rules (Allow_Manual_Override__c = true):', this.overrideableRules.length);
}
    // Process AI data
    processAIData(data) {
        this.aiScore = Math.round(data.Overall_Score__c || 0);
        this.aiRecommendation = data.Recommendation__c || '';
        this.aiConfidence = data.Confidence_Level__c || '';
        this.aiQuickSummary = data.Quick_Summary__c || '';
        this.aiFullAnalysis = data.Full_Analysis__c || '';
        
        try {
            const strengthsArray = JSON.parse(data.Strengths__c || '[]');
            this.aiStrengths = strengthsArray.slice(0, 5);
        } catch (e) {
            this.aiStrengths = [];
        }
        
        try {
            const concernsArray = JSON.parse(data.Concerns__c || '[]');
            this.aiConcerns = concernsArray.slice(0, 5);
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
                
                await Promise.all([
                    refreshApex(this._wiredAIResult),
                    this.handleRefresh()
                ]);
                
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
    
    // 🔥 NEW: Override Modal Handlers
    handleOpenOverrideModal(event) {
        const resultId = event.currentTarget.dataset.resultId;
        const ruleId = event.currentTarget.dataset.ruleId;
        const ruleName = event.currentTarget.dataset.ruleName;
        const outcome = event.currentTarget.dataset.outcome;
        
        console.log('Opening override modal with:', { resultId, ruleId, ruleName, outcome });
        
        this.selectedOverrideRule = {
            resultId: resultId,
            ruleId: ruleId,
            ruleName: ruleName,
            currentOutcome: outcome,
            currentOutcomeClass: this.getOutcomeBadgeClass(outcome)
        };
        
        // Reset form
        this.overrideForm = {
            newOutcome: '',
            overrideType: '',
            overrideReason: ''
        };
        
        this.showOverrideModal = true;
    }
    
    handleCloseOverrideModal() {
        this.showOverrideModal = false;
        this.selectedOverrideRule = {};
        this.overrideForm = {
            newOutcome: '',
            overrideType: '',
            overrideReason: ''
        };
    }
    
    handleOverrideFormChange(event) {
        const field = event.target.name;
        const value = event.detail.value;
        this.overrideForm = { ...this.overrideForm, [field]: value };
    }
    
    async handleSubmitOverride() {
        // Validation
        if (!this.overrideForm.newOutcome || !this.overrideForm.overrideType || !this.overrideForm.overrideReason) {
            this.showToast('Error', 'Please fill in all required fields', 'error');
            return;
        }
        
        if (this.overrideForm.overrideReason.trim().length < 10) {
            this.showToast('Error', 'Override reason must be at least 10 characters', 'error');
            return;
        }
        
        // Validate that we have a valid rule ID
        if (!this.selectedOverrideRule.ruleId) {
            this.showToast('Error', 'Invalid rule ID. Please refresh and try again.', 'error');
            console.error('Missing ruleId:', this.selectedOverrideRule);
            return;
        }
        
        this.isSubmittingOverride = true;
        
        try {
            console.log('Submitting override with:', {
                candidateId: this.recordId,
                ruleId: this.selectedOverrideRule.ruleId,
                overrideReason: this.overrideForm.overrideReason,
                newOutcome: this.overrideForm.newOutcome,
                overrideType: this.overrideForm.overrideType
            });
            
            await createManualOverride({
                candidateId: this.recordId,
                ruleId: this.selectedOverrideRule.ruleId,
                overrideReason: this.overrideForm.overrideReason,
                newOutcome: this.overrideForm.newOutcome,
                overrideType: this.overrideForm.overrideType
            });
            
            this.showToast('Success', 'Override submitted successfully', 'success');
            this.handleCloseOverrideModal();
            
            // Refresh data
            await this.handleRefresh();
            await this.loadExistingOverrides();
            
        } catch (error) {
            console.error('Error submitting override:', error);
            console.error('Error details:', JSON.stringify(error));
            this.showToast('Error', 'Failed to submit override: ' + this.extractError(error), 'error');
        } finally {
            this.isSubmittingOverride = false;
        }
    }
    
    // Confidence info modal handlers
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
    
    // 🔥 NEW: Override computed properties
    get hasOverrideableRules() {
        return this.overrideableRules && this.overrideableRules.length > 0;
    }
    
    get overrideableRulesCount() {
        return this.overrideableRules ? this.overrideableRules.length : 0;
    }
    
    get hasExistingOverrides() {
        return this.existingOverrides && this.existingOverrides.length > 0;
    }
    
    // 🔥 NEW: Override picklist options
    get outcomeOptions() {
        return [
            { label: 'Pass', value: 'Pass' },
            { label: 'Fail', value: 'Fail' },
            { label: 'Review', value: 'Review' }
        ];
    }
    
    get overrideTypeOptions() {
        return [
            { label: 'Manager Override', value: 'Manager Override' },
            { label: 'Exception', value: 'Exception' },
            { label: 'Data Correction', value: 'Data Correction' },
            { label: 'Other', value: 'Other' }
        ];
    }
    
    get traditionalBadgeClass() {
        if (this.traditionalScore >= 80) return 'slds-badge slds-theme_success score-badge-excellent';
        if (this.traditionalScore >= 60) return 'slds-badge slds-theme_warning score-badge-good';
        if (this.traditionalScore >= 40) return 'slds-badge slds-theme_warning score-badge-fair';
        return 'slds-badge slds-theme_error score-badge-poor';
    }

    get aiRecommendationBadgeClass() {
        const rec = this.aiRecommendation;
        if (rec === 'STRONGLY_RECOMMEND') return 'slds-badge ai-badge-strong-recommend';
        if (rec === 'RECOMMEND') return 'slds-badge ai-badge-recommend';
        if (rec === 'NEUTRAL') return 'slds-badge ai-badge-neutral';
        if (rec === 'NOT_RECOMMEND') return 'slds-badge ai-badge-not-recommend';
        if (rec === 'STRONGLY_NOT_RECOMMEND') return 'slds-badge ai-badge-reject';
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
    
    getApprovalStatusClass(status) {
        const classes = {
            'Pending': 'slds-badge slds-theme_warning',
            'Approved': 'slds-badge slds-theme_success',
            'Rejected': 'slds-badge slds-theme_error'
        };
        return classes[status] || 'slds-badge';
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