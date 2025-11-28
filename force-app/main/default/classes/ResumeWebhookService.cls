/**public with sharing class ResumeWebhookService {

    // Change this to a Named Credential if you want (recommended):
    // e.g. 'callout:ResumeWebhook'
    private static final String WEBHOOK_URL = 'https://webhook.site/cf86ccef-6b45-4870-84e8-bf130d8e1df8';

    
     // Calls the webhook.site URL using HTTP GET and returns the raw JSON string.
     
    public static String callWebhookRaw() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(WEBHOOK_URL);
        req.setMethod('GET');
        req.setTimeout(120000); // 120 seconds just to be safe

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            return res.getBody();
        } else {
            // You can throw a custom exception or handle it your way
            System.debug('Webhook call failed. Status: ' + res.getStatus() + ' Body: ' + res.getBody());
            throw new CalloutException('Failed to call webhook. Status: ' + res.getStatus());
        }
    }

   
     //Calls the webhook and deserializes the JSON into a generic Map.
     //Use this if your webhook returns JSON and you want to work with it.

    public static Map<String, Object> callWebhookAndParse() {
        String jsonBody = callWebhookRaw();

        // Generic JSON parsing (no specific schema)
        if (String.isBlank(jsonBody)) {
            return new Map<String, Object>();
        }

        Map<String, Object> parsed =
            (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

        return parsed;
    }

    // Optional: Custom exception for clarity
    public class CalloutException extends Exception {}
}
  */
public with sharing class ResumeWebhookService {

    // Change this to a Named Credential if you want (recommended):
    // e.g. 'callout:ResumeWebhook'
    private static final String WEBHOOK_URL = 'https://webhook.site/5127bd0e-fda8-40d5-a124-baaddadf5392';

    // ========================
    // DTO classes for the JSON
    // ========================

    public class ResumePayload {
       @AuraEnabled  public NameWrapper name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public LocationWrapper location;
        @AuraEnabled public String professional_summary;
        @AuraEnabled public Integer years_experience;
        @AuraEnabled public List<LicenseWrapper> licenses;
        @AuraEnabled public List<CertificationWrapper> certifications;
        @AuraEnabled public List<SkillWrapper> skills;
        @AuraEnabled public List<ExperienceWrapper> experience;
        @AuraEnabled public List<EducationWrapper> education;
        @AuraEnabled public List<String> languages;
        @AuraEnabled public List<String> additional_information;
    }

    public class NameWrapper {
        // Matches: "firstName" / "lastName"
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
    }

    public class LocationWrapper {
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String country;
    }

    public class LicenseWrapper {
        @AuraEnabled public String type;
        @AuraEnabled public String number1;
        @AuraEnabled public String state;
       @AuraEnabled  public String expiry; // keep as String; convert to Date later if needed
    }

    public class CertificationWrapper {
      @AuraEnabled  public String type;
      @AuraEnabled  public String issuer;
      @AuraEnabled   public String expiry; // can be null in JSON
    }

    public class SkillWrapper {
       @AuraEnabled  public String name;
       @AuraEnabled public String category;
    }

    public class ExperienceWrapper {
        @AuraEnabled public String title;
        @AuraEnabled public String company;
        @AuraEnabled  public String location;
        @AuraEnabled public String start_date; // e.g. "2021-03"
        @AuraEnabled public String end_date;   // e.g. "Present" or "2021-02"
        @AuraEnabled public List<String> responsibilities;
    }

    public class EducationWrapper {
        @AuraEnabled public String degree;
        @AuraEnabled public String institution;
        @AuraEnabled public String location;
        @AuraEnabled public Integer completion_year;
    }

    // ======================
    // Callout helper methods
    // ======================

    /**
     * Calls the webhook.site URL using HTTP GET and returns the raw JSON string.
     */
    public static String callWebhookRaw() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(WEBHOOK_URL);
        req.setMethod('GET');
        req.setTimeout(120000); // 120 seconds just to be safe

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            return res.getBody();
        } else {
            // You can throw a custom exception or handle it your way
            System.debug('Webhook call failed. Status: ' + res.getStatus() + ' Body: ' + res.getBody());
            throw new CalloutException('Failed to call webhook. Status: ' + res.getStatus());
        }
    }

    /**
     * Calls the webhook and deserializes the JSON into a typed ResumePayload.
     * This is aligned with the JSON structure you provided.
     */
    public static ResumePayload callWebhookAndParse() {
        String jsonBody = callWebhookRaw();

        if (String.isBlank(jsonBody)) {
            return null;
        }

        ResumePayload parsed =
            (ResumePayload) JSON.deserialize(jsonBody, ResumePayload.class);

        return parsed;
    }

    // Optional: Custom exception for clarity
    public class CalloutException extends Exception {}
}
