import { LightningElement, api, track } from 'lwc';
import fetchResumePreviewV2 from '@salesforce/apex/OnboardingOrchestratorV2.fetchResumePreviewV2';

export default class ResumePreviewPanelV2 extends LightningElement {
    _candidateId;
    @api get candidateId() {
        return this._candidateId;
    }
    set candidateId(value) {
        this._candidateId = value;
        if (value) {
            this.loadPreview();
        }
    }

    @track loading = true;
    @track error;

    // Form field properties
    @track fullName = '';
    @track email = '';
    @track phone = '';
    @track licensesAndCertifications = '';
    @track clinicalSkills = '';
    @track workExperience = {};
    @track internship = {};
    @track education = {};
    @track proceduresPerformed = '';
    @track researchAndPublications = '';
    @track technicalSkills = '';
    @track professionalMemberships = '';

    async loadPreview() {
        this.loading = true;
        this.error = null;
        try {
            const jsonString = await fetchResumePreviewV2({ candidateId: this._candidateId });
            if (!jsonString) {
                throw new Error('Received an empty response from the server.');
            }
            const payload = JSON.parse(jsonString);

            // Personal Information
            this.fullName = payload.personalInformation?.value?.fullName || '';
            this.email = payload.personalInformation?.value?.email || '';
            this.phone = payload.personalInformation?.value?.phone || '';

            // Arrays joined to comma-separated strings for textareas
            this.licensesAndCertifications = (payload.licensesAndCertifications?.value || []).join(', ');
            this.clinicalSkills = (payload.clinicalSkills?.value || []).join(', ');
            this.proceduresPerformed = (payload.proceduresPerformed?.value || []).join(', ');
            this.technicalSkills = (payload.technicalSkills?.value || []).join(', ');
            this.professionalMemberships = (payload.professionalMemberships?.value || []).join(', ');
            this.researchAndPublications = (payload.researchAndPublications?.value || []).join(', ');

            // Complex Objects
            this.workExperience = { ...payload.workExperience?.value, responsibilities: (payload.workExperience?.value?.responsibilities || []).join(', ') };
            this.internship = { ...payload.internship?.value, rotations: (payload.internship?.value?.rotations || []).join(', ') };
            this.education = { ...payload.education?.value };

        } catch (e) {
            this.error = 'Error loading resume preview: ' + ((e?.body?.message) || e.message);
            console.error('RESUME PREVIEW ERROR:', this.error, JSON.stringify(e));
        } finally {
            this.loading = false;
        }
    }

    handleInputChange(event) {
        this[event.target.dataset.id] = event.target.value;
    }

    handleObjectChange(event) {
        const section = event.target.dataset.section;
        const field = event.target.dataset.id;
        this[section] = { ...this[section], [field]: event.target.value };
    }

    handleOk() {
        // Rebuild the payload from the form fields, splitting strings back into arrays
        const detailPayload = {
            // *** THE FIX: Add the candidateId to the payload object ***
            candidateId: this._candidateId,
            
            personalInformation: {
                value: { fullName: this.fullName, email: this.email, phone: this.phone }
            },
            licensesAndCertifications: {
                value: this.licensesAndCertifications.split(',').map(s => s.trim()).filter(Boolean)
            },
            clinicalSkills: {
                value: this.clinicalSkills.split(',').map(s => s.trim()).filter(Boolean)
            },
            workExperience: {
                value: { ...this.workExperience, responsibilities: this.workExperience.responsibilities.split(',').map(s => s.trim()).filter(Boolean) }
            },
            internship: {
                value: { ...this.internship, rotations: this.internship.rotations.split(',').map(s => s.trim()).filter(Boolean) }
            },
            education: {
                value: this.education
            },
            proceduresPerformed: {
                value: this.proceduresPerformed.split(',').map(s => s.trim()).filter(Boolean)
            },
            researchAndPublications: {
                value: this.researchAndPublications.split(',').map(s => s.trim()).filter(Boolean)
            },
            technicalSkills: {
                value: this.technicalSkills.split(',').map(s => s.trim()).filter(Boolean)
            },
            professionalMemberships: {
                value: this.professionalMemberships.split(',').map(s => s.trim()).filter(Boolean)
            }
        };

        this.dispatchEvent(new CustomEvent('confirmed', { detail: detailPayload }));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancelled'));
    }
}