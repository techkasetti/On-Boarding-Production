import { LightningElement, track } from 'lwc';
import createCandidate from '@salesforce/apex/Onb_IntakeController.createCandidate';

export default class OnboardingBasicInfoForm extends LightningElement {
  @track name = '';
  @track email = '';
  @track phone = '';
  @track preferredLanguage = '';
  @track candidateId;

  languageOptions = [
    { label: 'English', value: 'en' },
    { label: 'Hindi', value: 'hi' },
    { label: 'Tamil', value: 'ta' },
    { label: 'French', value: 'fr' }
  ];

  handleName(e) { this.name = e.target.value; }
  handleEmail(e) { this.email = e.target.value; }
  handlePhone(e) { this.phone = e.target.value; }
  handleLanguage(e) { this.preferredLanguage = e.target.value; }

  handleCreate() {
    createCandidate({ name: this.name, email: this.email, tenantId: null, phone: this.phone, preferredLanguage: this.preferredLanguage })
      .then(result => {
        this.candidateId = result.Id;
        // dispatch created event with candidateId and preferredLanguage
        this.dispatchEvent(new CustomEvent('created', { detail: { candidateId: result.Id, preferredLanguage: this.preferredLanguage } }));
      })
      .catch(error => {
        // handle error (basic)
        console.error(error);
        this.dispatchEvent(new CustomEvent('error', { detail: error }));
      });
  }
}
