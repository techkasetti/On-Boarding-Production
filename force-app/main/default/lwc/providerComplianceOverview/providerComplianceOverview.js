import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProviderQueue from '@salesforce/apex/ProviderComplianceController.getProviderQueue';
import getOverviewKpis from '@salesforce/apex/ProviderComplianceController.getOverviewKpis';
import flagProviderForReview from '@salesforce/apex/ProviderComplianceController.flagProviderForReview';

const COLUMNS = [
    {
        label: 'Provider',
        fieldName: 'candidateUrl',
        type: 'url',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'candidateName' },
            target: '_blank'
        },
        cellAttributes: {
            iconName: 'standard:individual',
            iconPosition: 'left'
        }
    },
    {
        label: 'Overall Status',
        fieldName: 'overallStatus',
        type: 'text',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'overallStatusClass' },
            iconName: { fieldName: 'overallStatusIcon' }
        }
    },
    {
        label: 'License',
        fieldName: 'licenseSummary',
        type: 'text',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'licenseClass' }
        }
    },
    {
        label: 'Credentialing',
        fieldName: 'credentialSummary',
        type: 'text',
        sortable: false,
        cellAttributes: {
            class: { fieldName: 'credentialClass' }
        }
    },
    {
        label: 'HIPAA',
        fieldName: 'hipaaStatus',
        type: 'text',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'hipaaClass' }
        }
    },
    {
        label: 'CME',
        fieldName: 'cmeSummary',
        type: 'text',
        sortable: false,
        cellAttributes: {
            class: { fieldName: 'cmeClass' }
        }
    },
    {
        label: 'Next Compliance Trigger',
        fieldName: 'nextTriggerLabel',
        type: 'text',
        sortable: true
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Open Compliance Profile', name: 'open_profile' },
                { label: 'Flag for Manual Review', name: 'flag_review' },
                { label: 'Initiate License Verification', name: 'init_license' },
                { label: 'Reassign to Specialist', name: 'reassign' }
            ]
        }
    }
];

export default class ProviderComplianceOverview extends LightningElement {
    @track searchKey = '';
    @track facilityValue;
    @track facilityOptions = [];
    @track specialtyValue;
    @track specialtyOptions = [];
    @track selectedNav = 'queue_blocked';
    @track activeTab = 'providers';

    @track kpi = {};

    columns = COLUMNS;
    @track rows;
    @track totalCount = 0;
    @track sortedBy = 'overallStatus';
    @track sortedDirection = 'asc';
    @track statusFilter;
    @track statusFilterOptions = [
        { label: 'All Statuses', value: '' },
        { label: 'Blocked', value: 'Blocked' },
        { label: 'At Risk', value: 'At Risk' },
        { label: 'Eligible', value: 'Eligible' }
    ];
    @track isLoading = false;
    @track hasError = false;
    @track errorMessage;

    pageSize = 50;
    offset = 0;
    allLoaded = false;

    connectedCallback() {
        this.loadKpis();
        this.loadQueue(true);
    }

    get queueTitle() {
        return 'Provider Work Queue';
    }

    get queueLabel() {
        switch (this.selectedNav) {
            case 'queue_blocked':
                return 'Blocked Providers';
            case 'queue_at_risk':
                return 'At-Risk Providers';
            case 'queue_manual_review':
                return 'Manual Review Required';
            default:
                return 'Provider Queue';
        }
    }

    handleSearchChange(event) {
        this.searchKey = event.detail.value;
        this.loadQueue(true);
    }

    handleFacilityChange(event) {
        this.facilityValue = event.detail.value;
        this.loadQueue(true);
    }

    handleSpecialtyChange(event) {
        this.specialtyValue = event.detail.value;
        this.loadQueue(true);
    }

    handleExportSnapshot() {
        const data = this.rows;
        const columns = this.columns;

        if (!data || data.length === 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Export Snapshot',
                    message: 'There are no records in the current Provider Work Queue to export.',
                    variant: 'info'
                })
            );
            return;
        }

        const csv = this.buildCsvFromTable(columns, data);
        const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
        const link = document.createElement('a');
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

        link.href = encodedUri;
        link.target = '_self';
        link.download = `Provider_Work_Queue_${timestamp}.csv`;

        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    buildCsvFromTable(columns, data) {
        const header = columns
            .filter(col => col.type !== 'action')
            .map(col => this.escapeCsvValue(col.label))
            .join(',');

        const rows = data.map(row => {
            return columns
                .filter(col => col.type !== 'action')
                .map(col => {
                    const field =
                        col.fieldName ||
                        col.fieldNameCustom ||
                        col.apiName;

                    let value = row[field];

                    if (col.type === 'url' && row.candidateName) {
                        value = row.candidateName;
                    }

                    if (value === undefined || value === null) {
                        value = '';
                    }

                    return this.escapeCsvValue(value);
                })
                .join(',');
        });

        return [header].concat(rows).join('\n');
    }

    escapeCsvValue(value) {
        let str = value === undefined || value === null ? '' : String(value);
        str = str.replace(/"/g, '""');
        return `"${str}"`;
    }

    handleNavSelect(event) {
        this.selectedNav = event.detail.name;

        if (this.selectedNav.startsWith('queue_')) {
            this.activeTab = 'providers';
        } else {
            this.activeTab = 'overview';
        }

        this.loadQueue(true);
        this.loadKpis();
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.detail.value;
        this.loadQueue(true);
    }

    handleQuickFilter(event) {
        const value = event.detail.value;
        console.log('Quick filter changed:', value);
        this.loadQueue(true);
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.loadQueue(true);
    }

    handleLoadMore() {
        this.loadQueue(false);
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case 'open_profile':
                break;
            case 'flag_review':
                this.flagForReview(row.candidateId);
                break;
            case 'init_license':
                break;
            case 'reassign':
                break;
            default:
        }
    }

    flagForReview(candidateId) {
        flagProviderForReview({
            candidateId: candidateId,
            reason: 'Flagged from admin console work queue.'
        })
            .then(() => {})
            .catch(error => {
                this.hasError = true;
                this.errorMessage =
                    error && error.body && error.body.message
                        ? error.body.message
                        : 'Error flagging provider for review.';
            });
    }

    loadKpis() {
        getOverviewKpis()
            .then(result => {
                this.kpi = result || {};
            })
            .catch(error => {
                this.hasError = true;
                this.errorMessage =
                    error && error.body && error.body.message
                        ? error.body.message
                        : 'Error loading KPIs.';
            });
    }

    loadQueue(reset) {
        if (this.isLoading) {
            return;
        }

        if (reset) {
            this.offset = 0;
            this.rows = [];
            this.allLoaded = false;
        } else if (this.allLoaded) {
            return;
        }

        this.isLoading = true;
        this.hasError = false;
        this.errorMessage = null;

        getProviderQueue({
            queueName: this.selectedNav,
            searchKey: this.searchKey,
            facility: this.facilityValue,
            specialty: this.specialtyValue,
            statusFilter: this.statusFilter,
            pageSize: this.pageSize,
            offset: this.offset,
            sortBy: this.sortedBy,
            sortDirection: this.sortedDirection
        })
            .then(result => {
                const { records, totalCount } = result;
                this.totalCount = totalCount || 0;

                const mapped = (records || []).map(rec => ({
                    ...rec,
                    candidateUrl: '/' + rec.candidateId
                }));

                this.rows = reset
                    ? mapped
                    : [...(this.rows || []), ...mapped];

                this.offset += mapped.length;

                if (mapped.length < this.pageSize) {
                    this.allLoaded = true;
                }
            })
            .catch(error => {
                this.hasError = true;
                this.errorMessage =
                    error && error.body && error.body.message
                        ? error.body.message
                        : 'Error loading provider queue.';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}