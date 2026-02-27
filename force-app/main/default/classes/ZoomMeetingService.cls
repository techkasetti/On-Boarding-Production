public with sharing class ZoomMeetingService {

  
    public class ZoomMeetingRequest {
        @AuraEnabled public String topic;
        @AuraEnabled public String agenda;
        @AuraEnabled public String startTime; // ISO format: 2026-03-13T09:30:00
        @AuraEnabled public Integer duration;
        @AuraEnabled public String timezone;
    }

    public class ZoomMeetingResponse {
        @AuraEnabled public String id;
        @AuraEnabled public String join_url;
        @AuraEnabled public String start_url;
        @AuraEnabled public String status;
        @AuraEnabled public String topic;
        @AuraEnabled public String start_time;
        @AuraEnabled public Integer duration;
    }


    @AuraEnabled
    public static ZoomMeetingResponse createMeeting(
        String topic,
        String agenda,
        String startDateTime,
        Integer duration,
        String timezone
    ) {
        ZoomMeetingRequest req = new ZoomMeetingRequest();
        req.topic = topic;
        req.agenda = agenda;
        req.startTime = startDateTime;
        req.duration = duration;
        req.timezone = timezone;

        return createMeetingInternal(req);
    }

 
    public static ZoomMeetingResponse createMeetingInternal(ZoomMeetingRequest requestData) {

        try {
            System.debug('Zoom Request: ' + JSON.serializePretty(requestData));

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Zoom_Integration/v2/users/me/meetings');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000);

            Map<String, Object> body = new Map<String, Object>{
                'topic' => requestData.topic,
                'type' => 2,
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
                    'audio' => 'both',
                    'auto_recording' => 'none',
                    'waiting_room' => true
                }
            };

            req.setBody(JSON.serialize(body));

            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('Zoom Response Status: ' + res.getStatusCode());
            System.debug('Zoom Response Body: ' + res.getBody());

            if (res.getStatusCode() == 201) {
                ZoomMeetingResponse response =
                    (ZoomMeetingResponse) JSON.deserialize(res.getBody(), ZoomMeetingResponse.class);

                return response;
            }

            // structured error
            throw new AuraHandledException(
                'Zoom API Error → Status: ' + res.getStatusCode() +
                ' | Body: ' + res.getBody()
            );

        } catch (Exception e) {
            System.debug('Zoom Exception: ' + e.getMessage());
            throw new AuraHandledException('Zoom integration failed: ' + e.getMessage());
        }
    }
}