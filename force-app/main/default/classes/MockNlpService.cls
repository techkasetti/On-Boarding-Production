@isTest
global class MockNlpService implements HttpCalloutMock {
    global HttpResponse respond(HttpRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        
        // Simple mock logic: inspect the request body
        String requestBody = req.getBody();
        String responseBody = '';

        if (requestBody.containsIgnoreCase('jane doe')) {
            responseBody = '{"firstName": "Jane", "lastName": "Doe", "email": null}';
        } else if (requestBody.containsIgnoreCase('example.com')) {
             responseBody = '{"firstName": null, "lastName": null, "email": "jane.doe@example.com"}';
        } else {
            // Default response if no keywords are found
            responseBody = '{"firstName": null, "lastName": null, "email": null}';
        }
        
        res.setBody(responseBody);
        res.setStatusCode(200);
        return res;
    }
}
