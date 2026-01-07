// import { LightningElement, track, wire } from 'lwc';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent'; // CORRECTED LINE
// import { getObjectInfo } from 'lightning/uiObjectInfoApi';
// import { getPicklistValues } from 'lightning/uiObjectInfoApi';
// import SCREENING_RULE_OBJECT from '@salesforce/schema/Screening_Rule__c';
// import ACTION_FIELD from '@salesforce/schema/Screening_Rule__c.Action__c';
// import OPERATOR_FIELD from '@salesforce/schema/Screening_Rule__c.Operator__c';
// import getRules from '@salesforce/apex/ScreeningController.getRules';
// import saveRules from '@salesforce/apex/ScreeningController.saveRules';
// import saveNewRule from '@salesforce/apex/ScreeningController.saveNewRule';
// import deleteRule from '@salesforce/apex/ScreeningController.deleteRule';
// import getJobPostings from '@salesforce/apex/ScreeningController.getJobPostings';
// import getFieldsForObject from '@salesforce/apex/ScreeningController.getFieldsForObject';
// import getAvailableObjects from '@salesforce/apex/ScreeningController.getAvailableObjects';
// import getCandidates from '@salesforce/apex/ScreeningController.getCandidates';

// const columns = [
//     { label: 'Rule Name', fieldName: 'Name', type: 'text', editable: true, wrapText: true },
//     { label: 'Applied to Job/Role', fieldName: 'appliedRoleName', type: 'text' },
//     { label: 'Priority', fieldName: 'priority', type: 'number', editable: true, cellAttributes: { alignment: 'left' } },
//     { label: 'Target Object', fieldName: 'targetObject', type: 'text' },
//     { label: 'Operator', fieldName: 'operator', type: 'text' },
//     { label: 'Expected Value', fieldName: 'expectedValue', type: 'text', editable: true },
//     {
//         type: 'action',
//         typeAttributes: {
//             rowActions: [
//                 { label: 'Edit', name: 'edit' },
//                 { label: 'Delete', name: 'delete' },
//             ],
//         },
//     },
// ];

// export default class ScreeningAdmin extends LightningElement {
//     @track rules = [];
//     @track draftValues = [];
//     columns = columns;
//     isLoading = true;

//     // --- Modal Properties ---
//     @track isModalOpen = false;
//     @track newRule = {};
//     @track modalTitle = 'Add New Screening Rule';
//     @track isEditMode = false;

//     // --- Data for Picklists in Modal ---
//     @track jobPostingOptions = [];
//     @track actionOptions = [];
//     @track operatorOptions = [];

//     // --- Dynamic Logic Properties ---
//     @track targetObjectOptions = [];
//     @track fieldApiNameOptions = [];
//     @track isFieldApiNameDisabled = true;
//     selectedTargetObject = '';

//     // --- NEW: Candidate Results Properties ---
//     @track isResultModalOpen = false;
//     @track selectedCandidateId = '';
//     @track candidateOptions = [];

//     // --- WIRE SERVICES ---
//     @wire(getObjectInfo, { objectApiName: SCREENING_RULE_OBJECT })
//     objectInfo;

//     @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: ACTION_FIELD })
//     wiredActionPicklistValues({ error, data }) {
//         if (data) {
//             this.actionOptions = data.values;
//         } else if (error) {
//             console.error('Error loading Action picklist values', error);
//         }
//     }

//     @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: OPERATOR_FIELD })
//     wiredOperatorPicklistValues({ error, data }) {
//         if (data) {
//             this.operatorOptions = data.values;
//         } else if (error) {
//             console.error('Error loading Operator picklist values', error);
//         }
//     }
    
//     @wire(getCandidates)
//     wiredCandidates({ error, data }) {
//         if (data) {
//             this.candidateOptions = data.map(candidate => ({ label: candidate.Name, value: candidate.Id }));
//         } else if (error) {
//             this.showToast('Error', 'Could not load candidates.', 'error');
//         }
//     }

//     connectedCallback() {
//         this.loadInitialData();
//     }

//     // --- DATA LOADING ---
//     loadInitialData() {
//         this.isLoading = true;
//         Promise.all([
//             getRules(),
//             getJobPostings()
//         ]).then(([rulesData, jobsData]) => {
//             this.rules = rulesData.map(rule => ({ ...rule }));
//             this.jobPostingOptions = jobsData.map(job => ({ label: job.Name, value: job.Id }));
//             this.draftValues = [];
//         }).catch(error => {
//             this.showToast('Error Loading Data', this.getErrorMessage(error), 'error');
//         }).finally(() => {
//             this.isLoading = false;
//         });
//     }

//     loadRules() {
//         this.isLoading = true;
//         getRules().then(data => {
//             this.rules = data.map(rule => ({ ...rule }));
//             this.draftValues = [];
//         }).catch(error => {
//             this.showToast('Error Loading Rules', this.getErrorMessage(error), 'error');
//         }).finally(() => {
//             this.isLoading = false;
//         });
//     }

//     // --- UI EVENT HANDLERS ---
//     async handleSave(event) {
//         this.isLoading = true;
//         const updatedFields = event.detail.draftValues;
//         try {
//             await saveRules({ data: updatedFields });
//             this.showToast('Success', 'Rules updated successfully', 'success');
//             await this.loadRules();
//         } catch (error) {
//             this.showToast('Error saving rules', this.getErrorMessage(error), 'error');
//         } finally {
//             this.isLoading = false;
//         }
//     }

//     handleRowAction(event) {
//         const actionName = event.detail.action.name;
//         const row = event.detail.row;
//         switch (actionName) {
//             case 'edit':
//                 this.handleEditRule(row);
//                 break;
//             case 'delete':
//                 // For direct delete from row, we need a confirmation.
//                 // For simplicity, we'll just call the delete method directly.
//                 // A better UX would be a confirmation modal here.
//                 this.handleDeleteRuleById(row.Id);
//                 break;
//             default:
//         }
//     }

//     // --- MODAL LOGIC (ADD/EDIT RULE) ---
//     handleAddRule() {
//         this.isEditMode = false;
//         this.modalTitle = 'Add New Screening Rule';
//         this.newRule = { Active__c: true };
//         this.selectedTargetObject = '';
//         this.isFieldApiNameDisabled = true;
//         this.targetObjectOptions = [];
//         this.fieldApiNameOptions = [];
//         this.isModalOpen = true;
//         this.loadTargetObjects();
//     }

//     handleEditRule(row) {
//         this.isEditMode = true;
//         this.modalTitle = 'Edit Screening Rule';
//         this.newRule = JSON.parse(JSON.stringify(row));
        
//         // Map frontend-friendly names back to SObject field API names
//         this.newRule.Id = row.Id;
//         this.newRule.Name = row.Name;
//         this.newRule.Priority__c = row.priority;
//         this.newRule.Applied_Role__c = row.appliedRoleId;
//         this.newRule.Target_Object__c = row.targetObject;
//         this.newRule.Field_API_Name__c = row.fieldApiName;
//         this.newRule.Operator__c = row.operator;
//         this.newRule.Expected_Value__c = row.expectedValue;
//         this.newRule.Action__c = row.action;
//         this.newRule.Failure_Message__c = row.failureMessage;

//         this.selectedTargetObject = row.targetObject;
//         this.isModalOpen = true;

//         this.loadTargetObjects().then(() => {
//             if (this.selectedTargetObject) {
//                 this.loadFieldsForObject(this.selectedTargetObject);
//             }
//         });
//     }

//     // Renamed from handleDeleteRule to avoid confusion
//     handleDeleteRuleFromModal() {
//         this.handleDeleteRuleById(this.newRule.Id);
//     }
    
//     handleDeleteRuleById(ruleId) {
//         this.isLoading = true;
//         deleteRule({ ruleId: ruleId })
//             .then(() => {
//                 this.showToast('Success', 'Rule deleted successfully', 'success');
//                 if(this.isModalOpen) {
//                     this.isModalOpen = false;
//                 }
//                 this.loadRules();
//             })
//             .catch(error => {
//                 this.showToast('Error deleting rule', this.getErrorMessage(error), 'error');
//             })
//             .finally(() => {
//                 this.isLoading = false;
//             });
//     }

//     loadTargetObjects() {
//         this.isLoading = true;
//         return getAvailableObjects().then(result => {
//             this.targetObjectOptions = result;
//         }).catch(error => {
//             this.showToast('Error Loading Objects', this.getErrorMessage(error), 'error');
//         }).finally(() => {
//             this.isLoading = false;
//         });
//     }

//     loadFieldsForObject(objectApiName) {
//         this.isFieldApiNameDisabled = false;
//         this.isLoading = true;
//         getFieldsForObject({ objectApiName: objectApiName }).then(result => {
//             this.fieldApiNameOptions = result.map(opt => ({ label: `${opt.label} (${opt.value})`, value: opt.value }));
//         }).catch(error => {
//             this.showToast('Error Loading Fields', this.getErrorMessage(error), 'error');
//             this.isFieldApiNameDisabled = true;
//         }).finally(() => {
//             this.isLoading = false;
//         });
//     }

//     closeModal() {
//         this.isModalOpen = false;
//     }

//     handleNewRuleChange(event) {
//         const field = event.target.dataset.field;
//         const value = event.target.value;
//         this.newRule = { ...this.newRule, [field]: value };
//     }

//     handleTargetObjectChange(event) {
//         this.selectedTargetObject = event.detail.value;
//         this.newRule = { ...this.newRule, Target_Object__c: this.selectedTargetObject };
//         this.fieldApiNameOptions = [];
//         this.newRule = { ...this.newRule, Field_API_Name__c: null };

//         if (this.selectedTargetObject) {
//             this.loadFieldsForObject(this.selectedTargetObject);
//         } else {
//             this.isFieldApiNameDisabled = true;
//         }
//     }

//     handleSaveNewRule() {
//         if (!this.newRule.Name || !this.newRule.Priority__c || !this.newRule.Applied_Role__c) {
//             this.showToast('Error', 'Rule Name, Priority, and Job Posting are required.', 'error');
//             return;
//         }
//         this.isLoading = true;
//         saveNewRule({ newRule: this.newRule }).then(() => {
//             this.showToast('Success', `Rule ${this.isEditMode ? 'updated' : 'created'} successfully`, 'success');
//             this.isModalOpen = false;
//             this.loadRules();
//         }).catch(error => {
//             this.showToast('Error saving rule', this.getErrorMessage(error), 'error');
//         }).finally(() => {
//             this.isLoading = false;
//         });
//     }

//     // --- NEW: CANDIDATE RESULTS MODAL LOGIC ---
//     handleCandidateChange(event) {
//         this.selectedCandidateId = event.detail.value;
//     }

//     get isViewResultsDisabled() {
//         return !this.selectedCandidateId;
//     }

//     handleViewResults() {
//         if (this.selectedCandidateId) {
//             this.isResultModalOpen = true;
//         }
//     }

//     closeResultsModal() {
//         this.isResultModalOpen = false;
//     }

//     // --- UTILITY ---
//     showToast(title, message, variant) {
//         this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
//     }

//     getErrorMessage(error) {
//         if (error.body) {
//             if (Array.isArray(error.body)) {
//                 return error.body.map(e => e.message).join(', ');
//             } else if (typeof error.body.message === 'string') {
//                 return error.body.message;
//             }
//         }
//         return 'An unknown error occurred.';
//     }
// }
// screeningAdmin.js - FIXED VERSION
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { refreshApex } from '@salesforce/apex';

// Schema imports
import SCREENING_RULE_OBJECT from '@salesforce/schema/Screening_Rule__c';
import ACTION_FIELD from '@salesforce/schema/Screening_Rule__c.Action__c';
import OPERATOR_FIELD from '@salesforce/schema/Screening_Rule__c.Operator__c';
import JOURNEY_PATH_FIELD from '@salesforce/schema/Screening_Rule__c.Journey_Path__c';
import RULE_CATEGORY_FIELD from '@salesforce/schema/Screening_Rule__c.Rule_Category__c';

// Apex imports
import getRules from '@salesforce/apex/ScreeningController.getRules';
import saveRules from '@salesforce/apex/ScreeningController.saveRules';
import saveNewRule from '@salesforce/apex/ScreeningController.saveNewRule';
import deleteRule from '@salesforce/apex/ScreeningController.deleteRule';
import getJobPostings from '@salesforce/apex/ScreeningController.getJobPostings';
import getFieldsForObject from '@salesforce/apex/ScreeningController.getFieldsForObject';
import getAvailableObjects from '@salesforce/apex/ScreeningController.getAvailableObjects';
import getCandidates from '@salesforce/apex/ScreeningController.getCandidates';
import getRuleVersionHistory from '@salesforce/apex/ScreeningController.getRuleVersionHistory';
import rollbackRule from '@salesforce/apex/ScreeningController.rollbackRule';
import testRuleAgainstCandidate from '@salesforce/apex/ScreeningController.testRuleAgainstCandidate';
import rerunScreening from '@salesforce/apex/CandidateStatusController.rerunScreening';

const COLUMNS = [
    { label: 'Rule Name', fieldName: 'Name', type: 'text', wrapText: true },
    { label: 'Version', fieldName: 'version', type: 'number', cellAttributes: { alignment: 'left' } },
    { label: 'Job/Role', fieldName: 'appliedRoleName', type: 'text' },
    { label: 'Priority', fieldName: 'priority', type: 'number', editable: true, cellAttributes: { alignment: 'left' } },
    { label: 'Category', fieldName: 'ruleCategory', type: 'text' },
    { label: 'Journey Path', fieldName: 'journeyPath', type: 'text' },
    { label: 'Target Object', fieldName: 'targetObject', type: 'text' },
    { label: 'Pass Rate', fieldName: 'passRate', type: 'percent', cellAttributes: { alignment: 'left' } },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit', name: 'edit' },
                { label: 'Version History', name: 'version_history' },
                { label: 'Test Rule', name: 'test' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

export default class ScreeningAdmin extends LightningElement {
    @track rules = [];
    @track filteredRules = [];
    @track draftValues = [];
    columns = COLUMNS;
    isLoading = true;

    // Filter properties
    @track filterJobPosting = '';
    @track filterJourneyPath = '';
    @track filterCategory = '';

    // Modal properties
    @track isModalOpen = false;
    @track newRule = {};
    @track modalTitle = 'Add New Screening Rule';
    @track isEditMode = false;
    @track activeTab = 'basic';

    // Picklist data
    @track jobPostingOptions = [];
    @track actionOptions = [];
    @track operatorOptions = [];
    @track journeyPathOptions = [];
    @track categoryOptions = [];
    @track matchTypeOptions = [
        { label: 'Any (At least one match)', value: 'Any' },
        { label: 'All (All must match)', value: 'All' }
    ];

    // Dynamic object/field selection
    @track targetObjectOptions = [];
    @track fieldApiNameOptions = [];
    @track isFieldApiNameDisabled = true;
    selectedTargetObject = '';

    // Candidate selection
    @track isResultModalOpen = false;
    @track selectedCandidateId = '';
    @track candidateOptions = [];

    // Version history modal
    @track isVersionModalOpen = false;
    @track versionHistory = [];
    @track selectedRuleForVersion = null;

    // Test sandbox modal
    @track isTestModalOpen = false;
    @track selectedRuleForTest = null;
    @track testCandidateId = '';
    @track testResult = null;

    // Wire services
    @wire(getObjectInfo, { objectApiName: SCREENING_RULE_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: ACTION_FIELD })
    wiredActionPicklist({ data, error }) {
        if (data) this.actionOptions = data.values;
        if (error) console.error('Error loading Action picklist', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: OPERATOR_FIELD })
    wiredOperatorPicklist({ data, error }) {
        if (data) this.operatorOptions = data.values;
        if (error) console.error('Error loading Operator picklist', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: JOURNEY_PATH_FIELD })
    wiredJourneyPathPicklist({ data, error }) {
        if (data) this.journeyPathOptions = data.values;
        if (error) console.error('Error loading Journey Path picklist', error);
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: RULE_CATEGORY_FIELD })
    wiredCategoryPicklist({ data, error }) {
        if (data) this.categoryOptions = data.values;
        if (error) console.error('Error loading Category picklist', error);
    }

    @wire(getCandidates)
    wiredCandidates({ data, error }) {
        if (data) {
            this.candidateOptions = data.map(c => ({ label: c.Name, value: c.Id }));
        }
        if (error) this.showToast('Error', 'Could not load candidates', 'error');
    }

    connectedCallback() {
        this.loadInitialData();
    }

    async loadInitialData() {
        this.isLoading = true;
        try {
            const [rulesData, jobsData] = await Promise.all([
                getRules(),
                getJobPostings()
            ]);
            
            if (jobsData && jobsData.length > 0) {
                this.jobPostingOptions = [
                    { label: 'All Job Postings', value: '' },
                    ...jobsData.map(job => ({ 
                        label: job.Name, 
                        value: job.Id 
                    }))
                ];
            } else {
                this.jobPostingOptions = [
                    { label: 'All Job Postings', value: '' },
                    { label: 'No Job Postings Available', value: '', disabled: true }
                ];
            }
            
            this.rules = rulesData.map(rule => ({ ...rule }));
            this.filteredRules = [...this.rules];
            this.draftValues = [];
            
        } catch (error) {
            console.error('Error loading initial data:', error);
            this.showToast('Error Loading Data', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadRules() {
        this.isLoading = true;
        try {
            const data = await getRules();
            this.rules = data.map(rule => ({ ...rule }));
            this.applyFilters();
            this.draftValues = [];
        } catch (error) {
            this.showToast('Error Loading Rules', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadJobPostingsForModal() {
        try {
            const jobsData = await getJobPostings();
            
            if (jobsData && jobsData.length > 0) {
                this.jobPostingOptions = jobsData.map(job => ({ 
                    label: job.Name, 
                    value: job.Id 
                }));
            } else {
                this.jobPostingOptions = [
                    { label: 'No Job Postings Available', value: '', disabled: true }
                ];
            }
        } catch (error) {
            console.error('Error loading job postings:', error);
            this.showToast('Error', 'Could not load job postings', 'error');
        }
    }

    // Filter methods
    handleFilterChange(event) {
        const field = event.target.name;
        const value = event.detail.value;
        
        if (field === 'filterJob') this.filterJobPosting = value;
        if (field === 'filterPath') this.filterJourneyPath = value;
        if (field === 'filterCategory') this.filterCategory = value;
        
        this.applyFilters();
    }

    handleClearFilters() {
        this.filterJobPosting = '';
        this.filterJourneyPath = '';
        this.filterCategory = '';
        this.applyFilters();
    }

    applyFilters() {
        let filtered = [...this.rules];
        
        if (this.filterJobPosting) {
            filtered = filtered.filter(r => r.appliedRoleId === this.filterJobPosting);
        }
        if (this.filterJourneyPath) {
            filtered = filtered.filter(r => r.journeyPath === this.filterJourneyPath);
        }
        if (this.filterCategory) {
            filtered = filtered.filter(r => r.ruleCategory === this.filterCategory);
        }
        
        this.filteredRules = filtered;
    }

    // Rule CRUD operations
    async handleSave(event) {
        this.isLoading = true;
        const updatedFields = event.detail.draftValues;
        try {
            await saveRules({ data: updatedFields });
            this.showToast('Success', 'Rules updated successfully', 'success');
            await this.loadRules();
        } catch (error) {
            this.showToast('Error saving rules', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        switch (actionName) {
            case 'edit':
                this.handleEditRule(row);
                break;
            case 'delete':
                this.handleDeleteRuleById(row.Id);
                break;
            case 'version_history':
                this.handleShowVersionHistory(row);
                break;
            case 'test':
                this.handleShowTestModal(row);
                break;
        }
    }

    async handleAddRule() {
        this.isEditMode = false;
        this.modalTitle = 'Add New Screening Rule';
        this.newRule = { 
            Active__c: true, 
            Auto_Route__c: true 
        };
        this.selectedTargetObject = '';
        this.isFieldApiNameDisabled = true;
        this.targetObjectOptions = [];
        this.fieldApiNameOptions = [];
        this.activeTab = 'basic';
        
        await this.loadJobPostingsForModal();
        await this.loadTargetObjects();
        
        this.isModalOpen = true;
    }

    async handleEditRule(row) {
        this.isEditMode = true;
        this.modalTitle = 'Edit Screening Rule (Auto-versioned on save)';
        this.newRule = {
            Id: row.Id,
            Name: row.Name,
            Priority__c: row.priority,
            Applied_Role__c: row.appliedRoleId,
            Target_Object__c: row.targetObject,
            Field_API_Name__c: row.fieldApiName,
            Operator__c: row.operator,
            Expected_Value__c: row.expectedValue,
            Action__c: row.action,
            Failure_Message__c: row.failureMessage,
            Journey_Path__c: row.journeyPath,
            Route_To_Queue__c: row.routeToQueue,
            Escalation_Level__c: row.escalationLevel,
            Allow_Manual_Override__c: row.allowManualOverride,
            Override_Reason_Required__c: row.overrideReasonRequired,
            Override_Approval_Required__c: row.overrideApprovalRequired,
            Group_Name__c: row.groupName,
            Rule_Category__c: row.ruleCategory,
            Match_Type__c: row.matchType,
            Auto_Route__c: row.autoRoute
        };

        this.selectedTargetObject = row.targetObject;
        this.activeTab = 'basic';
        
        await this.loadJobPostingsForModal();
        await this.loadTargetObjects();
        
        if (this.selectedTargetObject) {
            await this.loadFieldsForObject(this.selectedTargetObject);
        }
        
        this.isModalOpen = true;
    }

    handleDeleteRuleFromModal() {
        this.handleDeleteRuleById(this.newRule.Id);
    }

    async handleDeleteRuleById(ruleId) {
        if (!confirm('Are you sure you want to delete this rule and all its versions? This action cannot be undone.')) {
            return;
        }
        this.isLoading = true;
        try {
            await deleteRule({ ruleId });
            this.showToast('Success', 'Rule deleted successfully', 'success');
            if (this.isModalOpen) this.isModalOpen = false;
            await this.loadRules();
        } catch (error) {
            this.showToast('Error deleting rule', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadTargetObjects() {
        try {
            this.targetObjectOptions = await getAvailableObjects();
        } catch (error) {
            console.error('Error loading target objects:', error);
            this.showToast('Error Loading Objects', this.getErrorMessage(error), 'error');
        }
    }

    async loadFieldsForObject(objectApiName) {
        this.isFieldApiNameDisabled = false;
        this.isLoading = true;
        try {
            const result = await getFieldsForObject({ objectApiName });
            this.fieldApiNameOptions = result.map(opt => ({ 
                label: `${opt.label} (${opt.value})`, 
                value: opt.value 
            }));
        } catch (error) {
            this.showToast('Error Loading Fields', this.getErrorMessage(error), 'error');
            this.isFieldApiNameDisabled = true;
        } finally {
            this.isLoading = false;
        }
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleNewRuleChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.detail.value;
        this.newRule = { ...this.newRule, [field]: value };
    }

    handleTargetObjectChange(event) {
        this.selectedTargetObject = event.detail.value;
        this.newRule = { ...this.newRule, Target_Object__c: this.selectedTargetObject };
        this.fieldApiNameOptions = [];
        this.newRule = { ...this.newRule, Field_API_Name__c: null };

        if (this.selectedTargetObject) {
            this.loadFieldsForObject(this.selectedTargetObject);
        } else {
            this.isFieldApiNameDisabled = true;
        }
    }

    async handleSaveNewRule() {
        if (!this.newRule.Name || !this.newRule.Priority__c || !this.newRule.Applied_Role__c) {
            this.showToast('Error', 'Rule Name, Priority, and Job Posting are required', 'error');
            return;
        }
        this.isLoading = true;
        try {
            await saveNewRule({ newRule: this.newRule });
            const action = this.isEditMode ? 'updated (new version created)' : 'created';
            this.showToast('Success', `Rule ${action} successfully`, 'success');
            this.isModalOpen = false;
            await this.loadRules();
        } catch (error) {
            this.showToast('Error saving rule', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Version history - NO manual create button
    async handleShowVersionHistory(row) {
        this.selectedRuleForVersion = row;
        this.isLoading = true;
        try {
            this.versionHistory = await getRuleVersionHistory({ ruleId: row.Id });
            this.isVersionModalOpen = true;
        } catch (error) {
            this.showToast('Error', 'Could not load version history', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    closeVersionModal() {
        this.isVersionModalOpen = false;
        this.versionHistory = [];
        this.selectedRuleForVersion = null;
    }

    async handleRollback(event) {
        const versionId = event.target.dataset.versionId;
        if (!confirm('Are you sure you want to rollback to this version? This will make it the current active version.')) {
            return;
        }
        this.isLoading = true;
        try {
            await rollbackRule({ targetVersionId: versionId });
            this.showToast('Success', 'Rule rolled back successfully', 'success');
            this.closeVersionModal();
            await this.loadRules();
        } catch (error) {
            this.showToast('Error', 'Rollback failed: ' + this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Test sandbox
    handleShowTestModal(row) {
        this.selectedRuleForTest = row;
        this.testCandidateId = '';
        this.testResult = null;
        this.isTestModalOpen = true;
    }

    closeTestModal() {
        this.isTestModalOpen = false;
        this.selectedRuleForTest = null;
        this.testCandidateId = '';
        this.testResult = null;
    }

    handleTestCandidateChange(event) {
        this.testCandidateId = event.detail.value;
    }

    async handleRunTest() {
        if (!this.testCandidateId) {
            this.showToast('Error', 'Please select a candidate to test', 'error');
            return;
        }
        this.isLoading = true;
        try {
            this.testResult = await testRuleAgainstCandidate({ 
                ruleId: this.selectedRuleForTest.Id, 
                candidateId: this.testCandidateId 
            });
            this.showToast('Test Complete', `Result: ${this.testResult.outcome}`, 'info');
        } catch (error) {
            this.showToast('Error', 'Test failed', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get testOutcomeClass() {
        if (!this.testResult) return '';
        switch (this.testResult.outcome) {
            case 'Pass': return 'slds-badge slds-badge_lightest slds-theme_success';
            case 'Fail': return 'slds-badge slds-badge_lightest slds-theme_error';
            case 'Review': return 'slds-badge slds-badge_lightest slds-theme_warning';
            default: return 'slds-badge';
        }
    }

    // Candidate results
    handleCandidateChange(event) {
        this.selectedCandidateId = event.detail.value;
    }

    get isViewResultsDisabled() {
        return !this.selectedCandidateId;
    }

    handleViewResults() {
        if (this.selectedCandidateId) {
            this.isResultModalOpen = true;
        }
    }

    async handleRerunScreening() {
        if (!this.selectedCandidateId) return;
        
        this.isLoading = true;
        try {
            await rerunScreening({ candidateId: this.selectedCandidateId });
            this.showToast('Success', 'Screening process started', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to start screening', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    closeResultsModal() {
        this.isResultModalOpen = false;
    }

    // Statistics
    get totalRules() {
        return this.rules.length;
    }

    get activeRules() {
        return this.rules.filter(r => r.active).length;
    }

    get averagePassRate() {
        const rulesWithData = this.rules.filter(r => r.passRate != null);
        if (rulesWithData.length === 0) return 0;
        const sum = rulesWithData.reduce((acc, r) => acc + r.passRate, 0);
        return (sum / rulesWithData.length).toFixed(1);
    }

    get totalExecutions() {
        return this.rules.reduce((acc, r) => acc + (r.executionCount || 0), 0);
    }

    get filteredRulesCount() {
        return this.filteredRules.length;
    }

    // Utility
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getErrorMessage(error) {
        if (error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map(e => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                return error.body.message;
            }
        }
        return 'An unknown error occurred';
    }

    // Import/Export placeholders
    handleImportRules() {
        this.showToast('Info', 'Import feature coming soon', 'info');
    }

    handleExportRules() {
        this.showToast('Info', 'Export feature coming soon', 'info');
    }
}