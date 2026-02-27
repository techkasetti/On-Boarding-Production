import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import processIntake from '@salesforce/apex/CandidateIntakeController.processIntake';

export default class CandidateIntake extends LightningElement {
    // State management for form fields and UI
    @track firstName = '';
    @track lastName = '';
    @track email = '';
    @track currentStep = 'name'; // 'name', 'email', 'finished'
    @track isLoading = false;
    transcript = [];

    // Step navigation
    get isStepName() { return this.currentStep === 'name'; }
    get isStepEmail() { return this.currentStep === 'email'; }
    get isFinished() { return this.currentStep === 'finished'; }

    // Input handlers
    handleFirstNameChange(event) { this.firstName = event.target.value; }
    handleLastNameChange(event) { this.lastName = event.target.value; }
    handleEmailChange(event) { this.email = event.target.value; }

    handleNextStep() {
        this.transcript.push({ user: 'Bot', text: 'What is your full name?' });
        this.transcript.push({ user: 'Candidate', text: `${this.firstName} ${this.lastName}` });
        this.currentStep = 'email';
    }

    // Call Apex to submit data
    async handleSubmit() {
        this.isLoading = true;
        this.transcript.push({ user: 'Bot', text: 'What is your best email address?' });
        this.transcript.push({ user: 'Candidate', text: this.email });

        try {
            await processIntake({
                firstName: this.firstName,
                lastName: this.lastName,
                email: this.email,
                transcript: JSON.stringify(this.transcript)
            });
            this.currentStep = 'finished';
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body.message,
                variant: 'error'
            }));
        } finally {
            this.isLoading = false;
        }
    }
}