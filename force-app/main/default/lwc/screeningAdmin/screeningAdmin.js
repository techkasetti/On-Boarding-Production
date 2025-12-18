import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; // CORRECTED LINE
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import SCREENING_RULE_OBJECT from '@salesforce/schema/Screening_Rule__c';
import ACTION_FIELD from '@salesforce/schema/Screening_Rule__c.Action__c';
import OPERATOR_FIELD from '@salesforce/schema/Screening_Rule__c.Operator__c';
import getRules from '@salesforce/apex/ScreeningController.getRules';
import saveRules from '@salesforce/apex/ScreeningController.saveRules';
import saveNewRule from '@salesforce/apex/ScreeningController.saveNewRule';
import deleteRule from '@salesforce/apex/ScreeningController.deleteRule';
import getJobPostings from '@salesforce/apex/ScreeningController.getJobPostings';
import getFieldsForObject from '@salesforce/apex/ScreeningController.getFieldsForObject';
import getAvailableObjects from '@salesforce/apex/ScreeningController.getAvailableObjects';
import getCandidates from '@salesforce/apex/ScreeningController.getCandidates';

const columns = [
    { label: 'Rule Name', fieldName: 'Name', type: 'text', editable: true, wrapText: true },
    { label: 'Applied to Job/Role', fieldName: 'appliedRoleName', type: 'text' },
    { label: 'Priority', fieldName: 'priority', type: 'number', editable: true, cellAttributes: { alignment: 'left' } },
    { label: 'Target Object', fieldName: 'targetObject', type: 'text' },
    { label: 'Operator', fieldName: 'operator', type: 'text' },
    { label: 'Expected Value', fieldName: 'expectedValue', type: 'text', editable: true },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit', name: 'edit' },
                { label: 'Delete', name: 'delete' },
            ],
        },
    },
];

export default class ScreeningAdmin extends LightningElement {
    @track rules = [];
    @track draftValues = [];
    columns = columns;
    isLoading = true;

    // --- Modal Properties ---
    @track isModalOpen = false;
    @track newRule = {};
    @track modalTitle = 'Add New Screening Rule';
    @track isEditMode = false;

    // --- Data for Picklists in Modal ---
    @track jobPostingOptions = [];
    @track actionOptions = [];
    @track operatorOptions = [];

    // --- Dynamic Logic Properties ---
    @track targetObjectOptions = [];
    @track fieldApiNameOptions = [];
    @track isFieldApiNameDisabled = true;
    selectedTargetObject = '';

    // --- NEW: Candidate Results Properties ---
    @track isResultModalOpen = false;
    @track selectedCandidateId = '';
    @track candidateOptions = [];

    // --- WIRE SERVICES ---
    @wire(getObjectInfo, { objectApiName: SCREENING_RULE_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: ACTION_FIELD })
    wiredActionPicklistValues({ error, data }) {
        if (data) {
            this.actionOptions = data.values;
        } else if (error) {
            console.error('Error loading Action picklist values', error);
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: OPERATOR_FIELD })
    wiredOperatorPicklistValues({ error, data }) {
        if (data) {
            this.operatorOptions = data.values;
        } else if (error) {
            console.error('Error loading Operator picklist values', error);
        }
    }
    
    @wire(getCandidates)
    wiredCandidates({ error, data }) {
        if (data) {
            this.candidateOptions = data.map(candidate => ({ label: candidate.Name, value: candidate.Id }));
        } else if (error) {
            this.showToast('Error', 'Could not load candidates.', 'error');
        }
    }

    connectedCallback() {
        this.loadInitialData();
    }

    // --- DATA LOADING ---
    loadInitialData() {
        this.isLoading = true;
        Promise.all([
            getRules(),
            getJobPostings()
        ]).then(([rulesData, jobsData]) => {
            this.rules = rulesData.map(rule => ({ ...rule }));
            this.jobPostingOptions = jobsData.map(job => ({ label: job.Name, value: job.Id }));
            this.draftValues = [];
        }).catch(error => {
            this.showToast('Error Loading Data', this.getErrorMessage(error), 'error');
        }).finally(() => {
            this.isLoading = false;
        });
    }

    loadRules() {
        this.isLoading = true;
        getRules().then(data => {
            this.rules = data.map(rule => ({ ...rule }));
            this.draftValues = [];
        }).catch(error => {
            this.showToast('Error Loading Rules', this.getErrorMessage(error), 'error');
        }).finally(() => {
            this.isLoading = false;
        });
    }

    // --- UI EVENT HANDLERS ---
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
                // For direct delete from row, we need a confirmation.
                // For simplicity, we'll just call the delete method directly.
                // A better UX would be a confirmation modal here.
                this.handleDeleteRuleById(row.Id);
                break;
            default:
        }
    }

    // --- MODAL LOGIC (ADD/EDIT RULE) ---
    handleAddRule() {
        this.isEditMode = false;
        this.modalTitle = 'Add New Screening Rule';
        this.newRule = { Active__c: true };
        this.selectedTargetObject = '';
        this.isFieldApiNameDisabled = true;
        this.targetObjectOptions = [];
        this.fieldApiNameOptions = [];
        this.isModalOpen = true;
        this.loadTargetObjects();
    }

    handleEditRule(row) {
        this.isEditMode = true;
        this.modalTitle = 'Edit Screening Rule';
        this.newRule = JSON.parse(JSON.stringify(row));
        
        // Map frontend-friendly names back to SObject field API names
        this.newRule.Id = row.Id;
        this.newRule.Name = row.Name;
        this.newRule.Priority__c = row.priority;
        this.newRule.Applied_Role__c = row.appliedRoleId;
        this.newRule.Target_Object__c = row.targetObject;
        this.newRule.Field_API_Name__c = row.fieldApiName;
        this.newRule.Operator__c = row.operator;
        this.newRule.Expected_Value__c = row.expectedValue;
        this.newRule.Action__c = row.action;
        this.newRule.Failure_Message__c = row.failureMessage;

        this.selectedTargetObject = row.targetObject;
        this.isModalOpen = true;

        this.loadTargetObjects().then(() => {
            if (this.selectedTargetObject) {
                this.loadFieldsForObject(this.selectedTargetObject);
            }
        });
    }

    // Renamed from handleDeleteRule to avoid confusion
    handleDeleteRuleFromModal() {
        this.handleDeleteRuleById(this.newRule.Id);
    }
    
    handleDeleteRuleById(ruleId) {
        this.isLoading = true;
        deleteRule({ ruleId: ruleId })
            .then(() => {
                this.showToast('Success', 'Rule deleted successfully', 'success');
                if(this.isModalOpen) {
                    this.isModalOpen = false;
                }
                this.loadRules();
            })
            .catch(error => {
                this.showToast('Error deleting rule', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    loadTargetObjects() {
        this.isLoading = true;
        return getAvailableObjects().then(result => {
            this.targetObjectOptions = result;
        }).catch(error => {
            this.showToast('Error Loading Objects', this.getErrorMessage(error), 'error');
        }).finally(() => {
            this.isLoading = false;
        });
    }

    loadFieldsForObject(objectApiName) {
        this.isFieldApiNameDisabled = false;
        this.isLoading = true;
        getFieldsForObject({ objectApiName: objectApiName }).then(result => {
            this.fieldApiNameOptions = result.map(opt => ({ label: `${opt.label} (${opt.value})`, value: opt.value }));
        }).catch(error => {
            this.showToast('Error Loading Fields', this.getErrorMessage(error), 'error');
            this.isFieldApiNameDisabled = true;
        }).finally(() => {
            this.isLoading = false;
        });
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleNewRuleChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
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

    handleSaveNewRule() {
        if (!this.newRule.Name || !this.newRule.Priority__c || !this.newRule.Applied_Role__c) {
            this.showToast('Error', 'Rule Name, Priority, and Job Posting are required.', 'error');
            return;
        }
        this.isLoading = true;
        saveNewRule({ newRule: this.newRule }).then(() => {
            this.showToast('Success', `Rule ${this.isEditMode ? 'updated' : 'created'} successfully`, 'success');
            this.isModalOpen = false;
            this.loadRules();
        }).catch(error => {
            this.showToast('Error saving rule', this.getErrorMessage(error), 'error');
        }).finally(() => {
            this.isLoading = false;
        });
    }

    // --- NEW: CANDIDATE RESULTS MODAL LOGIC ---
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

    closeResultsModal() {
        this.isResultModalOpen = false;
    }

    // --- UTILITY ---
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
        return 'An unknown error occurred.';
    }
}
