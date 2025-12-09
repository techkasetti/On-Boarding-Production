import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getRules from '@salesforce/apex/ScreeningController.getRules';
import toggleRuleActive from '@salesforce/apex/ScreeningController.toggleRuleActive';
// Prefer structured method if present
import runEvaluationStructured from '@salesforce/apex/ScreeningController.runEvaluationStructured';
import runEvaluation from '@salesforce/apex/ScreeningController.runEvaluation';

export default class ScreeningAdmin extends LightningElement {
  // reactive properties (no @track needed)
  rules = [];
  isLoading = false;
  isRunning = false;
  testCandidateId = '';
  lastResult = null;

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
      typeAttributes: {
        rowActions: [
          { label: 'Toggle Active', name: 'toggleActive' },
          { label: 'Run Rule (test)', name: 'runRule' }
        ]
      }
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

  /**
   * Callout wrapper:
   * - Try structured endpoint first (returns object with .results array)
   * - If that fails (method missing or error), fall back to legacy runEvaluation which returns serialized string
   */
  async _callRunEvaluation(candidateId, extraParams = {}) {
    // prefer structured call
    try {
      // call structured method if available
      const structuredResp = await runEvaluationStructured({ candidateId, ...extraParams });
      // structuredResp expected to be an object: { candidateId, correlationId, status, results: [...] }
      return { type: 'structured', payload: structuredResp };
    } catch (errStructured) {
      // fallback to legacy
      try {
        const legacyResp = await runEvaluation({ candidateId, ruleKey: extraParams.ruleKey || null });
        // legacyResp is typically a JSON-stringified array/string; return as-is for normalization
        return { type: 'legacy', payload: legacyResp };
      } catch (errLegacy) {
        // throw highest-level error
        throw errLegacy || errStructured;
      }
    }
  }

  async onRunAdhoc() {
    if (!this.testCandidateId) {
      this.showToast('Validation', 'Provide Candidate Id to run ad-hoc evaluation.', 'warning');
      return;
    }
    this.isRunning = true;
    this.lastResult = null;
    try {
      const callResp = await this._callRunEvaluation(this.testCandidateId);
      this.lastResult = this._normalizeAndPretty(callResp);
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
        this.showToast('Validation', 'Set Candidate Id in the input to test this rule.', 'warning');
        return;
      }
      this.isRunning = true;
      this.lastResult = null;
      try {
        const callResp = await this._callRunEvaluation(this.testCandidateId, { ruleKey: row.ruleKey });
        this.lastResult = this._normalizeAndPretty(callResp);
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
      this.showToast('Success', 'Export initiated.', 'success');
    } catch (err) {
      this.showToast('Error', 'Export failed: ' + this._extractError(err), 'error');
    }
  }

  /**
   * Normalization helper
   * Accept both forms:
   *  - { type: 'structured', payload: { candidateId, correlationId, status, results: [...] } }
   *  - { type: 'legacy', payload: '...[ escaped JSON ]...' }  (stringified)
   *
   * Returns pretty-printed JSON string for display.
   */
  _normalizeAndPretty(callResp) {
    try {
      if (!callResp) return '';
      if (callResp.type === 'structured') {
        return JSON.stringify(callResp.payload, null, 2);
      }
      // legacy - attempt to parse payload (it may be stringified JSON or array)
      if (callResp.type === 'legacy') {
        const payload = callResp.payload;
        if (typeof payload === 'string') {
          // it may be a JSON string (serialized array/object) or already pretty JSON string
          try {
            const parsed = JSON.parse(payload);
            return JSON.stringify(parsed, null, 2);
          } catch (e) {
            // payload might be stringified nested JSON (e.g. '["{...}"]') - try another pass
            try {
              const doub = JSON.parse(payload);
              return JSON.stringify(doub, null, 2);
            } catch (ee) {
              // fallback to raw string
              return payload;
            }
          }
        } else {
          // not a string - pretty print directly
          return JSON.stringify(payload, null, 2);
        }
      }
      // fallback
      return JSON.stringify(callResp, null, 2);
    } catch (e) {
      return String(callResp);
    }
  }

  _extractError(err) {
    try {
      if (!err) return 'Unknown error';
      // If it's a network/Apex error object
      if (err && err.body && err.body.message) return err.body.message;
      // If it's our wrapped error from callRunEvaluation
      if (err && err.message) return err.message;
      // If it's an object with type/payload and payload contains error string
      if (err && err.type && err.payload) return JSON.stringify(err.payload);
      return JSON.stringify(err);
    } catch (e) {
      return 'Unknown error';
    }
  }

  showToast(title, msg, variant = 'info') {
    const evt = new ShowToastEvent({ title, message: msg, variant });
    this.dispatchEvent(evt);
  }
}
