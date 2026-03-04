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

    public class DocumentInfo {
        @AuraEnabled public Id Id { get; set; }
        @AuraEnabled public String Title { get; set; }
        @AuraEnabled public String FileExtension { get; set; }
        @AuraEnabled public Integer ContentSize { get; set; }
        @AuraEnabled public DateTime CreatedDate { get; set; }
        @AuraEnabled public Id LatestPublishedVersionId { get; set; }
    }

    public class PhotoInfo {
        @AuraEnabled public Boolean hasPhoto { get; set; }
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String uploadDate { get; set; }
        @AuraEnabled public Id contentDocumentId { get; set; }
        @AuraEnabled public Id contentVersionId { get; set; }
        @AuraEnabled public String downloadUrl { get; set; }
    }

    @AuraEnabled
    public static ProfileDataDto getProfileData(Id candidateId) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID is required.');
        }
        
        ProfileDataDto result = new ProfileDataDto();

        List<Candidate__c> candidates = [
            SELECT Id, Name, Full_Name__c, Email__c, Phone__c, Location__c
            FROM Candidate__c 
            WHERE Id = :candidateId 
            LIMIT 1
        ];
        
        if (candidates.isEmpty()) {
            throw new AuraHandledException('Candidate not found.');
        }
        
        result.candidate = candidates[0];

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

    @AuraEnabled
    public static Id saveRecord(String recordData, String recordType) {
        if (String.isBlank(recordData) || String.isBlank(recordType)) {
            throw new AuraHandledException('Record data and type are required.');
        }

        try {
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(recordData);
            SObject recordToSave;

            switch on recordType {
                when 'workExperience' { recordToSave = mapToWorkExperience(dataMap); }
                when 'education'      { recordToSave = mapToEducation(dataMap); }
                when 'license'        { recordToSave = mapToLicense(dataMap); }
                when 'clinicalSkill'  { recordToSave = mapToClinicalSkill(dataMap); }
                when 'technicalSkill' { recordToSave = mapToTechnicalSkill(dataMap); }
                when 'procedure'      { recordToSave = mapToProcedure(dataMap); }
                when 'internship'     { recordToSave = mapToInternship(dataMap); }
                when 'research'       { recordToSave = mapToResearchPublication(dataMap); }
                when 'membership'     { recordToSave = mapToMembership(dataMap); }
                when else { throw new AuraHandledException('Invalid record type: ' + recordType); }
            }

            upsert recordToSave;
            return recordToSave.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Error saving record: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteRecord(Id recordId, String recordType) {
        if (recordId == null || String.isBlank(recordType)) {
            throw new AuraHandledException('Record ID and type are required.');
        }

        try {
            SObject recordToDelete;
            
            switch on recordType {
                when 'workExperience' { recordToDelete = new Work_Experience__c(Id = recordId); }
                when 'education'      { recordToDelete = new Education__c(Id = recordId); }
                when 'license'        { recordToDelete = new License_Certification__c(Id = recordId); }
                when 'clinicalSkill'  { recordToDelete = new Clinical_Skill__c(Id = recordId); }
                when 'technicalSkill' { recordToDelete = new Technical_Skill__c(Id = recordId); }
                when 'procedure'      { recordToDelete = new Procedure__c(Id = recordId); }
                when 'internship'     { recordToDelete = new Internship__c(Id = recordId); }
                when 'research'       { recordToDelete = new Research_Publication__c(Id = recordId); }
                when 'membership'     { recordToDelete = new Membership__c(Id = recordId); }
                when else { throw new AuraHandledException('Invalid record type: ' + recordType); }
            }

            delete recordToDelete;

        } catch (Exception e) {
            throw new AuraHandledException('Error deleting record: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<DocumentInfo> getLicenseDocuments(Id licenseId) {
        List<DocumentInfo> documentList = new List<DocumentInfo>();
        if (licenseId == null) return documentList;
        
        try {
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
            throw new AuraHandledException('Error fetching documents: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteLicenseDocument(Id documentId) {
        if (documentId == null) {
            throw new AuraHandledException('Document ID is required');
        }
        try {
            delete new ContentDocument(Id = documentId);
        } catch (Exception e) {
            throw new AuraHandledException('Failed to delete document: ' + e.getMessage());
        }
    }

    // =================================================================
    // Private Helper Methods to Map Data to SObjects
    // =================================================================

    private static Work_Experience__c mapToWorkExperience(Map<String, Object> dataMap) {
        Work_Experience__c record = new Work_Experience__c();
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) record.Id = (Id) dataMap.get('Id');
        record.Candidate__c       = (Id) dataMap.get('Candidate__c');
        record.Role__c            = (String) dataMap.get('Role__c');
        record.Organization__c    = (String) dataMap.get('Organization__c');
        record.Start_Date__c      = parseDate(dataMap.get('Start_Date__c'));
        record.End_Date__c        = parseDate(dataMap.get('End_Date__c'));
        record.Is_Current__c      = (Boolean) dataMap.get('Is_Current__c');
        record.Responsibilities__c = (String) dataMap.get('Responsibilities__c');
        return record;
    }

    private static Education__c mapToEducation(Map<String, Object> dataMap) {
        Education__c record = new Education__c();
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) record.Id = (Id) dataMap.get('Id');
        record.Candidate__c   = (Id) dataMap.get('Candidate__c');
        record.Institution__c = (String) dataMap.get('Institution__c');
        record.Degree__c      = (String) dataMap.get('Degree__c');
        record.Start_Year__c  = parseDecimal(dataMap.get('Start_Year__c'));
        record.End_Year__c    = parseDecimal(dataMap.get('End_Year__c'));
        record.Details__c     = (String) dataMap.get('Details__c');
        return record;
    }

    private static License_Certification__c mapToLicense(Map<String, Object> dataMap) {
        License_Certification__c record = new License_Certification__c();
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) record.Id = (Id) dataMap.get('Id');
        record.Candidate__c  = (Id) dataMap.get('Candidate__c');
        record.Name          = (String) dataMap.get('Name');
        record.Type__c       = (String) dataMap.get('Type__c');
        record.Issue_Date__c  = parseDate(dataMap.get('Issue_Date__c'));
        record.Expiry_Date__c = parseDate(dataMap.get('Expiry_Date__c'));
        record.Notes__c      = (String) dataMap.get('Notes__c');
        return record;
    }

    private static Clinical_Skill__c mapToClinicalSkill(Map<String, Object> dataMap) {
        Clinical_Skill__c record = new Clinical_Skill__c();
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) record.Id = (Id) dataMap.get('Id');
        record.Candidate__c  = (Id) dataMap.get('Candidate__c');
        record.Name          = (String) dataMap.get('Name');
        record.Skill_Type__c = (String) dataMap.get('Skill_Type__c');
        record.Description__c = (String) dataMap.get('Description__c');
        return record;
    }

    private static Technical_Skill__c mapToTechnicalSkill(Map<String, Object> dataMap) {
        Technical_Skill__c record = new Technical_Skill__c();
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) record.Id = (Id) dataMap.get('Id');
        record.Candidate__c   = (Id) dataMap.get('Candidate__c');
        record.Name           = (String) dataMap.get('Name');
        record.Category__c    = (String) dataMap.get('Category__c');
        record.Description__c = (String) dataMap.get('Description__c');
        return record;
    }

    private static Procedure__c mapToProcedure(Map<String, Object> dataMap) {
        Procedure__c record = new Procedure__c();
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) record.Id = (Id) dataMap.get('Id');
        record.Candidate__c = (Id) dataMap.get('Candidate__c');
        record.Name         = (String) dataMap.get('Name');
        record.Category__c  = (String) dataMap.get('Category__c');
        record.Notes__c     = (String) dataMap.get('Notes__c');
        return record;
    }

    private static Internship__c mapToInternship(Map<String, Object> dataMap) {
        Internship__c record = new Internship__c();
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) record.Id = (Id) dataMap.get('Id');
        record.Candidate__c    = (Id) dataMap.get('Candidate__c');
        record.Organization__c = (String) dataMap.get('Organization__c');
        record.Start_Date__c   = parseDate(dataMap.get('Start_Date__c'));
        record.End_Date__c     = parseDate(dataMap.get('End_Date__c'));
        return record;
    }

    private static Research_Publication__c mapToResearchPublication(Map<String, Object> dataMap) {
        Research_Publication__c record = new Research_Publication__c();
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) record.Id = (Id) dataMap.get('Id');
        record.Candidate__c       = (Id) dataMap.get('Candidate__c');
        record.Title__c           = (String) dataMap.get('Title__c');
        record.Type__c            = (String) dataMap.get('Type__c');
        record.Publication_Date__c = parseDate(dataMap.get('Publication_Date__c'));
        record.Description__c     = (String) dataMap.get('Description__c');
        return record;
    }

    private static Membership__c mapToMembership(Map<String, Object> dataMap) {
        Membership__c record = new Membership__c();
        if (dataMap.containsKey('Id') && dataMap.get('Id') != null) record.Id = (Id) dataMap.get('Id');
        record.Candidate__c        = (Id) dataMap.get('Candidate__c');
        record.Organization_Name__c = (String) dataMap.get('Organization_Name__c');
        record.Membership_Type__c  = (String) dataMap.get('Membership_Type__c');
        record.Member_Id__c        = (String) dataMap.get('Member_Id__c');
        record.Member_Since__c     = parseDate(dataMap.get('Member_Since__c'));
        return record;
    }

    // =================================================================
    // Helper Methods for Data Type Conversion
    // =================================================================

    private static Date parseDate(Object dateValue) {
        if (dateValue == null) return null;
        if (dateValue instanceof String) {
            String dateStr = (String) dateValue;
            if (String.isBlank(dateStr)) return null;
            try {
                return Date.valueOf(dateStr);
            } catch (Exception e) {
                return null;
            }
        }
        return null;
    }

    private static Decimal parseDecimal(Object decimalValue) {
        if (decimalValue == null) return null;
        if (decimalValue instanceof Integer) return Decimal.valueOf((Integer) decimalValue);
        if (decimalValue instanceof Decimal) return (Decimal) decimalValue;
        if (decimalValue instanceof String) {
            String decStr = (String) decimalValue;
            if (String.isBlank(decStr)) return null;
            try {
                return Decimal.valueOf(decStr);
            } catch (Exception e) {
                return null;
            }
        }
        return null;
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getCandidateResumeInfo(Id candidateId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            List<Candidate__c> candidates = [
                SELECT Id, Name, S3_Resume_URL__c, Resume_Status__c, 
                       Resume_parsing_using_ai__c, LastModifiedDate
                FROM Candidate__c
                WHERE Id = :candidateId
                LIMIT 1
            ];
            
            if (candidates.isEmpty()) {
                result.put('hasResume', false);
                result.put('useAiParsing', false);
                return result;
            }
            
            Candidate__c candidate = candidates[0];
            
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
                result.put('hasResume', false);
            } else {
                ContentDocumentLink cdl = cdls[0];
                result.put('hasResume', true);
                result.put('fileName', cdl.ContentDocument.Title + '.' + cdl.ContentDocument.FileExtension);
                result.put('uploadDate', cdl.ContentDocument.CreatedDate.format('MMM dd, yyyy'));
                result.put('s3Url', candidate.S3_Resume_URL__c);
            }
            
            result.put('useAiParsing', candidate.Resume_parsing_using_ai__c == true);
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching resume info: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void uploadResumeFile(Id candidateId, String fileName, String base64Data) {
        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.FirstPublishLocationId = candidateId;
            cv.IsMajorVersion = true;
            insert cv;
        } catch (Exception e) {
            throw new AuraHandledException('Upload failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void resetResumeStatus(Id candidateId) {
        try {
            update new Candidate__c(Id = candidateId, Resume_Status__c = false);
        } catch (Exception e) {
            throw new AuraHandledException('Failed to reset resume status: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static PhotoInfo getCandidatePhotoInfo(Id candidateId) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID is required.');
        }

        PhotoInfo info = new PhotoInfo();
        info.hasPhoto = false;

        Candidate__c candidate = [
            SELECT Id, Profile_Photo_Document_Id__c
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];

        if (String.isBlank(candidate.Profile_Photo_Document_Id__c)) return info;

        Id photoDocId;
        try {
            photoDocId = (Id) candidate.Profile_Photo_Document_Id__c;
        } catch (Exception e) {
            candidate.Profile_Photo_Document_Id__c = null;
            update candidate;
            return info;
        }

        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, CreatedDate, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId = :photoDocId
            AND IsLatest = true
            LIMIT 1
        ];

        if (versions.isEmpty()) {
            candidate.Profile_Photo_Document_Id__c = null;
            update candidate;
            return info;
        }

        ContentVersion versionRec = versions[0];
        Set<String> allowedExts = new Set<String>{ 'jpg', 'jpeg', 'png', 'webp', 'gif' };
        String ext = versionRec.FileExtension == null ? '' : versionRec.FileExtension.toLowerCase();
        if (!allowedExts.contains(ext)) {
            candidate.Profile_Photo_Document_Id__c = null;
            update candidate;
            return info;
        }

        info.hasPhoto        = true;
        info.contentDocumentId = versionRec.ContentDocumentId;
        info.contentVersionId  = versionRec.Id;
        info.fileName        = versionRec.Title + '.' + versionRec.FileExtension;
        info.uploadDate      = versionRec.CreatedDate.format('MMM dd, yyyy');
        info.downloadUrl     = '/sfc/servlet.shepherd/version/download/' + versionRec.Id;
        return info;
    }

    // =================================================================
    // ★ UPDATED: setCandidateProfilePhoto
    //
    // Changes from original:
    //   1. ★ Added VersionData to ContentVersion SELECT
    //   2. ★ Removed CDL link check (causes false failures with lightning-file-upload)
    //   3. ★ Added Face++ detect → saves Face_Token__c + Face_Token_Status__c
    //      Picklist values: Pending | Verified | Failed
    // =================================================================
    @AuraEnabled
    public static void setCandidateProfilePhoto(Id candidateId, Id contentDocumentId) {
        if (candidateId == null || contentDocumentId == null) {
            throw new AuraHandledException('Candidate ID and content document ID are required.');
        }

        // ★ VersionData added — required to encode image for Face++ API
        ContentVersion versionRec = [
            SELECT Id, FileExtension, ContentDocumentId, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];

        Set<String> allowedExts = new Set<String>{ 'jpg', 'jpeg', 'png', 'webp', 'gif' };
        String ext = versionRec.FileExtension == null ? '' : versionRec.FileExtension.toLowerCase();
        if (!allowedExts.contains(ext)) {
            throw new AuraHandledException('Only image files are allowed for profile photo.');
        }

        Candidate__c candidate = [
            SELECT Id, Profile_Photo_Document_Id__c
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];

        String oldDocId = candidate.Profile_Photo_Document_Id__c;
        String newDocId = String.valueOf(contentDocumentId);

        // ★ Call Face++ detect on uploaded photo to get face_token
        // face_token = unique fingerprint Face++ assigns to the detected face
        // Saved on Candidate__c so e-sign can compare it against live camera snapshot
        String faceToken  = null;
        String faceStatus = 'Pending';

        try {
            String imageBase64 = EncodingUtil.base64Encode(versionRec.VersionData);
            faceToken  = FacePlusPlusService.detectFaceAndReturnToken(imageBase64);
            faceStatus = (faceToken != null) ? 'Verified' : 'Failed';
            System.debug('Face++ token: ' + faceToken + ' | status: ' + faceStatus);
        } catch (Exception faceEx) {
            faceStatus = 'Failed';
            System.debug('Face++ detect failed: ' + faceEx.getMessage());
        }

        // ★ Save all three fields in one update
        candidate.Profile_Photo_Document_Id__c = newDocId;
        candidate.Face_Token__c                = faceToken;
        candidate.Face_Token_Status__c         = faceStatus;
        update candidate;

        // Clean up old photo CDL
        if (!String.isBlank(oldDocId) && oldDocId != newDocId) {
            try {
                Id oldDocIdAsId = (Id) oldDocId;
                List<ContentDocumentLink> oldLinks = [
                    SELECT Id FROM ContentDocumentLink
                    WHERE LinkedEntityId = :candidateId
                    AND ContentDocumentId = :oldDocIdAsId
                ];
                if (!oldLinks.isEmpty()) delete oldLinks;
            } catch (Exception e) {
                System.debug('Old profile photo cleanup skipped: ' + e.getMessage());
            }
        }
    }

    @AuraEnabled
    public static void deleteCandidatePhoto(Id candidateId) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID is required.');
        }

        Candidate__c candidate = [
            SELECT Id, Profile_Photo_Document_Id__c
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];

        String oldDocId = candidate.Profile_Photo_Document_Id__c;

        // Clear photo + face token when photo is deleted
        candidate.Profile_Photo_Document_Id__c = null;
        candidate.Face_Token__c                = null;
        candidate.Face_Token_Status__c         = null;
        update candidate;

        if (!String.isBlank(oldDocId)) {
            try {
                Id oldDocIdAsId = (Id) oldDocId;
                List<ContentDocumentLink> oldLinks = [
                    SELECT Id FROM ContentDocumentLink
                    WHERE LinkedEntityId = :candidateId
                    AND ContentDocumentId = :oldDocIdAsId
                ];
                if (!oldLinks.isEmpty()) delete oldLinks;
            } catch (Exception e) {
                System.debug('Profile photo delete skipped: ' + e.getMessage());
            }
        }
    }

    @AuraEnabled
    public static String checkDuplicate(
        String candidateId,
        String recordType,  
        String fieldsJson,
        String excludeId
    ) {
        try {
            if (String.isBlank(candidateId) || String.isBlank(recordType) || String.isBlank(fieldsJson)) {
                return null;
            }

            Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(fieldsJson);
            String dupMessage = null;

            switch on recordType {

                when 'workExperience' {
                    String role = getStr(fields, 'Role__c');
                    String org  = getStr(fields, 'Organization__c');
                    if (String.isNotBlank(role) && String.isNotBlank(org)) {
                        List<Work_Experience__c> dups = [
                            SELECT Id FROM Work_Experience__c
                            WHERE Candidate__c = :candidateId AND Role__c = :role AND Organization__c = :org
                            LIMIT 1
                        ];
                        if (!dups.isEmpty() && (String.isBlank(excludeId) || dups[0].Id != excludeId))
                            dupMessage = 'A work experience entry for "' + role + '" at "' + org + '" already exists.';
                    }
                }

                when 'education' {
                    String degree      = getStr(fields, 'Degree__c');
                    String institution = getStr(fields, 'Institution__c');
                    if (String.isNotBlank(degree) && String.isNotBlank(institution)) {
                        List<Education__c> dups = [
                            SELECT Id FROM Education__c
                            WHERE Candidate__c = :candidateId AND Degree__c = :degree AND Institution__c = :institution
                            LIMIT 1
                        ];
                        if (!dups.isEmpty() && (String.isBlank(excludeId) || dups[0].Id != excludeId))
                            dupMessage = 'Education "' + degree + '" at "' + institution + '" already exists.';
                    }
                }

                when 'license' {
                    String name = getStr(fields, 'Name');
                    if (String.isNotBlank(name)) {
                        List<License_Certification__c> dups = [
                            SELECT Id FROM License_Certification__c
                            WHERE Candidate__c = :candidateId AND Name = :name LIMIT 1
                        ];
                        if (!dups.isEmpty() && (String.isBlank(excludeId) || dups[0].Id != excludeId))
                            dupMessage = 'License/Certification "' + name + '" already exists.';
                    }
                }

                when 'clinicalSkill' {
                    String name = getStr(fields, 'Name');
                    if (String.isNotBlank(name)) {
                        List<Clinical_Skill__c> dups = [
                            SELECT Id FROM Clinical_Skill__c
                            WHERE Candidate__c = :candidateId AND Name = :name LIMIT 1
                        ];
                        if (!dups.isEmpty() && (String.isBlank(excludeId) || dups[0].Id != excludeId))
                            dupMessage = 'Clinical Skill "' + name + '" already exists.';
                    }
                }

                when 'technicalSkill' {
                    String name = getStr(fields, 'Name');
                    if (String.isNotBlank(name)) {
                        List<Technical_Skill__c> dups = [
                            SELECT Id FROM Technical_Skill__c
                            WHERE Candidate__c = :candidateId AND Name = :name LIMIT 1
                        ];
                        if (!dups.isEmpty() && (String.isBlank(excludeId) || dups[0].Id != excludeId))
                            dupMessage = 'Technical Skill "' + name + '" already exists.';
                    }
                }

                when 'procedure' {
                    String name = getStr(fields, 'Name');
                    if (String.isNotBlank(name)) {
                        List<Procedure__c> dups = [
                            SELECT Id FROM Procedure__c
                            WHERE Candidate__c = :candidateId AND Name = :name LIMIT 1
                        ];
                        if (!dups.isEmpty() && (String.isBlank(excludeId) || dups[0].Id != excludeId))
                            dupMessage = 'Procedure "' + name + '" already exists.';
                    }
                }

                when 'internship' {
                    String org = getStr(fields, 'Organization__c');
                    if (String.isNotBlank(org)) {
                        List<Internship__c> dups = [
                            SELECT Id FROM Internship__c
                            WHERE Candidate__c = :candidateId AND Organization__c = :org LIMIT 1
                        ];
                        if (!dups.isEmpty() && (String.isBlank(excludeId) || dups[0].Id != excludeId))
                            dupMessage = 'Internship at "' + org + '" already exists.';
                    }
                }

                when 'research' {
                    String title = getStr(fields, 'Title__c');
                    if (String.isNotBlank(title)) {
                        List<Research_Publication__c> dups = [
                            SELECT Id FROM Research_Publication__c
                            WHERE Candidate__c = :candidateId AND Title__c = :title LIMIT 1
                        ];
                        if (!dups.isEmpty() && (String.isBlank(excludeId) || dups[0].Id != excludeId))
                            dupMessage = 'Publication/Research "' + title + '" already exists.';
                    }
                }

                when 'membership' {
                    String org = getStr(fields, 'Organization_Name__c');
                    if (String.isNotBlank(org)) {
                        List<Membership__c> dups = [
                            SELECT Id FROM Membership__c
                            WHERE Candidate__c = :candidateId AND Organization_Name__c = :org LIMIT 1
                        ];
                        if (!dups.isEmpty() && (String.isBlank(excludeId) || dups[0].Id != excludeId))
                            dupMessage = 'Membership for "' + org + '" already exists.';
                    }
                }
            }

            return dupMessage;

        } catch (Exception e) {
            System.debug('checkDuplicate error: ' + e.getMessage());
            return null;
        }
    }

    private static String getStr(Map<String, Object> fields, String key) {
        Object val = fields.get(key);
        return val != null ? String.valueOf(val).trim() : '';
    }
}