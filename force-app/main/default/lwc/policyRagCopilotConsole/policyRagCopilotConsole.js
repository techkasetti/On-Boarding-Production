import { LightningElement, api, track } from 'lwc';
import evaluateFromJson from '@salesforce/apex/PolicyRagComplianceCopilotService.evaluateFromJson';
import evaluateUsingStoredEvidence from '@salesforce/apex/PolicyRagComplianceCopilotService.evaluateUsingStoredEvidence';
import resolveCandidateContext from '@salesforce/apex/PolicyRagComplianceCopilotService.resolveCandidateContext';
import searchCandidates from '@salesforce/apex/PolicyRagComplianceCopilotService.searchCandidates';

const DEFAULT_CHUNK = {
    chunkId: 'chunk_12',
    source: 'policy/hipaa.md#L10',
    content: 'HIPAA training completion is mandatory before PHI access.'
};

const QUESTION_TEMPLATES = [
    {
        label: 'HIPAA Pending Gate Check',
        value: 'hipaa_pending',
        question: 'Can this candidate proceed if HIPAA is pending?',
        jurisdiction: 'US'
    },
    {
        label: 'License Expired Gate Check',
        value: 'license_expired',
        question: 'Should this candidate be blocked if license status is Expired?',
        jurisdiction: 'US'
    },
    {
        label: 'Background Verification Hold',
        value: 'bgv_hold',
        question: 'Can onboarding proceed when background verification is not completed?',
        jurisdiction: 'US'
    },
    {
        label: 'Manual Review Trigger',
        value: 'manual_review',
        question: 'Does this candidate need manual review before clearance?',
        jurisdiction: 'US'
    }
];

export default class PolicyRagCopilotConsole extends LightningElement {
    @api recordId;

    @track candidateId = '';
    @track candidateSearchText = '';
    @track candidateOptions = [];
    @track showCandidateSuggestions = false;
    @track autoFillMessage = '';
    @track resolvingCandidate = false;

    @track jurisdiction = 'US';
    @track question = '';
    @track selectedTemplate = '';

    @track inputMode = 'builder';
    @track chunkRows = [];
    @track chunksJson = '';
    @track useStoredEvidence = false;
    @track policyType = '';
    @track maxRetrievedChunks = 8;

    @track loading = false;
    @track errorMessage = '';
    @track result;
    @track runHistory = [];

    candidateSearchDebounce;

    connectedCallback() {
        this.initializeState();
        this.tryResolveCandidateFromRecord();
    }

    initializeState() {
        this.chunkRows = [this.createChunkRow(DEFAULT_CHUNK)];
        this.chunksJson = this.serializeChunkRows(this.chunkRows);
    }

    createChunkRow(seed) {
        const base = seed || {};
        return {
            uid: String(Date.now()) + '-' + Math.floor(Math.random() * 100000),
            chunkId: base.chunkId || '',
            source: base.source || '',
            content: base.content || ''
        };
    }

    get templateOptions() {
        return [{ label: 'Select a template', value: '' }].concat(
            QUESTION_TEMPLATES.map((t) => ({ label: t.label, value: t.value }))
        );
    }

    get modeOptions() {
        return [
            { label: 'Visual Builder', value: 'builder' },
            { label: 'Raw JSON', value: 'json' }
        ];
    }

    get candidateSelectionOptions() {
        return [{ label: 'Select suggested candidate', value: '' }].concat(
            (this.candidateOptions || []).map((opt) => ({ label: opt.label, value: opt.id }))
        );
    }

    get hasCandidateOptions() {
        return this.candidateOptions && this.candidateOptions.length > 0;
    }

    get visibleCandidateOptions() {
        return (this.candidateOptions || []).slice(0, 8);
    }

    get shouldShowCandidateSuggestions() {
        return this.showCandidateSuggestions && this.visibleCandidateOptions.length > 0;
    }

    get isBuilderMode() {
        return this.inputMode === 'builder';
    }

    get isJsonMode() {
        return this.inputMode === 'json';
    }

    get hasResult() {
        return !!this.result;
    }

    get hasHistory() {
        return this.runHistory.length > 0;
    }

    get questionLength() {
        return this.question ? this.question.trim().length : 0;
    }

    get chunkCount() {
        if (this.useStoredEvidence) {
            return 'auto';
        }
        return this.isBuilderMode ? this.chunkRows.length : this.safeParseChunkCount(this.chunksJson);
    }

    get evidenceModeLabel() {
        return this.useStoredEvidence ? 'Stored Retrieval' : 'Manual Input';
    }

    get parsedJsonValid() {
        if (!this.chunksJson || !this.chunksJson.trim()) {
            return false;
        }

        try {
            const parsed = JSON.parse(this.chunksJson);
            return Array.isArray(parsed);
        } catch (e) {
            return false;
        }
    }

    get jsonStatusLabel() {
        if (this.useStoredEvidence) {
            return 'Using stored policy retrieval';
        }
        if (this.isBuilderMode) {
            return 'Auto-generated from builder';
        }

        return this.parsedJsonValid ? 'Valid JSON payload' : 'Invalid JSON payload';
    }

    get jsonStatusClass() {
        if (this.useStoredEvidence) {
            return 'pill success';
        }
        if (this.isBuilderMode) {
            return 'pill neutral';
        }

        return this.parsedJsonValid ? 'pill success' : 'pill error';
    }

    get validationMessage() {
        if (!this.question || !this.question.trim()) {
            return 'Question is required.';
        }

        if (!this.candidateId || !this.candidateId.trim()) {
            return 'Candidate Id is required.';
        }

        if (this.useStoredEvidence) {
            return '';
        }

        try {
            const payload = this.buildPayloadJson();
            const parsed = JSON.parse(payload || '[]');
            if (!Array.isArray(parsed) || parsed.length === 0) {
                return 'At least one policy chunk is required.';
            }

            const hasEmptyContent = parsed.some((c) => !c || !c.content || !String(c.content).trim());
            if (hasEmptyContent) {
                return 'Every chunk must include content.';
            }
        } catch (e) {
            return 'Chunk JSON is invalid: ' + e.message;
        }

        return '';
    }

    get hasValidationMessage() {
        return !!this.validationMessage;
    }

    get canRun() {
        return !this.loading && !this.hasValidationMessage;
    }

    get readinessClass() {
        return this.canRun ? 'readiness ok' : 'readiness blocked';
    }

    get readinessLabel() {
        return this.canRun ? 'Ready to Run' : 'Input Required';
    }

    get readinessHint() {
        return this.canRun ? 'All required fields are valid.' : this.validationMessage;
    }

    get runButtonLabel() {
        return this.loading ? 'Running...' : 'Run Copilot';
    }

    get confidencePercent() {
        const score = this.result && this.result.confidence != null ? Number(this.result.confidence) : 0;
        const bounded = Math.max(0, Math.min(1, score));
        const percent = Math.round(bounded * 100);
        return Number.isNaN(percent) ? 0 : percent;
    }

    get confidenceVariant() {
        if (this.confidencePercent >= 75) {
            return 'success';
        }
        if (this.confidencePercent >= 45) {
            return 'warning';
        }
        return 'expired';
    }

    get decisionClass() {
        if (!this.hasResult || !this.result.decision) {
            return 'decision neutral';
        }

        if (this.result.decision === 'ALLOW') {
            return 'decision allow';
        }

        if (this.result.decision === 'BLOCK') {
            return 'decision block';
        }

        return 'decision review';
    }

    get decisionIcon() {
        if (!this.hasResult || !this.result.decision) {
            return 'utility:info';
        }

        if (this.result.decision === 'ALLOW') {
            return 'utility:success';
        }

        if (this.result.decision === 'BLOCK') {
            return 'utility:error';
        }

        return 'utility:warning';
    }

    get citations() {
        return this.hasResult && this.result.citations ? this.result.citations : [];
    }

    get hasCitations() {
        return this.citations.length > 0;
    }

    get missingInformation() {
        return this.hasResult && this.result.missing_information ? this.result.missing_information : [];
    }

    get hasMissingInformation() {
        return this.missingInformation.length > 0;
    }

    get resultJsonPretty() {
        return this.hasResult ? JSON.stringify(this.result, null, 2) : '';
    }

    handleTemplateChange(event) {
        this.selectedTemplate = event.detail.value;
        const template = QUESTION_TEMPLATES.find((t) => t.value === this.selectedTemplate);
        if (template) {
            this.question = template.question;
            this.jurisdiction = template.jurisdiction;
        }
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        if (field === 'maxRetrievedChunks') {
            this[field] = Number(event.target.value);
        } else {
            this[field] = event.target.value;
        }
        this.errorMessage = '';
    }

    handleStoredEvidenceToggle(event) {
        this.useStoredEvidence = event.target.checked;
        this.errorMessage = '';
    }

    handleCandidateSearchInput(event) {
        this.candidateSearchText = event.target.value || '';
        this.errorMessage = '';
        this.showCandidateSuggestions = true;

        window.clearTimeout(this.candidateSearchDebounce);
        this.candidateSearchDebounce = window.setTimeout(() => {
            this.fetchCandidateSuggestions(this.candidateSearchText);
        }, 250);
    }

    handleCandidateSuggestionClick(event) {
        const pickedId = event.currentTarget.dataset.id;
        if (!pickedId) {
            return;
        }

        this.candidateId = pickedId;
        const selected = (this.candidateOptions || []).find((opt) => opt.id === pickedId);
        if (selected) {
            this.candidateSearchText = selected.name;
            this.autoFillMessage = 'Selected candidate: ' + selected.name;
        } else {
            this.autoFillMessage = 'Selected candidate: ' + pickedId;
        }
        this.showCandidateSuggestions = false;
    }

    handleCandidateSearchBlur() {
        window.setTimeout(() => {
            this.showCandidateSuggestions = false;
        }, 200);
    }

    handleCandidateSearchFocus() {
        this.showCandidateSuggestions = this.visibleCandidateOptions.length > 0;
    }

    handleModeChange(event) {
        this.inputMode = event.detail.value;
        this.errorMessage = '';

        if (this.isJsonMode) {
            this.chunksJson = this.serializeChunkRows(this.chunkRows);
        } else {
            this.syncRowsFromJson();
        }
    }

    handleChunkFieldChange(event) {
        const uid = event.target.dataset.uid;
        const field = event.target.dataset.field;
        const value = event.target.value;

        this.chunkRows = this.chunkRows.map((row) => {
            if (row.uid !== uid) {
                return row;
            }

            return {
                ...row,
                [field]: value
            };
        });

        this.chunksJson = this.serializeChunkRows(this.chunkRows);
        this.errorMessage = '';
    }

    addChunk() {
        this.chunkRows = [...this.chunkRows, this.createChunkRow()];
        this.chunksJson = this.serializeChunkRows(this.chunkRows);
    }

    removeChunk(event) {
        const uid = event.currentTarget.dataset.uid;
        if (this.chunkRows.length === 1) {
            this.errorMessage = 'At least one chunk row is required.';
            return;
        }

        this.chunkRows = this.chunkRows.filter((row) => row.uid !== uid);
        this.chunksJson = this.serializeChunkRows(this.chunkRows);
    }

    loadSample() {
        this.errorMessage = '';
        this.selectedTemplate = 'hipaa_pending';
        this.question = 'Can this candidate proceed if HIPAA is pending?';
        this.jurisdiction = 'US';

        const samples = [
            {
                chunkId: 'chunk_12',
                source: 'policy/hipaa.md#L10',
                content: 'HIPAA training completion is mandatory before PHI access.'
            },
            {
                chunkId: 'chunk_27',
                source: 'policy/license.md#L3',
                content: 'Active license verification is required before final clearance.'
            }
        ];

        this.chunkRows = samples.map((s) => this.createChunkRow(s));
        this.chunksJson = this.serializeChunkRows(this.chunkRows);
        this.inputMode = 'builder';
        this.useStoredEvidence = false;
    }

    formatJson() {
        try {
            const parsed = JSON.parse(this.chunksJson || '[]');
            this.chunksJson = JSON.stringify(parsed, null, 2);
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Cannot format JSON: ' + e.message;
        }
    }

    syncRowsFromJson() {
        try {
            const parsed = JSON.parse(this.chunksJson || '[]');
            if (!Array.isArray(parsed) || parsed.length === 0) {
                this.chunkRows = [this.createChunkRow()];
                return;
            }

            this.chunkRows = parsed.map((item) =>
                this.createChunkRow({
                    chunkId: item.chunkId,
                    source: item.source,
                    content: item.content
                })
            );
            this.errorMessage = '';
        } catch (e) {
            this.errorMessage = 'Chunk JSON is invalid: ' + e.message;
        }
    }

    serializeChunkRows(rows) {
        const payload = (rows || []).map((row) => ({
            chunkId: (row.chunkId || '').trim(),
            source: (row.source || '').trim(),
            content: (row.content || '').trim()
        }));

        return JSON.stringify(payload, null, 2);
    }

    buildPayloadJson() {
        if (this.useStoredEvidence) {
            return '[]';
        }
        return this.isBuilderMode ? this.serializeChunkRows(this.chunkRows) : this.chunksJson;
    }

    safeParseChunkCount(raw) {
        try {
            const parsed = JSON.parse(raw || '[]');
            return Array.isArray(parsed) ? parsed.length : 0;
        } catch (e) {
            return 0;
        }
    }

    restoreRun(event) {
        const historyId = event.currentTarget.dataset.id;
        const found = this.runHistory.find((h) => h.id === historyId);
        if (!found) {
            return;
        }

        const request = found.request || {};
        this.question = request.question || this.question;
        this.candidateId = request.candidateId || this.candidateId;
        this.jurisdiction = request.jurisdiction || this.jurisdiction;
        this.chunksJson = request.chunksJson || this.chunksJson;
        this.useStoredEvidence =
            request.useStoredEvidence !== undefined ? request.useStoredEvidence : this.useStoredEvidence;
        this.policyType = request.policyType || this.policyType;
        this.maxRetrievedChunks = request.maxRetrievedChunks || this.maxRetrievedChunks;

        if (request.chunksJson) {
            this.syncRowsFromJson();
        }

        this.result = found.result;
        this.errorMessage = '';
    }

    async runCopilot() {
        this.errorMessage = '';

        const validationError = this.validationMessage;
        if (validationError) {
            this.errorMessage = validationError;
            return;
        }

        this.loading = true;
        const payloadChunks = this.buildPayloadJson();

        try {
            let response;
            if (this.useStoredEvidence) {
                response = await evaluateUsingStoredEvidence({
                    question: this.question,
                    candidateId: this.candidateId,
                    jurisdiction: this.jurisdiction,
                    policyType: this.policyType,
                    maxChunks: this.maxRetrievedChunks
                });
            } else {
                response = await evaluateFromJson({
                    question: this.question,
                    candidateId: this.candidateId,
                    jurisdiction: this.jurisdiction,
                    retrievedChunksJson: payloadChunks
                });
            }

            this.result = response;
            this.runHistory = [
                {
                    id: String(Date.now()) + '-' + Math.floor(Math.random() * 1000),
                    when: new Date().toLocaleString(),
                    decision: response && response.decision ? response.decision : 'UNKNOWN',
                    confidence:
                        response && response.confidence != null
                            ? Math.round(Number(response.confidence) * 100) + '%'
                            : '0%',
                    correlationId: response && response.correlationId ? response.correlationId : '',
                    retrievalMode:
                        response && response.retrievalMode ? response.retrievalMode : this.evidenceModeLabel,
                    request: {
                        question: this.question,
                        candidateId: this.candidateId,
                        jurisdiction: this.jurisdiction,
                        chunksJson: payloadChunks,
                        useStoredEvidence: this.useStoredEvidence,
                        policyType: this.policyType,
                        maxRetrievedChunks: this.maxRetrievedChunks
                    },
                    result: response
                },
                ...this.runHistory
            ].slice(0, 8);
        } catch (e) {
            this.result = undefined;
            this.errorMessage =
                e && e.body && e.body.message
                    ? e.body.message
                    : 'Unexpected error while running copilot.';
        } finally {
            this.loading = false;
        }
    }

    async tryResolveCandidateFromRecord() {
        this.resolvingCandidate = true;

        try {
            const resolved = await resolveCandidateContext({
                recordId: this.recordId || null
            });

            this.autoFillMessage = resolved && resolved.message ? resolved.message : '';

            if (resolved && resolved.candidateId) {
                this.candidateId = resolved.candidateId;
                if (resolved.candidateName) {
                    this.candidateSearchText = resolved.candidateName;
                }
            }

            if (resolved && resolved.suggestions) {
                this.candidateOptions = resolved.suggestions;
            } else {
                await this.fetchCandidateSuggestions('');
            }
        } catch (e) {
            this.autoFillMessage = 'Candidate autofill unavailable. Use search below.';
            await this.fetchCandidateSuggestions('');
        } finally {
            this.resolvingCandidate = false;
        }
    }

    async fetchCandidateSuggestions(searchText) {
        try {
            const options = await searchCandidates({
                searchTerm: searchText || '',
                limitSize: 8
            });
            this.candidateOptions = options || [];
            if (this.candidateOptions.length > 0 && this.candidateSearchText) {
                this.showCandidateSuggestions = true;
            }
        } catch (e) {
            this.candidateOptions = [];
        }
    }
}
