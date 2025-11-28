import { LightningElement, api, track } from 'lwc';
import fetchResumePreview from '@salesforce/apex/OnboardingOrchestrator.fetchResumePreview';

export default class ResumePreviewPanel extends LightningElement {
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

    originalEmail = '';

    @track previewFirstName = '';
    @track previewLastName = '';
    @track previewLocation = '';
    @track previewPhone = '';
    @track previewYearsExperience = '';
    @track previewSkills = '';

    async loadPreview() {
        if (!this._candidateId) return;
        this.loading = true;
        this.error = null;
        await new Promise((resolve) => setTimeout(resolve, 1500));

        try {
            const payload = await fetchResumePreview({ candidateId: this._candidateId });

            // --- DEBUGGING LINE ---
            // This will print the exact structure of your skills data to the browser console.
            console.log('DEBUG: Raw skills object from Apex:', JSON.stringify(payload.skills, null, 2));

            this.previewFirstName = payload?.name?.firstName || '';
            this.previewLastName = payload?.name?.lastName || '';
            this.originalEmail = payload?.email || '';
            this.previewPhone = payload?.phone || '';

            let loc = '';
            if (payload?.location) {
                const parts = [payload.location.city, payload.location.state, payload.location.country].filter(Boolean);
                loc = parts.join(', ');
            }
            this.previewLocation = loc;

            this.previewYearsExperience = payload?.years_experience != null ? String(payload.years_experience) : '';

            // --- THE DEFINITIVE FIX IS HERE ---
            // This now correctly handles a variety of possible object structures.
            if (payload?.skills?.length > 0) {
                // The map function now checks for common property names ('name', 'label', 'value')
                // or assumes the item itself is a string. This is much more robust.
                this.previewSkills = payload.skills.map(skill => {
                    if (typeof skill === 'string') return skill; // It's just a string
                    return skill.name || skill.label || skill.value || ''; // It's an object, find the right property
                }).filter(Boolean).join(', ');
            } else {
                this.previewSkills = '';
            }

        } catch (e) {
            this.error = 'Error loading resume preview: ' + ((e?.body?.message) || (e?.message) || JSON.stringify(e));
        } finally {
            this.loading = false;
        }
    }

    // --- Change Handlers ---
    handlePreviewFirstNameChange(event) { this.previewFirstName = event.target.value; }
    handlePreviewLastNameChange(event) { this.previewLastName = event.target.value; }
    handlePreviewLocationChange(event) { this.previewLocation = event.target.value; }
    handlePreviewPhoneChange(event) { this.previewPhone = event.target.value; }
    handlePreviewYearsExperienceChange(event) { this.previewYearsExperience = event.target.value; }
    handlePreviewSkillsChange(event) { this.previewSkills = event.target.value; }

    // --- Button Click Handlers ---
    handleOk() {
        this.dispatchEvent(
            new CustomEvent('confirmed', {
                detail: {
                    candidateId: this._candidateId,
                    firstName: this.previewFirstName,
                    lastName: this.previewLastName,
                    location: this.previewLocation,
                    email: this.originalEmail,
                    phone: this.previewPhone,
                    yearsExperience: this.previewYearsExperience,
                    skills: this.previewSkills
                }
            })
        );
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancelled'));
    }
}
