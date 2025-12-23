import { LightningElement, api } from 'lwc';

export default class ProfileItemCard extends LightningElement {
    @api iconName = 'standard:record';
    @api recordId;

    handleEdit() {
        const event = new CustomEvent('edit', {
            detail: { recordId: this.recordId },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(event);
    }
}