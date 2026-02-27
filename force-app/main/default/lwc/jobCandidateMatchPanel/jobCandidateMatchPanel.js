import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getMatchedCandidates from '@salesforce/apex/JobCandidateMatcherController.getMatchedCandidates';

export default class jobCandidateMatchPanel extends LightningElement {

    @track jobId;
    @track candidates = [];
    @track selectedCandidateId;

    @wire(CurrentPageReference)
    getPageRef(pageRef) {
        if (pageRef && pageRef.state && pageRef.state.c__jobId) {
            this.jobId = pageRef.state.c__jobId;
            this.loadMatchedCandidates();
        }
    }

    async loadMatchedCandidates() {
        if (!this.jobId) return;

        try {
            this.candidates = await getMatchedCandidates({ jobPostingId: this.jobId });
        } catch (e) {
            console.error(e);
        }
    }

    handleSelect(event) {
        this.selectedCandidateId = event.currentTarget.dataset.id;
    }
}