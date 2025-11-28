@isTest
global class PresignMock implements HttpCalloutMock {
  global HTTPResponse respond(HTTPRequest req) {
    HttpResponse res = new HttpResponse();
    res.setStatusCode(200);
    // return JSON: presignedUrl and s3Key
    Map<String,Object> r = new Map<String,Object>{
      'presignedUrl' => 'https://s3-presigned.example.com/put/abc123',
      's3Key' => 'onboarding/12345/resume.pdf',
      'expiresAt' => Datetime.now().addHours(1).format()
    };
    res.setHeader('Content-Type','application/json');
    res.setBody(JSON.serialize(r));
    return res;
  }
}
