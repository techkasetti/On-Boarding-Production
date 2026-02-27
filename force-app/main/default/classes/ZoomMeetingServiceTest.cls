@IsTest
private class ZoomMeetingServiceTest {
    private class ZoomSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody(
                '{"id":"12345","join_url":"https://zoom.us/j/12345","start_url":"https://zoom.us/s/12345","status":"waiting","topic":"Interview","start_time":"2026-03-13T09:30:00Z","duration":30}'
            );
            return res;
        }
    }

    private class ZoomErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"message":"bad request"}');
            return res;
        }
    }

    @IsTest
    static void testCreateMeeting_Success() {
        Test.setMock(HttpCalloutMock.class, new ZoomSuccessMock());

        Test.startTest();
        ZoomMeetingService.ZoomMeetingResponse response = ZoomMeetingService.createMeeting(
            'Interview',
            'Candidate discussion',
            '2026-03-13T09:30:00',
            30,
            'America/New_York'
        );
        Test.stopTest();

        System.assertEquals('12345', response.id);
        System.assert(response.join_url.contains('zoom.us'));
    }

    @IsTest
    static void testCreateMeetingInternal_ErrorHandled() {
        Test.setMock(HttpCalloutMock.class, new ZoomErrorMock());
        ZoomMeetingService.ZoomMeetingRequest req = new ZoomMeetingService.ZoomMeetingRequest();
        req.topic = 'Bad Meeting';
        req.agenda = 'Bad payload';
        req.startTime = '2026-03-13T09:30:00';
        req.duration = 30;
        req.timezone = 'UTC';

        try {
            Test.startTest();
            ZoomMeetingService.createMeetingInternal(req);
            Test.stopTest();
            System.assert(false, 'Expected handled exception');
        } catch (Exception e) {
            System.assert(!String.isBlank(e.getMessage()));
        }
    }
}
