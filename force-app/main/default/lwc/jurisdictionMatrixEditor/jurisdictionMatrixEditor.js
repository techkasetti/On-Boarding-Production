import { LightningElement, track } from 'lwc';
import loadMatrix from '@salesforce/apex/JurisdictionMatrixController.loadMatrix';
import upsertMatrix from '@salesforce/apex/JurisdictionMatrixController.upsertMatrix';
import deleteMatrix from '@salesforce/apex/JurisdictionMatrixController.deleteMatrix';

export default class JurisdictionMatrixEditor extends LightningElement {
  @track country=''; @track state=''; @track routingKey=''; @track matrix; @track error;
  countryOptions = [{label:'United States', value:'US'},{label:'India', value:'IN'}];

  connectedCallback(){ this.refresh(); }

  async refresh(){ 
    try{ this.matrix = await loadMatrix(); } catch(err){ this.error = err.body ? err.body.message : String(err); }
  }

  onCountryChange(e){ this.country = e.detail.value; }
  onStateChange(e){ this.state = e.target.value; }
  onRoutingKeyChange(e){ this.routingKey = e.target.value; }

  async handleUpsert(){
    this.error = undefined;
    try{
      await upsertMatrix({ country:this.country, state:this.state, routingKey:this.routingKey });
      await this.refresh();
    } catch(err){ this.error = err.body ? err.body.message : String(err); }
  }

  async handleDelete(e){
    const id = e.target.dataset.id;
    try{ await deleteMatrix({ id }); await this.refresh(); } catch(err){ this.error = err.body ? err.body.message : String(err); }
  }
}
