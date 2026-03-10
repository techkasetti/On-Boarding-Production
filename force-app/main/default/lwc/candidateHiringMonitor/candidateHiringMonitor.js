import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getHomeSnapshot from '@salesforce/apex/CandidateHiringMonitorController.getHomeSnapshot';

const ROW_COLUMNS = [
    {
        label: 'Candidate',
        fieldName: 'candidateUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'candidateName' }, target: '_blank' }
    },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Age (Days)', fieldName: 'ageDays', type: 'number' },
    { label: 'HIPAA Complete', fieldName: 'hipaaLabel', type: 'text' },
    { label: 'Identity Phase', fieldName: 'identityPhase', type: 'text' }
];

export default class CandidateHiringMonitor extends LightningElement {
    @api maxRows = 10;

    wiredSnapshotResult;
    snapshot;
    errorMessage;

    rowColumns = ROW_COLUMNS;

    @wire(getHomeSnapshot, { maxRows: '$maxRows' })
    wiredSnapshot(value) {
        this.wiredSnapshotResult = value;
        const { data, error } = value;
        if (data) {
            this.snapshot = {
                ...data,
                readyQueue: this.normalizeRows(data.readyQueue),
                missingEmployeeQueue: this.normalizeRows(data.missingEmployeeQueue),
                oldestPendingQueue: this.normalizeRows(data.oldestPendingQueue)
            };
            this.errorMessage = null;
        } else if (error) {
            this.snapshot = null;
            this.errorMessage = this.resolveError(error);
        }
    }

    get hasSnapshot() {
        return !!this.snapshot;
    }

    get generatedText() {
        return this.snapshot?.generatedAt ? new Date(this.snapshot.generatedAt).toLocaleString() : '';
    }

    get averageAgeText() {
        return this.snapshot?.averagePendingAgeDays ?? 0;
    }

    get lastFailureText() {
        if (!this.snapshot?.lastConversionFailureMessage) {
            return 'None';
        }
        return this.snapshot.lastConversionFailureMessage;
    }

    get lastFailureAtText() {
        return this.snapshot?.lastConversionFailureAt
            ? new Date(this.snapshot.lastConversionFailureAt).toLocaleString()
            : '';
    }

    async handleRefresh() {
        if (this.wiredSnapshotResult) {
            await refreshApex(this.wiredSnapshotResult);
        }
    }

    normalizeRows(rows) {
        return (rows || []).map((row) => ({
            ...row,
            candidateUrl: row.candidateId ? `/lightning/r/Candidate__c/${row.candidateId}/view` : null,
            hipaaLabel: row.hipaaComplete ? 'Yes' : 'No'
        }));
    }

    resolveError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((entry) => entry.message).join(', ');
        }
        if (error.body?.message) {
            return error.body.message;
        }
        return error.message || 'Unknown error';
    }
}
