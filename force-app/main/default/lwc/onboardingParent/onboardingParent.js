import { LightningElement, track } from 'lwc';

export default class OnboardingParent extends LightningElement {
    @track currentStep = 1;

    // This method is called when the 'wizardstep' event is received.
    handleWizardStep(event) {
        // 1. Access the data from the event's 'detail' property.
        const action = event.detail.action;

        // 2. Perform logic based on the action received.
        if (action === 'next') {
            this.currentStep++;
            console.log('Moving to the next step:', this.currentStep);
        } else if (action === 'prev') {
            if (this.currentStep > 1) {
                this.currentStep--;
                console.log('Moving to the previous step:', this.currentStep);
            }
        }
    }
}
