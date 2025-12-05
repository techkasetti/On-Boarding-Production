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

  // computed property used by template to avoid inline operators
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

      // parsedJson may be object or string; store pretty string for display if present
      if (data.parsedJson) {
        try {
          const pj = (typeof data.parsedJson === 'string') ? JSON.parse(data.parsedJson) : data.parsedJson;
          this.parsedJson = JSON.stringify(pj, null, 2);
        } catch (e) {
          // if parsing fails, show raw string
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
      const data = (typeof res === 'string') ? JSON.parse(res) : res;

      this.screeningResults = Array.isArray(data.results) ? data.results : [];
      this.routingInfo = data.routing || null;
      this.candidateStatus = data.status || this.candidateStatus;

      this.showToast('Success','Screening re-run completed.','success');
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
    // data-* attributes arrive as strings; LWC converts them to strings.
    // We stored r.details directly; if it's an object, stringify it safely.
    let payload = event.currentTarget.dataset.payload;
    try {
      // If payload is already JSON string (serialized), pretty print it
      if (typeof payload === 'string') {
        // Attempt to parse to format nicely - if parse fails, use raw string
        try {
          const parsed = JSON.parse(payload);
          payload = JSON.stringify(parsed, null, 2);
        } catch (e) {
          // keep payload as-is (string)
        }
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
