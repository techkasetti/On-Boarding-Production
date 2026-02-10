// public with sharing class OnboardingOrchestratorV2 {

//     // Hardcoded URL for the webhook endpoint.
//     // A Remote Site Setting is required for this to work.
//     private static final String WEBHOOK_URL =
//         'https://webhook.site/4faeec1d-3bed-4cfe-8bc0-416b7a467a73';

//     /**
//      * @description Fetches the new resume JSON format by making an HTTP GET callout
//      *              to a hardcoded URL.
//      * @param candidateId The ID of the candidate, used for context
//      *                    (not used in the callout itself).
//      * @return A raw JSON string containing the structured resume data.
//      */
//     @AuraEnabled(cacheable=false)
//     public static String fetchResumePreviewV2(Id candidateId) {
//         // Create and configure the HTTP request using the hardcoded URL.
//         HttpRequest req = new HttpRequest();
//         req.setEndpoint(WEBHOOK_URL);
//         req.setMethod('GET');
//         req.setTimeout(120000); // 120-second timeout for safety.

//         try {
//             Http http = new Http();
//             HttpResponse res = http.send(req);

//             // Check for a successful response (HTTP 2xx).
//             if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
//                 return res.getBody(); // Return the raw JSON string.
//             } else {
//                 // If the callout fails, throw an exception that the LWC can catch.
//                 throw new AuraHandledException(
//                     'Failed to fetch resume data. Status: ' +
//                     res.getStatus() + ' - Body: ' + res.getBody()
//                 );
//             }
//         } catch (Exception e) {
//             // Assumes an error logging service exists from your other files.
//             // Onb_ErrorLogService.logError('OnboardingV2.fetchResume', e);
//             throw new AuraHandledException(
//                 'An error occurred while fetching the resume: ' + e.getMessage()
//             );
//         }
//     }

//     /**
//      * @description Deserializes the confirmed data from the LWC and saves it to the
//      *              main Candidate__c record and all related custom objects.
//      */
//     @AuraEnabled
//     public static void persistStructuredResumeData(String jsonData) {
//         Map<String, Object> dataMap =
//             (Map<String, Object>) JSON.deserializeUntyped(jsonData);

//         Id candidateId = (Id) dataMap.get('candidateId');

//         if (candidateId == null) {
//             throw new AuraHandledException('Candidate ID is missing.');
//         }

//         // --- Prepare lists for bulk DML ---
//         List<License_Certification__c> licenses      = new List<License_Certification__c>();
//         List<Clinical_Skill__c>        clinicalSkills = new List<Clinical_Skill__c>();
//         List<Work_Experience__c>       experiences   = new List<Work_Experience__c>();
//         List<Education__c>             educations    = new List<Education__c>();
//         List<Procedure__c>             procedures    = new List<Procedure__c>();
//         List<Research_Publication__c>  publications  = new List<Research_Publication__c>();
//         List<Technical_Skill__c>       techSkills    = new List<Technical_Skill__c>();
//         List<Membership__c>            memberships   = new List<Membership__c>();

//         try {
//             // 1. Update Candidate__c record
//             Map<String, Object> personalInfo = getSectionValue(dataMap, 'personalInformation');

//             Candidate__c candidateToUpdate = new Candidate__c(
//                 Id       = candidateId,
//                 Name     = (String) personalInfo.get('fullName'),
//                 Phone__c = (String) personalInfo.get('phone')
//             );
//             update candidateToUpdate;

//             // 2. Create License_Certification__c records
//             for (Object certName : getSectionValueAsList(dataMap, 'licensesAndCertifications')) {
//                 licenses.add(new License_Certification__c(
//                     Candidate__c = candidateId,
//                     Name         = (String) certName
//                 ));
//             }

//             // 3. Create Clinical_Skill__c records
//             for (Object skillName : getSectionValueAsList(dataMap, 'clinicalSkills')) {
//                 clinicalSkills.add(new Clinical_Skill__c(
//                     Candidate__c = candidateId,
//                     Name         = (String) skillName
//                 ));
//             }

//             // 4. Create Work_Experience__c record
//             Map<String, Object> expData = getSectionValue(dataMap, 'workExperience');
//             if (expData != null) {
//                 List<Object> respListObj = (List<Object>) expData.get('responsibilities');
//                 List<String> respListStr = new List<String>();

//                 // NOTE: convert List<Object> -> List<String> safely
//                 if (respListObj != null) {
//                     for (Object o : respListObj) {
//                         respListStr.add((String) o);
//                     }
//                 }

//                 experiences.add(new Work_Experience__c(
//                     Candidate__c       = candidateId,
//                     Role__c            = (String) expData.get('role'),
//                     Organization__c    = (String) expData.get('organization'),
//                     Duration_Text__c   = (String) expData.get('duration'),
//                     Responsibilities__c = String.join(respListStr, '\n')
//                 ));
//             }

//             // 5. Create Internship__c and Internship_Rotation__c records
//             Map<String, Object> internshipData = getSectionValue(dataMap, 'internship');
//             if (internshipData != null) {
//                 Internship__c newInternship = new Internship__c(
//                     Candidate__c   = candidateId,
//                     Organization__c = (String) internshipData.get('organization'),
//                     Duration_Text__c = (String) internshipData.get('duration')
//                 );
//                 insert newInternship; // Insert parent first to get ID

//                 List<Internship_Rotation__c> rotationsToInsert = new List<Internship_Rotation__c>();
//                 List<Object> rotationList =
//                     (List<Object>) internshipData.get('rotations');

//                 if (rotationList != null) {
//                     for (Object rotationName : rotationList) {
//                         rotationsToInsert.add(new Internship_Rotation__c(
//                             Internship__c      = newInternship.Id,
//                             Candidate__c       = candidateId,
//                             Department_Name__c = (String) rotationName
//                         ));
//                     }
//                 }

//                 if (!rotationsToInsert.isEmpty()) {
//                     insert rotationsToInsert;
//                 }
//             }

//             // 6. Create Education__c records
//             Map<String, Object> eduData = getSectionValue(dataMap, 'education');
//             if (eduData != null) {
//                 educations.add(new Education__c(
//                     Candidate__c    = candidateId,
//                     Degree__c       = (String) eduData.get('degree'),
//                     Institution__c  = (String) eduData.get('institution'),
//                     Duration_Text__c = (String) eduData.get('year'),
//                     Details__c      = (String) eduData.get('details')
//                 ));
//             }

//             // 7–10. Create other related records

//             // Procedures
//             for (Object procName : getSectionValueAsList(dataMap, 'proceduresPerformed')) {
//                 procedures.add(new Procedure__c(
//                     Candidate__c = candidateId,
//                     Name         = (String) procName
//                 ));
//             }

//             // Research / Publications
//             for (Object pubName : getSectionValueAsList(dataMap, 'researchAndPublications')) {
//                 publications.add(new Research_Publication__c(
//                     Candidate__c = candidateId,
//                     Title__c     = (String) pubName
//                 ));
//             }

//             // Technical Skills
//             for (Object techName : getSectionValueAsList(dataMap, 'technicalSkills')) {
//                 techSkills.add(new Technical_Skill__c(
//                     Candidate__c = candidateId,
//                     Name         = (String) techName
//                 ));
//             }

//             // Memberships
//             for (Object memberName : getSectionValueAsList(dataMap, 'professionalMemberships')) {
//                 memberships.add(new Membership__c(
//                     Candidate__c        = candidateId,
//                     Organization_Name__c = (String) memberName
//                 ));
//             }

//             // --- Perform Bulk DML ---
//             if (!licenses.isEmpty())     insert licenses;
//             if (!clinicalSkills.isEmpty()) insert clinicalSkills;
//             if (!experiences.isEmpty())  insert experiences;
//             if (!educations.isEmpty())   insert educations;
//             if (!procedures.isEmpty())   insert procedures;
//             if (!publications.isEmpty()) insert publications;
//             if (!techSkills.isEmpty())   insert techSkills;
//             if (!memberships.isEmpty())  insert memberships;

//         } catch (Exception e) {
//             // Assumes an error logging service exists, as seen in other files.
//             // Onb_ErrorLogService.logError('OnboardingV2.persistData', e);
//             throw new AuraHandledException('Error saving profile: ' + e.getMessage());
//         }
//     }

//     // Helper to safely get a nested map value
//     private static Map<String, Object> getSectionValue(
//         Map<String, Object> data,
//         String key
//     ) {
//         if (data.containsKey(key) && data.get(key) != null) {
//             Map<String, Object> section = (Map<String, Object>) data.get(key);
//             if (section.containsKey('value') &&
//                 section.get('value') instanceof Map<String, Object>) {
//                 return (Map<String, Object>) section.get('value');
//             }
//         }
//         return null;
//     }

//     // Helper to safely get a nested list value
//     private static List<Object> getSectionValueAsList(
//         Map<String, Object> data,
//         String key
//     ) {
//         if (data.containsKey(key) && data.get(key) != null) {
//             Map<String, Object> section = (Map<String, Object>) data.get(key);
//             if (section.containsKey('value') &&
//                 section.get('value') instanceof List<Object>) {
//                 return (List<Object>) section.get('value');
//             }
//         }
//         return new List<Object>();
//     }
// }

public without sharing class OnboardingOrchestratorV2 {

    private static final String WEBHOOK_URL =
        'https://webhook.site/d6d018ab-db1f-4d17-9bf9-b1aadc182f1b';

    @AuraEnabled(cacheable=false)
    public static String fetchResumePreviewV2(Id candidateId) {
        System.debug('=== fetchResumePreviewV2 Called ===');
        System.debug('Candidate ID: ' + candidateId);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(WEBHOOK_URL);
        req.setMethod('GET');
        req.setTimeout(120000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('Response Status Code: ' + res.getStatusCode());
            System.debug('Response Body Length: ' + (res.getBody()?.length() ?? 0));

            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                String responseBody = res.getBody();
                
                if (String.isBlank(responseBody)) {
                    throw new AuraHandledException('Webhook returned empty response');
                }
                
                System.debug('✅ Successfully fetched resume data');
                return responseBody;
            } else {
                throw new AuraHandledException('Webhook error: ' + res.getStatus());
            }
        } catch (System.CalloutException e) {
            if (e.getMessage().contains('Unauthorized endpoint')) {
                throw new AuraHandledException('Remote Site Setting missing for https://webhook.site');
            }
            throw new AuraHandledException('Network error: ' + e.getMessage());
        } catch (Exception e) {
            System.debug('❌ Exception: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void persistStructuredResumeData(String jsonData) {
        System.debug('=== persistStructuredResumeData Called ===');
        System.debug('JSON Data Length: ' + (jsonData?.length() ?? 0));
        
        Map<String, Object> dataMap;
        
        try {
            dataMap = (Map<String, Object>) JSON.deserializeUntyped(jsonData);
            System.debug('✅ JSON deserialized');
            System.debug('Keys: ' + dataMap.keySet());
        } catch (Exception e) {
            System.debug('❌ JSON Error: ' + e.getMessage());
            throw new AuraHandledException('Invalid JSON: ' + e.getMessage());
        }

        Id candidateId = (Id) dataMap.get('candidateId');
        System.debug('Candidate ID: ' + candidateId);

        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID missing');
        }

        List<License_Certification__c> licenses = new List<License_Certification__c>();
        List<Clinical_Skill__c> clinicalSkills = new List<Clinical_Skill__c>();
        List<Work_Experience__c> experiences = new List<Work_Experience__c>();
        List<Education__c> educations = new List<Education__c>();
        List<Procedure__c> procedures = new List<Procedure__c>();
        List<Research_Publication__c> publications = new List<Research_Publication__c>();
        List<Technical_Skill__c> techSkills = new List<Technical_Skill__c>();
        List<Membership__c> memberships = new List<Membership__c>();

        try {
            // 1. Update Candidate
            Map<String, Object> personalInfo = getSectionValue(dataMap, 'personalInformation');
            if (personalInfo != null) {
                Candidate__c candidateToUpdate = new Candidate__c(
                    Id = candidateId,
                   // Name = (String) personalInfo.get('fullName'),
                    Phone__c = (String) personalInfo.get('phone')
                );
                update candidateToUpdate;
                System.debug('✅ Candidate updated');
            }

            // 2. Licenses
            List<Object> licenseList = getSectionValueAsList(dataMap, 'licensesAndCertifications');
            System.debug('Licenses to create: ' + licenseList.size());
            for (Object certName : licenseList) {
                licenses.add(new License_Certification__c(
                    Candidate__c = candidateId,
                    Name = (String) certName
                ));
            }

            // 3. Clinical Skills
            List<Object> clinicalSkillList = getSectionValueAsList(dataMap, 'clinicalSkills');
            System.debug('Clinical Skills to create: ' + clinicalSkillList.size());
            for (Object skillName : clinicalSkillList) {
                clinicalSkills.add(new Clinical_Skill__c(
                    Candidate__c = candidateId,
                    Name = (String) skillName
                ));
            }

            // 4. Work Experience
            Map<String, Object> expData = getSectionValue(dataMap, 'workExperience');
            if (expData != null) {
                List<Object> respListObj = (List<Object>) expData.get('responsibilities');
                List<String> respListStr = new List<String>();
                if (respListObj != null) {
                    for (Object o : respListObj) {
                        respListStr.add((String) o);
                    }
                }
                experiences.add(new Work_Experience__c(
                    Candidate__c = candidateId,
                    Role__c = (String) expData.get('role'),
                    Organization__c = (String) expData.get('organization'),
                    Duration_Text__c = (String) expData.get('duration'),
                    Responsibilities__c = String.join(respListStr, '\n')
                ));
            }

            // 5. Internship
            Map<String, Object> internshipData = getSectionValue(dataMap, 'internship');
            if (internshipData != null) {
                Internship__c newInternship = new Internship__c(
                    Candidate__c = candidateId,
                    Organization__c = (String) internshipData.get('organization'),
                    Duration_Text__c = (String) internshipData.get('duration')
                );
                insert newInternship;

                List<Internship_Rotation__c> rotationsToInsert = new List<Internship_Rotation__c>();
                List<Object> rotationList = (List<Object>) internshipData.get('rotations');
                if (rotationList != null) {
                    for (Object rotationName : rotationList) {
                        rotationsToInsert.add(new Internship_Rotation__c(
                            Internship__c = newInternship.Id,
                            Candidate__c = candidateId,
                            Department_Name__c = (String) rotationName
                        ));
                    }
                }
                if (!rotationsToInsert.isEmpty()) {
                    insert rotationsToInsert;
                }
            }

            // 6. Education
            Map<String, Object> eduData = getSectionValue(dataMap, 'education');
            if (eduData != null) {
                educations.add(new Education__c(
                    Candidate__c = candidateId,
                    Degree__c = (String) eduData.get('degree'),
                    Institution__c = (String) eduData.get('institution'),
                    Duration_Text__c = (String) eduData.get('year'),
                    Details__c = (String) eduData.get('details')
                ));
            }

            // 7. Procedures
            List<Object> procedureList = getSectionValueAsList(dataMap, 'proceduresPerformed');
            for (Object procName : procedureList) {
                procedures.add(new Procedure__c(
                    Candidate__c = candidateId,
                    Name = (String) procName
                ));
            }

            // 8. Publications
            List<Object> publicationList = getSectionValueAsList(dataMap, 'researchAndPublications');
            for (Object pubName : publicationList) {
                publications.add(new Research_Publication__c(
                    Candidate__c = candidateId,
                    Title__c = (String) pubName
                ));
            }

            // 9. Technical Skills
            List<Object> techSkillList = getSectionValueAsList(dataMap, 'technicalSkills');
            for (Object techName : techSkillList) {
                techSkills.add(new Technical_Skill__c(
                    Candidate__c = candidateId,
                    Name = (String) techName
                ));
            }

            // 10. Memberships
            List<Object> membershipList = getSectionValueAsList(dataMap, 'professionalMemberships');
            for (Object memberName : membershipList) {
                memberships.add(new Membership__c(
                    Candidate__c = candidateId,
                    Organization_Name__c = (String) memberName
                ));
            }

            // Bulk DML
            if (!licenses.isEmpty()) {
                insert licenses;
                System.debug('✅ Inserted ' + licenses.size() + ' Licenses');
            }
            if (!clinicalSkills.isEmpty()) {
                insert clinicalSkills;
                System.debug('✅ Inserted ' + clinicalSkills.size() + ' Skills');
            }
            if (!experiences.isEmpty()) {
                insert experiences;
                System.debug('✅ Inserted ' + experiences.size() + ' Experiences');
            }
            if (!educations.isEmpty()) {
                insert educations;
                System.debug('✅ Inserted ' + educations.size() + ' Educations');
            }
            if (!procedures.isEmpty()) {
                insert procedures;
                System.debug('✅ Inserted ' + procedures.size() + ' Procedures');
            }
            if (!publications.isEmpty()) {
                insert publications;
                System.debug('✅ Inserted ' + publications.size() + ' Publications');
            }
            if (!techSkills.isEmpty()) {
                insert techSkills;
                System.debug('✅ Inserted ' + techSkills.size() + ' Tech Skills');
            }
            if (!memberships.isEmpty()) {
                insert memberships;
                System.debug('✅ Inserted ' + memberships.size() + ' Memberships');
            }

            System.debug('=== ✅ All data saved successfully ===');

        } catch (Exception e) {
            System.debug('❌ Save Error: ' + e.getMessage());
            System.debug('Line: ' + e.getLineNumber());
            System.debug('Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Save failed: ' + e.getMessage());
        }
    }

    private static Map<String, Object> getSectionValue(Map<String, Object> data, String key) {
        if (data.containsKey(key) && data.get(key) != null) {
            Map<String, Object> section = (Map<String, Object>) data.get(key);
            if (section.containsKey('value') &&
                section.get('value') instanceof Map<String, Object>) {
                return (Map<String, Object>) section.get('value');
            }
        }
        return null;
    }

    // ✅ FIXED: Added quotes around 'value'
    private static List<Object> getSectionValueAsList(Map<String, Object> data, String key) {
        if (data.containsKey(key) && data.get(key) != null) {
            Map<String, Object> section = (Map<String, Object>) data.get(key);
            if (section.containsKey('value') &&
                section.get('value') instanceof List<Object>) {
                return (List<Object>) section.get('value'); // ✅ FIXED
            }
        }
        return new List<Object>();
    }
}