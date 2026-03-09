public with sharing class FacePlusPlusService {

  @AuraEnabled(cacheable=false)
public static FaceDetectionResult detectFaces(String imageBase64) {

    System.debug('=== detectFaces START ===');
    System.debug('Image Base64 length: ' + (imageBase64 != null ? imageBase64.length() : 0));

    FacePlusPlus_Credential__mdt credential = [
        SELECT ApiKey__c, ApiSecret__c 
        FROM FacePlusPlus_Credential__mdt 
        WHERE DeveloperName = 'Default' 
        LIMIT 1
    ];

    System.debug('Credential fetched successfully');

    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:FacePlusPlus_API/facepp/v3/detect');
    req.setMethod('POST');
    req.setTimeout(60000);

    String body = '';
    body += 'api_key=' + EncodingUtil.urlEncode(credential.ApiKey__c, 'UTF-8');
    body += '&api_secret=' + EncodingUtil.urlEncode(credential.ApiSecret__c, 'UTF-8');
    body += '&image_base64=' + EncodingUtil.urlEncode(imageBase64, 'UTF-8');

    req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    req.setBody(body);

    System.debug('Sending detect callout to Face++');

    try {
        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('Detect Response Status: ' + res.getStatusCode());
        System.debug('Detect Response Body: ' + res.getBody());

        if (res.getStatusCode() == 200) {
            FaceDetectionResult result =
                (FaceDetectionResult) JSON.deserialize(res.getBody(), FaceDetectionResult.class);

            System.debug('Faces detected: ' + result.face_num);
            return result;
        } else {
            throw new AuraHandledException(
                'Face++ API Error: ' + res.getStatusCode() + ' - ' + res.getBody()
            );
        }
    } catch (Exception e) {
        System.debug('Detect Exception: ' + e.getMessage());
        throw new AuraHandledException(
            'An error occurred during the Face++ callout: ' + e.getMessage()
        );
    }
}


   @AuraEnabled(cacheable=false)
public static FaceCompareResult compareFaces(String faceToken1, String faceToken2) {

    System.debug('=== compareFaces START ===');
    System.debug('FaceToken1: ' + faceToken1);
    System.debug('FaceToken2: ' + faceToken2);

    FacePlusPlus_Credential__mdt credential = [
        SELECT ApiKey__c, ApiSecret__c
        FROM FacePlusPlus_Credential__mdt
        WHERE DeveloperName = 'Default'
        LIMIT 1
    ];

    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:FacePlusPlus_API/facepp/v3/compare');
    req.setMethod('POST');
    req.setTimeout(60000);

    String body = '';
    body += 'api_key=' + EncodingUtil.urlEncode(credential.ApiKey__c, 'UTF-8');
    body += '&api_secret=' + EncodingUtil.urlEncode(credential.ApiSecret__c, 'UTF-8');
    body += '&face_token1=' + EncodingUtil.urlEncode(faceToken1, 'UTF-8');
    body += '&face_token2=' + EncodingUtil.urlEncode(faceToken2, 'UTF-8');

    req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    req.setBody(body);

    System.debug('Sending compare callout to Face++');

    try {
        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('Compare Response Status: ' + res.getStatusCode());
        System.debug('Compare Response Body: ' + res.getBody());

        if (res.getStatusCode() == 200) {
            FaceCompareResult result =
                (FaceCompareResult) JSON.deserialize(res.getBody(), FaceCompareResult.class);

            System.debug('Confidence Score: ' + result.confidence);
            return result;
        } else {
            throw new AuraHandledException('Face++ Compare Error: ' + res.getBody());
        }
    } catch (Exception e) {
        System.debug('Compare Exception: ' + e.getMessage());
        throw new AuraHandledException('Compare callout failed: ' + e.getMessage());
    }
}
@AuraEnabled
public static Id saveVerifiedFaceImage(String imageBase64, Id requestId, String signerName) {

    Blob imageBlob = EncodingUtil.base64Decode(imageBase64);

    String safeName = String.isNotBlank(signerName) ? signerName.trim() : 'Signer';

    ContentVersion cv = new ContentVersion();
    cv.Title = safeName + ' - Face Verified';
    cv.PathOnClient = safeName + '_Face_Verified.jpg';
    cv.VersionData = imageBlob;
    cv.FirstPublishLocationId = requestId;
    cv.IsMajorVersion = true;

    insert cv;

    return cv.Id;
}

// Add this method — called from CandidateProfileController
public static String detectFaceAndReturnToken(String imageBase64) {
    
    FacePlusPlus_Credential__mdt credential = [
        SELECT ApiKey__c, ApiSecret__c 
        FROM FacePlusPlus_Credential__mdt 
        WHERE DeveloperName = 'Default' 
        LIMIT 1
    ];

    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:FacePlusPlus_API/facepp/v3/detect');
    req.setMethod('POST');
    req.setTimeout(60000);

    String body = 'api_key='      + EncodingUtil.urlEncode(credential.ApiKey__c, 'UTF-8')
                + '&api_secret='  + EncodingUtil.urlEncode(credential.ApiSecret__c, 'UTF-8')
                + '&image_base64=' + EncodingUtil.urlEncode(imageBase64, 'UTF-8');

    req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    req.setBody(body);

    Http http = new Http();
    HttpResponse res = http.send(req);

    if (res.getStatusCode() == 200) {
        FaceDetectionResult result = 
            (FaceDetectionResult) JSON.deserialize(
                res.getBody(), FaceDetectionResult.class
            );

        if (result.face_num > 0 && result.faces != null && !result.faces.isEmpty()) {
            return result.faces[0].face_token;
        }
        return null; // no face in photo
    }
    
    throw new AuraHandledException('Face++ Error: ' + res.getBody());
}


// Wrapper classes
public class FaceCompareResult {
    @AuraEnabled public Decimal confidence;
    @AuraEnabled public Thresholds thresholds;
}
public class Thresholds {
    @AuraEnabled public Decimal e3;
    @AuraEnabled public Decimal e4;
    @AuraEnabled public Decimal e5;
}

    // Wrapper class to cleanly deserialize the JSON response from Face++
    public class FaceDetectionResult {
        @AuraEnabled public List<Face> faces;
        @AuraEnabled public String image_id;
        @AuraEnabled public Integer face_num;
    }
    public class Face {
        @AuraEnabled public FaceRectangle face_rectangle;
        @AuraEnabled public String face_token;
    }
    public class FaceRectangle {
        @AuraEnabled public Integer top;
        @AuraEnabled public Integer left;
        @AuraEnabled public Integer width;
        @AuraEnabled public Integer height;
    }
}