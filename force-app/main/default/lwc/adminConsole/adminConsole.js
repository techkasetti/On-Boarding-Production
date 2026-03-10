import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getFeatures from '@salesforce/apex/AdminConsoleController.getFeatures';
import updateFeatures from '@salesforce/apex/AdminConsoleController.updateFeatures';

export default class AdminConsole extends LightningElement {

    @track featureList = [];
    @track error;
    isLoading = true;

    _wiredResult;

    // ================= LOAD FEATURES =================
    @wire(getFeatures)
    wiredFeatures(result) {
        this._wiredResult = result;
        this.isLoading = false;
        console.log('Wired Result:', result);   
        if (result.data) {

            this.featureList = Object.keys(result.data).map(key => {
                const value = result.data[key];

                return {
                    apiName: key,
                    label: this.formatLabel(key),
                    value: value,
                    status: value ? 'Active' : 'Inactive'
                };
            });

            this.error = undefined;

        } else if (result.error) {
            this.error = result.error;
            this.featureList = [];
        }
    }

    // ================= FORMAT LABEL =================
    formatLabel(apiName) {
        return apiName
            .replace('__c', '')
            .replace(/_/g, ' ')
            .toUpperCase();
    }

    // ================= HANDLE TOGGLE =================
    handleToggleChange(event) {

        const field = event.target.dataset.field;
        const value = event.target.checked;

        // 🔥 Update UI instantly
        this.featureList = this.featureList.map(item => {
            if (item.apiName === field) {
                return {
                    ...item,
                    value: value,
                    status: value ? 'Active' : 'Inactive'
                };
            }
            return item;
        });

        // 🔥 Send as SObject-compatible payload
        const updatedSettings = {};
        updatedSettings[field] = value;

        this.isLoading = true;

        updateFeatures({ updatedSettings: updatedSettings })
            .then(() => {
                this.showToast('Success', 'Settings updated', 'success');
                return refreshApex(this._wiredResult);
            })
            .catch(error => {
                console.error('Update Error:', error);

                this.showToast(
                    'Error',
                    error?.body?.message || 'Update failed',
                    'error'
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ================= TOAST =================
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    // ================= ERROR TEXT =================
    get errorText() {
        return this.error?.body?.message || 'Unknown error';
    }
}