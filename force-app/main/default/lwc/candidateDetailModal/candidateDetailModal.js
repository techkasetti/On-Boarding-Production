import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCandidateDetails from '@salesforce/apex/MedicalRecruitmentController.getCandidateDetails';
import updateApplicationStatus from '@salesforce/apex/MedicalRecruitmentController.updateApplicationStatus';
import getLicenseVerifications from '@salesforce/apex/MedicalRecruitmentController.getLicenseVerifications';
import updateLicenseVerification from '@salesforce/apex/MedicalRecruitmentController.updateLicenseVerification';
import createLicenseVerification from '@salesforce/apex/MedicalRecruitmentController.createLicenseVerification';
import getInterviewDetails from '@salesforce/apex/MedicalRecruitmentController.getInterviewDetails';
import updateInterviewDetail from '@salesforce/apex/MedicalRecruitmentController.updateInterviewDetail';
import createInterviewDetail from '@salesforce/apex/MedicalRecruitmentController.createInterviewDetail';

export default class CandidateDetailModal extends LightningElement {
    @api applicationId;
    
    @track candidateDetail;
    @track selectedStatus;
    @track originalStatus;
    @track isLoading = false;
    @track isSaving = false;
    @track timelineSteps = [];
    
    // Editing state
    @track editingStepId = null;
    @track editingStatus = '';
    @track editingNotes = '';
    @track isSavingStep = false;
    expandedStepValue = null;
    
    // License data
    @track licenseVerifications = [];
    @track currentLicenseId = null;
    
    // Interview data
    @track interviewDetails = [];
    @track currentInterviewId = null;
    
    stageFieldValues = {};
    ONBOARDING_STAGES = [
        {
            value: 'Application Received',
            label: 'Application Received',
            description: 'Initial application submitted and recorded',
            category: 'application'
        },
        {
            value: 'Eligibility Check In Progress',
            label: 'Eligibility Verification',
            description: 'Reviewing qualifications and requirements',
            category: 'eligibility'
        },
        {
            value: 'Eligibility Passed',
            label: 'Eligibility Cleared',
            description: 'Candidate meets all basic requirements',
            category: 'eligibility'
        },
        {
            value: 'License Verification Pending',
            label: 'License Verification',
            description: 'Validating medical licenses and certifications',
            category: 'license'
        },
        {
            value: 'License Verified',
            label: 'License Confirmed',
            description: 'All licenses verified and valid',
            category: 'license'
        },
        {
            value: 'Clinical Assessment Scheduled',
            label: 'Clinical Assessment',
            description: 'Evaluating clinical skills and competencies',
            category: 'clinical'
        },
        {
            value: 'Clinical Assessment Passed',
            label: 'Clinical Skills Verified',
            description: 'Clinical assessment successfully completed',
            category: 'clinical'
        },
        {
            value: 'Interview Scheduled',
            label: 'Interview Process',
            description: 'Conducting interviews with hiring team',
            category: 'interview'
        },
        {
            value: 'Interview Cleared',
            label: 'Interview Completed',
            description: 'Interview process successfully completed',
            category: 'interview'
        },
        {
            value: 'Background Check In Progress',
            label: 'Background Verification',
            description: 'Conducting background and reference checks',
            category: 'background'
        },
        {
            value: 'Background Check Cleared',
            label: 'Background Cleared',
            description: 'Background check successfully completed',
            category: 'background'
        },
        {
            value: 'Offer Released',
            label: 'Offer Extended',
            description: 'Employment offer sent to candidate',
            category: 'offer'
        },
        {
            value: 'Offer Accepted',
            label: 'Offer Accepted',
            description: 'Candidate accepted the offer',
            category: 'offer'
        },
        {
            value: 'Credentialing In Progress',
            label: 'Credentialing',
            description: 'Processing credentials and privileges',
            category: 'credentialing'
        },
        {
            value: 'Privileges Approved',
            label: 'Privileges Granted',
            description: 'Clinical privileges approved',
            category: 'credentialing'
        },
        {
            value: 'Medical Onboarding In Progress',
            label: 'Onboarding',
            description: 'Completing onboarding procedures',
            category: 'onboarding'
        },
        {
            value: 'Onboarding Completed',
            label: 'Onboarding Complete',
            description: 'All onboarding steps finalized',
            category: 'onboarding'
        },
        {
            value: 'Active – Allowed to Practice',
            label: 'Active',
            description: 'Fully credentialed and ready to practice',
            category: 'active'
        }
    ];

    FAILED_STATUSES = [
        'Eligibility Failed',
        'License Issue / Expired',
        'Clinical Assessment Failed',
        'Interview Rejected',
        'Background Check Failed',
        'Offer Declined'
    ];

    // Stage-specific fields mapping
    STAGE_FIELDS_MAP = {
        'License Verification Pending': {
            objectName: 'LicenseVerification__c',
            fields: [
                { label: 'License Number', apiName: 'LicenseNumber__c', type: 'text', required: true },
                { label: 'Issuing Authority', apiName: 'IssuingAuthority__c', type: 'text', required: true },
                { label: 'Expiration Date', apiName: 'ExpirationDate__c', type: 'date', required: true },
                { label: 'Provider', apiName: 'Provider__c', type: 'lookup', required: false },
                { label: 'Status', apiName: 'Status__c', type: 'picklist', required: true },
                { label: 'Name Match AI Decision', apiName: 'Name_Match_AI_Decision__c', type: 'picklist', required: false },
                { label: 'Name Match AI Score', apiName: 'Name_Match_AI_Score__c', type: 'number', required: false },
                { label: 'Requires Manual Review', apiName: 'Requires_Manual_Review__c', type: 'checkbox', required: false }
            ]
        },
        'License Verified': {
            objectName: 'LicenseVerification__c',
            fields: [
                { label: 'License Number', apiName: 'LicenseNumber__c', type: 'text', required: true },
                { label: 'Issuing Authority', apiName: 'IssuingAuthority__c', type: 'text', required: true },
                { label: 'Expiration Date', apiName: 'ExpirationDate__c', type: 'date', required: true },
                { label: 'Provider', apiName: 'Provider__c', type: 'lookup', required: false },
                { label: 'Status', apiName: 'Status__c', type: 'picklist', required: true },
                { label: 'Verification ID', apiName: 'Name', type: 'text', required: false, readonly: true },
                { label: 'Name Match AI Decision', apiName: 'Name_Match_AI_Decision__c', type: 'picklist', required: false },
                { label: 'Name On License', apiName: 'Name_On_License__c', type: 'text', required: false }
            ]
        },
        'License Issue / Expired': {
            objectName: 'LicenseVerification__c',
            fields: [
                { label: 'License Number', apiName: 'LicenseNumber__c', type: 'text', required: true },
                { label: 'Issuing Authority', apiName: 'IssuingAuthority__c', type: 'text', required: true },
                { label: 'Expiration Date', apiName: 'ExpirationDate__c', type: 'date', required: true },
                { label: 'Status', apiName: 'Status__c', type: 'picklist', required: true },
                { label: 'Name Match AI Reason', apiName: 'Name_Match_AI_Reason__c', type: 'textarea', required: false },
                { label: 'Requires Manual Review', apiName: 'Requires_Manual_Review__c', type: 'checkbox', required: false }
            ]
        },
        'Interview Scheduled': {
            objectName: 'Interview_Detail__c',
            fields: [
                { label: 'External Interviewer Name', apiName: 'External_Interviewer_Name__c', type: 'text', required: false },
                { label: 'External Interviewer Email', apiName: 'External_Interviewer_Email__c', type: 'email', required: false },
                { label: 'Interviewer (User)', apiName: 'Interviewer_User__c', type: 'lookup', required: false },
                { label: 'Interviewer Type', apiName: 'Interviewer_Type__c', type: 'picklist', required: true },
                { label: 'Meeting Type', apiName: 'Meeting_Type__c', type: 'picklist', required: true },
                { label: 'Interview Feedback', apiName: 'Feedback__c', type: 'textarea', required: false }
            ]
        },
        'Interview Cleared': {
            objectName: 'Interview_Detail__c',
            fields: [
                { label: 'Interview Detail Name', apiName: 'Name', type: 'text', required: false, readonly: true },
                { label: 'External Interviewer Name', apiName: 'External_Interviewer_Name__c', type: 'text', required: false },
                { label: 'External Interviewer Email', apiName: 'External_Interviewer_Email__c', type: 'email', required: false },
                { label: 'Interviewer (User)', apiName: 'Interviewer_User__c', type: 'lookup', required: false },
                { label: 'Interviewer Type', apiName: 'Interviewer_Type__c', type: 'picklist', required: true },
                { label: 'Meeting Type', apiName: 'Meeting_Type__c', type: 'picklist', required: true },
                { label: 'Interview Feedback', apiName: 'Feedback__c', type: 'textarea', required: true }
            ]
        },
        'Interview Rejected': {
            objectName: 'Interview_Detail__c',
            fields: [
                { label: 'External Interviewer Name', apiName: 'External_Interviewer_Name__c', type: 'text', required: false },
                { label: 'Interviewer (User)', apiName: 'Interviewer_User__c', type: 'lookup', required: false },
                { label: 'Interviewer Type', apiName: 'Interviewer_Type__c', type: 'picklist', required: true },
                { label: 'Meeting Type', apiName: 'Meeting_Type__c', type: 'picklist', required: true },
                { label: 'Interview Feedback', apiName: 'Feedback__c', type: 'textarea', required: true }
            ]
        }
    };

    statusOptions = [
        { label: 'Application Received', value: 'Application Received' },
        { label: 'Eligibility Check In Progress', value: 'Eligibility Check In Progress' },
        { label: 'Eligibility Failed', value: 'Eligibility Failed' },
        { label: 'Eligibility Passed', value: 'Eligibility Passed' },
        { label: 'License Verification Pending', value: 'License Verification Pending' },
        { label: 'License Verified', value: 'License Verified' },
        { label: 'License Issue / Expired', value: 'License Issue / Expired' },
        { label: 'Clinical Assessment Scheduled', value: 'Clinical Assessment Scheduled' },
        { label: 'Clinical Assessment Failed', value: 'Clinical Assessment Failed' },
        { label: 'Clinical Assessment Passed', value: 'Clinical Assessment Passed' },
        { label: 'Interview Scheduled', value: 'Interview Scheduled' },
        { label: 'Interview Rejected', value: 'Interview Rejected' },
        { label: 'Interview Cleared', value: 'Interview Cleared' },
        { label: 'Background Check In Progress', value: 'Background Check In Progress' },
        { label: 'Background Check Failed', value: 'Background Check Failed' },
        { label: 'Background Check Cleared', value: 'Background Check Cleared' },
        { label: 'Offer Released', value: 'Offer Released' },
        { label: 'Offer Accepted', value: 'Offer Accepted' },
        { label: 'Offer Declined', value: 'Offer Declined' },
        { label: 'Credentialing In Progress', value: 'Credentialing In Progress' },
        { label: 'Privileges Approved', value: 'Privileges Approved' },
        { label: 'Medical Onboarding In Progress', value: 'Medical Onboarding In Progress' },
        { label: 'Onboarding Completed', value: 'Onboarding Completed' },
        { label: 'Active – Allowed to Practice', value: 'Active – Allowed to Practice' }
    ];

    // Picklist options for stage-specific fields
    picklistOptions = {
        'Status__c': [
            { label: 'Active', value: 'Active' },
            { label: 'Pending', value: 'Pending' },
            { label: 'Expired', value: 'Expired' },
            { label: 'Verified', value: 'Verified' },
            { label: 'Failed', value: 'Failed' }
        ],
        'Name_Match_AI_Decision__c': [
            { label: 'Match', value: 'Match' },
            { label: 'No Match', value: 'No Match' },
            { label: 'Partial Match', value: 'Partial Match' },
            { label: 'Needs Review', value: 'Needs Review' }
        ],
        'Interviewer_Type__c': [
            { label: 'Internal', value: 'Internal' },
            { label: 'External', value: 'External' },
            { label: 'Panel', value: 'Panel' }
        ],
        'Meeting_Type__c': [
            { label: 'In-Person', value: 'In-Person' },
            { label: 'Virtual', value: 'Virtual' },
            { label: 'Phone', value: 'Phone' },
            { label: 'Hybrid', value: 'Hybrid' }
        ]
    };

    get educationCount() {
        return this.candidateDetail?.educations?.length || 0;
    }

    get licenseCount() {
        return this.candidateDetail?.licenses?.length || 0;
    }

    get experienceCount() {
        return this.candidateDetail?.experiences?.length || 0;
    }

    get clinicalSkillsCount() {
        return this.candidateDetail?.clinicalSkills?.length || 0;
    }

    get candidateInitials() {
        if (!this.candidateDetail) return '?';
        const name = this.candidateDetail.application.Candidate__r.Full_Name__c;
        if (!name) return '?';
        const parts = name.trim().split(' ');
        if (parts.length >= 2) {
            return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
        }
        return name.substring(0, 2).toUpperCase();
    }

    get currentStatusPillClass() {
        return this.getStatusPillClass(this.selectedStatus);
    }

    get hasScores() {
        return this.candidateDetail?.application.Eligibility_Score__c || 
               this.candidateDetail?.application.Screening_Score__c;
    }

    get hasProsCons() {
        return this.candidateDetail?.application.Eligibility_Pros__c || 
               this.candidateDetail?.application.Eligibility_Cons__c;
    }

    get completedStepsText() {
        const completed = this.timelineSteps.filter(s => s.isCompleted).length;
        const total = this.timelineSteps.length;
        return `${completed} of ${total} completed`;
    }

    get saveButtonLabel() {
        return this.isSavingStep ? 'Saving...' : 'Save Changes';
    }

    get hasStageFields() {
        return this.expandedStepValue && this.STAGE_FIELDS_MAP[this.expandedStepValue];
    }

    get stageFieldsTitle() {
        if (!this.hasStageFields) return 'Stage Details';
        const objectName = this.STAGE_FIELDS_MAP[this.expandedStepValue].objectName;
        
        if (objectName === 'LicenseVerification__c') {
            return 'License Verification Details';
        } else if (objectName === 'Interview_Detail__c') {
            return 'Interview Details';
        }
        return 'Stage Details';
    }

    get currentStageFields() {
        if (!this.hasStageFields) {
            console.log('No stage fields configured for:', this.expandedStepValue);
            return [];
        }
        
        const stageConfig = this.STAGE_FIELDS_MAP[this.expandedStepValue];
        const fields = stageConfig.fields;
        const objectName = stageConfig.objectName;
        
        console.log('Fields config:', fields);
        console.log('Object name:', objectName);
        
        // Get data based on object type
        let stageData = null;
        if (objectName === 'LicenseVerification__c') {
            stageData = this.licenseVerifications && this.licenseVerifications.length > 0 
                ? this.licenseVerifications[0] 
                : null;
            console.log('Using License data:', stageData);
        } else if (objectName === 'Interview_Detail__c') {
            stageData = this.interviewDetails && this.interviewDetails.length > 0 
                ? this.interviewDetails[0] 
                : null;
            console.log('Using Interview data:', stageData);
        }
        
        console.log('Stage data for fields:', stageData);
        
        // Add type detection flags and values for template conditionals
        const mappedFields = fields.map(field => {
            let fieldValue = '';
            
            // Get value from stage data or from edited values
            if (this.stageFieldValues[field.apiName] !== undefined) {
                fieldValue = this.stageFieldValues[field.apiName];
                console.log(`Field ${field.apiName} from stageFieldValues:`, fieldValue);
            } else if (stageData && stageData[field.apiName] !== undefined) {
                fieldValue = stageData[field.apiName];
                console.log(`Field ${field.apiName} from stageData:`, fieldValue);
                
                // Handle lookup fields (get name from relationship)
                if (field.type === 'lookup') {
                    if (field.apiName === 'Provider__c' && stageData.Provider__r) {
                        fieldValue = stageData.Provider__r.Name;
                    } else if (field.apiName === 'Interviewer_User__c' && stageData.Interviewer_User__r) {
                        fieldValue = stageData.Interviewer_User__r.Name;
                    }
                    console.log(`Lookup field resolved to:`, fieldValue);
                }
            } else {
                console.log(`Field ${field.apiName} has no value`);
            }
            
            return {
                ...field,
                value: fieldValue,
                options: field.type === 'picklist' ? this.picklistOptions[field.apiName] : undefined,
                isText: field.type === 'text' || field.type === 'lookup',
                isDate: field.type === 'date',
                isEmail: field.type === 'email',
                isNumber: field.type === 'number',
                isCheckbox: field.type === 'checkbox',
                isPicklist: field.type === 'picklist',
                isTextarea: field.type === 'textarea'
            };
        });
        
        console.log('Mapped fields with values:', mappedFields);
        return mappedFields;
    }

    connectedCallback() {
        this.loadCandidateDetails();
    }

    loadCandidateDetails() {
        this.isLoading = true;

        getCandidateDetails({ applicationId: this.applicationId })
            .then(result => {
                this.candidateDetail = result;
                this.selectedStatus = result.application.Status__c;
                this.originalStatus = result.application.Status__c;
                
                // Fetch both license and interview data for the candidate
                const candidateId = result.application.Candidate__c;
                console.log('Loading data for candidate:', candidateId);
                
                // Fetch license and interview data in parallel
                return Promise.all([
                    getLicenseVerifications({ candidateId: candidateId })
                        .catch(err => {
                            console.error('Error loading licenses:', err);
                            return [];
                        }),
                    getInterviewDetails({ candidateId: candidateId })
                        .catch(err => {
                            console.error('Error loading interviews:', err);
                            return [];
                        })
                ]);
            })
            .then(([licenses, interviews]) => {
                console.log('License data loaded:', licenses);
                console.log('Interview data loaded:', interviews);
                
                this.licenseVerifications = licenses || [];
                this.currentLicenseId = licenses && licenses.length > 0 ? licenses[0].Id : null;
                
                this.interviewDetails = interviews || [];
                this.currentInterviewId = interviews && interviews.length > 0 ? interviews[0].Id : null;
                
                console.log('Current license ID:', this.currentLicenseId);
                console.log('Current interview ID:', this.currentInterviewId);
                
                // Build timeline after data is loaded
                this.buildTimeline(this.selectedStatus, true);
                this.isLoading = false;
                
                // Auto-scroll to current step after render
                setTimeout(() => {
                    this.scrollToCurrentStep();
                }, 400);
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error loading data:', error);
                this.showToast('Error', 'Error loading candidate details: ' + (error.body?.message || error.message), 'error');
            });
    }

    buildTimeline(currentStatus, autoExpandCurrent = false) {
        const currentIndex = this.ONBOARDING_STAGES.findIndex(stage => stage.value === currentStatus);
        const isFailedStatus = this.FAILED_STATUSES.includes(currentStatus);
        
        this.timelineSteps = this.ONBOARDING_STAGES.map((stage, index) => {
            const isCompleted = index < currentIndex;
            const isCurrent = stage.value === currentStatus;
            const isPending = index > currentIndex;
            const isFailed = stage.value === currentStatus && isFailedStatus;
            const isLast = index === this.ONBOARDING_STAGES.length - 1;
            
            // Determine if this step should be expanded
            const shouldExpand = autoExpandCurrent && isCurrent;
            const isExpanded = this.expandedStepValue === stage.value || shouldExpand;
            
            let nodeClass = 'timeline-node';
            let connectorClass = 'timeline-connector';
            let containerClass = 'timeline-step';
            let icon = 'utility:record';
            
            if (isFailed) {
                nodeClass += ' node-failed';
                connectorClass += ' connector-failed';
                containerClass += ' step-failed';
                icon = 'utility:error';
            } else if (isCompleted) {
                nodeClass += ' node-completed';
                connectorClass += ' connector-completed';
                containerClass += ' step-completed';
                icon = 'utility:check';
            } else if (isCurrent) {
                nodeClass += ' node-current';
                connectorClass += ' connector-current';
                containerClass += ' step-current';
                icon = 'utility:steps';
            } else {
                nodeClass += ' node-pending';
                connectorClass += ' connector-pending';
                containerClass += ' step-pending';
                icon = 'utility:record';
            }

            if (isExpanded) {
                containerClass += ' step-expanded';
            }
            
            return {
                id: `step-${index}`,
                ...stage,
                nodeClass,
                connectorClass,
                containerClass,
                icon,
                isCompleted,
                isCurrent,
                isPending,
                isFailed,
                isLast,
                isExpanded,
                timestamp: isCurrent || isCompleted ? this.getRelativeTime() : null
            };
        });

        if (shouldExpand) {
            this.expandedStepValue = currentStatus;
            this.editingStatus = currentStatus;
        }
    }

    scrollToCurrentStep() {
        const currentStep = this.template.querySelector('.step-current');
        if (currentStep) {
            currentStep.scrollIntoView({ 
                behavior: 'smooth', 
                block: 'center',
                inline: 'nearest'
            });
        }
    }

    getRelativeTime() {
        // Placeholder - in production, use actual timestamp from application
        return 'Recently updated';
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        // Rebuild timeline with new status
        this.buildTimeline(this.selectedStatus);
    }

    handleSave() {
        if (!this.selectedStatus) {
            this.showToast('Warning', 'Please select a status', 'warning');
            return;
        }

        if (this.selectedStatus === this.originalStatus) {
            this.showToast('Info', 'No changes detected', 'info');
            return;
        }

        this.isSaving = true;

        updateApplicationStatus({
            applicationId: this.applicationId,
            newStatus: this.selectedStatus,
            comments: ''
        })
            .then(() => {
                this.isSaving = false;
                this.showToast('Success', 'Application status updated successfully', 'success');
                
                // Fire event to parent to refresh applications list
                this.dispatchEvent(new CustomEvent('statusupdate'));
                
                // Close modal after short delay
                setTimeout(() => {
                    this.handleClose();
                }, 1000);
            })
            .catch(error => {
                this.isSaving = false;
                this.showToast('Error', 'Error updating status', 'error');
                console.error('Error:', error);
            });
    }

    // Interactive Timeline Handlers
    handleStepClick(event) {
        event.stopPropagation();
        const stepValue = event.currentTarget.dataset.stepValue;
        
        // Find the clicked step
        const clickedStep = this.timelineSteps.find(s => s.value === stepValue);
        
        // Prevent editing future/pending steps
        if (clickedStep && clickedStep.isPending) {
            this.showToast('Info', 'Cannot edit future steps. Please update current step first.', 'info');
            return;
        }
        
        // Toggle expansion
        if (this.expandedStepValue === stepValue) {
            // Collapse if clicking same step
            this.expandedStepValue = null;
            this.editingStatus = '';
            this.editingNotes = '';
        } else {
            // Expand clicked step
            this.expandedStepValue = stepValue;
            this.editingStatus = stepValue;
            this.editingNotes = '';
            
            // Scroll to expanded step
            setTimeout(() => {
                const expandedStep = this.template.querySelector(`[data-step-value="${stepValue}"]`);
                if (expandedStep) {
                    expandedStep.scrollIntoView({ 
                        behavior: 'smooth', 
                        block: 'nearest'
                    });
                }
            }, 100);
        }
        
        // Rebuild timeline to update expansion state
        this.buildTimeline(this.selectedStatus, false);
    }

    handleEditStatusChange(event) {
        this.editingStatus = event.detail.value;
    }

    handleNotesChange(event) {
        this.editingNotes = event.detail.value;
    }

    handleFieldChange(event) {
        const fieldName = event.target.name;
        const fieldValue = event.target.type === 'checkbox' ? event.target.checked : event.detail.value;
        
        // Store field changes
        this.stageFieldValues[fieldName] = fieldValue;
    }

    handlePanelClick(event) {
        // Stop click events inside the panel from bubbling up
        event.stopPropagation();
    }

    handleQuickStatusChange(event) {
        this.selectedStatus = event.detail.value;
        // Rebuild timeline with new status
        this.buildTimeline(this.selectedStatus, false);
    }

    handleCancelEdit() {
        this.expandedStepValue = null;
        this.editingStatus = '';
        this.editingNotes = '';
        this.stageFieldValues = {}; // Clear field changes
        this.buildTimeline(this.selectedStatus, false);
    }

    handleSaveStepEdit() {
        if (!this.editingStatus) {
            this.showToast('Warning', 'Please select a status', 'warning');
            return;
        }

        if (this.editingStatus === this.selectedStatus && !this.editingNotes && Object.keys(this.stageFieldValues).length === 0) {
            this.showToast('Info', 'No changes detected', 'info');
            return;
        }

        this.isSavingStep = true;

        // Determine which object to update based on expanded step
        const stageConfig = this.hasStageFields ? this.STAGE_FIELDS_MAP[this.expandedStepValue] : null;
        const objectName = stageConfig ? stageConfig.objectName : null;
        
        console.log('Saving to object:', objectName);
        console.log('Field values:', this.stageFieldValues);

        // Update application status first
        updateApplicationStatus({
            applicationId: this.applicationId,
            newStatus: this.editingStatus,
            comments: this.editingNotes || ''
        })
            .then(() => {
                // Save stage-specific fields if any changes exist
                if (Object.keys(this.stageFieldValues).length > 0 && objectName) {
                    const candidateId = this.candidateDetail.application.Candidate__c;
                    
                    // Route to correct object based on stage
                    if (objectName === 'LicenseVerification__c') {
                        console.log('Updating/Creating License record');
                        if (this.currentLicenseId) {
                            return updateLicenseVerification({
                                licenseId: this.currentLicenseId,
                                fieldValues: this.stageFieldValues
                            });
                        } else {
                            return createLicenseVerification({
                                candidateId: candidateId,
                                fieldValues: this.stageFieldValues
                            }).then(newLicenseId => {
                                this.currentLicenseId = newLicenseId;
                            });
                        }
                    } else if (objectName === 'Interview_Detail__c') {
                        console.log('Updating/Creating Interview record');
                        if (this.currentInterviewId) {
                            return updateInterviewDetail({
                                interviewId: this.currentInterviewId,
                                fieldValues: this.stageFieldValues
                            });
                        } else {
                            return createInterviewDetail({
                                candidateId: candidateId,
                                applicationId: this.applicationId,
                                fieldValues: this.stageFieldValues
                            }).then(newInterviewId => {
                                this.currentInterviewId = newInterviewId;
                            });
                        }
                    }
                }
                return Promise.resolve();
            })
            .then(() => {
                this.isSavingStep = false;
                this.selectedStatus = this.editingStatus;
                this.originalStatus = this.editingStatus;
                
                // Success message
                this.showToast('Success', 
                    `Status updated to "${this.editingStatus}"`, 
                    'success');
                
                // Clear field values
                this.stageFieldValues = {};
                
                // Collapse panel
                this.expandedStepValue = null;
                this.editingNotes = '';
                
                // Rebuild timeline
                this.buildTimeline(this.editingStatus, false);
                
                // Reload data from both objects
                const candidateId = this.candidateDetail.application.Candidate__c;
                return Promise.all([
                    getLicenseVerifications({ candidateId: candidateId })
                        .catch(() => []),
                    getInterviewDetails({ candidateId: candidateId })
                        .catch(() => [])
                ]);
            })
            .then(([licenses, interviews]) => {
                this.licenseVerifications = licenses || [];
                this.currentLicenseId = licenses && licenses.length > 0 ? licenses[0].Id : null;
                
                this.interviewDetails = interviews || [];
                this.currentInterviewId = interviews && interviews.length > 0 ? interviews[0].Id : null;
                
                // Fire event to parent
                this.dispatchEvent(new CustomEvent('statusupdate'));
                
                // Scroll to new current step
                setTimeout(() => {
                    this.scrollToCurrentStep();
                }, 300);
            })
            .catch(error => {
                this.isSavingStep = false;
                this.showToast('Error', 'Error updating: ' + (error.body?.message || error.message), 'error');
                console.error('Save error:', error);
            });
    }

    handleClose() {
        // Fire event to parent to close modal
        this.dispatchEvent(new CustomEvent('closemodal'));
    }

    handleBackdropClick(event) {
        if (event.target.classList.contains('modal-backdrop-premium')) {
            this.handleClose();
        }
    }

    handleModalClick(event) {
        event.stopPropagation();
    }

    getStatusPillClass(status) {
        const s = status?.toLowerCase() || '';
        
        if (s.includes('passed') || s.includes('cleared') || s.includes('verified') || 
            s.includes('approved') || s.includes('active') || s.includes('accepted')) {
            return 'status-pill-large success';
        } else if (s.includes('failed') || s.includes('rejected') || s.includes('expired') || 
                   s.includes('suspended') || s.includes('declined')) {
            return 'status-pill-large error';
        } else if (s.includes('pending') || s.includes('progress') || s.includes('scheduled')) {
            return 'status-pill-large warning';
        } else if (s.includes('received') || s.includes('new')) {
            return 'status-pill-large info';
        }
        
        return 'status-pill-large default';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}