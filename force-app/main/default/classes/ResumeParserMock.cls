// Mock class – simulates external resume parser
@IsTest
global class ResumeParserMock implements HttpCalloutMock {

    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');

        // Example JSON similar to a real parser response
        String body =
            '{' +
            '  "name": {"first": "Eleanor", "last": "Vance"},' +
            '  "email": "eleanor@example.com",' +
            '  "phone": "+1-555-555-1212",' +
            '  "licenses": [' +
            '    {"type": "Registered Nurse (RN)", "number": "RN987654", "state": "CA", "expiry": "2026-12-31"}' +
            '  ],' +
            '  "certifications": [' +
            '    {"type": "Basic Life Support (BLS)", "issuer": "American Heart Association", "expiry": "2025-08-31"}' +
            '  ],' +
            '  "skills": [' +
            '    {"name": "Epic EMR", "category": "EMR/EHR System"},' +
            '    {"name": "Pediatrics", "category": "Clinical Specialization"}' +
            '  ],' +
            '  "years_experience": 5' +
            '}';

        res.setBody(body);
        return res;
    }
}