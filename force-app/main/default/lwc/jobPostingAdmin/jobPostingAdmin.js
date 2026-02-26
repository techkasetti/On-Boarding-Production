// jobPostingAdmin.js - WITH TAB NAVIGATION
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import getJobPostings from '@salesforce/apex/JobPostingAdminController.getJobPostings';
import saveJobPosting from '@salesforce/apex/JobPostingAdminController.saveJobPosting';
import deleteJobPosting from '@salesforce/apex/JobPostingAdminController.deleteJobPosting';
import getPicklistValues from '@salesforce/apex/JobPostingAdminController.getPicklistValues';

const actions = [
    { label: 'Edit', name: 'edit', iconName: 'utility:edit' },
    { label: 'Delete', name: 'delete', iconName: 'utility:delete' }
];

export default class JobPostingAdmin extends NavigationMixin(LightningElement) {
    @track jobPostings = [];
    @track filteredJobPostings = [];
    @track columns = [];
    @track currentJob = {};
    
    // Picklist Options
    @track categoryOptions = [];
    @track roleTypeOptions = [];
    @track departmentOptions = [];
    @track employmentTypeOptions = [];
    @track shiftTypeOptions = [];
    @track skillLevelOptions = [];

    // Child Objects
    @track educationRequirements = [];
    @track licenseRequirements = [];
    @track certificationRequirements = [];
    @track clinicalSkills = [];
    @track procedureRequirements = [];
    @track complianceRequirements = [];

    isModalOpen = false;
    isDeleteModalOpen = false;
    modalTitle = '';
    searchKey = '';
    isLoading = false;
    jobToDelete = null;
    activeTab = 'basic';
    currentPage = 1;
    pageSize = 10;
    // Counter for generating unique keys
    keyCounter = 0;

    get totalJobs() {
        return this.filteredJobPostings.length;
    }

    get hasJobs() {
        return this.filteredJobPostings.length > 0;
    }
    get paginatedJobs() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    return this.filteredJobPostings.slice(start, end);
}

get totalPages() {
    return Math.ceil(this.filteredJobPostings.length / this.pageSize);
}

get startRecord() {
    return this.filteredJobPostings.length === 0 ? 0 : (this.currentPage - 1) * this.pageSize + 1;
}

get endRecord() {
    const end = this.currentPage * this.pageSize;
    return end > this.filteredJobPostings.length ? this.filteredJobPostings.length : end;
}

get isFirstPage() {
    return this.currentPage === 1;
}

get isLastPage() {
    return this.currentPage === this.totalPages || this.totalPages === 0;
}

get pageInfo() {
    return `Page ${this.currentPage} of ${this.totalPages}`;
}
handlePrevious() {
    if (this.currentPage > 1) {
        this.currentPage -= 1;
    }
}

handleNext() {
    if (this.currentPage < this.totalPages) {
        this.currentPage += 1;
    }
}
    connectedCallback() {
        this.loadData();
        this.initializeSkillLevelOptions();
    }

    /**
     * Navigate to AI Console Tab
     */
    handleNavigateToAIConsole() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'AI_Job_Posting_Console' 
            }
        });
    }

    initializeSkillLevelOptions() {
        this.skillLevelOptions = [
            { label: 'Basic', value: 'Basic' },
            { label: 'Intermediate', value: 'Intermediate' },
            { label: 'Advanced', value: 'Advanced' }
        ];
    }

    async loadData() {
        this.isLoading = true;
        try {
            const [categoryData, roleTypeData, departmentData, employmentTypeData, shiftTypeData] = await Promise.all([
                getPicklistValues({ fieldName: 'Category__c' }),
                getPicklistValues({ fieldName: 'Role_Type__c' }),
                getPicklistValues({ fieldName: 'Department__c' }),
                getPicklistValues({ fieldName: 'Employment_Type__c' }),
                getPicklistValues({ fieldName: 'Shift_Type__c' })
            ]);

            this.categoryOptions = categoryData;
            this.roleTypeOptions = roleTypeData;
            this.departmentOptions = departmentData;
            this.employmentTypeOptions = employmentTypeData;
            this.shiftTypeOptions = shiftTypeData;

            this.columns = [
                { 
                    label: 'Job Title', 
                    fieldName: 'Job_Title__c', 
                    type: 'text', 
                    wrapText: true,
                    cellAttributes: { class: 'slds-text-title_bold' }
                },
                { 
                    label: 'Category', 
                    fieldName: 'Category__c', 
                    type: 'text'
                },
                { 
                    label: 'Role Type', 
                    fieldName: 'Role_Type__c', 
                    type: 'text'
                },
                { 
                    label: 'Department', 
                    fieldName: 'Department__c', 
                    type: 'text'
                },
                { 
                    label: 'Facility', 
                    fieldName: 'Facility_Name__c', 
                    type: 'text'
                },
                { 
                    label: 'City', 
                    fieldName: 'City__c', 
                    type: 'text'
                },
                { 
                    label: 'Start Date', 
                    fieldName: 'Start_Date__c', 
                    type: 'date',
                    typeAttributes: {
                        year: 'numeric',
                        month: 'short',
                        day: '2-digit'
                    }
                },
                { 
                    label: 'Status', 
                    fieldName: 'Job_Status__c', 
                    type: 'text',
                    cellAttributes: { 
                        class: { fieldName: 'statusClass' }
                    }
                },
                { 
                    type: 'action', 
                    typeAttributes: { rowActions: actions }
                }
            ];

            await this.refreshJobData();

        } catch (error) {
            this.showToast(
                'Error Loading Data',
                error.body ? error.body.message : error.message,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async refreshJobData() {
        try {
            const jobData = await getJobPostings();
            this.jobPostings = jobData.map(record => ({
                ...record,
                statusClass: this.getStatusClass(record.Job_Status__c)
            }));
            this.filteredJobPostings = [...this.jobPostings];
            
            if (this.searchKey) {
                this.applySearchFilter();
            }
        } catch (error) {
            throw error;
        }
    }

    getStatusClass(status) {
        const statusMap = {
            'Open': 'status-active',
            'Closed': 'status-closed'
        };
        return statusMap[status] || 'status-draft';
    }

    // handleSearch(event) {
    //     this.searchKey = event.target.value.toLowerCase();
    //     this.applySearchFilter();
    // }
handleSearch(event) {
    this.searchKey = event.target.value.toLowerCase();
    this.currentPage = 1; // reset to first page
    this.applySearchFilter();
}
    applySearchFilter() {
        if (!this.searchKey) {
            this.filteredJobPostings = [...this.jobPostings];
            return;
        }

        this.filteredJobPostings = this.jobPostings.filter(job => {
            return (
                (job.Job_Title__c && job.Job_Title__c.toLowerCase().includes(this.searchKey)) ||
                (job.Category__c && job.Category__c.toLowerCase().includes(this.searchKey)) ||
                (job.Facility_Name__c && job.Facility_Name__c.toLowerCase().includes(this.searchKey)) ||
                (job.City__c && job.City__c.toLowerCase().includes(this.searchKey))
            );
        });
    }

    handleNew() {
        this.modalTitle = 'Create New Job Posting';
        this.currentJob = {
            Credentialing_Required__c: true
        };
        this.educationRequirements = [];
        this.licenseRequirements = [];
        this.certificationRequirements = [];
        this.clinicalSkills = [];
        this.procedureRequirements = [];
        this.complianceRequirements = [];
        this.activeTab = 'basic';
        this.isModalOpen = true;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit') {
            this.modalTitle = 'Edit Job Posting';
            this.currentJob = { ...row };
            
            this.educationRequirements = this.getChildRecords(row.Education_Requirements__r);
            this.licenseRequirements = this.getChildRecords(row.License_Requirements__r);
            this.certificationRequirements = this.getChildRecords(row.Certification_Requirements__r);
            this.clinicalSkills = this.getChildRecords(row.Job_Clinical_Skill__r);
            this.procedureRequirements = this.getChildRecords(row.Job_Procedure_Requirements__r);
            this.complianceRequirements = this.getChildRecords(row.Job_Compliance_Requirements__r);
            
            this.activeTab = 'basic';
            this.isModalOpen = true;
        } else if (actionName === 'delete') {
            this.jobToDelete = row;
            this.isDeleteModalOpen = true;
        }
    }

//Organization
handleAccountChange(event) {
    this.currentJob.Account__c = event.detail.recordId;
    this.currentJob = { ...this.currentJob };
}

getChildRecords(childArray) {
        if (!childArray || !Array.isArray(childArray)) {
            return [];
        }
        return childArray.map(item => ({...item, key: this.generateKey()}));
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.currentJob[field] = value;
        this.currentJob = { ...this.currentJob };
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }

    // ========== EDUCATION REQUIREMENTS ==========
    handleAddEducation() {
        this.educationRequirements = [...this.educationRequirements, {
            key: this.generateKey(),
            Degree_Name__c: '',
            Mandatory__c: false
        }];
    }

    handleEducationChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        
        this.educationRequirements[index][field] = value;
        this.educationRequirements = [...this.educationRequirements];
    }

    handleRemoveEducation(event) {
        const index = parseInt(event.target.dataset.index);
        this.educationRequirements.splice(index, 1);
        this.educationRequirements = [...this.educationRequirements];
    }

    // ========== LICENSE REQUIREMENTS ==========
    handleAddLicense() {
        this.licenseRequirements = [...this.licenseRequirements, {
            key: this.generateKey(),
            License_Name__c: '',
            Issuing_Authority__c: '',
            Active_Required__c: false,
            Expiry_Check_Required__c: false
        }];
    }

    handleLicenseChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        
        this.licenseRequirements[index][field] = value;
        this.licenseRequirements = [...this.licenseRequirements];
    }

    handleRemoveLicense(event) {
        const index = parseInt(event.target.dataset.index);
        this.licenseRequirements.splice(index, 1);
        this.licenseRequirements = [...this.licenseRequirements];
    }

    // ========== CERTIFICATION REQUIREMENTS ==========
    handleAddCertification() {
        this.certificationRequirements = [...this.certificationRequirements, {
            key: this.generateKey(),
            Certification_Name__c: '',
            Mandatory__c: false
        }];
    }

    handleCertificationChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        
        this.certificationRequirements[index][field] = value;
        this.certificationRequirements = [...this.certificationRequirements];
    }

    handleRemoveCertification(event) {
        const index = parseInt(event.target.dataset.index);
        this.certificationRequirements.splice(index, 1);
        this.certificationRequirements = [...this.certificationRequirements];
    }

    // ========== CLINICAL SKILLS ==========
    handleAddSkill() {
        this.clinicalSkills = [...this.clinicalSkills, {
            key: this.generateKey(),
            Skill_Name__c: '',
            Skill_Level__c: '',
            Mandatory__c: false
        }];
    }

    handleSkillChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        
        this.clinicalSkills[index][field] = value;
        this.clinicalSkills = [...this.clinicalSkills];
    }

    handleRemoveSkill(event) {
        const index = parseInt(event.target.dataset.index);
        this.clinicalSkills.splice(index, 1);
        this.clinicalSkills = [...this.clinicalSkills];
    }

    // ========== PROCEDURE REQUIREMENTS ==========
    handleAddProcedure() {
        this.procedureRequirements = [...this.procedureRequirements, {
            key: this.generateKey(),
            Procedure_Name__c: '',
            Critical__c: false
        }];
    }

    handleProcedureChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        
        this.procedureRequirements[index][field] = value;
        this.procedureRequirements = [...this.procedureRequirements];
    }

    handleRemoveProcedure(event) {
        const index = parseInt(event.target.dataset.index);
        this.procedureRequirements.splice(index, 1);
        this.procedureRequirements = [...this.procedureRequirements];
    }

    // ========== COMPLIANCE REQUIREMENTS ==========
    handleAddCompliance() {
        this.complianceRequirements = [...this.complianceRequirements, {
            key: this.generateKey(),
            Compliance_Name__c: '',
            Mandatory__c: false
        }];
    }

    handleComplianceChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        
        this.complianceRequirements[index][field] = value;
        this.complianceRequirements = [...this.complianceRequirements];
    }

    handleRemoveCompliance(event) {
        const index = parseInt(event.target.dataset.index);
        this.complianceRequirements.splice(index, 1);
        this.complianceRequirements = [...this.complianceRequirements];
    }

    // ========== SAVE LOGIC ==========
    async handleSave() {
        if (!this.currentJob.Job_Title__c) {
            this.showToast('Validation Error', 'Job Title is required.', 'error');
            return;
        }

        if (!this.currentJob.Category__c) {
            this.showToast('Validation Error', 'Category is required.', 'error');
            return;
        }

        if (!this.currentJob.Role_Type__c) {
            this.showToast('Validation Error', 'Role Type is required.', 'error');
            return;
        }

        if (!this.currentJob.Employment_Type__c) {
            this.showToast('Validation Error', 'Employment Type is required.', 'error');
            return;
        }

        if (!this.currentJob.Facility_Name__c) {
            this.showToast('Validation Error', 'Facility Name is required.', 'error');
            return;
        }

        if (!this.currentJob.City__c || !this.currentJob.State__c || !this.currentJob.Country__c) {
            this.showToast('Validation Error', 'Complete location (City, State, Country) is required.', 'error');
            return;
        }

        if (!this.currentJob.Start_Date__c) {
            this.showToast('Validation Error', 'Start Date is required.', 'error');
            return;
        }

        if (this.currentJob.Start_Date__c && this.currentJob.End_Date__c) {
            const startDate = new Date(this.currentJob.Start_Date__c);
            const endDate = new Date(this.currentJob.End_Date__c);
            
            if (endDate < startDate) {
                this.showToast('Validation Error', 'End Date cannot be before Start Date.', 'error');
                return;
            }
        }

        if (this.currentJob.Min_Experience_Years__c && this.currentJob.Max_Experience_Years__c) {
            if (parseInt(this.currentJob.Max_Experience_Years__c) < parseInt(this.currentJob.Min_Experience_Years__c)) {
                this.showToast('Validation Error', 'Maximum Experience cannot be less than Minimum Experience.', 'error');
                return;
            }
        }

        this.isLoading = true;
        try {
            const dataToSave = {
                jobPosting: this.currentJob,
                educationRequirements: this.educationRequirements.filter(item => item.Degree_Name__c),
                licenseRequirements: this.licenseRequirements.filter(item => item.License_Name__c),
                certificationRequirements: this.certificationRequirements.filter(item => item.Certification_Name__c),
                clinicalSkills: this.clinicalSkills.filter(item => item.Skill_Name__c),
                procedureRequirements: this.procedureRequirements.filter(item => item.Procedure_Name__c),
                complianceRequirements: this.complianceRequirements.filter(item => item.Compliance_Name__c)
            };

            await saveJobPosting({ jobPostingData: JSON.stringify(dataToSave) });
            
            this.showToast(
                'Success', 
                this.currentJob.Id ? 'Job Posting updated successfully.' : 'Job Posting created successfully.', 
                'success'
            );

            this.closeModal();
            await this.refreshJobData();

        } catch (error) {
            this.showToast(
                'Error Saving',
                error.body ? error.body.message : error.message,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    async confirmDelete() {
        if (!this.jobToDelete) return;

        this.isLoading = true;
        try {
            await deleteJobPosting({ jobPostingId: this.jobToDelete.Id });
            this.showToast('Success', 'Job Posting deleted successfully.', 'success');
            this.closeDeleteModal();
            await this.refreshJobData();
            
        } catch (error) {
            this.showToast(
                'Error Deleting',
                error.body ? error.body.message : error.message,
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    closeModal() {
        this.isModalOpen = false;
        this.currentJob = {};
        this.educationRequirements = [];
        this.licenseRequirements = [];
        this.certificationRequirements = [];
        this.clinicalSkills = [];
        this.procedureRequirements = [];
        this.complianceRequirements = [];
        this.activeTab = 'basic';
    }

    closeDeleteModal() {
        this.isDeleteModalOpen = false;
        this.jobToDelete = null;
    }

    generateKey() {
        return `key_${this.keyCounter++}_${Date.now()}`;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}