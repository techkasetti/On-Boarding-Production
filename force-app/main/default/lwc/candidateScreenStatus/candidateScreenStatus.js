// // candidateScreenStatus.js
// import { LightningElement, api, track } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// import getCandidateStatus from '@salesforce/apex/ScreeningController.getCandidateStatus';
// import runEvaluation from '@salesforce/apex/ScreeningController.runEvaluation';
// import getEvaluationResults from '@salesforce/apex/EvaluateScreeningRules.getEvaluationResults'; // optional, used if you enable it

// export default class CandidateScreenStatus extends LightningElement {
//   @api recordId; // Candidate__c record id from record page
//   @track isLoading = true;
//   @track isRunning = false;
//   @track parsedJson = null;
//   @track screeningResults = [];
//   @track routingInfo = null;
//   @track candidateName = '';
//   @track candidateStatus = '';

//   connectedCallback() {
//     if (!this.recordId) {
//       this.isLoading = false;
//       this.showToast('Error','Component must be placed on Candidate record page and recordId provided.','error');
//       return;
//     }
//     this.loadStatus();
//   }

//   // computed property used by template to avoid inline operators
//   get hasResults() {
//     return Array.isArray(this.screeningResults) && this.screeningResults.length > 0;
//   }

//   // Load the candidate status (used for initial load and refresh)
//   async loadStatus() {
//     this.isLoading = true;
//     try {
//       const resp = await getCandidateStatus({ candidateId: this.recordId });
//       // getCandidateStatus may return an object or a JSON-string
//       const data = (typeof resp === 'string') ? JSON.parse(resp) : resp;

//       this.candidateName = data.name || 'Candidate';
//       this.candidateStatus = data.status || 'Unknown';

//       // parsedJson may be object or string; store pretty string for display if present
//       if (data.parsedJson) {
//         try {
//           const pj = (typeof data.parsedJson === 'string') ? JSON.parse(data.parsedJson) : data.parsedJson;
//           this.parsedJson = JSON.stringify(pj, null, 2);
//         } catch (e) {
//           // fallback: show raw
//           this.parsedJson = typeof data.parsedJson === 'string' ? data.parsedJson : JSON.stringify(data.parsedJson);
//         }
//       } else {
//         this.parsedJson = null;
//       }

//       // Results could already be structured (list of objects)
//       // Or some DTOs may return results as string, try to normalize
//       let results = [];
//       if (Array.isArray(data.results)) {
//         results = data.results;
//       } else if (data.results && typeof data.results === 'string') {
//         try {
//           results = JSON.parse(data.results);
//         } catch (e) {
//           // if it's not JSON, ignore
//           results = [];
//         }
//       }

//       // Deduplicate and normalize the results for display
//       this.screeningResults = this._normalizeAndDedupeResults(results);

//       // routing map
//       this.routingInfo = data.routing || null;
//     } catch (err) {
//       this.showToast('Error','Failed to load candidate status: ' + this._extractError(err),'error');
//       this.screeningResults = [];
//       this.routingInfo = null;
//     } finally {
//       this.isLoading = false;
//     }
//   }

//   // Re-run screening (ad-hoc). We must parse the return shape of runEvaluation properly.
//   async handleRerun() {
//     this.isRunning = true;
//     this.showToast('Info','Re-running screening (background)...','info');
//     try {
//       const res = await runEvaluation({ candidateId: this.recordId });

//       // runEvaluation returns JSON-stringified list of Response objects (per your Apex)
//       // Example: [ { candidateId: '...', correlationId:'..', status:'OK', resultsJson: "[{...},{...}]" } ]
//       let parsed = null;
//       if (typeof res === 'string') {
//         try {
//           parsed = JSON.parse(res);
//         } catch (e) {
//           parsed = res;
//         }
//       } else {
//         parsed = res;
//       }

//       // Get the first response (we called runEvaluation for a single candidate, so first element)
//       let resultsArr = [];
//       if (Array.isArray(parsed) && parsed.length > 0) {
//         const first = parsed[0];
//         // results may be inside first.resultsJson as a string
//         if (first.resultsJson) {
//           try {
//             resultsArr = JSON.parse(first.resultsJson);
//           } catch (e) {
//             // maybe resultsJson is already an array/object
//             resultsArr = Array.isArray(first.resultsJson) ? first.resultsJson : [];
//           }
//         } else if (first.results) {
//           resultsArr = Array.isArray(first.results) ? first.results : [];
//         }
//       } else if (Array.isArray(parsed)) {
//         // fallback
//         resultsArr = parsed;
//       } else if (parsed && parsed.results) {
//         resultsArr = Array.isArray(parsed.results) ? parsed.results : [];
//       }

//       // normalize shape & dedupe
//       this.screeningResults = this._normalizeAndDedupeResults(resultsArr);

//       // routing and status are not part of runEvaluation's Response by default; keep existing routing if not present
//       // If your runEvaluation starts returning routing/status, handle it here (example below)
//       if (Array.isArray(parsed) && parsed.length > 0 && parsed[0].status) {
//         this.candidateStatus = parsed[0].status;
//       }

//       this.showToast('Success','Screening re-run completed.','success');
//     } catch (err) {
//       this.showToast('Error','Re-run failed: ' + this._extractError(err),'error');
//     } finally {
//       this.isRunning = false;
//     }
//   }

//   // Simply reload using the same getCandidateStatus path
//   handleRefresh() {
//     this.loadStatus();
//   }

//   // Helper to safely show rule details
//   openDetails(event) {
//     let payload = event.currentTarget.dataset.payload;
//     try {
//       if (typeof payload === 'string') {
//         try {
//           const parsed = JSON.parse(payload);
//           payload = JSON.stringify(parsed, null, 2);
//         } catch (e) {
//           // keep payload as-is
//         }
//       } else if (typeof payload === 'object') {
//         payload = JSON.stringify(payload, null, 2);
//       } else {
//         payload = String(payload);
//       }
//     } catch (e) {
//       payload = String(event.currentTarget.dataset.payload);
//     }
//     this.showToast('Rule Details', payload || 'No details', 'info');
//   }

//   // Normalize results returned from Apex into UI-friendly objects and dedupe by ruleKey:
//   // Keeps LAST occurrence of ruleKey (assumes more recent results appear later in the array).
//   _normalizeAndDedupeResults(resultsArr) {
//     if (!Array.isArray(resultsArr)) return [];

//     // Normalize each result object: possible different field names / types
//     const normalized = resultsArr.map(r => {
//       // r might be stringified - parse if necessary
//       let item = r;
//       if (typeof r === 'string') {
//         try { item = JSON.parse(r); } catch (e) { item = { details: r }; }
//       }

//       // Standard fields expected: ruleKey, action, outcome, score, details, jurisdiction
//       const out = {
//         ruleKey: item.ruleKey || item.RuleKey || item.Rule_Key__c || item.rule || 'UNKNOWN',
//         action: item.action || item.Action || item.actionType || '',
//         outcome: item.outcome || item.Outcome || (item.score != null ? (item.score > 0 ? 'Pass' : 'Fail') : ''),
//         score: (item.score !== undefined && item.score !== null) ? Number(item.score) : (item.Score || 0),
//         details: item.details || item.Details || item.Event_Payload || '',
//         jurisdiction: item.jurisdiction || item.Jurisdiction || item.jur || null
//       };
//       return out;
//     });

//     // Deduplicate by ruleKey keeping last occurrence:
//     const byKey = new Map();
//     for (let i = 0; i < normalized.length; i++) {
//       const it = normalized[i];
//       // overwrite previous so last one remains
//       byKey.set(it.ruleKey, it);
//     }

//     // Return array in the same "logical" order as the original but only with unique keys:
//     // We'll preserve insertion order of the Map which corresponds to the last appearance order,
//     // but it's often more useful to display rules in priority-like order — keep this simple for now.
//     const deduped = Array.from(byKey.values());

//     // Optionally: sort so Fails appear first (comment out if you prefer original order)
//     // deduped.sort((a,b) => {
//     //   if (a.outcome === b.outcome) return 0;
//     //   if (a.outcome === 'Fail') return -1;
//     //   return 1;
//     // });

//     return deduped;
//   }

//   _extractError(err) {
//     try {
//       if (err && err.body && err.body.message) return err.body.message;
//       if (err && err.message) return err.message;
//       return JSON.stringify(err);
//     } catch (e) {
//       return 'Unknown error';
//     }
//   }

//   showToast(title, msg, variant='info') {
//     const evt = new ShowToastEvent({ title, message: msg, variant, mode: 'dismissable' });
//     this.dispatchEvent(evt);
//   }
// }
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getCandidateStatus from '@salesforce/apex/ScreeningController.getCandidateStatus';
import runEvaluation from '@salesforce/apex/ScreeningController.runEvaluation';

export default class CandidateScreenStatus extends LightningElement {
  @api recordId; // Candidate__c record id from record page
  @track isLoading = true;
  @track isRunning = false;
  @track parsedJson = null;
  @track screeningResults = [];
  @track routingInfo = null;
  @track candidateName = '';
  @track candidateStatus = '';

  connectedCallback() {
    if (!this.recordId) {
      this.isLoading = false;
      this.showToast('Error','Component must be placed on Candidate record page and recordId provided.','error');
      return;
    }
    this.loadStatus();
  }

  get hasResults() {
    return Array.isArray(this.screeningResults) && this.screeningResults.length > 0;
  }

  async loadStatus() {
    this.isLoading = true;
    try {
      const resp = await getCandidateStatus({ candidateId: this.recordId });
      const data = (typeof resp === 'string') ? JSON.parse(resp) : resp;

      this.candidateName = data.name || 'Candidate';
      this.candidateStatus = data.status || 'Unknown';

      if (data.parsedJson) {
        try {
          const pj = (typeof data.parsedJson === 'string') ? JSON.parse(data.parsedJson) : data.parsedJson;
          this.parsedJson = JSON.stringify(pj, null, 2);
        } catch (e) {
          this.parsedJson = typeof data.parsedJson === 'string' ? data.parsedJson : JSON.stringify(data.parsedJson);
        }
      } else {
        this.parsedJson = null;
      }

      this.screeningResults = Array.isArray(data.results) ? data.results : [];
      this.routingInfo = data.routing || null;
    } catch (err) {
      this.showToast('Error','Failed to load candidate status: ' + this._extractError(err),'error');
      this.screeningResults = [];
      this.routingInfo = null;
    } finally {
      this.isLoading = false;
    }
  }

  async handleRerun() {
    this.isRunning = true;
    this.showToast('Info','Re-running screening (background)...','info');
    try {
      const res = await runEvaluation({ candidateId: this.recordId });
      // runEvaluation returns a serialized JSON string (List<Response]); check for SKIPPED
      let parsed;
      if (typeof res === 'string') {
        try {
          parsed = JSON.parse(res);
        } catch (e) { parsed = res; }
      } else {
        parsed = res;
      }

      let first = Array.isArray(parsed) && parsed.length > 0 ? parsed[0] : parsed;
      if (first && first.status === 'SKIPPED') {
        this.showToast('Info', 'Evaluation skipped: no parsed resume data provided.', 'warning');
        // do not update UI results (keep existing)
      } else {
        // parsed is the serialized Response array; but client expected data.results/routing - so parse the resultsJson field
        let resultsForUI = [];
        if (Array.isArray(parsed) && parsed.length > 0 && parsed[0].resultsJson) {
          try {
            resultsForUI = JSON.parse(parsed[0].resultsJson);
          } catch (e) {
            resultsForUI = [];
          }
        }
        // Update the UI with structured results if available; else reload status
        if (resultsForUI.length > 0) {
          this.screeningResults = resultsForUI;
          this.showToast('Success','Screening re-run completed.','success');
        } else {
          // fallback - reload full status
          await this.loadStatus();
          this.showToast('Success','Screening re-run completed.','success');
        }
      }
    } catch (err) {
      this.showToast('Error','Re-run failed: ' + this._extractError(err),'error');
    } finally {
      this.isRunning = false;
    }
  }

  handleRefresh() {
    this.loadStatus();
  }

  openDetails(event) {
    let payload = event.currentTarget.dataset.payload;
    try {
      if (typeof payload === 'string') {
        try {
          const parsed = JSON.parse(payload);
          payload = JSON.stringify(parsed, null, 2);
        } catch (e) {}
      } else if (typeof payload === 'object') {
        payload = JSON.stringify(payload, null, 2);
      } else {
        payload = String(payload);
      }
    } catch (e) {
      payload = String(event.currentTarget.dataset.payload);
    }

    this.showToast('Rule Details', payload || 'No details', 'info');
  }

  _extractError(err) {
    try {
      if (err && err.body && err.body.message) return err.body.message;
      if (err && err.message) return err.message;
      return JSON.stringify(err);
    } catch (e) {
      return 'Unknown error';
    }
  }

  showToast(title, msg, variant='info') {
    const evt = new ShowToastEvent({ title, message: msg, variant, mode: 'dismissable' });
    this.dispatchEvent(evt);
  }
}
