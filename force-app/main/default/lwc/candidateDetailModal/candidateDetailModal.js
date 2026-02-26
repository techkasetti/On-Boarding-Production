import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCandidateDetails from '@salesforce/apex/MedicalRecruitmentController.getCandidateDetails';
import updateApplicationStatus from '@salesforce/apex/MedicalRecruitmentController.updateApplicationStatus';
import getLicenseVerifications from '@salesforce/apex/MedicalRecruitmentController.getLicenseVerifications';
import updateLicenseVerification from '@salesforce/apex/MedicalRecruitmentController.updateLicenseVerification';
import createLicenseVerification from '@salesforce/apex/MedicalRecruitmentController.createLicenseVerification';
import getInterviewDetails from '@salesforce/apex/MedicalRecruitmentController.getInterviewDetails';
import updateInterviewDetail from '@salesforce/apex/MedicalRecruitmentController.updateInterviewDetail';
import createInterviewDetail from '@salesforce/apex/MedicalRecruitmentController.createInterviewDetail';
import getActiveUsers from '@salesforce/apex/MedicalRecruitmentController.getActiveUsers';
import getContacts from '@salesforce/apex/MedicalRecruitmentController.getContacts';
import sendInterviewEmails from '@salesforce/apex/MedicalRecruitmentController.sendInterviewEmails';
// import createZoomMeeting from '@salesforce/apex/ZoomMeetingService.createZoomMeeting';

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
    
    // Active users for lookup
    @track activeUsers = [];
    
    // Contacts for Provider lookup
    @track contactOptions = [];
    
    // Zoom generation state
    isGeneratingZoom = false;
    
    // Docflow modal state
    isDocflowOpen = false;
    
    stageFieldValues = {};

    // ─── GROUPED PROCESS STAGES ───────────────────────────────────────────────
    // Each group has a label, category key, ordered sub-statuses, and pill variants.
    PROCESS_GROUPS = [
        {
            id: 'application',
            label: 'Application',
            icon: 'utility:record_create',
            description: 'Initial application submission',
            statuses: [
                { value: 'Application Received', label: 'Received', pillVariant: 'info' }
            ]
        },
        {
            id: 'eligibility',
            label: 'Eligibility Check',
            icon: 'utility:verified',
            description: 'Reviewing qualifications and eligibility requirements',
            statuses: [
                { value: 'Eligibility Check In Progress', label: 'In Progress', pillVariant: 'warning' },
                { value: 'Eligibility Passed', label: 'Passed', pillVariant: 'success' },
                { value: 'Eligibility Failed', label: 'Failed', pillVariant: 'error' }
            ]
        },
        {
            id: 'license',
            label: 'License Verification',
            icon: 'utility:shield',
            description: 'Validating medical licenses and certifications',
            statuses: [
                { value: 'License Verification Pending', label: 'Pending', pillVariant: 'warning' },
                { value: 'License Verified', label: 'Verified', pillVariant: 'success' },
                { value: 'License Issue / Expired', label: 'Issue / Expired', pillVariant: 'error' }
            ]
        },
        {
            id: 'clinical',
            label: 'Clinical Assessment',
            icon: 'utility:activity',
            description: 'Evaluating clinical skills and competencies',
            statuses: [
                { value: 'Clinical Assessment Scheduled', label: 'Scheduled', pillVariant: 'warning' },
                { value: 'Clinical Assessment Passed', label: 'Passed', pillVariant: 'success' },
                { value: 'Clinical Assessment Failed', label: 'Failed', pillVariant: 'error' }
            ]
        },
        {
            id: 'interview',
            label: 'Interview',
            icon: 'utility:chat',
            description: 'Conducting interviews with hiring team',
            statuses: [
                { value: 'Interview Scheduled', label: 'Scheduled', pillVariant: 'warning' },
                { value: 'Interview Cleared', label: 'Cleared', pillVariant: 'success' },
                { value: 'Interview Rejected', label: 'Rejected', pillVariant: 'error' }
            ]
        },
        {
            id: 'background',
            label: 'Background Check',
            icon: 'utility:search',
            description: 'Conducting background and reference checks',
            statuses: [
                { value: 'Background Check In Progress', label: 'In Progress', pillVariant: 'warning' },
                { value: 'Background Check Cleared', label: 'Cleared', pillVariant: 'success' },
                { value: 'Background Check Failed', label: 'Failed', pillVariant: 'error' }
            ]
        },
        {
            id: 'offer',
            label: 'Offer',
            icon: 'utility:contract',
            description: 'Employment offer extended and response tracking',
            statuses: [
                { value: 'Offer Released', label: 'Released', pillVariant: 'warning' },
                { value: 'Offer Accepted', label: 'Accepted', pillVariant: 'success' },
                { value: 'Offer Declined', label: 'Declined', pillVariant: 'error' }
            ]
        },
        {
            id: 'credentialing',
            label: 'Credentialing',
            icon: 'utility:badge',
            description: 'Processing credentials and clinical privileges',
            statuses: [
                { value: 'Credentialing In Progress', label: 'In Progress', pillVariant: 'warning' },
                { value: 'Privileges Approved', label: 'Approved', pillVariant: 'success' }
            ]
        },
        {
            id: 'onboarding',
            label: 'Onboarding',
            icon: 'utility:people',
            description: 'Completing onboarding procedures',
            statuses: [
                { value: 'Medical Onboarding In Progress', label: 'In Progress', pillVariant: 'warning' },
                { value: 'Onboarding Completed', label: 'Completed', pillVariant: 'success' }
            ]
        },
        {
            id: 'active',
            label: 'Active Practice',
            icon: 'utility:check',
            description: 'Fully credentialed and ready to practice',
            statuses: [
                { value: 'Active – Allowed to Practice', label: 'Active', pillVariant: 'success' }
            ]
        }
    ];

    // Flat list of all status values in order (used for progress tracking)
    ALL_STATUS_VALUES = [
        'Application Received',
        'Eligibility Check In Progress',
        'Eligibility Passed',
        'Eligibility Failed',
        'License Verification Pending',
        'License Verified',
        'License Issue / Expired',
        'Clinical Assessment Scheduled',
        'Clinical Assessment Passed',
        'Clinical Assessment Failed',
        'Interview Scheduled',
        'Interview Cleared',
        'Interview Rejected',
        'Background Check In Progress',
        'Background Check Cleared',
        'Background Check Failed',
        'Offer Released',
        'Offer Accepted',
        'Offer Declined',
        'Credentialing In Progress',
        'Privileges Approved',
        'Medical Onboarding In Progress',
        'Onboarding Completed',
        'Active – Allowed to Practice'
    ];

    FAILED_STATUSES = [
        'Eligibility Failed',
        'License Issue / Expired',
        'Clinical Assessment Failed',
        'Interview Rejected',
        'Background Check Failed',
        'Offer Declined'
    ];

    // Stage-specific fields mapping (unchanged)
    STAGE_FIELDS_MAP = {
        'License Verification Pending': {
            objectName: 'LicenseVerification__c',
            fields: [
                { label: 'License Number', apiName: 'LicenseNumber__c', type: 'text', required: true },
                { label: 'Issuing Authority', apiName: 'IssuingAuthority__c', type: 'text', required: true },
                { label: 'Expiration Date', apiName: 'ExpirationDate__c', type: 'date', required: true },
                { label: 'Provider', apiName: 'Provider__c', type: 'contactLookup', required: false },
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
                { label: 'Provider', apiName: 'Provider__c', type: 'contactLookup', required: false },
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
                { label: 'Interviewer Type', apiName: 'Interviewer_Type__c', type: 'picklist', required: true, order: 1 },
                { label: 'Interviewer (User)', apiName: 'Interviewer_User__c', type: 'userLookup', required: false, order: 2, showWhen: { field: 'Interviewer_Type__c', value: 'User' } },
                { label: 'External Interviewer Name', apiName: 'External_Interviewer_Name__c', type: 'text', required: false, order: 3, showWhen: { field: 'Interviewer_Type__c', value: 'External' } },
                { label: 'External Interviewer Email', apiName: 'External_Interviewer_Email__c', type: 'email', required: false, order: 4, showWhen: { field: 'Interviewer_Type__c', value: 'External' } },
                { label: 'Meeting Type', apiName: 'Meeting_Type__c', type: 'picklist', required: true, order: 5 },
                { label: 'Interview Date', apiName: 'Interview_Date__c', type: 'date', required: false, order: 6, showWhen: { field: 'Meeting_Type__c', value: 'Virtual' } },
                { label: 'Interview Time', apiName: 'Interview_Time__c', type: 'time', required: false, order: 7, showWhen: { field: 'Meeting_Type__c', value: 'Virtual' } },
                { label: 'Meeting Link (Zoom/Teams)', apiName: 'Meeting_Link__c', type: 'url', required: false, order: 8, showWhen: { field: 'Meeting_Type__c', value: 'Virtual' }, showGenerateButton: true },
                { label: 'Interview Feedback', apiName: 'Feedback__c', type: 'textarea', required: false, order: 9 }
            ],
            buttonLabel: 'Schedule Interview',
            allowEdit: true
        },
        'Interview Cleared': {
            objectName: 'Interview_Detail__c',
            fields: [
                { label: 'Interview Detail Name', apiName: 'Name', type: 'text', required: false, readonly: true, order: 1 },
                { label: 'Interviewer Type', apiName: 'Interviewer_Type__c', type: 'picklist', required: true, order: 2, disabled: true },
                { label: 'Interviewer (User)', apiName: 'Interviewer_User__c', type: 'userLookup', required: false, order: 3, disabled: true, showWhen: { field: 'Interviewer_Type__c', value: 'User' } },
                { label: 'External Interviewer Name', apiName: 'External_Interviewer_Name__c', type: 'text', required: false, order: 4, disabled: true, showWhen: { field: 'Interviewer_Type__c', value: 'External' } },
                { label: 'External Interviewer Email', apiName: 'External_Interviewer_Email__c', type: 'email', required: false, order: 5, disabled: true, showWhen: { field: 'Interviewer_Type__c', value: 'External' } },
                { label: 'Meeting Type', apiName: 'Meeting_Type__c', type: 'picklist', required: true, order: 6, disabled: true },
                { label: 'Interview Date', apiName: 'Interview_Date__c', type: 'date', required: false, order: 7, disabled: true, showWhen: { field: 'Meeting_Type__c', value: 'Virtual' } },
                { label: 'Interview Time', apiName: 'Interview_Time__c', type: 'time', required: false, order: 8, disabled: true, showWhen: { field: 'Meeting_Type__c', value: 'Virtual' } },
                { label: 'Meeting Link (Zoom/Teams)', apiName: 'Meeting_Link__c', type: 'url', required: false, order: 9, disabled: true, showWhen: { field: 'Meeting_Type__c', value: 'Virtual' } },
                { label: 'Interview Feedback', apiName: 'Feedback__c', type: 'textarea', required: true, order: 10 }
            ],
            buttonLabel: 'Save Changes',
            allowEdit: false
        },
        'Interview Rejected': {
            objectName: 'Interview_Detail__c',
            fields: [
                { label: 'Interviewer Type', apiName: 'Interviewer_Type__c', type: 'picklist', required: true, order: 1, disabled: true },
                { label: 'Interviewer (User)', apiName: 'Interviewer_User__c', type: 'userLookup', required: false, order: 2, disabled: true, showWhen: { field: 'Interviewer_Type__c', value: 'User' } },
                { label: 'External Interviewer Name', apiName: 'External_Interviewer_Name__c', type: 'text', required: false, order: 3, disabled: true, showWhen: { field: 'Interviewer_Type__c', value: 'External' } },
                { label: 'Meeting Type', apiName: 'Meeting_Type__c', type: 'picklist', required: true, order: 4, disabled: true },
                { label: 'Interview Feedback', apiName: 'Feedback__c', type: 'textarea', required: true, order: 5 }
            ],
            buttonLabel: 'Save Changes',
            allowEdit: false
        },
        'Background Check Cleared': {
            objectName: null,
            fields: [],
            buttonLabel: 'Open Document Flow',
            showDocflowButton: true,
            allowEdit: false
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

    picklistOptions = {
        'Status__c': [
            { label: 'Pending Verification', value: 'Pending Verification' },
            { label: 'Valid', value: 'Valid' },
            { label: 'Expired', value: 'Expired' },
            { label: 'Suspended', value: 'Suspended' },
            { label: 'Not Found', value: 'Not Found' },
            { label: 'Requires Manual Review', value: 'Requires Manual Review' }
        ],
        'Name_Match_AI_Decision__c': [
            { label: 'Match', value: 'Match' },
            { label: 'No Match', value: 'No Match' },
            { label: 'Partial Match', value: 'Partial Match' },
            { label: 'Needs Review', value: 'Needs Review' }
        ],
        'Interviewer_Type__c': [
            { label: 'User', value: 'User' },
            { label: 'External', value: 'External' }
        ],
        'Meeting_Type__c': [
            { label: 'In-Person', value: 'In-Person' },
            { label: 'Virtual', value: 'Virtual' },
            { label: 'Phone', value: 'Phone' },
            { label: 'Hybrid', value: 'Hybrid' }
        ]
    };

    // ─── GETTERS ─────────────────────────────────────────────────────────────

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
        const completed = this.timelineSteps.filter(s => s.isCompleted || s.isCurrent).length;
        const total = this.timelineSteps.length;
        return `${completed} of ${total} completed`;
    }

    get saveButtonLabel() {
        if (this.isSavingStep) return 'Saving...';
        if (this.hasStageFields) {
            const stageConfig = this.STAGE_FIELDS_MAP[this.expandedStepValue];
            if (stageConfig && stageConfig.buttonLabel) {
                return stageConfig.buttonLabel;
            }
        }
        return 'Save Changes';
    }

    get showDocflowButton() {
        return this.selectedStatus === 'Background Check Cleared';
    }

    get hasStageFields() {
        return this.expandedStepValue && this.STAGE_FIELDS_MAP[this.expandedStepValue];
    }

    get hasStageFieldsList() {
        if (!this.hasStageFields) return false;
        const stageConfig = this.STAGE_FIELDS_MAP[this.expandedStepValue];
        return stageConfig.fields && stageConfig.fields.length > 0;
    }

    get stageFieldsTitle() {
        if (!this.hasStageFields) return 'Stage Details';
        const objectName = this.STAGE_FIELDS_MAP[this.expandedStepValue].objectName;
        if (objectName === 'LicenseVerification__c') return 'License Verification Details';
        if (objectName === 'Interview_Detail__c') return 'Interview Details';
        return 'Stage Details';
    }

    get currentStageFields() {
        if (!this.hasStageFields) return [];
        
        const stageConfig = this.STAGE_FIELDS_MAP[this.expandedStepValue];
        const fields = stageConfig.fields;
        const objectName = stageConfig.objectName;
        
        let stageData = null;
        if (objectName === 'LicenseVerification__c') {
            stageData = this.licenseVerifications && this.licenseVerifications.length > 0 
                ? this.licenseVerifications[0] : null;
        } else if (objectName === 'Interview_Detail__c') {
            stageData = this.interviewDetails && this.interviewDetails.length > 0 
                ? this.interviewDetails[0] : null;
        }
        
        const sortedFields = [...fields].sort((a, b) => (a.order || 999) - (b.order || 999));
        
        return sortedFields.map(field => {
            let fieldValue = '';
            
            if (this.stageFieldValues[field.apiName] !== undefined) {
                fieldValue = this.stageFieldValues[field.apiName];
            } else if (stageData && stageData[field.apiName] !== undefined) {
                fieldValue = stageData[field.apiName];
                if (field.type === 'contactLookup' && field.apiName === 'Provider__c') {
                    // Keep the ID as value so combobox can match it; label comes from contactOptions
                    fieldValue = stageData.Provider__c || '';
                } else if (field.type === 'userLookup' && field.apiName === 'Interviewer_User__c' && stageData.Interviewer_User__c) {
                    fieldValue = stageData.Interviewer_User__c;
                }
            }
            
            let shouldShow = true;
            if (field.showWhen) {
                const dependentFieldValue = this.stageFieldValues[field.showWhen.field] || 
                    (stageData ? stageData[field.showWhen.field] : null);
                shouldShow = dependentFieldValue === field.showWhen.value;
            }
            
            let fieldOptions;
            if (field.type === 'picklist') fieldOptions = this.picklistOptions[field.apiName];
            else if (field.type === 'userLookup') fieldOptions = this.activeUsers;
            else if (field.type === 'contactLookup') fieldOptions = this.contactOptions;
            
            return {
                ...field,
                value: fieldValue,
                options: fieldOptions,
                shouldShow: shouldShow,
                isText: field.type === 'text',
                isDate: field.type === 'date',
                isTime: field.type === 'time',
                isEmail: field.type === 'email',
                isUrl: field.type === 'url',
                isNumber: field.type === 'number',
                isCheckbox: field.type === 'checkbox',
                isPicklist: field.type === 'picklist',
                isTextarea: field.type === 'textarea',
                isUserLookup: field.type === 'userLookup',
                isContactLookup: field.type === 'contactLookup'
            };
        });
    }

    @wire(getActiveUsers)
    wiredUsers({ data, error }) {
        if (data) {
            this.activeUsers = data;
        } else if (error) {
            console.error('Error loading users:', error);
        }
    }

    @wire(getContacts)
    wiredContacts({ data, error }) {
        if (data) {
            this.contactOptions = data;
            console.log('Contacts loaded:', this.contactOptions.length);
        } else if (error) {
            console.error('Error loading contacts:', error);
        }
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
                
                const candidateId = result.application.Candidate__c;
                
                return Promise.all([
                    getLicenseVerifications({ candidateId: candidateId }).catch(() => []),
                    getInterviewDetails({ candidateId: candidateId }).catch(() => [])
                ]);
            })
            .then(([licenses, interviews]) => {
                this.licenseVerifications = licenses || [];
                this.currentLicenseId = licenses && licenses.length > 0 ? licenses[0].Id : null;
                this.interviewDetails = interviews || [];
                this.currentInterviewId = interviews && interviews.length > 0 ? interviews[0].Id : null;
                
                this.buildTimeline(this.selectedStatus, true);
                this.isLoading = false;
                
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

    // ─── GROUPED TIMELINE BUILDER ─────────────────────────────────────────────
    buildTimeline(currentStatus, autoExpandCurrent = false) {
        const currentGroupId = this._getGroupForStatus(currentStatus);
        const currentGroupIndex = this.PROCESS_GROUPS.findIndex(g => g.id === currentGroupId);
        
        this.timelineSteps = this.PROCESS_GROUPS.map((group, index) => {
            // Find which status within this group is active (if any)
            const activeStatus = group.statuses.find(s => s.value === currentStatus);
            const isCurrentGroup = group.id === currentGroupId;
            const isCompleted = index < currentGroupIndex;
            const isPending = index > currentGroupIndex;
            const isFailed = isCurrentGroup && this.FAILED_STATUSES.includes(currentStatus);
            const isLast = index === this.PROCESS_GROUPS.length - 1;

            // Status pill shown when this group is active
            const activePill = activeStatus || null;

            // Whether the edit panel is expanded for this group's current status
            const isExpanded = this.expandedStepValue !== null && 
                               group.statuses.some(s => s.value === this.expandedStepValue) &&
                               isCurrentGroup;

            // Auto-expand the current group on first load
            const shouldExpand = autoExpandCurrent && isCurrentGroup;

            let nodeClass = 'timeline-node';
            let connectorClass = 'timeline-connector';
            let containerClass = 'timeline-step';
            let icon = group.icon || 'utility:record';

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
            } else if (isCurrentGroup) {
                nodeClass += ' node-current';
                connectorClass += ' connector-current';
                containerClass += ' step-current';
            } else {
                nodeClass += ' node-pending';
                connectorClass += ' connector-pending';
                containerClass += ' step-pending';
            }

            if (isExpanded || shouldExpand) {
                containerClass += ' step-expanded';
            }

            // Build pill data based on step state:
            // - Completed groups: single green "Completed" pill
            // - Current group: all sub-status pills, active one highlighted
            // - Failed group: all sub-status pills, failed one highlighted
            // - Pending groups: all sub-status pills, all faded
            let statusPills;
            if (isCompleted) {
                statusPills = [{
                    value: 'completed',
                    label: 'Completed',
                    pillClass: 'group-status-pill pill-success pill-active',
                    isActive: true
                }];
            } else {
                statusPills = group.statuses.map(s => ({
                    value: s.value,
                    label: s.label,
                    pillClass: `group-status-pill pill-${s.pillVariant}${(s.value === currentStatus && isCurrentGroup) ? ' pill-active' : ''}`,
                    isActive: s.value === currentStatus && isCurrentGroup
                }));
            }

            return {
                id: `step-${group.id}`,
                value: currentStatus, // the value used for edit panel lookup
                groupId: group.id,
                label: group.label,
                description: group.description,
                nodeClass,
                connectorClass,
                containerClass,
                icon,
                isCompleted,
                isCurrent: isCurrentGroup,
                isPending,
                isFailed,
                isLast,
                isExpanded: isExpanded || shouldExpand,
                statusPills,
                activePill,
                timestamp: (isCurrentGroup || isCompleted) ? this.getRelativeTime() : null
            };
        });

        if (autoExpandCurrent) {
            this.expandedStepValue = currentStatus;
            this.editingStatus = currentStatus;
        }
    }

    _getGroupForStatus(status) {
        for (const group of this.PROCESS_GROUPS) {
            if (group.statuses.some(s => s.value === status)) {
                return group.id;
            }
        }
        return null;
    }

    scrollToCurrentStep() {
        const currentStep = this.template.querySelector('.step-current');
        if (currentStep) {
            currentStep.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'nearest' });
        }
    }

    getRelativeTime() {
        return 'Recently updated';
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
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
        updateApplicationStatus({ applicationId: this.applicationId, newStatus: this.selectedStatus, comments: '' })
            .then(() => {
                this.isSaving = false;
                this.showToast('Success', 'Application status updated successfully', 'success');
                this.dispatchEvent(new CustomEvent('statusupdate'));
                setTimeout(() => { this.handleClose(); }, 1000);
            })
            .catch(error => {
                this.isSaving = false;
                this.showToast('Error', 'Error updating status', 'error');
                console.error('Error:', error);
            });
    }

    handleStepClick(event) {
        event.stopPropagation();
        const groupId = event.currentTarget.dataset.groupId;
        const clickedStep = this.timelineSteps.find(s => s.groupId === groupId);
        
        if (clickedStep && clickedStep.isPending) {
            this.showToast('Info', 'Cannot edit future steps. Please update current step first.', 'info');
            return;
        }

        // The expandedStepValue should be the current actual status (for STAGE_FIELDS_MAP lookup)
        if (clickedStep && clickedStep.isCurrent) {
            if (this.expandedStepValue === this.selectedStatus) {
                this.expandedStepValue = null;
                this.editingStatus = '';
                this.editingNotes = '';
            } else {
                this.expandedStepValue = this.selectedStatus;
                this.editingStatus = this.selectedStatus;
                this.editingNotes = '';
                setTimeout(() => {
                    const expandedStep = this.template.querySelector(`[data-group-id="${groupId}"]`);
                    if (expandedStep) {
                        expandedStep.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
                    }
                }, 100);
            }
        } else if (clickedStep && clickedStep.isCompleted) {
            // For completed steps, allow viewing but use the group's "best" status for display
            const completedStatus = clickedStep.statusPills.find(p => p.isActive)?.value || 
                                    clickedStep.statusPills[clickedStep.statusPills.length - 1]?.value;
            if (this.expandedStepValue === completedStatus) {
                this.expandedStepValue = null;
                this.editingStatus = '';
            } else {
                this.expandedStepValue = completedStatus;
                this.editingStatus = completedStatus;
            }
        }

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
        this.stageFieldValues[fieldName] = fieldValue;
        if (fieldName === 'Interviewer_Type__c' || fieldName === 'Meeting_Type__c') {
            this.stageFieldValues = { ...this.stageFieldValues };
        }
    }

    handlePanelClick(event) {
        event.stopPropagation();
    }

    handleGenerateZoomLink() {
        this.isGeneratingZoom = true;
        const candidateName = this.candidateDetail?.application?.Candidate__r?.Full_Name__c || 'Candidate';
        const jobTitle = this.candidateDetail?.application?.Job_Posting__r?.Job_Title__c || 'Position';
        const interviewDate = this.stageFieldValues['Interview_Date__c'] || null;
        const interviewTime = this.stageFieldValues['Interview_Time__c'] || null;
        if (!interviewDate || !interviewTime) {
            this.showToast('Warning', 'Please select Interview Date and Time first', 'warning');
            this.isGeneratingZoom = false;
            return;
        }
        const dateTimeStr = `${interviewDate}T${interviewTime}:00`;
        createZoomMeeting({
            topic: `Interview: ${candidateName} - ${jobTitle}`,
            agenda: `Interview for ${jobTitle} position`,
            startDateTime: dateTimeStr,
            duration: 60,
            timezone: 'Asia/Kolkata'
        })
            .then(result => {
                this.stageFieldValues['Meeting_Link__c'] = result.join_url;
                this.stageFieldValues['Zoom_Start_URL__c'] = result.start_url;
                this.stageFieldValues['Zoom_Meeting_ID__c'] = result.id;
                this.stageFieldValues = { ...this.stageFieldValues };
                this.isGeneratingZoom = false;
                this.showToast('Success', 'Zoom meeting created successfully!', 'success');
            })
            .catch(error => {
                this.isGeneratingZoom = false;
                this.showToast('Error', 'Failed to create Zoom meeting: ' + (error.body?.message || error.message), 'error');
            });
    }

    handleQuickStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.buildTimeline(this.selectedStatus, false);
    }

    handleCancelEdit() {
        this.expandedStepValue = null;
        this.editingStatus = '';
        this.editingNotes = '';
        this.stageFieldValues = {};
        this.buildTimeline(this.selectedStatus, false);
    }

    handleSaveStepEdit() {
        if (this.expandedStepValue === 'Background Check Cleared') {
            this.handleOpenDocflow();
            return;
        }
        if (!this.editingStatus) {
            this.showToast('Warning', 'Please select a status', 'warning');
            return;
        }
        if (this.editingStatus === this.selectedStatus && !this.editingNotes && Object.keys(this.stageFieldValues).length === 0) {
            this.showToast('Info', 'No changes detected', 'info');
            return;
        }
        this.isSavingStep = true;
        const stageConfig = this.hasStageFields ? this.STAGE_FIELDS_MAP[this.expandedStepValue] : null;
        const objectName = stageConfig ? stageConfig.objectName : null;

        updateApplicationStatus({ applicationId: this.applicationId, newStatus: this.editingStatus, comments: this.editingNotes || '' })
            .then(() => {
                if (Object.keys(this.stageFieldValues).length > 0 && objectName) {
                    const candidateId = this.candidateDetail.application.Candidate__c;
                    const fieldValuesToSave = { ...this.stageFieldValues };
                    
                    // Sanitize date fields — ensure they are plain 'YYYY-MM-DD' strings
                    // (lightning-input type="date" can sometimes include time component on some browsers)
                    const DATE_FIELDS = ['ExpirationDate__c', 'Interview_Date__c'];
                    DATE_FIELDS.forEach(f => {
                        if (fieldValuesToSave[f] && typeof fieldValuesToSave[f] === 'string') {
                            // Take only the date portion in case there's a T or time appended
                            fieldValuesToSave[f] = fieldValuesToSave[f].split('T')[0];
                        }
                    });
                    
                    if (objectName === 'LicenseVerification__c') {
                        if (this.currentLicenseId) {
                            return updateLicenseVerification({ licenseId: this.currentLicenseId, fieldValues: fieldValuesToSave });
                        } else {
                            return createLicenseVerification({ candidateId: candidateId, fieldValues: fieldValuesToSave })
                                .then(newId => { this.currentLicenseId = newId; });
                        }
                    } else if (objectName === 'Interview_Detail__c') {
                        if (this.currentInterviewId) {
                            return updateInterviewDetail({ interviewId: this.currentInterviewId, fieldValues: fieldValuesToSave });
                        } else {
                            return createInterviewDetail({ candidateId: candidateId, applicationId: this.applicationId, fieldValues: fieldValuesToSave })
                                .then(newId => { this.currentInterviewId = newId; });
                        }
                    }
                }
                return Promise.resolve();
            })
            .then(() => {
                if (this.expandedStepValue === 'Interview Scheduled' && Object.keys(this.stageFieldValues).length > 0) {
                    return sendInterviewEmails({
                        applicationId: this.applicationId,
                        interviewerType: this.stageFieldValues['Interviewer_Type__c'] || '',
                        interviewerUserId: this.stageFieldValues['Interviewer_User__c'] || null,
                        externalInterviewerEmail: this.stageFieldValues['External_Interviewer_Email__c'] || '',
                        meetingType: this.stageFieldValues['Meeting_Type__c'] || '',
                        meetingLink: this.stageFieldValues['Meeting_Link__c'] || '',
                        zoomStartUrl: this.stageFieldValues['Zoom_Start_URL__c'] || ''
                    }).catch(emailError => {
                        console.error('Email sending failed:', emailError);
                        this.showToast('Warning', 'Interview saved but email notification failed', 'warning');
                    });
                }
                return Promise.resolve();
            })
            .then(() => {
                this.isSavingStep = false;
                this.selectedStatus = this.editingStatus;
                this.originalStatus = this.editingStatus;
                const successMessage = this.expandedStepValue === 'Interview Scheduled'
                    ? 'Interview scheduled! Emails sent to candidate and interviewer.'
                    : `Status updated to "${this.editingStatus}"`;
                this.showToast('Success', successMessage, 'success');
                this.stageFieldValues = {};
                this.expandedStepValue = null;
                this.editingNotes = '';
                this.buildTimeline(this.editingStatus, false);
                const candidateId = this.candidateDetail.application.Candidate__c;
                return Promise.all([
                    getLicenseVerifications({ candidateId: candidateId }).catch(() => []),
                    getInterviewDetails({ candidateId: candidateId }).catch(() => [])
                ]);
            })
            .then(([licenses, interviews]) => {
                this.licenseVerifications = licenses || [];
                this.currentLicenseId = licenses && licenses.length > 0 ? licenses[0].Id : null;
                this.interviewDetails = interviews || [];
                this.currentInterviewId = interviews && interviews.length > 0 ? interviews[0].Id : null;
                this.dispatchEvent(new CustomEvent('statusupdate'));
                setTimeout(() => { this.scrollToCurrentStep(); }, 300);
            })
            .catch(error => {
                this.isSavingStep = false;
                this.showToast('Error', 'Error updating: ' + (error.body?.message || error.message), 'error');
                console.error('Save error:', error);
            });
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('closemodal'));
    }

    handleOpenDocflow() {
        this.dispatchEvent(new CustomEvent('opendocflow', { detail: { applicationId: this.applicationId } }));
    }

    handleCloseDocflow() {
        this.isDocflowOpen = false;
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
            s.includes('approved') || s.includes('active') || s.includes('accepted')) return 'status-pill-large success';
        if (s.includes('failed') || s.includes('rejected') || s.includes('expired') || 
            s.includes('suspended') || s.includes('declined')) return 'status-pill-large error';
        if (s.includes('pending') || s.includes('progress') || s.includes('scheduled')) return 'status-pill-large warning';
        if (s.includes('received') || s.includes('new')) return 'status-pill-large info';
        return 'status-pill-large default';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}