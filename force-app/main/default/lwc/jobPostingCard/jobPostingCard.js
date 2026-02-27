import { LightningElement, api } from 'lwc';

export default class JobPostingCard extends LightningElement {
    @api jobId;
    @api jobTitle;
    @api jobDescription;
    @api jobLocation;

    handleSelect() {
        const selectEvent = new CustomEvent('selected', {
            detail: {
                jobId: this.jobId,
                jobTitle: this.jobTitle
            }
        });
        this.dispatchEvent(selectEvent);
    }
}