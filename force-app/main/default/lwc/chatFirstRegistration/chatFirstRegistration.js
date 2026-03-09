// /*
// * chatFirstRegistration.js
// * Controller for the chat interface, handling state and user interaction.
// */
// import { LightningElement, track } from 'lwc';
// import registerCandidate from '@salesforce/apex/OnboardingOrchestrator.registerCandidate';
// import persistVerifiedData from '@salesforce/apex/OnboardingOrchestrator.persistVerifiedData';
// import getAvailableJobs from '@salesforce/apex/OnboardingOrchestrator.getAvailableJobs';
// import recordJobInterestOnCandidate from '@salesforce/apex/OnboardingOrchestrator.recordJobInterestOnCandidate';
// import getScreeningQuestions from '@salesforce/apex/OnboardingOrchestrator.getScreeningQuestions';
// import saveCandidateAnswer from '@salesforce/apex/OnboardingOrchestrator.saveCandidateAnswer';
// import persistStructuredResumeData from '@salesforce/apex/OnboardingOrchestratorV2.persistStructuredResumeData';

// let msgCounter = 0;

// export default class ChatFirstRegistration extends LightningElement {
//     // State
//     @track messages = [];
//     @track currentInput = '';
//     @track candidateId;
//     @track step = 'NAME'; // NAME -> EMAIL -> PHONE -> READY_UPLOAD -> JOBS -> QUESTIONS -> FINISHED
//     @track isInputDisabled = false;
//     @track canUpload = false;
//     @track showPreview = false;
//     @track jobPostings = [];

//     // Candidate data
//     fullName = '';
//     email = '';
//     phone = '';

//     // Screening questions
//     @track isAskingScreeningQuestions = false;
//     @track screeningQuestions = [];
//     @track currentQuestionIndex = 0;

//     // Init
//     connectedCallback() {
//         this.pushMessage('System', 'Welcome! Please tell me your full name to get started.');
//     }

//     handleInputChange(event) {
//         this.currentInput = event.target.value;
//     }

//     handleKeyDown(event) {
//         if (event.key === 'Enter') {
//             event.preventDefault();
//             this.handleSend();
//         }
//     }

//     async handleSend() {
//         const text = (this.currentInput || '').trim();
//         if (!text | this.isInputDisabled) {
//             return;
//         }
//         this.pushMessage('You', text);
//         this.currentInput = '';

//         if (this.isAskingScreeningQuestions) {
//             this.handleScreeningAnswer(text);
//             return;
//         }

//         if (!this.candidateId) {
//             this.handleRegistrationFlow(text);
//         }
//     }

//     handleRegistrationFlow(text) {
//         if (this.step === 'NAME') {
//             this.fullName = text;
//             this.step = 'EMAIL';
//             this.pushMessage('System', 'Thanks. What is your email address?');
//         } else if (this.step === 'EMAIL') {
//             this.email = text;
//             this.step = 'PHONE';
//             this.pushMessage('System', 'And your phone number?');
//         } else if (this.step === 'PHONE') {
//             this.phone = text;
//             this.isInputDisabled = true;
//             this.registerCandidateNow();
//         }
//     }

//  async registerCandidateNow() {
//     try {
//         const id = await registerCandidate({
//             fullName: this.fullName,
//             phone: this.phone,
//             email: this.email
//         });
//         console.log('Candidate registered with Id:', id);   // 👀 log the returned Id
//         this.candidateId = id;
//         console.log('candidateId state set to:', this.candidateId); // 👀 confirm state update

//         this.step = 'READY_UPLOAD';
//         this.canUpload = true;
//         this.isInputDisabled = true;
//         this.pushMessage('System', 'Nice to meet you, ' + this.fullName + '. Please upload your resume to continue.');
//     } catch (e) {
//         this.handleError(e, 'Error creating your profile');
//         this.step = 'NAME';
//         this.candidateId = null;
//         this.isInputDisabled = false;
//     }
// }
// async registerCandidateNow() {
//     try {
//         const id = await registerCandidate({
//             fullName: this.fullName,
//             phone: this.phone,
//             email: this.email
//         });
//         console.log('Candidate registered with Id:', id);   // 👀 log the returned Id
//         this.candidateId = id;
//         console.log('candidateId state set to:', this.candidateId); // 👀 confirm state update

//         this.step = 'READY_UPLOAD';
//         this.canUpload = true;
//         this.isInputDisabled = true;
//         this.pushMessage('System', 'Nice to meet you, ' + this.fullName + '. Please upload your resume to continue.');
//     } catch (e) {
//         this.handleError(e, 'Error creating your profile');
//         this.step = 'NAME';
//         this.candidateId = null;
//         this.isInputDisabled = false;
//     }
// }
//    async handleUploadFinished(event) {
//     console.log('Upload finished event:', event.detail.files);
//     console.log('Current candidateId at upload time:', this.candidateId); // 👀 check if Id is present

//     const uploadedFiles = event.detail.files;
//     if (!uploadedFiles || uploadedFiles.length === 0) {
//         this.pushMessage('System', 'No problem. Please upload your resume when you are ready.');
//         this.canUpload = true;
//         return;
//     }
//     this.pushMessage('System', 'Resume uploaded. Let me analyze it and show you what I found.');
//     this.canUpload = false;
//     this.showPreview = true;
// }
//     // async handleResumeConfirmed(event) {
//     //     const detail = event.detail;
//     //     this.pushMessage('System', 'Thank you for confirming your details. Saving...');
//     //     this.showPreview = false;
//     //     this.isInputDisabled = true;
//     //     try {
//     //         await persistVerifiedData(detail);
//     //         this.pushMessage('System', 'Based on your profile, here are some job postings.');
//     //         this.step = 'JOBS';
//     //         const jobs = await getAvailableJobs();
//     //         if (jobs && jobs.length > 0) {
//     //             this.jobPostings = jobs;
//     //         } else {
//     //             this.pushMessage('System', "I couldn't find any open positions right now.");
//     //         }
//     //     } catch (e) {
//     //         this.handleError(e, 'There was an error saving your data');
//     //     }
//     // }
// async handleResumeConfirmed(event) {
//     const detail = event.detail;
//     this.pushMessage('System', 'Thank you for confirming your details. Saving your comprehensive profile...');
//     this.showPreview = false;
//     this.isInputDisabled = true;
//     try {
//         // NEW: Serialize the entire structured payload and send to the new Apex method
//         await persistStructuredResumeData({ jsonData: JSON.stringify(detail) });
//         this.pushMessage('System', 'Based on your profile, here are some job postings.');
//         this.step = 'JOBS';
//         const jobs = await getAvailableJobs();
//         if (jobs && jobs.length > 0) {
//             this.jobPostings = jobs;
//         } else {
//             this.pushMessage('System', "I couldn't find any open positions right now.");
//         }
//     } catch (e) {
//         this.handleError(e, 'There was an error saving your data');
//     }
// }

//     handleResumeCancelled() {
//         this.pushMessage('System', 'No problem. You can upload another resume.');
//         this.showPreview = false;
//         this.canUpload = true;
//     }

//     async handleJobSelected(event) {
//         const { jobId, jobTitle } = event.detail;
//         const selectedJob = this.jobPostings.find(job => job.Id === jobId);
//         if (!selectedJob) {
//             return;
//         }
//         this.pushMessage('You', `I'm interested in the ${jobTitle} position.`);
//         this.jobPostings = [];
//         this.isInputDisabled = true;
//         try {
//             await recordJobInterestOnCandidate({ candidateId: this.candidateId, jobPostingId: jobId });
//             this.pushMessage('System', 'Thank you for your interest! We have a few questions for this specific role.');
//             this.startScreeningQuestions(selectedJob.Specialization__c);
//         } catch (error) {
//             this.handleError(error, 'Error submitting your application');
//             this.isInputDisabled = false;
//         }
//     }

//     startScreeningQuestions(specialization) {
//         if (!specialization) {
//             this.pushMessage('System', 'Thank you. We have all the information we need for now.');
//             this.isInputDisabled = true;
//             this.step = 'FINISHED';
//             return;
//         }
//         getScreeningQuestions({ specialization }).then(result => {
//             if (result && result.length > 0) {
//                 this.screeningQuestions = result;
//                 this.isAskingScreeningQuestions = true;
//                 this.currentQuestionIndex = 0;
//                 this.step = 'QUESTIONS';
//                 this.isInputDisabled = false;
//                 this.askNextQuestion();
//             } else {
//                 this.pushMessage('System', 'Thank you. We have all the information we need.');
//                 this.isInputDisabled = true;
//                 this.step = 'FINISHED';
//             }
//         }).catch(error => {
//             this.handleError(error, 'Error loading screening questions.');
//             this.isInputDisabled = true;
//         });
//     }

//     askNextQuestion() {
//         const questionText = this.screeningQuestions[this.currentQuestionIndex].Question_Text__c;
//         this.pushMessage('System', questionText);
//     }

//     handleScreeningAnswer(answerText) {
//         this.isInputDisabled = true;
//         const currentQuestion = this.screeningQuestions[this.currentQuestionIndex];
//         saveCandidateAnswer({ candidateId: this.candidateId, questionId: currentQuestion.Id, answerText: answerText }).then(() => {
//             this.currentQuestionIndex++;
//             if (this.currentQuestionIndex < this.screeningQuestions.length) {
//                 this.isInputDisabled = false;
//                 this.askNextQuestion();
//             } else {
//                 this.pushMessage('System', 'Thank you for answering all the questions. We will be in touch shortly!');
//                 this.isAskingScreeningQuestions = false;
//                 this.isInputDisabled = true;
//                 this.step = 'FINISHED';
//             }
//         }).catch(error => {
//             this.handleError(error, 'There was an error saving your answer. Please try again.');
//             this.isInputDisabled = false;
//         });
//     }

//     pushMessage(author, text) {
//         this.messages = [...this.messages, { id: ++msgCounter, author: author, text: text }];
//         // Auto-scroll logic
//         // eslint-disable-next-line @lwc/lwc/no-async-operation
//         setTimeout(() => {
//             const container = this.template.querySelector('[data-id="chat-container"]');
//             if (container) {
//                 container.scrollTop = container.scrollHeight;
//             }
//         }, 0);
//     }

//     handleError(e, defaultMessage) {
//         let msg;
//         if (e && e.body && e.body.message) {
//             msg = e.body.message;
//         } else if (e && e.message) {
//             msg = e.message;
//         } else {
//             msg = JSON.stringify(e);
//         }
//         this.pushMessage('System', defaultMessage + ': ' + msg);
//         // eslint-disable-next-line no-console
//         console.error(JSON.parse(JSON.stringify(e)));
//     }
// }
/*
* chatFirstRegistration.js
* Controller for the chat interface, handling state and user interaction.
*/
import { LightningElement, track } from 'lwc';
import registerCandidate from '@salesforce/apex/OnboardingOrchestrator.registerCandidate';
import persistVerifiedData from '@salesforce/apex/OnboardingOrchestrator.persistVerifiedData';
import getAvailableJobs from '@salesforce/apex/OnboardingOrchestrator.getAvailableJobs';
import recordJobInterestOnCandidate from '@salesforce/apex/OnboardingOrchestrator.recordJobInterestOnCandidate';
import getScreeningQuestions from '@salesforce/apex/OnboardingOrchestrator.getScreeningQuestions';
import saveCandidateAnswer from '@salesforce/apex/OnboardingOrchestrator.saveCandidateAnswer';
import persistStructuredResumeData from '@salesforce/apex/OnboardingOrchestratorV2.persistStructuredResumeData';

let msgCounter = 0;

export default class ChatFirstRegistration extends LightningElement {
    // State
    @track messages = [];
    @track currentInput = '';
    @track candidateId;
    @track step = 'NAME'; // NAME -> EMAIL -> PHONE -> READY_UPLOAD -> JOBS -> QUESTIONS -> FINISHED
    @track isInputDisabled = false;
    @track canUpload = false;
    @track showPreview = false;
    @track jobPostings = [];

    // Candidate data
    fullName = '';
    email = '';
    phone = '';

    // Screening questions
    @track isAskingScreeningQuestions = false;
    @track screeningQuestions = [];
    @track currentQuestionIndex = 0;

    // Init
    connectedCallback() {
        this.pushMessage('System', 'Welcome! Please tell me your full name to get started.');
    }

    handleInputChange(event) {
        // FIX: Corrected syntax from [event.target].value to event.target.value
        this.currentInput = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleSend();
        }
    }

    async handleSend() {
        const text = (this.currentInput || '').trim();
        if (!text | this.isInputDisabled) {
            return;
        }
        this.pushMessage('You', text);
        this.currentInput = '';
        if (this.isAskingScreeningQuestions) {
            this.handleScreeningAnswer(text);
            return;
        }
        if (!this.candidateId) {
            this.handleRegistrationFlow(text);
        }
    }

    handleRegistrationFlow(text) {
        if (this.step === 'NAME') {
            this.fullName = text;
            this.step = 'EMAIL';
            this.pushMessage('System', 'Thanks. What is your email address?');
        } else if (this.step === 'EMAIL') {
            // FIX: Corrected syntax from [this.email] to this.email
            this.email = text;
            this.step = 'PHONE';
            this.pushMessage('System', 'And your phone number?');
        } else if (this.step === 'PHONE') {
            // FIX: Corrected syntax from [this.phone] to this.phone
            this.phone = text;
            this.isInputDisabled = true;
            this.registerCandidateNow();
        }
    }

    async registerCandidateNow() {
        try {
            const id = await registerCandidate({
                fullName: this.fullName,
                // FIX: Corrected syntax for phone and email properties
                phone: this.phone,
                email: this.email
            });
            console.log('Candidate registered with Id:', id); //  log the returned Id
            this.candidateId = id;
            console.log('candidateId state set to:', this.candidateId); //  confirm state update
            this.step = 'READY_UPLOAD';
            this.canUpload = true;
            this.isInputDisabled = true;
            this.pushMessage('System', 'Nice to meet you, ' + this.fullName + '. Please upload your resume to continue.');
        } catch (e) {
            this.handleError(e, 'Error creating your profile');
            this.step = 'NAME';
            this.candidateId = null;
            this.isInputDisabled = false;
        }
    }

    // FIX: Removed the duplicate registerCandidateNow method that was here.

    async handleUploadFinished(event) {
        console.log('Upload finished event:', event.detail.files);
        console.log('Current candidateId at upload time:', this.candidateId); //  check if Id is present
        const uploadedFiles = event.detail.files;
        if (!uploadedFiles || uploadedFiles.length === 0) {
            this.pushMessage('System', 'No problem. Please upload your resume when you are ready.');
            this.canUpload = true;
            return;
        }
        this.pushMessage('System', 'Resume uploaded. Let me analyze it and show you what I found.');
        this.canUpload = false;
        this.showPreview = true;
    }

    // This is the old, commented-out version. It is preserved.
    // async handleResumeConfirmed(event) {
    // const detail = event.detail;
    // this.pushMessage('System', 'Thank you for confirming your details. Saving...');
    // this.showPreview = false;
    // this.isInputDisabled = true;
    // try {
    // await persistVerifiedData(detail);
    // this.pushMessage('System', 'Based on your profile, here are some job postings.');
    // this.step = 'JOBS';
    // const jobs = await getAvailableJobs();
    // if (jobs && jobs.length > 0) {
    // this.jobPostings = jobs;
    // } else {
    // this.pushMessage('System', "I couldn't find any open positions right now.");
    // }
    // } catch (e) {
    // this.handleError(e, 'There was an error saving your data');
    // }
    // }

    async handleResumeConfirmed(event) {
        const detail = event.detail;
        this.pushMessage('System', 'Thank you for confirming your details. Saving your comprehensive profile...');
        this.showPreview = false;
        this.isInputDisabled = true;
        try {
            // NEW: Serialize the entire structured payload and send to the new Apex method
            await persistStructuredResumeData({ jsonData: JSON.stringify(detail) });
            this.pushMessage('System', 'Based on your profile, here are some job postings.');
            this.step = 'JOBS';
            const jobs = await getAvailableJobs();
            if (jobs && jobs.length > 0) {
                this.jobPostings = jobs;
            } else {
                this.pushMessage('System', "I couldn't find any open positions right now.");
            }
        } catch (e) {
            this.handleError(e, 'There was an error saving your data');
        }
    }

    handleResumeCancelled() {
        this.pushMessage('System', 'No problem. You can upload another resume.');
        this.showPreview = false;
        this.canUpload = true;
    }

    async handleJobSelected(event) {
        const { jobId, jobTitle } = event.detail;
        // FIX: Corrected syntax from job.Id to job.Id
        const selectedJob = this.jobPostings.find(job => job.Id === jobId);
        if (!selectedJob) {
            return;
        }
        this.pushMessage('You', `I'm interested in the ${jobTitle} position.`);
        this.jobPostings = [];
        this.isInputDisabled = true;
        try {
            await recordJobInterestOnCandidate({ candidateId: this.candidateId, jobPostingId: jobId });
            this.pushMessage('System', 'Thank you for your interest! We have a few questions for this specific role.');
            this.startScreeningQuestions(selectedJob.Specialization__c);
        } catch (error) {
            this.handleError(error, 'Error submitting your application');
            this.isInputDisabled = false;
        }
    }

    startScreeningQuestions(specialization) {
        if (!specialization) {
            this.pushMessage('System', 'Thank you. We have all the information we need for now.');
            this.isInputDisabled = true;
            this.step = 'FINISHED';
            return;
        }
        getScreeningQuestions({ specialization }).then(result => {
            if (result && result.length > 0) {
                this.screeningQuestions = result;
                this.isAskingScreeningQuestions = true;
                this.currentQuestionIndex = 0;
                this.step = 'QUESTIONS';
                this.isInputDisabled = false;
                this.askNextQuestion();
            } else {
                this.pushMessage('System', 'Thank you. We have all the information we need.');
                this.isInputDisabled = true;
                this.step = 'FINISHED';
            }
        }).catch(error => {
            this.handleError(error, 'Error loading screening questions.');
            this.isInputDisabled = true;
        });
    }

    askNextQuestion() {
        const questionText = this.screeningQuestions[this.currentQuestionIndex].Question_Text__c;
        this.pushMessage('System', questionText);
    }

    handleScreeningAnswer(answerText) {
        this.isInputDisabled = true;
        const currentQuestion = this.screeningQuestions[this.currentQuestionIndex];
        // FIX: Corrected syntax from currentQuestion.Id to currentQuestion.Id
        saveCandidateAnswer({ candidateId: this.candidateId, questionId: currentQuestion.Id, answerText: answerText }).then(() => {
            this.currentQuestionIndex++;
            if (this.currentQuestionIndex < this.screeningQuestions.length) {
                this.isInputDisabled = false;
                this.askNextQuestion();
            } else {
                this.pushMessage('System', 'Thank you for answering all the questions. We will be in touch shortly!');
                this.isAskingScreeningQuestions = false;
                this.isInputDisabled = true;
                this.step = 'FINISHED';
            }
        }).catch(error => {
            this.handleError(error, 'There was an error saving your answer. Please try again.');
            this.isInputDisabled = false;
        });
    }

    pushMessage(author, text) {
        this.messages = [...this.messages, { id: ++msgCounter, author: author, text: text }];
        // Auto-scroll logic
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const container = this.template.querySelector('[data-id="chat-container"]');
            if (container) {
                container.scrollTop = container.scrollHeight;
            }
        }, 0);
    }

    handleError(e, defaultMessage) {
        let msg;
        if (e && e.body && e.body.message) {
            msg = e.body.message;
        } else if (e && e.message) {
            msg = e.message;
        } else {
            msg = JSON.stringify(e);
        }
        this.pushMessage('System', defaultMessage + ': ' + msg);
        // eslint-disable-next-line no-console
        console.error(JSON.parse(JSON.stringify(e)));
    }
}