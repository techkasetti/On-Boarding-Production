import { LightningElement, api } from 'lwc';

export default class ProfileSection extends LightningElement {
    @api iconName;
    @api addButtonLabel = 'Add New';
    @api emptyStateMessage = 'No items added yet';
    @api items = [];

    get hasItems() {
        return this.items && this.items.length > 0;
    }

    handleAddNew() {
        const event = new CustomEvent('addnew', {
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(event);
    }
}