public with sharing class CandidateProfileController {
    
    // DTO for returning profile data
    public class ProfileDataDto {
        @AuraEnabled public Candidate__c candidate;
        @AuraEnabled public List<Work_Experience__c> workExperiences;
        @AuraEnabled public List<Education__c> educations;
        @AuraEnabled public List<License_Certification__c> licenses;
        @AuraEnabled public List<Clinical_Skill__c> clinicalSkills;
        @AuraEnabled public List<Technical_Skill__c> technicalSkills;
        @AuraEnabled public List<Procedure__c> procedures;
        @AuraEnabled public List<Internship__c> internships;
        @AuraEnabled public List<Research_Publication__c> researchPublications;
        @AuraEnabled public List<Membership__c> memberships;
    }

    /**
     * Retrieves all profile data for a candidate
     */
    @AuraEnabled
    public static ProfileDataDto getProfileData(Id candidateId) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID is required.');
        }
        
        ProfileDataDto result = new ProfileDataDto();

        // Query candidate
        List<Candidate__c> candidates = [
            SELECT Id, Name, Email__c, Phone__c, Location__c
            FROM Candidate__c 
            WHERE Id = :candidateId 
            LIMIT 1
        ];
        
        if (candidates.isEmpty()) {
            throw new AuraHandledException('Candidate not found.');
        }
        
        result.candidate = candidates[0];

        // Query related records
        result.workExperiences = [
            SELECT Id, Role__c, Organization__c, Duration_Text__c, Responsibilities__c 
            FROM Work_Experience__c 
            WHERE Candidate__c = :candidateId 
            ORDER BY CreatedDate DESC
        ];

        result.educations = [
            SELECT Id, Degree__c, Institution__c, Duration_Text__c, Details__c 
            FROM Education__c 
            WHERE Candidate__c = :candidateId 
            ORDER BY CreatedDate DESC
        ];

        result.licenses = [
            SELECT Id, Name, Type__c, Notes__c 
            FROM License_Certification__c 
            WHERE Candidate__c = :candidateId 
            ORDER BY Name ASC
        ];

        result.clinicalSkills = [
            SELECT Id, Name, Skill_Type__c, Description__c 
            FROM Clinical_Skill__c 
            WHERE Candidate__c = :candidateId 
            ORDER BY Name ASC
        ];

        result.technicalSkills = [
            SELECT Id, Name, Category__c, Description__c 
            FROM Technical_Skill__c 
            WHERE Candidate__c = :candidateId 
            ORDER BY Name ASC
        ];

        result.procedures = [
            SELECT Id, Name, Category__c, Notes__c
            FROM Procedure__c
            WHERE Candidate__c = :candidateId
            ORDER BY Name ASC
        ];

        result.internships = [
            SELECT Id, Organization__c, Duration_Text__c
            FROM Internship__c
            WHERE Candidate__c = :candidateId
            ORDER BY CreatedDate DESC
        ];

        result.researchPublications = [
            SELECT Id, Title__c, Type__c, Description__c
            FROM Research_Publication__c
            WHERE Candidate__c = :candidateId
            ORDER BY CreatedDate DESC
        ];

        result.memberships = [
            SELECT Id, Organization_Name__c, Membership_Type__c, Member_Id__c
            FROM Membership__c
            WHERE Candidate__c = :candidateId
            ORDER BY Organization_Name__c ASC
        ];

        return result;
    }

    /**
     * Generic method to save or update a record
     */
    @AuraEnabled
    public static Id saveRecord(String recordData, String recordType) {
        if (String.isBlank(recordData) || String.isBlank(recordType)) {
            throw new AuraHandledException('Record data and type are required.');
        }

        try {
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(recordData);
            SObject recordToSave;

            switch on recordType {
                when 'workExperience' {
                    recordToSave = mapToWorkExperience(dataMap);
                }
                when 'education' {
                    recordToSave = mapToEducation(dataMap);
                }
                when 'license' {
                    recordToSave = mapToLicense(dataMap);
                }
                when 'clinicalSkill' {
                    recordToSave = mapToClinicalSkill(dataMap);
                }
                when 'technicalSkill' {
                    recordToSave = mapToTechnicalSkill(dataMap);
                }
                when 'procedure' {
                    recordToSave = mapToProcedure(dataMap);
                }
                when 'internship' {
                    recordToSave = mapToInternship(dataMap);
                }
                when 'research' {
                    recordToSave = mapToResearchPublication(dataMap);
                }
                when 'membership' {
                    recordToSave = mapToMembership(dataMap);
                }
                when else {
                    throw new AuraHandledException('Invalid record type: ' + recordType);
                }
            }

            upsert recordToSave;
            return recordToSave.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Error saving record: ' + e.getMessage());
        }
    }

    /**
     * Delete a record by ID and type
     */
    @AuraEnabled
    public static void deleteRecord(Id recordId, String recordType) {
        if (recordId == null || String.isBlank(recordType)) {
            throw new AuraHandledException('Record ID and type are required.');
        }

        try {
            SObject recordToDelete;
            
            switch on recordType {
                when 'workExperience' {
                    recordToDelete = new Work_Experience__c(Id = recordId);
                }
                when 'education' {
                    recordToDelete = new Education__c(Id = recordId);
                }
                when 'license' {
                    recordToDelete = new License_Certification__c(Id = recordId);
                }
                when 'clinicalSkill' {
                    recordToDelete = new Clinical_Skill__c(Id = recordId);
                }
                when 'technicalSkill' {
                    recordToDelete = new Technical_Skill__c(Id = recordId);
                }
                when 'procedure' {
                    recordToDelete = new Procedure__c(Id = recordId);
                }
                when 'internship' {
                    recordToDelete = new Internship__c(Id = recordId);
                }
                when 'research' {
                    recordToDelete = new Research_Publication__c(Id = recordId);
                }
                when 'membership' {
                    recordToDelete = new Membership__c(Id = recordId);
                }
                when else {
                    throw new AuraHandledException('Invalid record type: ' + recordType);
                }
            }

            delete recordToDelete;

        } catch (Exception e) {
            throw new AuraHandledException('Error deleting record: ' + e.getMessage());
        }
    }

    // =================================================================
    // Private Helper Methods to Map Data to SObjects
    // =================================================================

    private static Work_Experience__c mapToWorkExperience(Map<String, Object> dataMap) {
        Work_Experience__c record = new Work_Experience__c();
        
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) {
            record.Id = (Id) dataMap.get('Id');
        }
        
        record.Candidate__c = (Id) dataMap.get('Candidate__c');
        record.Role__c = (String) dataMap.get('Role__c');
        record.Organization__c = (String) dataMap.get('Organization__c');
        record.Duration_Text__c = (String) dataMap.get('Duration_Text__c');
        record.Responsibilities__c = (String) dataMap.get('Responsibilities__c');
        
        return record;
    }

    private static Education__c mapToEducation(Map<String, Object> dataMap) {
        Education__c record = new Education__c();
        
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) {
            record.Id = (Id) dataMap.get('Id');
        }
        
        record.Candidate__c = (Id) dataMap.get('Candidate__c');
        record.Institution__c = (String) dataMap.get('Institution__c');
        record.Degree__c = (String) dataMap.get('Degree__c');
        record.Duration_Text__c = (String) dataMap.get('Duration_Text__c');
        record.Details__c = (String) dataMap.get('Details__c');
        
        return record;
    }

    private static License_Certification__c mapToLicense(Map<String, Object> dataMap) {
        License_Certification__c record = new License_Certification__c();
        
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) {
            record.Id = (Id) dataMap.get('Id');
        }
        
        record.Candidate__c = (Id) dataMap.get('Candidate__c');
        record.Name = (String) dataMap.get('Name');
        record.Type__c = (String) dataMap.get('Type__c');
        record.Notes__c = (String) dataMap.get('Notes__c');
        
        return record;
    }

    private static Clinical_Skill__c mapToClinicalSkill(Map<String, Object> dataMap) {
        Clinical_Skill__c record = new Clinical_Skill__c();
        
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) {
            record.Id = (Id) dataMap.get('Id');
        }
        
        record.Candidate__c = (Id) dataMap.get('Candidate__c');
        record.Name = (String) dataMap.get('Name');
        record.Skill_Type__c = (String) dataMap.get('Skill_Type__c');
        record.Description__c = (String) dataMap.get('Description__c');
        
        return record;
    }

    private static Technical_Skill__c mapToTechnicalSkill(Map<String, Object> dataMap) {
        Technical_Skill__c record = new Technical_Skill__c();
        
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) {
            record.Id = (Id) dataMap.get('Id');
        }
        
        record.Candidate__c = (Id) dataMap.get('Candidate__c');
        record.Name = (String) dataMap.get('Name');
        record.Category__c = (String) dataMap.get('Category__c');
        record.Description__c = (String) dataMap.get('Description__c');
        
        return record;
    }

    private static Procedure__c mapToProcedure(Map<String, Object> dataMap) {
        Procedure__c record = new Procedure__c();
        
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) {
            record.Id = (Id) dataMap.get('Id');
        }
        
        record.Candidate__c = (Id) dataMap.get('Candidate__c');
        record.Name = (String) dataMap.get('Name');
        record.Category__c = (String) dataMap.get('Category__c');
        record.Notes__c = (String) dataMap.get('Notes__c');
        
        return record;
    }

    private static Internship__c mapToInternship(Map<String, Object> dataMap) {
        Internship__c record = new Internship__c();
        
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) {
            record.Id = (Id) dataMap.get('Id');
        }
        
        record.Candidate__c = (Id) dataMap.get('Candidate__c');
        record.Organization__c = (String) dataMap.get('Organization__c');
        record.Duration_Text__c = (String) dataMap.get('Duration_Text__c');
        
        return record;
    }

    private static Research_Publication__c mapToResearchPublication(Map<String, Object> dataMap) {
        Research_Publication__c record = new Research_Publication__c();
        
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) {
            record.Id = (Id) dataMap.get('Id');
        }
        
        record.Candidate__c = (Id) dataMap.get('Candidate__c');
        record.Title__c = (String) dataMap.get('Title__c');
        record.Type__c = (String) dataMap.get('Type__c');
        record.Description__c = (String) dataMap.get('Description__c');
        
        return record;
    }

    private static Membership__c mapToMembership(Map<String, Object> dataMap) {
        Membership__c record = new Membership__c();
        
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) {
            record.Id = (Id) dataMap.get('Id');
        }
        
        record.Candidate__c = (Id) dataMap.get('Candidate__c');
        record.Organization_Name__c = (String) dataMap.get('Organization_Name__c');
        record.Membership_Type__c = (String) dataMap.get('Membership_Type__c');
        record.Member_Id__c = (String) dataMap.get('Member_Id__c');
        
        return record;
    }
}