import { LightningElement, track } from 'lwc';
export default class OnboardingWizard extends LightningElement {
  @track candidateId;
  @track preferredLanguage;

  handleCandidateCreated(event) {
    this.candidateId = event.detail.candidateId;
    this.preferredLanguage = event.detail.preferredLanguage;
  }
}
