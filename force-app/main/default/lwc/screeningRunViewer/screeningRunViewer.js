import { LightningElement, track } from 'lwc';
import fetchRecentRuns from '@salesforce/apex/ScreeningRunViewerController.fetchRecentRuns';
import fetchRunById from '@salesforce/apex/ScreeningRunViewerController.fetchRunById';

export default class ScreeningRunViewer extends LightningElement {
  @track runs = [];
  @track loading = false;
  @track error;
  @track selectedRunId;

  connectedCallback(){ this.load(); }

  async load(){
    this.loading = true; this.error = undefined;
    try {
      const res = await fetchRecentRuns();
      // ensure each run has a stable __isSelected flag
      this.runs = (res || []).map(r => ({ ...r, __isSelected: false }));
    } catch(err){
      this.error = err.body ? err.body.message : String(err);
    } finally {
      this.loading = false;
    }
  }

  handleRefresh(){ this.load(); }

  async handleInspect(e){
    const id = e.target.dataset.id;
    if (!id) return;

    try{
      const rec = await fetchRunById({ id });
      // update runs in-place: mark selected and update the record with fetched fields
      this.runs = this.runs.map(r => {
        if (r.Id === id) {
          // merge server response into the list item and set selected flag
          return { ...rec, __isSelected: true };
        }
        // clear previously selected flags
        return { ...r, __isSelected: false };
      });
      this.selectedRunId = id;
    } catch(err){
      this.error = err.body ? err.body.message : String(err);
    }
  }
}
