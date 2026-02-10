public without sharing class CandidateProfileController {
    
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
     * DTO class for document information
     */
    public class DocumentInfo {
        @AuraEnabled public Id Id { get; set; }
        @AuraEnabled public String Title { get; set; }
        @AuraEnabled public String FileExtension { get; set; }
        @AuraEnabled public Integer ContentSize { get; set; }
        @AuraEnabled public DateTime CreatedDate { get; set; }
        @AuraEnabled public Id LatestPublishedVersionId { get; set; }
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

        // Query related records with date fields
        result.workExperiences = [
            SELECT Id, Role__c, Organization__c, Start_Date__c, End_Date__c, Is_Current__c, Responsibilities__c 
            FROM Work_Experience__c 
            WHERE Candidate__c = :candidateId 
            ORDER BY Start_Date__c DESC NULLS LAST, CreatedDate DESC
        ];

        result.educations = [
            SELECT Id, Degree__c, Institution__c, Start_Year__c, End_Year__c, Details__c 
            FROM Education__c 
            WHERE Candidate__c = :candidateId 
            ORDER BY Start_Year__c DESC NULLS LAST, CreatedDate DESC
        ];

        result.licenses = [
            SELECT Id, Name, Type__c, Issue_Date__c, Expiry_Date__c, Notes__c 
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
            SELECT Id, Organization__c, Start_Date__c, End_Date__c
            FROM Internship__c
            WHERE Candidate__c = :candidateId
            ORDER BY Start_Date__c DESC NULLS LAST, CreatedDate DESC
        ];

        result.researchPublications = [
            SELECT Id, Title__c, Type__c, Publication_Date__c, Description__c
            FROM Research_Publication__c
            WHERE Candidate__c = :candidateId
            ORDER BY Publication_Date__c DESC NULLS LAST, CreatedDate DESC
        ];

        result.memberships = [
            SELECT Id, Organization_Name__c, Membership_Type__c, Member_Id__c, Member_Since__c
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

    /**
     * Get all documents attached to a License/Certification record
     */
    @AuraEnabled(cacheable=true)
    public static List<DocumentInfo> getLicenseDocuments(Id licenseId) {
        System.debug('=== getLicenseDocuments Called ===');
        System.debug('License ID: ' + licenseId);
        
        List<DocumentInfo> documentList = new List<DocumentInfo>();
        
        if (licenseId == null) {
            System.debug('License ID is null, returning empty list');
            return documentList;
        }
        
        try {
            // Query ContentDocumentLinks to get files attached to this license
            List<ContentDocumentLink> cdls = [
                SELECT ContentDocumentId,
                       ContentDocument.Title,
                       ContentDocument.FileExtension,
                       ContentDocument.ContentSize,
                       ContentDocument.CreatedDate,
                       ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :licenseId
                ORDER BY ContentDocument.CreatedDate DESC
            ];
            
            System.debug('Found ' + cdls.size() + ' documents');
            
            for (ContentDocumentLink cdl : cdls) {
                DocumentInfo doc = new DocumentInfo();
                doc.Id = cdl.ContentDocumentId;
                doc.Title = cdl.ContentDocument.Title;
                doc.FileExtension = cdl.ContentDocument.FileExtension;
                doc.ContentSize = cdl.ContentDocument.ContentSize;
                doc.CreatedDate = cdl.ContentDocument.CreatedDate;
                doc.LatestPublishedVersionId = cdl.ContentDocument.LatestPublishedVersionId;
                
                documentList.add(doc);
            }
            
            return documentList;
            
        } catch (Exception e) {
            System.debug('Error fetching license documents: ' + e.getMessage());
            throw new AuraHandledException('Error fetching documents: ' + e.getMessage());
        }
    }

    /**
     * Delete a document from a License/Certification record
     */
    @AuraEnabled
    public static void deleteLicenseDocument(Id documentId) {
        System.debug('=== deleteLicenseDocument Called ===');
        System.debug('Document ID: ' + documentId);
        
        if (documentId == null) {
            throw new AuraHandledException('Document ID is required');
        }
        
        try {
            // Delete the ContentDocument (this will also delete related ContentDocumentLinks)
            ContentDocument doc = new ContentDocument(Id = documentId);
            delete doc;
            
            System.debug('✅ Document deleted successfully');
            
        } catch (Exception e) {
            System.debug('❌ Error deleting document: ' + e.getMessage());
            throw new AuraHandledException('Failed to delete document: ' + e.getMessage());
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
        record.Start_Date__c = parseDate(dataMap.get('Start_Date__c'));
        record.End_Date__c = parseDate(dataMap.get('End_Date__c'));
        record.Is_Current__c = (Boolean) dataMap.get('Is_Current__c');
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
        record.Start_Year__c = parseDecimal(dataMap.get('Start_Year__c'));
        record.End_Year__c = parseDecimal(dataMap.get('End_Year__c'));
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
        record.Issue_Date__c = parseDate(dataMap.get('Issue_Date__c'));
        record.Expiry_Date__c = parseDate(dataMap.get('Expiry_Date__c'));
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
        record.Start_Date__c = parseDate(dataMap.get('Start_Date__c'));
        record.End_Date__c = parseDate(dataMap.get('End_Date__c'));
        
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
        record.Publication_Date__c = parseDate(dataMap.get('Publication_Date__c'));
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
        record.Member_Since__c = parseDate(dataMap.get('Member_Since__c'));
        
        return record;
    }

    // =================================================================
    // Helper Methods for Data Type Conversion
    // =================================================================

    private static Date parseDate(Object dateValue) {
        if (dateValue == null) {
            return null;
        }
        
        if (dateValue instanceof String) {
            String dateStr = (String) dateValue;
            if (String.isBlank(dateStr)) {
                return null;
            }
            try {
                // Parse YYYY-MM-DD format
                return Date.valueOf(dateStr);
            } catch (Exception e) {
                System.debug('Error parsing date: ' + dateStr + ', Error: ' + e.getMessage());
                return null;
            }
        }
        
        return null;
    }

    private static Decimal parseDecimal(Object decimalValue) {
        if (decimalValue == null) {
            return null;
        }
        
        if (decimalValue instanceof Integer) {
            return Decimal.valueOf((Integer) decimalValue);
        }
        
        if (decimalValue instanceof Decimal) {
            return (Decimal) decimalValue;
        }
        
        if (decimalValue instanceof String) {
            String decStr = (String) decimalValue;
            if (String.isBlank(decStr)) {
                return null;
            }
            try {
                return Decimal.valueOf(decStr);
            } catch (Exception e) {
                System.debug('Error parsing decimal: ' + decStr + ', Error: ' + e.getMessage());
                return null;
            }
        }
        
        return null;
    }

    /**
     * Get resume information for a candidate
     * IMPORTANT: cacheable=false to always get fresh checkbox state
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getCandidateResumeInfo(Id candidateId) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            System.debug('=== getCandidateResumeInfo called ===');
            System.debug('Candidate ID: ' + candidateId);
            
            // Query candidate with resume fields
            List<Candidate__c> candidates = [
                SELECT Id, Name, S3_Resume_URL__c, Resume_Status__c, 
                       Resume_parsing_using_ai__c, LastModifiedDate
                FROM Candidate__c
                WHERE Id = :candidateId
                LIMIT 1
            ];
            
            if (candidates.isEmpty()) {
                System.debug('❌ No candidate found');
                result.put('hasResume', false);
                result.put('useAiParsing', false);
                return result;
            }
            
            Candidate__c candidate = candidates[0];
            System.debug('✅ Candidate found: ' + candidate.Name);
            System.debug('Resume_parsing_using_ai__c value: ' + candidate.Resume_parsing_using_ai__c);
            
            // Check if resume file exists
            List<ContentDocumentLink> cdls = [
                SELECT ContentDocument.LatestPublishedVersionId, 
                       ContentDocument.Title,
                       ContentDocument.FileExtension,
                       ContentDocument.CreatedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :candidateId
                AND ContentDocument.FileExtension IN ('pdf', 'doc', 'docx')
                ORDER BY ContentDocument.CreatedDate DESC
                LIMIT 1
            ];
            
            if (cdls.isEmpty()) {
                System.debug('No resume file found');
                result.put('hasResume', false);
            } else {
                ContentDocumentLink cdl = cdls[0];
                System.debug('Resume file found: ' + cdl.ContentDocument.Title);
                result.put('hasResume', true);
                result.put('fileName', cdl.ContentDocument.Title + '.' + cdl.ContentDocument.FileExtension);
                result.put('uploadDate', cdl.ContentDocument.CreatedDate.format('MMM dd, yyyy'));
                result.put('s3Url', candidate.S3_Resume_URL__c);
            }
            
            // CRITICAL: Explicitly set boolean value (not null)
            Boolean aiParsingEnabled = candidate.Resume_parsing_using_ai__c == true;
            result.put('useAiParsing', aiParsingEnabled);
            
            System.debug('✅ useAiParsing returned: ' + aiParsingEnabled);
            System.debug('Full result map: ' + result);
            
            return result;
            
        } catch (Exception e) {
            System.debug('❌ Error in getCandidateResumeInfo: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching resume info: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void uploadResumeFile(Id candidateId, String fileName, String base64Data) {
        System.debug('=== uploadResumeFile Called ===');
        System.debug('Candidate ID: ' + candidateId);
        System.debug('File Name: ' + fileName);
        
        try {
            // Create ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.FirstPublishLocationId = candidateId;
            cv.IsMajorVersion = true;
            
            insert cv;
            
            System.debug('✅ ContentVersion created: ' + cv.Id);
            
        } catch (Exception e) {
            System.debug('❌ Error: ' + e.getMessage());
            throw new AuraHandledException('Upload failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void resetResumeStatus(Id candidateId) {
        try {
            Candidate__c candidate = new Candidate__c(
                Id = candidateId,
                Resume_Status__c = false
            );
            update candidate;
            
            System.debug('Resume_Status__c reset to false for Candidate: ' + candidateId);
        } catch (Exception e) {
            System.debug('Error resetting Resume_Status__c: ' + e.getMessage());
            throw new AuraHandledException('Failed to reset resume status: ' + e.getMessage());
        }
    }
}
