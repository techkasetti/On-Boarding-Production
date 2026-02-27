import { LightningElement, api, wire} from 'lwc';
import getMatchedCandidates from '@salesforce/apex/JobCandidateMatcherController.getMatchedCandidates';

export default class JobCandidateMatcher extends LightningElement {
    @api recordId;
    candidates;
    error;

    columns = [
    { label: 'Candidate Name', fieldName: 'candidateName' },
    { label: 'Match Score (%)', fieldName: 'score', type: 'number' },
    { label: 'Fit Level', fieldName: 'scoreLabel' }
];
    @wire(getMatchedCandidates, { jobPostingId: '$recordId' })
    wiredCandidates({ data, error }) {
        if (data) {
            this.candidates = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.candidates = undefined;
        }
    }
}