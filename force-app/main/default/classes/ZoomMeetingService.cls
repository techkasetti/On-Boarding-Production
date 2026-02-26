public with sharing class ZoomMeetingService {

    public class ZoomMeetingRequest {
        @AuraEnabled public String topic;
        @AuraEnabled public String agenda;
        @AuraEnabled public String startTime; // ISO format
        @AuraEnabled public Integer duration;
        @AuraEnabled public String timezone;
    }

    public class ZoomMeetingResponse {
        @AuraEnabled public String id;
        @AuraEnabled public String join_url;
        @AuraEnabled public String start_url;
        @AuraEnabled public String status;
    }

    public static ZoomMeetingResponse createMeeting(ZoomMeetingRequest requestData) {

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Zoom_Integration/v2/users/me/meetings');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'topic' => requestData.topic,
            'type' => 2, // Scheduled meeting
            'start_time' => requestData.startTime,
            'duration' => requestData.duration,
            'timezone' => requestData.timezone,
            'agenda' => requestData.agenda,
            'settings' => new Map<String, Object>{
                'host_video' => true,
                'participant_video' => true,
                'join_before_host' => false,
                'mute_upon_entry' => true,
                'approval_type' => 0,
                'registration_type' => 1,
                'audio' => 'both',
                'auto_recording' => 'cloud',
                'waiting_room' => true
            }
        };

        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 201) {
            return (ZoomMeetingResponse)
                JSON.deserialize(res.getBody(), ZoomMeetingResponse.class);
        } else {
            throw new AuraHandledException(
                'Zoom API Error: ' + res.getStatusCode() + ' - ' + res.getBody()
            );
        }
    }
}
