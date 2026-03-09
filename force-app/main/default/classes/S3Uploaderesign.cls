public with sharing class S3Uploaderesign {

    @future(callout=true)
    public static void uploadFileToS3Async(
        String bucket,
        String key,
        Blob fileBody
    ) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:S3_Uploadesign/' + bucket + '/' + key);
        req.setMethod('PUT');
        req.setBodyAsBlob(fileBody);
        req.setHeader('Content-Type', 'text/html');

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('S3 Upload Status: ' + res.getStatus());
    }
}