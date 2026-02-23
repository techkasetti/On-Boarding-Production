import { LightningElement, track } from 'lwc';
import getLicenseVerifications from '@salesforce/apex/LicenseStatusViewerController.getLicenseVerifications';

export default class LicenseStatusViewer extends LightningElement {
    @track rows = [];
    @track error;
    @track isLoading = false;

    statusFilter = '';
    expiringBefore = '';

    columns = [
        { label: 'Provider', fieldName: 'providerName', type: 'text' },
        { label: 'License Number', fieldName: 'licenseNumber', type: 'text' },
        { label: 'State', fieldName: 'state', type: 'text' },
        { label: 'Status', fieldName: 'status', type: 'text' },
        { label: 'Expiration Date', fieldName: 'expirationDate', type: 'date' },
        { label: 'Last Verified', fieldName: 'lastVerifiedDate', type: 'date' }
    ];

    get statusOptions() {
        return [
            { label: 'All Statuses', value: '' },
            { label: 'Valid', value: 'Valid' },
            { label: 'Expired', value: 'Expired' },
            { label: 'Suspended', value: 'Suspended' },
            { label: 'Not Found', value: 'Not Found' }
        ];
    }

    get hasData() {
        return this.rows && this.rows.length > 0 && !this.isLoading && !this.error;
    }

    get hasNoData() {
        return (!this.rows || this.rows.length === 0) && !this.isLoading && !this.error;
    }

    connectedCallback() {
        this.loadData();
    }

    handleStatusChange(event) {
        this.statusFilter = event.detail.value;
                this.loadData();

    }

    handleExpiringBeforeChange(event) {
        this.expiringBefore = event.detail.value;
                this.loadData();

    }

    handleRefresh() {
        this.loadData();
    }

    loadData() {
        this.isLoading = true;
        this.error = undefined;

        let expiringDateParam = null;
        if (this.expiringBefore) {
            expiringDateParam = this.expiringBefore;
        }

        getLicenseVerifications({
            statusFilter: this.statusFilter,
            expiringBefore: expiringDateParam
        })
            .then((result) => {
                this.rows = result;
                this.isLoading = false;
            })
            .catch((error) => {
                this.error = error;
                this.rows = [];
                this.isLoading = false;
            });
    }
}