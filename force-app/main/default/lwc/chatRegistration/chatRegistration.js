import { LightningElement, track } from 'lwc';
import startConversation from '@salesforce/apex/CandidateIntakeController.startConversation';
import processMessage from '@salesforce/apex/CandidateIntakeController.processMessage';

export default class ChatRegistration extends LightningElement {
    @track messages = [];
    @track userInput = '';
    @track candidateId;
    @track isLoading = false;
    messageCounter = 0;

    connectedCallback() {
        this.isLoading = true;
        startConversation()
            .then(result => {
                this.candidateId = result;
                this.addMessage('Welcome to our onboarding portal! To get started, please tell me your full name.', 'bot');
            })
            .catch(error => {
                this.addMessage('Error starting conversation: ' + error.body.message, 'bot');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleInputChange(event) {
        this.userInput = event.target.value;
    }

    handleKeyDown(event) {
        if (event.keyCode === 13) {
            this.handleSendMessage();
        }
    }

    handleSendMessage() {
        if (!this.userInput | this.isLoading) {
            return;
        }

        this.isLoading = true;
        this.addMessage(this.userInput, 'user');
        const messageToSend = this.userInput;
        this.userInput = '';

        processMessage({ message: messageToSend, candidateIdStr: this.candidateId })
            .then(result => {
                this.addMessage(result.response, 'bot');
            })
            .catch(error => {
                this.addMessage('An error occurred: ' + error.body.message, 'bot');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    addMessage(text, sender) {
        this.messageCounter++;
        this.messages = [...this.messages, {
            id: this.messageCounter,
            text: text,
            style: sender === 'bot' ? 'slds-chat-listitem slds-chat-listitem_inbound' : 'slds-chat-listitem slds-chat-listitem_outbound'
        }];
    }
}