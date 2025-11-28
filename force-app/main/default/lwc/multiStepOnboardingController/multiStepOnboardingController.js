import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import findCandidateByEmail from '@salesforce/apex/MultiStepOnboardingController.findCandidateByEmail';
import processCandidateDetails from '@salesforce/apex/MultiStepOnboardingController.processCandidateDetails';
import initiateDocumentProcessing from '@salesforce/apex/MultiStepOnboardingController.initiateDocumentProcessing';
import getNextChatResponse from '@salesforce/apex/MultiStepOnboardingController.getNextChatResponse';

export default class MultiStepOnboardingController extends LightningElement {
    // --- View & State Management ---
    @track currentView = 'chat'; // 'chat' or 'form'
    @track currentStep = '1';
    @track isLoading = false;
    @track candidateId;
    @track isExistingCandidate = false;

    // --- Chat Properties ---
    @track conversationHistory = [];
    @track currentMessage = '';
    @track isBotTyping = false;
    chatCurrentStep = 'start';
    chatCandidateData = {};

    // --- Form Properties ---
    @track firstName = '';
    @track lastName = '';
    @track email = '';
    @track phone = '';
    @track streetAddress = '';
    @track city = '';
    @track state = '';
    @track zipCode = '';
    @track emergencyContactName = '';
    @track emergencyContactPhone = '';

    // --- Getters ---
    get isChatView() {
        return this.currentView === 'chat';
    }
    get isFormView() {
        return this.currentView === 'form';
    }
    get isStep1() {
        return this.currentStep === '1';
    }
    get isStep2() {
        return this.currentStep === '2';
    }
    get isStep3() {
        return this.currentStep === '3';
    }
    get isStep4() {
        return this.currentStep === '4';
    }
    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg'];
    }
    
    /**
     * Controls the disabled state of the submit button on Step 2.
     * Disables if it's an existing candidate OR if required fields are empty.
     */
    get isSubmitDisabled() {
        if (this.isExistingCandidate) {
            return true;
        }
        return !(this.phone && this.streetAddress && this.city && this.state && this.zipCode && this.emergencyContactName && this.emergencyContactPhone);
    }

    // --- Lifecycle Hook ---
    connectedCallback() {
        this.addBotMessage('Hello! To begin, what is your first name?');
    }

    // --- View Switching ---
    switchToFormView() {
        this.currentView = 'form';
    }

    // --- Chat Logic ---
    handleChatChange(event) {
        this.currentMessage = event.target.value;
    }

    handleChatKeyDown(event) {
        if (event.keyCode === 13) this.handleChatSend();
    }

    handleChatSend() {
        if (!this.currentMessage || this.isBotTyping) return;
        const userReply = this.currentMessage;
        this.addUserMessage(userReply);
        this.currentMessage = '';
        this.isBotTyping = true;
        this.updateCandidateData(this.chatCurrentStep, userReply);

        getNextChatResponse({ currentStepKey: this.chatCurrentStep, userResponse: userReply, collectedData: this.chatCandidateData })
            .then(result => {
                this.addBotMessage(result.botMessage);
                this.chatCurrentStep = result.nextStepKey;

                if (this.chatCurrentStep === 'registration_complete') {
                    this.submitChatRegistration();
                } else if (this.chatCurrentStep === 'start') {
                    this.chatCandidateData = {};
                }
            })
            .catch(error => {
                this.addBotMessage('Sorry, an error occurred. Please try again.');
                console.error('Chat Error:', error);
            })
            .finally(() => {
                this.isBotTyping = false;
            });
    }

    updateCandidateData(step, value) {
        if (step === 'start') this.chatCandidateData.firstName = value;
        else if (step === 'getLastName') this.chatCandidateData.lastName = value;
        // Extend this as your chat flow grows
    }
    
    submitChatRegistration() {
        this.isLoading = true;
        const payload = {
            firstName: this.chatCandidateData.firstName,
            lastName: this.chatCandidateData.lastName,
            email: this.chatCandidateData.email,
            transcript: JSON.stringify(this.conversationHistory)
        };

        processCandidateDetails({ payload: payload })
            .then(candidateId => {
                this.candidateId = candidateId;
                this.firstName = this.chatCandidateData.firstName;
                this.lastName = this.chatCandidateData.lastName;
                this.email = this.chatCandidateData.email;

                setTimeout(() => {
                    this.goToStep('2');
                    this.switchToFormView();
                }, 1500);
            })
            .catch(error => {
                this.addBotMessage('Sorry, there was an error registering. Please use the form instead.');
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    addBotMessage(text) {
        if (!text) return;
        this.conversationHistory = [...this.conversationHistory, { id: this.conversationHistory.length + 1, text, cssClass: 'slds-chat-listitem slds-chat-listitem_inbound' }];
    }

    addUserMessage(text) {
        this.conversationHistory = [...this.conversationHistory, { id: this.conversationHistory.length + 1, text, cssClass: 'slds-chat-listitem slds-chat-listitem_outbound' }];
    }

    // --- Multi-Step Form Logic ---
    handleChange(event) {
        this[event.target.name] = event.target.value;
    }

    goToStep(step) {
        this.currentStep = step;
    }

    handleEmailBlur(event) {
        const email = event.target.value;
        this.isExistingCandidate = false;
        if (!email) return;

        this.isLoading = true;
        findCandidateByEmail({ email: email })
            .then(result => {
                if (result) {
                    this.isExistingCandidate = true;
                    this.candidateId = result.Id;
                    this.firstName = result.FirstName__c || '';
                    this.lastName = result.LastName__c || '';
                    this.phone = result.Phone__c || '';
                    this.streetAddress = result.Street_Address__c || '';
                    this.city = result.City__c || '';
                    this.state = result.State__c || '';
                    this.zipCode = result.Zip_Code__c || '';
                    this.emergencyContactName = result.Emergency_Contact_Name__c || '';
                    this.emergencyContactPhone = result.Emergency_Contact_Phone__c || '';

                    this.showToast('Record Found', `Welcome back, ${this.firstName}. Please review your details.`, 'info');
                    this.goToStep('2');
                }
            })
            .catch(error => console.error('Error finding candidate:', error))
            .finally(() => {
                this.isLoading = false;
            });
    }

    validateFields() {
        return [...this.template.querySelectorAll('lightning-input, lightning-textarea')]
            .reduce((valid, input) => {
                input.reportValidity();
                return valid && input.checkValidity();
            }, true);
    }

    handleNextStep1() {
        if (this.validateFields()) this.goToStep('2');
    }

    handlePreviousStep2() {
        this.goToStep('1');
    }

    handleDetailsSubmit() {
        if (this.isSubmitDisabled) return;

        if (!this.validateFields()) {
            this.showToast('Error', 'Please complete all required fields.', 'error');
            return;
        }
        
        this.isLoading = true;
        const payload = {
            firstName: this.firstName,
            lastName: this.lastName,
            email: this.email,
            phone: this.phone,
            transcript: 'Onboarding submission via multi-step form.',
            streetAddress: this.streetAddress,
            city: this.city,
            state: this.state,
            zipCode: this.zipCode,
            emergencyContactName: this.emergencyContactName,
            emergencyContactPhone: this.emergencyContactPhone
        };

        processCandidateDetails({ payload: payload })
            .then(result => {
                this.candidateId = result;
                this.showToast('Success', 'Details submitted successfully!', 'success');
                this.goToStep('3');
            })
            .catch(error => this.showToast('Error Submitting Details', error.body.message, 'error'))
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleUploadFinished(event) {
        this.isLoading = true;
        const promises = event.detail.files.map(file =>
            initiateDocumentProcessing({
                candidateId: this.candidateId,
                contentDocumentId: file.documentId
            })
        );

        Promise.all(promises)
            .then(() => this.showToast('Success', `${event.detail.files.length} document(s) uploaded.`, 'success'))
            .catch(error => this.showToast('Document Upload Error', error.body.message, 'error'))
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleFinish() {
        this.goToStep('4');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
