import { LightningElement,api,track } from 'lwc';
import getAllfieldsFromMetadata from '@salesforce/apex/PassJsonDataController.getAllfieldsFromMetadata';
import getAllRelatedChildObjects from '@salesforce/apex/PassJsonDataController.getAllRelatedChildObjects';

export default class ChildLwc extends LightningElement {
  @api storejson;
  @track storejson;
  @api item;
  @track objectOptions;
  @track childObjectOptions;
    @api row;
  @track fieldsForRequiredObject=[];
  @track SelObj; 
  @track SelectedObj; 
  @track storejsonValue = [];
  @track allField = [];  @track getAllField = [];
  @track allObject = [];  @track getAllObject = [];
  @track allChildObj = []; @track allChildObject = [];
  @track relatedObjChlid; @track relatedChildObjects;

  connectedCallback(){
    getAllfieldsFromMetadata()
       .then(result => {
           const objectfields = result.objectfield;
           console.log('get-All-fields-From-Metadata-->'+JSON.stringify(result.objectfield));
           const arrayMapKey = [];
           for (let key in objectfields) {
               arrayMapKey.push({ key: key, value: objectfields[key] });
           }
           this.getAllObject = arrayMapKey;
        //    this.objectOptions = this.getAllObject;
          //  this.getAllField = arrayMapKey;
           console.log('get all object-->'+JSON.stringify(this.getAllObject));

       })
       .catch(error => {
           console.error('Error fetching fields from metadata:', error);
       });
  
       this.childarrayMap = [];

   getAllRelatedChildObjects()
       .then(result => {
           const relChildObjects = result.relatedObjectmap;
           const childarrayMapValues = [];

           for (const key in relChildObjects) {
               if (relChildObjects.hasOwnProperty(key)) {
                   childarrayMapValues.push({ key: key, value: relChildObjects[key] });
               }
           }
           this.relatedObjChlid = childarrayMapValues;
         
           const relatedChildFieldsMap = result.relatedFieldsMap;
           for (const key in relatedChildFieldsMap) {
               if (relatedChildFieldsMap.hasOwnProperty(key)) {
                   this.childarrayMap.push({ key: key, value: relatedChildFieldsMap[key] });
               }
           }
           console.log('Child object fields-->'+JSON.stringify(this.childarrayMap));
           })
       .catch(error => {
         //  this.hideSpinner();
           console.error('Error fetching related child objects:', error.message);
       });
this.setJsonValue();
}

setJsonValue(){
    alert();
    const pushallvalue = [];
    for(var i=0;i<this.storejson.length;i++){
       // console.log(' this.SelObj-->'+this.storejson[i].Name);
      pushallvalue.push({ "Name": this.storejson[i].Name,"SF_Object1_Field_Name__c": null, "ObjectNames1__c": null, "ChildObjectName1__c": null});
      }
      this.storejsonValue=pushallvalue;
      console.log('objectValue'+JSON.stringify(this.storejsonValue));
}

handleChange(event) {
  const selectedField = event.currentTarget.dataset.id;
//   alert('selectedField'+selectedField);
  console.log('objectValue'+JSON.stringify(this.storejson));

  const selectedValue = event.target.value;

 
  this.SelObj = selectedValue;
 
  
  this.storejson[event.currentTarget.dataset.id].ObjectNames1__c=event.target.value;
  if(this.SelObj ==null){
      this.relatedChildObjects=null;
  }
   if (this.SelObj =='Sales_Order__c'){
       this.relatedChildObjects=this.childarrayMap;
    //   this.childObjectOptions=this.childarrayMap;
  }
  console.log('storejson values-->'+JSON.stringify(this.storejsonValue));
}




handleChildField(event) {
    const selectedField = event.target.id;
    const childObjField = event.target.value;
    this.SelectedChildField = childObjField;
    console.log('Selected Child Obj Name-->'+this.SelectedChildField);
    console.log('data id set-->'+event.currentTarget.dataset.id);

    this.storejson[event.currentTarget.dataset.id].SF_Object1_Field_Name__c=event.target.value;
    console.log('storejson Field value-->'+JSON.stringify(this.storejson));

}

getValuesByKey(childarrayMap, requiredKey) {
    const result = [];
    for (const item of childarrayMap) {
        if (item.key === requiredKey) {
        const fields = item.value;
        fields.forEach(field => {
            result.push(field.split(','));
        });
        }
    }
    return result;
}

@track fieldsForRequiredObject=[];
handleChildObjName(event) {
    const selectedFieldId = event.currentTarget.dataset.id;
    const childObjValue = event.target.value;
    this.SelectedChildObjName = childObjValue;
    console.log('Selected Child Obj Name-->'+this.SelectedChildObjName);
    
    this.storejson[event.currentTarget.dataset.id].ChildObjectName1__c=this.SelectedChildObjName;
    console.log('storejson Child Object value-->'+JSON.stringify(this.storejson));
    
    if(this.childarrayMap){
        const requiredObject = this.SelectedChildObjName; // Replace with the object name you want
        
        this.fieldsForRequiredObject = this.getValuesByKey(this.childarrayMap, requiredObject);
        console.log('Fields for -->' + requiredObject + ': ' + this.fieldsForRequiredObject);    
    }

}
}