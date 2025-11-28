import { LightningElement, track } from 'lwc';
import fetchAssessment from '@salesforce/apex/AssessmentInspectorController.fetchAssessment';

export default class AssessmentResultInspector extends LightningElement {
  @track assessmentId=''; @track assessment; @track loading=false; @track error;

  onIdChange(e){ this.assessmentId = e.target.value; }

  async handleLoad(){
    this.loading = true; this.error = undefined;
    try{
      this.assessment = await fetchAssessment({ id: this.assessmentId });
    } catch(err){
      this.error = err.body ? err.body.message : String(err);
      this.assessment = undefined;
    } finally { this.loading = false; }
  }
}
