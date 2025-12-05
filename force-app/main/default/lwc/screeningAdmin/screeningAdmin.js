import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getRules from '@salesforce/apex/ScreeningController.getRules';
import toggleRuleActive from '@salesforce/apex/ScreeningController.toggleRuleActive';
import runEvaluation from '@salesforce/apex/ScreeningController.runEvaluation';

export default class ScreeningAdmin extends LightningElement {
  @track rules = [];
  @track isLoading = false;
  @track isRunning = false;
  @track testCandidateId = '';
  @track lastResult = null;

  columns = [
    { label: 'Rule Key', fieldName: 'ruleKey', type: 'text', sortable: true },
    { label: 'Priority', fieldName: 'priority', type: 'number' },
    { label: 'Active', fieldName: 'active', type: 'boolean' },
    { label: 'Condition', fieldName: 'condition', type: 'text', cellAttributes: { wrapText: true } },
    { label: 'Action', fieldName: 'action', type: 'text' },
    { label: 'Jurisdiction', fieldName: 'jurisdiction', type: 'text' },
    { label: 'Schema', fieldName: 'schemaVersion', type: 'text' },
    {
      type: 'action',
      typeAttributes: { rowActions: [
        { label: 'Toggle Active', name: 'toggleActive' },
        { label: 'Run Rule (test)', name: 'runRule' }
      ] }
    }
  ];

  connectedCallback() {
    this.loadRules();
  }

  get runDisabled() {
    return this.isRunning || !this.testCandidateId;
  }

  async loadRules() {
    this.isLoading = true;
    try {
      const resp = await getRules();
      // Normalize response: array or JSON string
      if (Array.isArray(resp)) {
        this.rules = resp;
      } else if (typeof resp === 'string') {
        try {
          this.rules = JSON.parse(resp || '[]');
        } catch (e) {
          this.rules = [];
          this.showToast('Warning', 'Unexpected rules payload (not JSON).', 'warning');
        }
      } else {
        this.rules = [];
      }
    } catch (err) {
      this.showToast('Error', 'Failed to load rules: ' + this._extractError(err), 'error');
      this.rules = [];
    } finally {
      this.isLoading = false;
    }
  }

  handleRefresh() {
    this.loadRules();
  }

  onCandidateIdChange(event) {
    this.testCandidateId = event.target.value;
  }

  async onRunAdhoc() {
    if (!this.testCandidateId) {
      this.showToast('Validation', 'Provide Candidate Id to run ad-hoc evaluation.', 'warning');
      return;
    }
    this.isRunning = true;
    this.lastResult = null;
    try {
      const res = await runEvaluation({ candidateId: this.testCandidateId });
      this.lastResult = this._normalizeAndPretty(res);
      this.showToast('Success', 'Ad-hoc evaluation completed.', 'success');
    } catch (err) {
      this.showToast('Error', 'Ad-hoc evaluation failed: ' + this._extractError(err), 'error');
    } finally {
      this.isRunning = false;
    }
  }

  async handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;

    if (actionName === 'toggleActive') {
      const newVal = !row.active;
      try {
        await toggleRuleActive({ ruleKey: row.ruleKey, active: newVal });
        this.showToast('Success', `${row.ruleKey} set to ${newVal ? 'Active' : 'Inactive'}`, 'success');
        // Refresh authoritative state from server
        await this.loadRules();
      } catch (err) {
        this.showToast('Error', 'Failed to toggle: ' + this._extractError(err), 'error');
      }
    } else if (actionName === 'runRule') {
      if (!this.testCandidateId) {
        this.showToast('Validation','Set Candidate Id in the input to test this rule.','warning');
        return;
      }
      this.isRunning = true;
      this.lastResult = null;
      try {
        const res = await runEvaluation({ candidateId: this.testCandidateId, ruleKey: row.ruleKey });
        this.lastResult = this._normalizeAndPretty(res);
        this.showToast('Success', `Rule ${row.ruleKey} evaluated for candidate ${this.testCandidateId}`, 'success');
      } catch (err) {
        this.showToast('Error', 'Rule eval failed: ' + this._extractError(err), 'error');
      } finally {
        this.isRunning = false;
      }
    }
  }

  handleExport() {
    try {
      const dataStr = JSON.stringify(this.rules, null, 2);
      const blob = new Blob([dataStr], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'screening_rules_export.json';
      a.click();
      URL.revokeObjectURL(url);
      this.showToast('Success','Export initiated.','success');
    } catch (err) {
      this.showToast('Error','Export failed: ' + this._extractError(err),'error');
    }
  }

  // Helper: normalize Apex responses (stringified JSON or native object), return pretty string
  _normalizeAndPretty(res) {
    try {
      if (typeof res === 'string') {
        try {
          const parsed = JSON.parse(res);
          return JSON.stringify(parsed, null, 2);
        } catch (e) {
          // not JSON - return raw string
          return res;
        }
      } else {
        return JSON.stringify(res, null, 2);
      }
    } catch (e) {
      return String(res);
    }
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
    const evt = new ShowToastEvent({ title, message: msg, variant });
    this.dispatchEvent(evt);
  }
}
