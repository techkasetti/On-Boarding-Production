import { LightningElement, wire, track } from 'lwc';
import getFeatures from '@salesforce/apex/AIFeatureController.getFeatures';
import toggleFeature from '@salesforce/apex/AIFeatureController.toggleFeature';
import createFeature from '@salesforce/apex/AIFeatureController.createFeature';

import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AiFeatureConsole extends LightningElement {

    @track features;
    wiredResult;

    showModal = false;

    name;
    description;

    @wire(getFeatures)
    wiredFeatures(result){
        this.wiredResult = result;

        if(result.data){
            this.features = result.data;
        }
    }

    handleToggle(event){

        const featureId = event.target.dataset.id;
        const status = event.target.checked;

        toggleFeature({
            featureId : featureId,
            status : status
        })
        .then(()=>{
            this.showToast('Success','Feature Updated','success');
            return refreshApex(this.wiredResult);
        });
    }

    openModal(){
        this.showModal = true;
    }

    closeModal(){
        this.showModal = false;
    }

    handleName(event){
        this.name = event.target.value;
    }

    handleDescription(event){
        this.description = event.target.value;
    }

    createFeature(){

        createFeature({
            name : this.name,
            description : this.description
        })
        .then(()=>{

            this.showToast('Success','Feature Created','success');

            this.showModal = false;

            this.name = '';
            this.description = '';

            return refreshApex(this.wiredResult);
        });
    }

    showToast(title,message,variant){

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}
