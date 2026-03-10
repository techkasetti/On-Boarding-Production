import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getEmployerAccounts from '@salesforce/apex/ShiftAdminController.getEmployerAccounts';
import getEmployees from '@salesforce/apex/ShiftAdminController.getEmployees';
import getTemplates from '@salesforce/apex/ShiftAdminController.getTemplates';
import getTemplateRows from '@salesforce/apex/ShiftAdminController.getTemplateRows';
import getAssignments from '@salesforce/apex/ShiftAdminController.getAssignments';
import createTemplateFromFields from '@salesforce/apex/ShiftAdminController.createTemplateFromFields';
import createAssignment from '@salesforce/apex/ShiftAdminController.createAssignment';
import deleteTemplate from '@salesforce/apex/ShiftAdminController.deleteTemplate';
import checkAssignmentConflicts from '@salesforce/apex/ShiftAdminController.checkAssignmentConflicts';

const TEMPLATE_COLUMNS = [
    { label: 'Template', fieldName: 'templateName', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Shift Type', fieldName: 'shiftType', type: 'text' },
    { label: 'Start', fieldName: 'startTimeDisplay', type: 'text' },
    { label: 'End', fieldName: 'endTimeDisplay', type: 'text' },
    { label: 'Recurrence', fieldName: 'recurrence', type: 'text' },
    { label: 'Days', fieldName: 'daysOfWeek', type: 'text' },
    {
        type: 'button-icon',
        initialWidth: 44,
        typeAttributes: {
            name: 'delete_template',
            title: 'Delete Template',
            iconName: 'utility:delete',
            variant: 'bare',
            alternativeText: 'Delete'
        },
        cellAttributes: { alignment: 'center' }
    }
];

const ASSIGNMENT_COLUMNS = [
    { label: 'Assignment', fieldName: 'assignmentName', type: 'text' },
    { label: 'Employee', fieldName: 'employeeName', type: 'text' },
    { label: 'Template', fieldName: 'templateName', type: 'text' },
    { label: 'Date', fieldName: 'shiftDate', type: 'date' },
    { label: 'Start', fieldName: 'startTimeDisplay', type: 'text' },
    { label: 'End', fieldName: 'endTimeDisplay', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' }
];

export default class ShiftAdminConsole extends LightningElement {
    @track employerOptions = [];
    @track employeeOptions = [];
    @track templateOptions = [];
    @track templateRows = [];
    @track assignmentRows = [];

    activeTab = 'templates';
    employerAccountId;

    templateColumns = TEMPLATE_COLUMNS;
    assignmentColumns = ASSIGNMENT_COLUMNS;

    templateForm = {
        name: '',
        status: 'Draft',
        shiftType: 'Day',
        startTime: '',
        endTime: '',
        breakMinutes: null,
        recurrence: 'None',
        daysOfWeek: [],
        maxHeadcount: null,
        requiredSkill: 'Nurse',
        complianceRequired: false,
        notes: ''
    };

    assignmentForm = {
        employeeId: '',
        templateId: '',
        shiftDate: '',
        startTime: '',
        endTime: '',
        status: 'Scheduled',
        locationName: '',
        notes: ''
    };

    assignmentFilter = {
        startDate: '',
        endDate: ''
    };

    guidedForm = {
        employeeId: '',
        shiftDate: '',
        startTime: '',
        endTime: ''
    };

    conflictBanner;
    conflictBannerClass = 'conflict-banner warning';
    conflictTitle = 'Conflict Check';
    conflictIcon = 'utility:warning';

    guidedConflictMessage;
    guidedBannerClass = 'conflict-banner warning';
    guidedTitle = 'Conflict Check';
    guidedIcon = 'utility:warning';
    guidedConflicts = [];

    templateStatusOptions = [
        { label: 'Draft', value: 'Draft' },
        { label: 'Active', value: 'Active' },
        { label: 'Archived', value: 'Archived' }
    ];

    shiftTypeOptions = [
        { label: 'Day', value: 'Day' },
        { label: 'Evening', value: 'Evening' },
        { label: 'Night', value: 'Night' },
        { label: 'On-Call', value: 'On-Call' }
    ];

    recurrenceOptions = [
        { label: 'None', value: 'None' },
        { label: 'Daily', value: 'Daily' },
        { label: 'Weekly', value: 'Weekly' },
        { label: 'Biweekly', value: 'Biweekly' }
    ];

    daysOfWeekOptions = [
        { label: 'Mon', value: 'Mon' },
        { label: 'Tue', value: 'Tue' },
        { label: 'Wed', value: 'Wed' },
        { label: 'Thu', value: 'Thu' },
        { label: 'Fri', value: 'Fri' },
        { label: 'Sat', value: 'Sat' },
        { label: 'Sun', value: 'Sun' }
    ];

    requiredSkillOptions = [
        { label: 'Nurse', value: 'Nurse' },
        { label: 'Physician', value: 'Physician' },
        { label: 'Medical Assistant', value: 'Medical Assistant' },
        { label: 'Billing', value: 'Billing' }
    ];

    assignmentStatusOptions = [
        { label: 'Scheduled', value: 'Scheduled' },
        { label: 'Confirmed', value: 'Confirmed' },
        { label: 'Completed', value: 'Completed' },
        { label: 'Cancelled', value: 'Cancelled' }
    ];

    isLoading = false;
    hasEmployerAccounts = true;
    autoRefreshHandle;

    connectedCallback() {
        this.startAutoRefresh();
    }

    disconnectedCallback() {
        this.stopAutoRefresh();
    }

    @wire(getEmployerAccounts)
    wiredEmployers({ data, error }) {
        if (data) {
            this.employerOptions = (data || []).filter(
                (opt) => (opt.label || '').trim().toLowerCase() !== 'candidates'
            );
            this.hasEmployerAccounts = this.employerOptions.length > 0;
            if (!this.employerOptions.length) {
                this.resetLoadedData();
            }
        } else if (error) {
            this.showToast('Error', this.resolveError(error), 'error');
            this.hasEmployerAccounts = false;
            this.resetLoadedData();
        }
    }

    get templateSaveDisabled() {
        return !this.employerAccountId ||
            !this.templateForm.name ||
            !this.templateForm.name.trim() ||
            !this.templateForm.startTime ||
            !this.templateForm.endTime;
    }

    get assignmentSaveDisabled() {
        return !this.assignmentForm.employeeId ||
            !this.assignmentForm.shiftDate ||
            !this.assignmentForm.startTime ||
            !this.assignmentForm.endTime ||
            !this.assignmentForm.status;
    }

    get guidedCheckDisabled() {
        return !this.guidedForm.employeeId ||
            !this.guidedForm.shiftDate ||
            !this.guidedForm.startTime ||
            !this.guidedForm.endTime;
    }

    get templateCount() {
        return this.templateRows?.length || 0;
    }

    get assignmentCount() {
        return this.assignmentRows?.length || 0;
    }

    get conflictCount() {
        return this.guidedConflicts?.length || 0;
    }

    get componentVersion() {
        return 'Shift Console v5';
    }

    get isRefreshDisabled() {
        return !this.employerAccountId || this.isLoading;
    }

    get hasTemplateRows() {
        return this.templateRows.length > 0;
    }

    get hasAssignmentRows() {
        return this.assignmentRows.length > 0;
    }

    get dayChips() {
        const selected = new Set(this.templateForm.daysOfWeek || []);
        return this.daysOfWeekOptions.map((day) => ({
            ...day,
            selected: selected.has(day.value),
            className: selected.has(day.value) ? 'day-chip selected' : 'day-chip'
        }));
    }

    get selectedDaysSummary() {
        const selected = this.templateForm.daysOfWeek || [];
        if (!selected.length) {
            return 'No recurring days selected';
        }
        return `Selected: ${selected.join(', ')}`;
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }

    handleEmployerChange(event) {
        this.employerAccountId = event.detail.value;
        this.resetAssignmentForm();
        this.resetTemplateForm();
        this.guidedForm = {
            employeeId: '',
            shiftDate: '',
            startTime: '',
            endTime: ''
        };
        this.guidedConflictMessage = null;
        this.guidedConflicts = [];
        if (this.employerAccountId) {
            this.startAutoRefresh();
            this.refreshAll();
        } else {
            this.stopAutoRefresh();
            this.resetLoadedData();
        }
    }

    handleTemplateChange(event) {
        const field = event.currentTarget?.dataset?.field;
        const value = event.detail?.value ?? event.target.value;
        if (!field) {
            return;
        }
        this.templateForm = { ...this.templateForm, [field]: value };
    }

    handleTemplateCheckbox(event) {
        const field = event.target.dataset.field;
        this.templateForm = { ...this.templateForm, [field]: event.target.checked };
    }

    handleDayToggle(event) {
        const day = event.currentTarget?.dataset?.value;
        if (!day || this.isLoading) {
            return;
        }
        const selected = new Set(this.templateForm.daysOfWeek || []);
        if (selected.has(day)) {
            selected.delete(day);
        } else {
            selected.add(day);
        }
        this.templateForm = { ...this.templateForm, daysOfWeek: Array.from(selected) };
    }

    handleSelectWeekdays() {
        if (this.isLoading) {
            return;
        }
        this.templateForm = { ...this.templateForm, daysOfWeek: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'] };
    }

    handleSelectAllDays() {
        if (this.isLoading) {
            return;
        }
        this.templateForm = { ...this.templateForm, daysOfWeek: this.daysOfWeekOptions.map((day) => day.value) };
    }

    handleClearDays() {
        if (this.isLoading) {
            return;
        }
        this.templateForm = { ...this.templateForm, daysOfWeek: [] };
    }

    async handleSaveTemplate() {
        try {
            this.syncTemplateFormFromDom();
            if (!this.templateForm.name || !this.templateForm.name.trim()) {
                this.showToast('Validation', 'Template name is required.', 'error');
                return;
            }
            if (!this.employerAccountId) {
                this.showToast('Validation', 'Employer Account is required.', 'error');
                return;
            }
            if (!this.templateForm.startTime || !this.templateForm.endTime) {
                this.showToast('Validation', 'Start Time and End Time are required.', 'error');
                return;
            }
            this.isLoading = true;
            await createTemplateFromFields({
                templateName: this.templateForm.name.trim(),
                employerAccountId: this.employerAccountId,
                status: this.templateForm.status,
                shiftType: this.templateForm.shiftType,
                startTime: this.templateForm.startTime,
                endTime: this.templateForm.endTime,
                breakMinutes: this.templateForm.breakMinutes,
                recurrence: this.templateForm.recurrence,
                daysOfWeek: (this.templateForm.daysOfWeek || []).join(';'),
                maxHeadcount: this.templateForm.maxHeadcount,
                requiredSkill: this.templateForm.requiredSkill,
                complianceRequired: !!this.templateForm.complianceRequired,
                notes: this.templateForm.notes
            });
            this.showToast('Success', 'Shift template saved.', 'success');
            this.resetTemplateForm();
            await this.refreshAfterMutation();
        } catch (error) {
            this.showToast('Error', this.resolveError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleQuickTemplate(event) {
        const templateType = event.currentTarget.dataset.type;
        const presets = {
            Day: { name: 'Day Shift', shiftType: 'Day', startTime: '08:00', endTime: '16:00' },
            Evening: { name: 'Evening Shift', shiftType: 'Evening', startTime: '16:00', endTime: '22:00' },
            Night: { name: 'Night Shift', shiftType: 'Night', startTime: '22:00', endTime: '06:00' }
        };
        const preset = presets[templateType];
        if (!preset) {
            return;
        }
        this.templateForm = {
            ...this.templateForm,
            ...preset,
            recurrence: 'Weekly'
        };
    }

    async handleSaveAssignment() {
        try {
            this.syncAssignmentFormFromDom();
            this.isLoading = true;
            await createAssignment({ input: { ...this.assignmentForm } });
            this.showToast('Success', 'Shift assignment saved.', 'success');
            this.resetAssignmentForm();
            await this.refreshAfterMutation();
        } catch (error) {
            this.showToast('Error', this.resolveError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleTemplateRowAction(event) {
        const actionName = event.detail?.action?.name;
        const row = event.detail?.row;
        if (actionName !== 'delete_template' || !row?.templateId) {
            return;
        }

        const confirmed = await LightningConfirm.open({
            message: 'Delete this template? This cannot be undone.',
            variant: 'headerless',
            label: 'Confirm Template Delete'
        });
        if (!confirmed) {
            return;
        }

        this.isLoading = true;
        try {
            await deleteTemplate({ templateId: row.templateId });
            this.showToast('Success', 'Template deleted.', 'success');
            await this.refreshAfterMutation();
        } catch (error) {
            this.showToast('Error', this.resolveError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleAssignmentChange(event) {
        const field = event.currentTarget?.dataset?.field;
        const value = event.detail?.value ?? event.target.value;
        if (!field) {
            return;
        }
        this.assignmentForm = { ...this.assignmentForm, [field]: value };
        this.runConflictCheck();
    }

    handleTemplateSelect(event) {
        const templateId = event.detail.value;
        const selectedTemplate = this.templateRows.find((row) => row.templateId === templateId);
        this.assignmentForm = {
            ...this.assignmentForm,
            templateId,
            startTime: this.asTimeInputValue(selectedTemplate?.startTimeValue, selectedTemplate?.startTime, this.assignmentForm.startTime),
            endTime: this.asTimeInputValue(selectedTemplate?.endTimeValue, selectedTemplate?.endTime, this.assignmentForm.endTime)
        };
        this.runConflictCheck();
    }

    handleFilterChange(event) {
        const field = event.currentTarget?.dataset?.field;
        const value = event.detail?.value ?? event.target.value;
        if (!field) {
            return;
        }
        this.assignmentFilter = { ...this.assignmentFilter, [field]: value };
    }

    async handleFilterApply() {
        await this.refreshAssignments();
    }

    handleGuidedChange(event) {
        const field = event.currentTarget?.dataset?.field;
        const value = event.detail?.value ?? event.target.value;
        if (!field) {
            return;
        }
        this.guidedForm = { ...this.guidedForm, [field]: value };
    }

    async handleConflictCheck() {
        this.syncGuidedFormFromDom();
        await this.fetchConflictResults(this.guidedForm, true);
    }

    async runConflictCheck() {
        if (this.assignmentForm.employeeId &&
            this.assignmentForm.shiftDate &&
            this.assignmentForm.startTime &&
            this.assignmentForm.endTime) {
            await this.fetchConflictResults(this.assignmentForm, false);
        } else {
            this.conflictBanner = null;
        }
    }

    async fetchConflictResults(formData, isGuided) {
        try {
            const result = await checkAssignmentConflicts({
                employeeId: formData.employeeId,
                shiftDate: formData.shiftDate,
                startTime: formData.startTime,
                endTime: formData.endTime
            });
            if (isGuided) {
                this.guidedConflictMessage = result.message;
                this.guidedConflicts = result.conflicts || [];
                this.guidedBannerClass = result.hasConflict ? 'conflict-banner error' : 'conflict-banner success';
                this.guidedTitle = result.hasConflict ? 'Conflict Found' : 'No Conflicts';
                this.guidedIcon = result.hasConflict ? 'utility:error' : 'utility:check';
            } else {
                this.conflictBanner = result.message;
                this.conflictBannerClass = result.hasConflict ? 'conflict-banner error' : 'conflict-banner success';
                this.conflictTitle = result.hasConflict ? 'Conflict Found' : 'No Conflicts';
                this.conflictIcon = result.hasConflict ? 'utility:error' : 'utility:check';
            }
        } catch (error) {
            if (isGuided) {
                this.guidedConflictMessage = this.resolveError(error);
                this.guidedBannerClass = 'conflict-banner error';
                this.guidedTitle = 'Unable To Check';
                this.guidedIcon = 'utility:error';
            } else {
                this.conflictBanner = this.resolveError(error);
                this.conflictBannerClass = 'conflict-banner error';
                this.conflictTitle = 'Unable To Check';
                this.conflictIcon = 'utility:error';
            }
        }
    }

    async handleRefresh() {
        if (!this.employerAccountId) {
            this.showToast('Info', 'Select an employer account to load records.', 'info');
            return;
        }
        this.isLoading = true;
        try {
            await this.refreshAll();
        } finally {
            this.isLoading = false;
        }
    }

    async refreshAll() {
        if (!this.employerAccountId) {
            this.resetLoadedData();
            return;
        }
        await Promise.all([this.refreshTemplates(), this.refreshEmployees(), this.refreshAssignments()]);
    }

    async refreshAfterMutation() {
        // Small delay helps avoid stale reads immediately after DML in high-latency orgs.
        await Promise.resolve();
        await this.refreshAll();
    }

    async refreshTemplates() {
        try {
            const templates = await getTemplates({ accountId: this.employerAccountId });
            this.templateOptions = [...templates];
            this.templateRows = [...await getTemplateRows({ accountId: this.employerAccountId })];
        } catch (error) {
            this.showToast('Error', this.resolveError(error), 'error');
        }
    }

    async refreshEmployees() {
        try {
            this.employeeOptions = [...await getEmployees({ accountId: this.employerAccountId })];
        } catch (error) {
            this.showToast('Error', this.resolveError(error), 'error');
        }
    }

    async refreshAssignments() {
        try {
            const assignments = await getAssignments({
                accountId: this.employerAccountId,
                startDate: this.assignmentFilter.startDate || null,
                endDate: this.assignmentFilter.endDate || null
            });
            this.assignmentRows = [...assignments];
        } catch (error) {
            this.showToast('Error', this.resolveError(error), 'error');
        }
    }

    resetTemplateForm() {
        this.templateForm = {
            name: '',
            status: 'Draft',
            shiftType: 'Day',
            startTime: '',
            endTime: '',
            breakMinutes: null,
            recurrence: 'None',
            daysOfWeek: [],
            maxHeadcount: null,
            requiredSkill: 'Nurse',
            complianceRequired: false,
            notes: ''
        };
    }

    resetAssignmentForm() {
        this.assignmentForm = {
            employeeId: '',
            templateId: '',
            shiftDate: '',
            startTime: '',
            endTime: '',
            status: 'Scheduled',
            locationName: '',
            notes: ''
        };
        this.conflictBanner = null;
    }

    resetLoadedData() {
        this.employeeOptions = [];
        this.templateOptions = [];
        this.templateRows = [];
        this.assignmentRows = [];
    }

    startAutoRefresh() {
        this.stopAutoRefresh();
        this.autoRefreshHandle = window.setInterval(() => {
            if (this.employerAccountId && !this.isLoading) {
                this.refreshAll();
            }
        }, 15000);
    }

    stopAutoRefresh() {
        if (this.autoRefreshHandle) {
            window.clearInterval(this.autoRefreshHandle);
            this.autoRefreshHandle = null;
        }
    }

    asTimeInputValue(primary, fallback, defaultValue = '') {
        if (primary) {
            return primary;
        }
        if (typeof fallback === 'string' && fallback.includes(':')) {
            return fallback.slice(0, 5);
        }
        return defaultValue;
    }

    syncTemplateFormFromDom() {
        const nameInput = this.template.querySelector('[data-id="template-name"]');
        const startInput = this.template.querySelector('[data-id="template-start"]');
        const endInput = this.template.querySelector('[data-id="template-end"]');
        if (nameInput) {
            this.templateForm = { ...this.templateForm, name: nameInput.value };
        }
        if (startInput) {
            this.templateForm = { ...this.templateForm, startTime: startInput.value };
        }
        if (endInput) {
            this.templateForm = { ...this.templateForm, endTime: endInput.value };
        }
    }

    syncAssignmentFormFromDom() {
        const startInput = this.template.querySelector('[data-id="assignment-start"]');
        const endInput = this.template.querySelector('[data-id="assignment-end"]');
        const dateInput = this.template.querySelector('[data-id="assignment-date"]');
        if (startInput) {
            this.assignmentForm = { ...this.assignmentForm, startTime: startInput.value };
        }
        if (endInput) {
            this.assignmentForm = { ...this.assignmentForm, endTime: endInput.value };
        }
        if (dateInput) {
            this.assignmentForm = { ...this.assignmentForm, shiftDate: dateInput.value };
        }
    }

    syncGuidedFormFromDom() {
        const startInput = this.template.querySelector('[data-id="guided-start"]');
        const endInput = this.template.querySelector('[data-id="guided-end"]');
        const dateInput = this.template.querySelector('[data-id="guided-date"]');
        if (startInput) {
            this.guidedForm = { ...this.guidedForm, startTime: startInput.value };
        }
        if (endInput) {
            this.guidedForm = { ...this.guidedForm, endTime: endInput.value };
        }
        if (dateInput) {
            this.guidedForm = { ...this.guidedForm, shiftDate: dateInput.value };
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    resolveError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((entry) => entry.message).join(', ');
        }
        if (error.body?.message) {
            return error.body.message;
        }
        return error.message || 'Unknown error';
    }
}
