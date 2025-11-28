import { LightningElement, track } from 'lwc';
import getVersions from '@salesforce/apex/SchemaVersionManager.getVersions';
import activateVersion from '@salesforce/apex/SchemaVersionManager.activateVersion';

export default class SchemaVersionHistory extends LightningElement {
  @track versions; @track error;

  connectedCallback(){ this.load(); }

  async load(){
    try{ this.versions = await getVersions(); } catch(err){ this.error = err.body ? err.body.message : String(err); }
  }

  async handleActivate(e){
    const version = e.target.dataset.version;
    try{
      await activateVersion({ version });
      await this.load();
    } catch(err){ this.error = err.body ? err.body.message : String(err); }
  }
}
