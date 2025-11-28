import { LightningElement, track } from 'lwc';
import saveRule from '@salesforce/apex/ScreeningRuleAdminController.saveRule';
import previewRule from '@salesforce/apex/ScreeningRuleAdminController.previewRule';

export default class ScreeningRuleAdmin extends LightningElement {
  @track ruleName = '';
  @track expression = '';
  @track enabled = false;
  @track samplePayload = '{"amount":12345,"country":"US"}';
  @track previewResult;
  @track error;

  onNameChange(e){ this.ruleName = e.target.value; }
  onExpressionChange(e){ this.expression = e.target.value; }
  onEnabledChange(e){ this.enabled = e.target.checked; }
  onSampleChange(e){ this.samplePayload = e.target.value; }

  async handleSave(){
    this.error = undefined;
    try{
      const res = await saveRule({ name: this.ruleName, expr: this.expression, enabled: this.enabled });
      if(res && res.success){
        this.dispatchEvent(new CustomEvent('rulesaved',{detail:{id:res.id}}));
      } else {
        this.error = res.message || 'Save failed';
      }
    } catch(err){
      this.error = err.body ? err.body.message : String(err);
    }
  }

  async handlePreview(){
    this.error = undefined;
    try{
      const payload = JSON.parse(this.samplePayload);
      const res = await previewRule({ expr: this.expression, payloadJson: JSON.stringify(payload) });
      this.previewResult = JSON.stringify(res, null, 2);
    } catch(err){
      this.error = 'Preview failed: ' + (err.body ? err.body.message : String(err));
    }
  }

  handleReset(){
    this.ruleName = '';
    this.expression = '';
    this.enabled = false;
    this.previewResult = undefined;
    this.error = undefined;
  }
}
