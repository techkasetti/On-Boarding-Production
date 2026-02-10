
// profileItemCard.js - UPDATED WITH DELETE EVENT
import { LightningElement, api } from 'lwc';

export default class ProfileItemCard extends LightningElement {
    @api iconName;
    @api recordId;

    handleEdit() {
        const event = new CustomEvent('edit', {
            detail: {
                recordId: this.recordId
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(event);
    }

    handleDelete() {
        const event = new CustomEvent('delete', {
            detail: {
                recordId: this.recordId
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(event);
    }
}