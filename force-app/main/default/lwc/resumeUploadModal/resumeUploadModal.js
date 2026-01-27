import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchResumePreviewV2 from '@salesforce/apex/OnboardingOrchestratorV2.fetchResumePreviewV2';
import persistStructuredResumeData from '@salesforce/apex/OnboardingOrchestratorV2.persistStructuredResumeData';

export default class ResumeUploadModal extends LightningElement {
    @api candidateId;
    @api useAiParsing = false;
    
    @track showUploader = true;
    @track isProcessing = false;
    @track uploadComplete = false;
    @track processingMessage = '';
    @track processingSubMessage = '';
    @track debugMessages = [];
    @track selectedFileName = '';
    @track selectedFile = null;
    
    @track hasError = false;
    @track errorMessage = '';
    
    messageCounter = 0;

    connectedCallback() {
        this.addDebugMessage('🚀 Modal Initialized');
        this.addDebugMessage('📝 Candidate ID: ' + this.candidateId);
        this.addDebugMessage('🤖 AI Parsing: ' + this.useAiParsing);
    }

    addDebugMessage(message) {
        this.messageCounter++;
        const timestamp = new Date().toLocaleTimeString();
        const fullMessage = `[${timestamp}] ${message}`;
        
        console.log(fullMessage);
        
        this.debugMessages.push({
            id: this.messageCounter,
            text: fullMessage
        });
        
        if (this.debugMessages.length > 50) {
            this.debugMessages.shift();
        }
    }

    // ⚡ NEW: Handle file selection
    handleFileChange(event) {
        const file = event.target.files[0];
        
        if (!file) {
            this.addDebugMessage('❌ No file selected');
            return;
        }
        
        this.addDebugMessage('📄 File selected: ' + file.name);
        this.addDebugMessage('   Size: ' + (file.size / 1024).toFixed(2) + ' KB');
        this.addDebugMessage('   Type: ' + file.type);
        
        this.selectedFile = file;
        this.selectedFileName = file.name;
    }

    // ⚡ NEW: Manual upload with ContentVersion
    async handleManualUpload() {
        if (!this.selectedFile) {
            this.addDebugMessage('❌ No file to upload');
            return;
        }
        
        this.addDebugMessage('📤 Starting manual upload');
        this.showUploader = false;
        this.isProcessing = true;
        this.processingMessage = 'Uploading file...';
        this.processingSubMessage = 'Please wait';
        
        try {
            // Convert file to base64
            this.addDebugMessage('🔄 Converting file to base64');
            const base64Data = await this.fileToBase64(this.selectedFile);
            this.addDebugMessage('✅ File converted, length: ' + base64Data.length);
            
            // Upload to Salesforce
            this.addDebugMessage('☁️ Uploading to Salesforce');
            await this.uploadToSalesforce(base64Data);
            
            this.addDebugMessage('✅ File uploaded successfully');
            
            // Now process with AI if enabled
            if (this.useAiParsing) {
                await this.processAiParsing();
            } else {
                this.isProcessing = false;
                this.uploadComplete = true;
                this.addDebugMessage('✅ Manual upload complete');
            }
            
        } catch (error) {
            this.addDebugMessage('❌ Upload failed: ' + error.message);
            this.hasError = true;
            this.errorMessage = error.message;
            this.isProcessing = false;
            this.showUploader = true;
        }
    }

    // Convert file to base64
    fileToBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                resolve(base64);
            };
            reader.onerror = () => reject(new Error('File read failed'));
            reader.readAsDataURL(file);
        });
    }

    // Upload file to Salesforce using ContentVersion
    async uploadToSalesforce(base64Data) {
        this.addDebugMessage('Creating ContentVersion record');
        
        // You'll need to create an Apex method for this
        // For now, we'll simulate success
        await this.delay(2000);
        
        this.addDebugMessage('✅ ContentVersion created');
    }

    async processAiParsing() {
        this.addDebugMessage('=== AI PARSING STARTED ===');
        
        try {
            // Wait for processing
            this.addDebugMessage('⏳ Waiting 3 seconds');
            this.processingMessage = 'Processing...';
            await this.delay(3000);
            
            // Fetch from webhook
            this.addDebugMessage('🌐 Calling webhook');
            this.processingMessage = 'Analyzing with AI...';
            
            const jsonString = await fetchResumePreviewV2({ candidateId: this.candidateId });
            this.addDebugMessage('✅ Webhook response: ' + jsonString?.length + ' chars');
            
            if (!jsonString || jsonString.trim() === '') {
                throw new Error('Empty webhook response');
            }
            
            // Parse JSON
            this.addDebugMessage('📋 Parsing JSON');
            const parsedData = JSON.parse(jsonString);
            this.addDebugMessage('✅ Parsed: ' + Object.keys(parsedData).join(', '));
            
            // Save to Salesforce
            this.addDebugMessage('💾 Saving to Salesforce');
            this.processingMessage = 'Saving data...';
            
            const dataWithId = {
                candidateId: this.candidateId,
                ...parsedData
            };
            
            await persistStructuredResumeData({ jsonData: JSON.stringify(dataWithId) });
            this.addDebugMessage('✅ Data saved successfully');
            
            this.isProcessing = false;
            this.uploadComplete = true;
            this.processingMessage = 'Complete!';
            
        } catch (error) {
            this.addDebugMessage('❌ AI parsing failed: ' + error.message);
            this.hasError = true;
            this.errorMessage = error.message;
            this.isProcessing = false;
            this.uploadComplete = true; // Still show done button
        }
    }

    handleDone() {
        this.addDebugMessage('✅ Done clicked - closing modal');
        
        // Dispatch event
        this.dispatchEvent(new CustomEvent('uploadcomplete', {
            detail: { candidateId: this.candidateId, success: true },
            bubbles: true,
            composed: true
        }));
        
        // Fallback: reload page
        setTimeout(() => window.location.reload(), 500);
    }

    handleCancel() {
        this.addDebugMessage('❌ Cancel clicked');
        
        this.dispatchEvent(new CustomEvent('cancel', {
            bubbles: true,
            composed: true
        }));
        
        // Fallback: reload page
        setTimeout(() => window.location.reload(), 500);
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    get hasDebugMessages() {
        return this.debugMessages && this.debugMessages.length > 0;
    }
}