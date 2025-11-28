public with sharing class PresignController {
  private static final Integer DEFAULT_TIMEOUT_MS = 120000;

  @AuraEnabled
  public static String getPresignedUrl(String fileName, String contentType, String candidateId) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:CandidateMiddleware/presign');
    req.setMethod('POST');
    req.setHeader('Content-Type','application/json');
    req.setTimeout(DEFAULT_TIMEOUT_MS);
    // Build payload for middleware
    Map<String, Object> payload = new Map<String, Object>{
      'fileName' => fileName,
      'contentType' => contentType,
      'candidateId' => candidateId
    };
    req.setBody(JSON.serialize(payload));
    Http http = new Http();
    HttpResponse res = http.send(req);
    if (res.getStatusCode() >=200 && res.getStatusCode()<300) {
      // return the raw JSON string to LWC (which will parse it)
      return res.getBody();
    } else {
      // bubble error to client
      throw new AuraHandledException('Middleware presign failed: ' + res.getStatusCode() + ' ' + res.getStatus());
    }
  }

  @AuraEnabled
  public static String notifyUpload(String candidateId, String s3Key, String fileName, Long fileSize) {
    try {
      // upsert into Candidate_Document__c; if that object does not exist, adjust to ContentVersion or a custom object
      SObject doc;
      // Attempt to create Candidate_Document__c dynamically to avoid compile time dependency if object absent
      if (Schema.getGlobalDescribe().containsKey('Candidate_Document__c')) {
        doc = (SObject) Schema.getGlobalDescribe().get('Candidate_Document__c').newSObject();
        doc.put('Candidate__c', candidateId);
        doc.put('S3_Key__c', s3Key);
        doc.put('File_Name__c', fileName);
        doc.put('File_Size__c', fileSize);
        doc.put('Status__c', 'Uploaded');
        insert doc;
      } else {
        // fallback: create ContentVersion record (store minimal metadata) OR throw a clear error
        throw new AuraHandledException('Custom object Candidate_Document__c not found. Create it or update the Apex to use your object.');
      }
      return JSON.serialize(new Map<String,String>{'status'=>'ok','s3Key'=>s3Key});
    } catch (Exception ex) {
      throw new AuraHandledException('notifyUpload failed: ' + ex.getMessage());
    }
  }
}
