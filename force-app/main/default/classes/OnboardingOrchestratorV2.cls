// public without sharing class OnboardingOrchestratorV2 {

//     private static final String WEBHOOK_URL =
//         'https://webhook.site/d6d018ab-db1f-4d17-9bf9-b1aadc182f1b';

//     @AuraEnabled(cacheable=false)
//     public static String fetchResumePreviewV2(Id candidateId) {
//         System.debug('=== fetchResumePreviewV2 Called ===');
//         System.debug('Candidate ID: ' + candidateId);
        
//         HttpRequest req = new HttpRequest();
//         req.setEndpoint(WEBHOOK_URL);
//         req.setMethod('GET');
//         req.setTimeout(120000);

//         try {
//             Http http = new Http();
//             HttpResponse res = http.send(req);

//             System.debug('Response Status Code: ' + res.getStatusCode());
//             System.debug('Response Body Length: ' + (res.getBody()?.length() ?? 0));

//             if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
//                 String responseBody = res.getBody();
                
//                 if (String.isBlank(responseBody)) {
//                     throw new AuraHandledException('Webhook returned empty response');
//                 }
                
//                 System.debug('✅ Successfully fetched resume data');
//                 return responseBody;
//             } else {
//                 throw new AuraHandledException('Webhook error: ' + res.getStatus());
//             }
//         } catch (System.CalloutException e) {
//             if (e.getMessage().contains('Unauthorized endpoint')) {
//                 throw new AuraHandledException('Remote Site Setting missing for https://webhook.site');
//             }
//             throw new AuraHandledException('Network error: ' + e.getMessage());
//         } catch (Exception e) {
//             System.debug('❌ Exception: ' + e.getMessage());
//             throw new AuraHandledException('Error: ' + e.getMessage());
//         }
//     }

//     @AuraEnabled
//     public static void persistStructuredResumeData(String jsonData) {
//         System.debug('=== persistStructuredResumeData Called ===');
//         System.debug('JSON Data Length: ' + (jsonData?.length() ?? 0));
        
//         Map<String, Object> dataMap;
        
//         try {
//             dataMap = (Map<String, Object>) JSON.deserializeUntyped(jsonData);
//             System.debug('✅ JSON deserialized');
//             System.debug('Keys: ' + dataMap.keySet());
//         } catch (Exception e) {
//             System.debug('❌ JSON Error: ' + e.getMessage());
//             throw new AuraHandledException('Invalid JSON: ' + e.getMessage());
//         }

//         Id candidateId = (Id) dataMap.get('candidateId');
//         System.debug('Candidate ID: ' + candidateId);

//         if (candidateId == null) {
//             throw new AuraHandledException('Candidate ID missing');
//         }

//         List<License_Certification__c> licenses = new List<License_Certification__c>();
//         List<Clinical_Skill__c> clinicalSkills = new List<Clinical_Skill__c>();
//         List<Work_Experience__c> experiences = new List<Work_Experience__c>();
//         List<Education__c> educations = new List<Education__c>();
//         List<Procedure__c> procedures = new List<Procedure__c>();
//         List<Research_Publication__c> publications = new List<Research_Publication__c>();
//         List<Technical_Skill__c> techSkills = new List<Technical_Skill__c>();
//         List<Membership__c> memberships = new List<Membership__c>();

//         try {
//             // 1. Update Candidate
//             Map<String, Object> personalInfo = getSectionValue(dataMap, 'personalInformation');
//             if (personalInfo != null) {
//                 Candidate__c candidateToUpdate = new Candidate__c(
//                     Id = candidateId,
//                    // Name = (String) personalInfo.get('fullName'),
//                     Phone__c = (String) personalInfo.get('phone')
//                 );
//                 update candidateToUpdate;
//                 System.debug('✅ Candidate updated');
//             }

//             // 2. Licenses
//             List<Object> licenseList = getSectionValueAsList(dataMap, 'licensesAndCertifications');
//             System.debug('Licenses to create: ' + licenseList.size());
//             for (Object certName : licenseList) {
//                 licenses.add(new License_Certification__c(
//                     Candidate__c = candidateId,
//                     Name = (String) certName
//                 ));
//             }

//             // 3. Clinical Skills
//             List<Object> clinicalSkillList = getSectionValueAsList(dataMap, 'clinicalSkills');
//             System.debug('Clinical Skills to create: ' + clinicalSkillList.size());
//             for (Object skillName : clinicalSkillList) {
//                 clinicalSkills.add(new Clinical_Skill__c(
//                     Candidate__c = candidateId,
//                     Name = (String) skillName
//                 ));
//             }

//             // 4. Work Experience
//             Map<String, Object> expData = getSectionValue(dataMap, 'workExperience');
//             if (expData != null) {
//                 List<Object> respListObj = (List<Object>) expData.get('responsibilities');
//                 List<String> respListStr = new List<String>();
//                 if (respListObj != null) {
//                     for (Object o : respListObj) {
//                         respListStr.add((String) o);
//                     }
//                 }
//                 experiences.add(new Work_Experience__c(
//                     Candidate__c = candidateId,
//                     Role__c = (String) expData.get('role'),
//                     Organization__c = (String) expData.get('organization'),
//                     Duration_Text__c = (String) expData.get('duration'),
//                     Responsibilities__c = String.join(respListStr, '\n')
//                 ));
//             }

//             // 5. Internship
//             Map<String, Object> internshipData = getSectionValue(dataMap, 'internship');
//             if (internshipData != null) {
//                 Internship__c newInternship = new Internship__c(
//                     Candidate__c = candidateId,
//                     Organization__c = (String) internshipData.get('organization'),
//                     Duration_Text__c = (String) internshipData.get('duration')
//                 );
//                 insert newInternship;

//                 List<Internship_Rotation__c> rotationsToInsert = new List<Internship_Rotation__c>();
//                 List<Object> rotationList = (List<Object>) internshipData.get('rotations');
//                 if (rotationList != null) {
//                     for (Object rotationName : rotationList) {
//                         rotationsToInsert.add(new Internship_Rotation__c(
//                             Internship__c = newInternship.Id,
//                             Candidate__c = candidateId,
//                             Department_Name__c = (String) rotationName
//                         ));
//                     }
//                 }
//                 if (!rotationsToInsert.isEmpty()) {
//                     insert rotationsToInsert;
//                 }
//             }

//             // 6. Education
//             Map<String, Object> eduData = getSectionValue(dataMap, 'education');
//             if (eduData != null) {
//                 educations.add(new Education__c(
//                     Candidate__c = candidateId,
//                     Degree__c = (String) eduData.get('degree'),
//                     Institution__c = (String) eduData.get('institution'),
//                     Duration_Text__c = (String) eduData.get('year'),
//                     Details__c = (String) eduData.get('details')
//                 ));
//             }

//             // 7. Procedures
//             List<Object> procedureList = getSectionValueAsList(dataMap, 'proceduresPerformed');
//             for (Object procName : procedureList) {
//                 procedures.add(new Procedure__c(
//                     Candidate__c = candidateId,
//                     Name = (String) procName
//                 ));
//             }

//             // 8. Publications
//             List<Object> publicationList = getSectionValueAsList(dataMap, 'researchAndPublications');
//             for (Object pubName : publicationList) {
//                 publications.add(new Research_Publication__c(
//                     Candidate__c = candidateId,
//                     Title__c = (String) pubName
//                 ));
//             }

//             // 9. Technical Skills
//             List<Object> techSkillList = getSectionValueAsList(dataMap, 'technicalSkills');
//             for (Object techName : techSkillList) {
//                 techSkills.add(new Technical_Skill__c(
//                     Candidate__c = candidateId,
//                     Name = (String) techName
//                 ));
//             }

//             // 10. Memberships
//             List<Object> membershipList = getSectionValueAsList(dataMap, 'professionalMemberships');
//             for (Object memberName : membershipList) {
//                 memberships.add(new Membership__c(
//                     Candidate__c = candidateId,
//                     Organization_Name__c = (String) memberName
//                 ));
//             }

//             // Bulk DML
//             if (!licenses.isEmpty()) {
//                 insert licenses;
//                 System.debug('✅ Inserted ' + licenses.size() + ' Licenses');
//             }
//             if (!clinicalSkills.isEmpty()) {
//                 insert clinicalSkills;
//                 System.debug('✅ Inserted ' + clinicalSkills.size() + ' Skills');
//             }
//             if (!experiences.isEmpty()) {
//                 insert experiences;
//                 System.debug('✅ Inserted ' + experiences.size() + ' Experiences');
//             }
//             if (!educations.isEmpty()) {
//                 insert educations;
//                 System.debug('✅ Inserted ' + educations.size() + ' Educations');
//             }
//             if (!procedures.isEmpty()) {
//                 insert procedures;
//                 System.debug('✅ Inserted ' + procedures.size() + ' Procedures');
//             }
//             if (!publications.isEmpty()) {
//                 insert publications;
//                 System.debug('✅ Inserted ' + publications.size() + ' Publications');
//             }
//             if (!techSkills.isEmpty()) {
//                 insert techSkills;
//                 System.debug('✅ Inserted ' + techSkills.size() + ' Tech Skills');
//             }
//             if (!memberships.isEmpty()) {
//                 insert memberships;
//                 System.debug('✅ Inserted ' + memberships.size() + ' Memberships');
//             }

//             System.debug('=== ✅ All data saved successfully ===');

//         } catch (Exception e) {
//             System.debug('❌ Save Error: ' + e.getMessage());
//             System.debug('Line: ' + e.getLineNumber());
//             System.debug('Stack: ' + e.getStackTraceString());
//             throw new AuraHandledException('Save failed: ' + e.getMessage());
//         }
//     }

//     private static Map<String, Object> getSectionValue(Map<String, Object> data, String key) {
//         if (data.containsKey(key) && data.get(key) != null) {
//             Map<String, Object> section = (Map<String, Object>) data.get(key);
//             if (section.containsKey('value') &&
//                 section.get('value') instanceof Map<String, Object>) {
//                 return (Map<String, Object>) section.get('value');
//             }
//         }
//         return null;
//     }

//     // ✅ FIXED: Added quotes around 'value'
//     private static List<Object> getSectionValueAsList(Map<String, Object> data, String key) {
//         if (data.containsKey(key) && data.get(key) != null) {
//             Map<String, Object> section = (Map<String, Object>) data.get(key);
//             if (section.containsKey('value') &&
//                 section.get('value') instanceof List<Object>) {
//                 return (List<Object>) section.get('value'); // ✅ FIXED
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

        HttpRequest req = new HttpRequest();
        req.setEndpoint(WEBHOOK_URL);
        req.setMethod('GET');
        req.setTimeout(120000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                String responseBody = res.getBody();
                if (String.isBlank(responseBody)) {
                    throw new AuraHandledException('Webhook returned empty response');
                }
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
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }

    /**
     * Persist structured resume data using true upsert logic per section:
     *   - Matches existing records by name/key field
     *   - Updates records that already exist
     *   - Inserts records that are new
     *   - Deletes records that are no longer in the parsed resume
     */
    @AuraEnabled
    public static void persistStructuredResumeData(String jsonData) {
        System.debug('=== persistStructuredResumeData Called ===');

        Map<String, Object> dataMap;
        try {
            dataMap = (Map<String, Object>) JSON.deserializeUntyped(jsonData);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid JSON: ' + e.getMessage());
        }

        Id candidateId = (Id) dataMap.get('candidateId');
        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID missing');
        }

        try {
            // 1. Update candidate basic info
            Map<String, Object> personalInfo = getSectionValue(dataMap, 'personalInformation');
            if (personalInfo != null) {
                update new Candidate__c(
                    Id       = candidateId,
                    Phone__c = (String) personalInfo.get('phone')
                );
                System.debug('✅ Candidate updated');
            }

            // 2. List-type sections — upsert by Name field
            upsertLicenses(candidateId,       getSectionValueAsList(dataMap, 'licensesAndCertifications'));
            upsertClinicalSkills(candidateId,  getSectionValueAsList(dataMap, 'clinicalSkills'));
            upsertTechnicalSkills(candidateId, getSectionValueAsList(dataMap, 'technicalSkills'));
            upsertProcedures(candidateId,      getSectionValueAsList(dataMap, 'proceduresPerformed'));
            upsertPublications(candidateId,    getSectionValueAsList(dataMap, 'researchAndPublications'));
            upsertMemberships(candidateId,     getSectionValueAsList(dataMap, 'professionalMemberships'));

            // 3. Single-record sections — update first existing or insert
            upsertWorkExperience(candidateId, getSectionValue(dataMap, 'workExperience'));
            upsertEducation(candidateId,      getSectionValue(dataMap, 'education'));
            upsertInternship(candidateId,     getSectionValue(dataMap, 'internship'));

            System.debug('=== ✅ All resume data synced successfully ===');

        } catch (Exception e) {
            System.debug('❌ Save Error: ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
            throw new AuraHandledException('Save failed: ' + e.getMessage());
        }
    }

    // ================================================================
    // LIST-TYPE UPSERT HELPERS
    //
    // Pattern for each:
    //   1. Load existing records into Map<NameLower, Record>
    //   2. Loop incoming names:
    //        - found in map  → update (preserve Id, fix casing)
    //        - not in map    → add to insert list
    //   3. Remaining map entries not seen in incoming → delete (stale)
    // ================================================================

    private static void upsertLicenses(Id candidateId, List<Object> incoming) {
        if (incoming == null || incoming.isEmpty()) return;

        Map<String, License_Certification__c> existingMap = new Map<String, License_Certification__c>();
        for (License_Certification__c r : [
            SELECT Id, Name FROM License_Certification__c WHERE Candidate__c = :candidateId
        ]) {
            existingMap.put(r.Name.toLowerCase(), r);
        }

        List<License_Certification__c> toInsert = new List<License_Certification__c>();
        List<License_Certification__c> toUpdate = new List<License_Certification__c>();
        Set<String> seen = new Set<String>();

        for (Object obj : incoming) {
            String name = (String) obj;
            String key  = name.toLowerCase();
            seen.add(key);
            if (existingMap.containsKey(key)) {
                License_Certification__c r = existingMap.get(key);
                r.Name = name;          // keep correct casing from new resume
                toUpdate.add(r);
            } else {
                toInsert.add(new License_Certification__c(Candidate__c = candidateId, Name = name));
            }
        }

        List<License_Certification__c> toDelete = new List<License_Certification__c>();
        for (String key : existingMap.keySet()) {
            if (!seen.contains(key)) toDelete.add(existingMap.get(key));
        }

        if (!toUpdate.isEmpty()) { update toUpdate; System.debug('✅ Updated '  + toUpdate.size() + ' Licenses'); }
        if (!toInsert.isEmpty()) { insert toInsert; System.debug('✅ Inserted ' + toInsert.size() + ' Licenses'); }
        if (!toDelete.isEmpty()) { delete toDelete; System.debug('🗑️ Deleted '  + toDelete.size() + ' stale Licenses'); }
    }

    private static void upsertClinicalSkills(Id candidateId, List<Object> incoming) {
        if (incoming == null || incoming.isEmpty()) return;

        Map<String, Clinical_Skill__c> existingMap = new Map<String, Clinical_Skill__c>();
        for (Clinical_Skill__c r : [
            SELECT Id, Name FROM Clinical_Skill__c WHERE Candidate__c = :candidateId
        ]) {
            existingMap.put(r.Name.toLowerCase(), r);
        }

        List<Clinical_Skill__c> toInsert = new List<Clinical_Skill__c>();
        List<Clinical_Skill__c> toUpdate = new List<Clinical_Skill__c>();
        Set<String> seen = new Set<String>();

        for (Object obj : incoming) {
            String name = (String) obj;
            String key  = name.toLowerCase();
            seen.add(key);
            if (existingMap.containsKey(key)) {
                Clinical_Skill__c r = existingMap.get(key);
                r.Name = name;
                toUpdate.add(r);
            } else {
                toInsert.add(new Clinical_Skill__c(Candidate__c = candidateId, Name = name));
            }
        }

        List<Clinical_Skill__c> toDelete = new List<Clinical_Skill__c>();
        for (String key : existingMap.keySet()) {
            if (!seen.contains(key)) toDelete.add(existingMap.get(key));
        }

        if (!toUpdate.isEmpty()) { update toUpdate; System.debug('✅ Updated '  + toUpdate.size() + ' Clinical Skills'); }
        if (!toInsert.isEmpty()) { insert toInsert; System.debug('✅ Inserted ' + toInsert.size() + ' Clinical Skills'); }
        if (!toDelete.isEmpty()) { delete toDelete; System.debug('🗑️ Deleted '  + toDelete.size() + ' stale Clinical Skills'); }
    }

    private static void upsertTechnicalSkills(Id candidateId, List<Object> incoming) {
        if (incoming == null || incoming.isEmpty()) return;

        Map<String, Technical_Skill__c> existingMap = new Map<String, Technical_Skill__c>();
        for (Technical_Skill__c r : [
            SELECT Id, Name FROM Technical_Skill__c WHERE Candidate__c = :candidateId
        ]) {
            existingMap.put(r.Name.toLowerCase(), r);
        }

        List<Technical_Skill__c> toInsert = new List<Technical_Skill__c>();
        List<Technical_Skill__c> toUpdate = new List<Technical_Skill__c>();
        Set<String> seen = new Set<String>();

        for (Object obj : incoming) {
            String name = (String) obj;
            String key  = name.toLowerCase();
            seen.add(key);
            if (existingMap.containsKey(key)) {
                Technical_Skill__c r = existingMap.get(key);
                r.Name = name;
                toUpdate.add(r);
            } else {
                toInsert.add(new Technical_Skill__c(Candidate__c = candidateId, Name = name));
            }
        }

        List<Technical_Skill__c> toDelete = new List<Technical_Skill__c>();
        for (String key : existingMap.keySet()) {
            if (!seen.contains(key)) toDelete.add(existingMap.get(key));
        }

        if (!toUpdate.isEmpty()) { update toUpdate; System.debug('✅ Updated '  + toUpdate.size() + ' Tech Skills'); }
        if (!toInsert.isEmpty()) { insert toInsert; System.debug('✅ Inserted ' + toInsert.size() + ' Tech Skills'); }
        if (!toDelete.isEmpty()) { delete toDelete; System.debug('🗑️ Deleted '  + toDelete.size() + ' stale Tech Skills'); }
    }

    private static void upsertProcedures(Id candidateId, List<Object> incoming) {
        if (incoming == null || incoming.isEmpty()) return;

        Map<String, Procedure__c> existingMap = new Map<String, Procedure__c>();
        for (Procedure__c r : [
            SELECT Id, Name FROM Procedure__c WHERE Candidate__c = :candidateId
        ]) {
            existingMap.put(r.Name.toLowerCase(), r);
        }

        List<Procedure__c> toInsert = new List<Procedure__c>();
        List<Procedure__c> toUpdate = new List<Procedure__c>();
        Set<String> seen = new Set<String>();

        for (Object obj : incoming) {
            String name = (String) obj;
            String key  = name.toLowerCase();
            seen.add(key);
            if (existingMap.containsKey(key)) {
                Procedure__c r = existingMap.get(key);
                r.Name = name;
                toUpdate.add(r);
            } else {
                toInsert.add(new Procedure__c(Candidate__c = candidateId, Name = name));
            }
        }

        List<Procedure__c> toDelete = new List<Procedure__c>();
        for (String key : existingMap.keySet()) {
            if (!seen.contains(key)) toDelete.add(existingMap.get(key));
        }

        if (!toUpdate.isEmpty()) { update toUpdate; System.debug('✅ Updated '  + toUpdate.size() + ' Procedures'); }
        if (!toInsert.isEmpty()) { insert toInsert; System.debug('✅ Inserted ' + toInsert.size() + ' Procedures'); }
        if (!toDelete.isEmpty()) { delete toDelete; System.debug('🗑️ Deleted '  + toDelete.size() + ' stale Procedures'); }
    }

    private static void upsertPublications(Id candidateId, List<Object> incoming) {
        if (incoming == null || incoming.isEmpty()) return;

        Map<String, Research_Publication__c> existingMap = new Map<String, Research_Publication__c>();
        for (Research_Publication__c r : [
            SELECT Id, Title__c FROM Research_Publication__c WHERE Candidate__c = :candidateId
        ]) {
            if (String.isNotBlank(r.Title__c)) {
                existingMap.put(r.Title__c.toLowerCase(), r);
            }
        }

        List<Research_Publication__c> toInsert = new List<Research_Publication__c>();
        List<Research_Publication__c> toUpdate = new List<Research_Publication__c>();
        Set<String> seen = new Set<String>();

        for (Object obj : incoming) {
            String title = (String) obj;
            String key   = title.toLowerCase();
            seen.add(key);
            if (existingMap.containsKey(key)) {
                Research_Publication__c r = existingMap.get(key);
                r.Title__c = title;
                toUpdate.add(r);
            } else {
                toInsert.add(new Research_Publication__c(Candidate__c = candidateId, Title__c = title));
            }
        }

        List<Research_Publication__c> toDelete = new List<Research_Publication__c>();
        for (String key : existingMap.keySet()) {
            if (!seen.contains(key)) toDelete.add(existingMap.get(key));
        }

        if (!toUpdate.isEmpty()) { update toUpdate; System.debug('✅ Updated '  + toUpdate.size() + ' Publications'); }
        if (!toInsert.isEmpty()) { insert toInsert; System.debug('✅ Inserted ' + toInsert.size() + ' Publications'); }
        if (!toDelete.isEmpty()) { delete toDelete; System.debug('🗑️ Deleted '  + toDelete.size() + ' stale Publications'); }
    }

    private static void upsertMemberships(Id candidateId, List<Object> incoming) {
        if (incoming == null || incoming.isEmpty()) return;

        Map<String, Membership__c> existingMap = new Map<String, Membership__c>();
        for (Membership__c r : [
            SELECT Id, Organization_Name__c FROM Membership__c WHERE Candidate__c = :candidateId
        ]) {
            if (String.isNotBlank(r.Organization_Name__c)) {
                existingMap.put(r.Organization_Name__c.toLowerCase(), r);
            }
        }

        List<Membership__c> toInsert = new List<Membership__c>();
        List<Membership__c> toUpdate = new List<Membership__c>();
        Set<String> seen = new Set<String>();

        for (Object obj : incoming) {
            String name = (String) obj;
            String key  = name.toLowerCase();
            seen.add(key);
            if (existingMap.containsKey(key)) {
                Membership__c r = existingMap.get(key);
                r.Organization_Name__c = name;
                toUpdate.add(r);
            } else {
                toInsert.add(new Membership__c(Candidate__c = candidateId, Organization_Name__c = name));
            }
        }

        List<Membership__c> toDelete = new List<Membership__c>();
        for (String key : existingMap.keySet()) {
            if (!seen.contains(key)) toDelete.add(existingMap.get(key));
        }

        if (!toUpdate.isEmpty()) { update toUpdate; System.debug('✅ Updated '  + toUpdate.size() + ' Memberships'); }
        if (!toInsert.isEmpty()) { insert toInsert; System.debug('✅ Inserted ' + toInsert.size() + ' Memberships'); }
        if (!toDelete.isEmpty()) { delete toDelete; System.debug('🗑️ Deleted '  + toDelete.size() + ' stale Memberships'); }
    }

    // ================================================================
    // SINGLE-RECORD UPSERT HELPERS
    //
    // Pattern: query first existing record → update it if found,
    // otherwise insert a new one.
    // ================================================================

    private static void upsertWorkExperience(Id candidateId, Map<String, Object> expData) {
        if (expData == null) return;

        List<String> respLines = new List<String>();
        List<Object> respObj = (List<Object>) expData.get('responsibilities');
        if (respObj != null) {
            for (Object o : respObj) respLines.add((String) o);
        }

        List<Work_Experience__c> existing = [
            SELECT Id FROM Work_Experience__c
            WHERE Candidate__c = :candidateId
            ORDER BY CreatedDate ASC LIMIT 1
        ];

        Work_Experience__c rec = existing.isEmpty()
            ? new Work_Experience__c(Candidate__c = candidateId)
            : existing[0];

        rec.Role__c             = (String) expData.get('role');
        rec.Organization__c     = (String) expData.get('organization');
        rec.Duration_Text__c    = (String) expData.get('duration');
        rec.Responsibilities__c = String.join(respLines, '\n');

        if (existing.isEmpty()) {
            insert rec;
            System.debug('✅ Inserted Work Experience');
        } else {
            update rec;
            System.debug('✅ Updated Work Experience');
        }
    }

    private static void upsertEducation(Id candidateId, Map<String, Object> eduData) {
        if (eduData == null) return;

        List<Education__c> existing = [
            SELECT Id FROM Education__c
            WHERE Candidate__c = :candidateId
            ORDER BY CreatedDate ASC LIMIT 1
        ];

        Education__c rec = existing.isEmpty()
            ? new Education__c(Candidate__c = candidateId)
            : existing[0];

        rec.Degree__c        = (String) eduData.get('degree');
        rec.Institution__c   = (String) eduData.get('institution');
        rec.Duration_Text__c = (String) eduData.get('year');
        rec.Details__c       = (String) eduData.get('details');

        if (existing.isEmpty()) {
            insert rec;
            System.debug('✅ Inserted Education');
        } else {
            update rec;
            System.debug('✅ Updated Education');
        }
    }

    private static void upsertInternship(Id candidateId, Map<String, Object> internshipData) {
        if (internshipData == null) return;

        List<Internship__c> existing = [
            SELECT Id FROM Internship__c
            WHERE Candidate__c = :candidateId
            ORDER BY CreatedDate ASC LIMIT 1
        ];

        Internship__c rec = existing.isEmpty()
            ? new Internship__c(Candidate__c = candidateId)
            : existing[0];

        rec.Organization__c  = (String) internshipData.get('organization');
        rec.Duration_Text__c = (String) internshipData.get('duration');

        if (existing.isEmpty()) {
            insert rec;
            System.debug('✅ Inserted Internship');
        } else {
            update rec;
            System.debug('✅ Updated Internship');
        }

        // Sync rotations using the same upsert pattern
        upsertInternshipRotations(
            rec.Id,
            candidateId,
            (List<Object>) internshipData.get('rotations')
        );
    }

    private static void upsertInternshipRotations(Id internshipId, Id candidateId, List<Object> incoming) {
        if (incoming == null) incoming = new List<Object>();

        Map<String, Internship_Rotation__c> existingMap = new Map<String, Internship_Rotation__c>();
        for (Internship_Rotation__c r : [
            SELECT Id, Department_Name__c FROM Internship_Rotation__c
            WHERE Internship__c = :internshipId
        ]) {
            if (String.isNotBlank(r.Department_Name__c)) {
                existingMap.put(r.Department_Name__c.toLowerCase(), r);
            }
        }

        List<Internship_Rotation__c> toInsert = new List<Internship_Rotation__c>();
        List<Internship_Rotation__c> toUpdate = new List<Internship_Rotation__c>();
        Set<String> seen = new Set<String>();

        for (Object obj : incoming) {
            String name = (String) obj;
            String key  = name.toLowerCase();
            seen.add(key);
            if (existingMap.containsKey(key)) {
                Internship_Rotation__c r = existingMap.get(key);
                r.Department_Name__c = name;
                toUpdate.add(r);
            } else {
                toInsert.add(new Internship_Rotation__c(
                    Internship__c      = internshipId,
                    Candidate__c       = candidateId,
                    Department_Name__c = name
                ));
            }
        }

        List<Internship_Rotation__c> toDelete = new List<Internship_Rotation__c>();
        for (String key : existingMap.keySet()) {
            if (!seen.contains(key)) toDelete.add(existingMap.get(key));
        }

        if (!toUpdate.isEmpty()) { update toUpdate; }
        if (!toInsert.isEmpty()) { insert toInsert; }
        if (!toDelete.isEmpty()) { delete toDelete; }
        System.debug('✅ Synced rotations — updated: ' + toUpdate.size()
            + ', inserted: ' + toInsert.size() + ', deleted: ' + toDelete.size());
    }

    // ================================================================
    // PRIVATE HELPERS
    // ================================================================

    private static Map<String, Object> getSectionValue(Map<String, Object> data, String key) {
        if (data.containsKey(key) && data.get(key) != null) {
            Map<String, Object> section = (Map<String, Object>) data.get(key);
            if (section.containsKey('value') && section.get('value') instanceof Map<String, Object>) {
                return (Map<String, Object>) section.get('value');
            }
        }
        return null;
    }

    private static List<Object> getSectionValueAsList(Map<String, Object> data, String key) {
        if (data.containsKey(key) && data.get(key) != null) {
            Map<String, Object> section = (Map<String, Object>) data.get(key);
            if (section.containsKey('value') && section.get('value') instanceof List<Object>) {
                return (List<Object>) section.get('value');
            }
        }
        return new List<Object>();
    }
}