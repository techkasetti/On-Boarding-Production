public with sharing class ClinicalAssessmentController {
    public class AssessmentRecordWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Date assessmentDate;
        @AuraEnabled public String assessmentType;
        @AuraEnabled public String assessorNotes;
        @AuraEnabled public Decimal attemptNumber;
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String department;
        @AuraEnabled public String roleType;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime submittedDate;
        @AuraEnabled public String uploadedFileIds;
        @AuraEnabled public Id jobApplicationId;
    }

    public class AssessmentContextWrapper {
        @AuraEnabled public Id applicationId;
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String department;
        @AuraEnabled public String roleType;
    }

    public class AssessmentFileWrapper {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileType;
        @AuraEnabled public Datetime lastModifiedDate;
        @AuraEnabled public String viewUrl;
    }

    @AuraEnabled(cacheable=true)
    public static List<AssessmentRecordWrapper> getAssessments(Id candidateId, Id applicationId) {
        try {
            if (candidateId == null && applicationId == null) {
                throw new AuraHandledException('candidateId or applicationId is required.');
            }

            if (!Schema.sObjectType.Clinical_Assessment__c.isAccessible()) {
                throw new AuraHandledException('You do not have access to Clinical Assessment records.');
            }

            List<Clinical_Assessment__c> rows;
            if (applicationId != null) {
                rows = [
                    SELECT
                        Id,
                        Name,
                        Assessment_Date__c,
                        Assessment_Type__c,
                        Assessor_Notes__c,
                        Attempt_Number__c,
                        Candidate__c,
                        Job_Application__c,
                        Department__c,
                        Role_Type__c,
                        Status__c,
                        Submitted_Date__c,
                        Uploaded_File_Ids__c
                    FROM Clinical_Assessment__c
                    WHERE Job_Application__c = :applicationId
                    ORDER BY Assessment_Date__c DESC, Submitted_Date__c DESC
                ];
            } else {
                rows = [
                    SELECT
                        Id,
                        Name,
                        Assessment_Date__c,
                        Assessment_Type__c,
                        Assessor_Notes__c,
                        Attempt_Number__c,
                        Candidate__c,
                        Job_Application__c,
                        Department__c,
                        Role_Type__c,
                        Status__c,
                        Submitted_Date__c,
                        Uploaded_File_Ids__c
                    FROM Clinical_Assessment__c
                    WHERE Candidate__c = :candidateId
                    ORDER BY Assessment_Date__c DESC, Submitted_Date__c DESC
                ];
            }

            SObjectAccessDecision accessDecision =
                Security.stripInaccessible(System.AccessType.READABLE, rows);
            List<Clinical_Assessment__c> sanitizedRows =
                (List<Clinical_Assessment__c>) accessDecision.getRecords();

            List<AssessmentRecordWrapper> response = new List<AssessmentRecordWrapper>();
            for (Clinical_Assessment__c row : sanitizedRows) {
                response.add(toWrapper(row));
            }
            return response;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load clinical assessments: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static AssessmentRecordWrapper saveAssessment(String recordWrapperJson) {
        try {
            AssessmentRecordWrapper recordWrapper = parseWrapper(recordWrapperJson);
            if (recordWrapper == null) {
                throw new AuraHandledException('Assessment payload is required.');
            }
            Boolean isUpdate = recordWrapper.id != null;
            if (isUpdate && !Schema.sObjectType.Clinical_Assessment__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update assessments.');
            }
            if (!isUpdate && !Schema.sObjectType.Clinical_Assessment__c.isCreateable()) {
                throw new AuraHandledException('You do not have permission to create assessments.');
            }
            Clinical_Assessment__c assessmentRecord;
            if (isUpdate) {
                List<Clinical_Assessment__c> existing = [
                    SELECT
                        Id,
                        Candidate__c,
                        Job_Application__c,
                        Assessment_Date__c,
                        Assessment_Type__c,
                        Assessor_Notes__c,
                        Attempt_Number__c,
                        Department__c,
                        Role_Type__c,
                        Status__c,
                        Submitted_Date__c,
                        Uploaded_File_Ids__c
                    FROM Clinical_Assessment__c
                    WHERE Id = :recordWrapper.id
                    LIMIT 1
                ];

                if (existing.isEmpty()) {
                    throw new AuraHandledException('Assessment not found or inaccessible.');
                }
                assessmentRecord = existing[0];
                if (recordWrapper.candidateId == null) {
                    recordWrapper.candidateId = assessmentRecord.Candidate__c;
                }
                if (recordWrapper.jobApplicationId == null) {
                    recordWrapper.jobApplicationId = assessmentRecord.Job_Application__c;
                }
            } else {
                if (recordWrapper.jobApplicationId == null && recordWrapper.candidateId == null) {
                    throw new AuraHandledException('Job Application Id or Candidate Id is required.');
                }
                assessmentRecord = new Clinical_Assessment__c();
            }

            if (!isUpdate && recordWrapper.jobApplicationId != null) {
                AssessmentContextWrapper ctx = getAssessmentContext(recordWrapper.jobApplicationId);
                if (ctx != null) {
                    if (ctx.candidateId != null) {
                        recordWrapper.candidateId = ctx.candidateId;
                    }
                    recordWrapper.department = ctx.department;
                    recordWrapper.roleType = ctx.roleType;
                }
            }

            assessmentRecord.Candidate__c = recordWrapper.candidateId;
            assessmentRecord.Job_Application__c = recordWrapper.jobApplicationId;
            assessmentRecord.Assessment_Date__c = recordWrapper.assessmentDate;
            assessmentRecord.Assessment_Type__c = recordWrapper.assessmentType;
            assessmentRecord.Assessor_Notes__c = recordWrapper.assessorNotes;
            assessmentRecord.Attempt_Number__c = recordWrapper.attemptNumber;
            assessmentRecord.Department__c = recordWrapper.department;
            assessmentRecord.Role_Type__c = recordWrapper.roleType;
            assessmentRecord.Status__c = recordWrapper.status;
            assessmentRecord.Uploaded_File_Ids__c = recordWrapper.uploadedFileIds;

            if (isUpdate) {
                if (recordWrapper.submittedDate != null) {
                    assessmentRecord.Submitted_Date__c = recordWrapper.submittedDate;
                }
            } else {
                assessmentRecord.Submitted_Date__c =
                    (recordWrapper.submittedDate != null) ? recordWrapper.submittedDate : System.now();
            }

            System.AccessType sanitizeAccessType =
                isUpdate ? System.AccessType.UPDATABLE : System.AccessType.CREATABLE;
            List<SObject> toSanitize = new List<SObject>{ assessmentRecord };
            SObjectAccessDecision writeDecision =
                Security.stripInaccessible(sanitizeAccessType, toSanitize);
            List<Clinical_Assessment__c> sanitized =
                (List<Clinical_Assessment__c>) writeDecision.getRecords();

            if (sanitized.isEmpty()) {
                throw new AuraHandledException('No writable fields provided for this assessment.');
            }

            Clinical_Assessment__c writableRecord = sanitized[0];
            if (isUpdate) {
                update writableRecord;
            } else {
                insert writableRecord;
            }

            List<Clinical_Assessment__c> savedRows = [
                SELECT
                    Id,
                    Name,
                    Assessment_Date__c,
                    Assessment_Type__c,
                    Assessor_Notes__c,
                    Attempt_Number__c,
                    Candidate__c,
                    Job_Application__c,
                    Department__c,
                    Role_Type__c,
                    Status__c,
                    Submitted_Date__c,
                    Uploaded_File_Ids__c
                FROM Clinical_Assessment__c
                WHERE Id = :writableRecord.Id
                LIMIT 1
            ];

            if (savedRows.isEmpty()) {
                throw new AuraHandledException('Assessment saved but could not be reloaded.');
            }

            SObjectAccessDecision postReadDecision =
                Security.stripInaccessible(System.AccessType.READABLE, savedRows);
            List<Clinical_Assessment__c> postReadRows =
                (List<Clinical_Assessment__c>) postReadDecision.getRecords();

            if (postReadRows.isEmpty()) {
                throw new AuraHandledException('Assessment saved but cannot be displayed due to access.');
            }

            return toWrapper(postReadRows[0]);
        } catch (DmlException e) {
            throw new AuraHandledException('Unable to save clinical assessment: ' + e.getDmlMessage(0));
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected error while saving clinical assessment: ' + e.getMessage());
        }
    }

    private static AssessmentRecordWrapper toWrapper(Clinical_Assessment__c row) {
        Map<String, Object> values = row.getPopulatedFieldsAsMap();
        AssessmentRecordWrapper wrapper = new AssessmentRecordWrapper();
        wrapper.id = (Id) values.get('Id');
        wrapper.name = (String) values.get('Name');
        wrapper.assessmentDate = (Date) values.get('Assessment_Date__c');
        wrapper.assessmentType = (String) values.get('Assessment_Type__c');
        wrapper.assessorNotes = (String) values.get('Assessor_Notes__c');
        wrapper.attemptNumber = (Decimal) values.get('Attempt_Number__c');
        wrapper.candidateId = (Id) values.get('Candidate__c');
        wrapper.jobApplicationId = (Id) values.get('Job_Application__c');
        wrapper.department = (String) values.get('Department__c');
        wrapper.roleType = (String) values.get('Role_Type__c');
        wrapper.status = (String) values.get('Status__c');
        wrapper.submittedDate = (Datetime) values.get('Submitted_Date__c');
        wrapper.uploadedFileIds = (String) values.get('Uploaded_File_Ids__c');
        return wrapper;
    }

    private static AssessmentRecordWrapper parseWrapper(String recordWrapperJson) {
        if (String.isBlank(recordWrapperJson)) {
            return null;
        }

        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(recordWrapperJson);
        AssessmentRecordWrapper wrapper = new AssessmentRecordWrapper();
        wrapper.id = parseId(data.get('id'));
        wrapper.name = (String) data.get('name');
        wrapper.assessmentDate = parseDate(data.get('assessmentDate'));
        wrapper.assessmentType = (String) data.get('assessmentType');
        wrapper.assessorNotes = (String) data.get('assessorNotes');
        wrapper.attemptNumber = parseDecimal(data.get('attemptNumber'));
        wrapper.candidateId = parseId(data.get('candidateId'));
        wrapper.jobApplicationId = parseId(data.get('jobApplicationId'));
        wrapper.department = (String) data.get('department');
        wrapper.roleType = (String) data.get('roleType');
        wrapper.status = (String) data.get('status');
        wrapper.submittedDate = parseDatetime(data.get('submittedDate'));
        wrapper.uploadedFileIds = (String) data.get('uploadedFileIds');
        return wrapper;
    }

    @AuraEnabled
    public static void appendAssessmentFileIds(Id assessmentId, List<Id> contentDocumentIds) {
        try {
            if (assessmentId == null) {
                throw new AuraHandledException('assessmentId is required.');
            }
            if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
                return;
            }
            if (!Schema.sObjectType.Clinical_Assessment__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update assessments.');
            }

            List<Clinical_Assessment__c> rows = [
                SELECT Id, Uploaded_File_Ids__c
                FROM Clinical_Assessment__c
                WHERE Id = :assessmentId
                LIMIT 1
            ];
            if (rows.isEmpty()) {
                throw new AuraHandledException('Assessment not found or inaccessible.');
            }

            Clinical_Assessment__c row = rows[0];
            Set<String> mergedIds = new Set<String>();

            if (!String.isBlank(row.Uploaded_File_Ids__c)) {
                for (String existingId : row.Uploaded_File_Ids__c.split(',')) {
                    if (!String.isBlank(existingId)) {
                        mergedIds.add(existingId.trim());
                    }
                }
            }

            for (Id fileId : contentDocumentIds) {
                if (fileId != null) {
                    mergedIds.add(String.valueOf(fileId));
                }
            }

            row.Uploaded_File_Ids__c = String.join(new List<String>(mergedIds), ',');

            List<SObject> candidateWrites = new List<SObject>{ row };
            SObjectAccessDecision writeDecision =
                Security.stripInaccessible(System.AccessType.UPDATABLE, candidateWrites);
            List<Clinical_Assessment__c> writableRows =
                (List<Clinical_Assessment__c>) writeDecision.getRecords();

            if (writableRows.isEmpty()) {
                throw new AuraHandledException('No writable fields for file tracking.');
            }

            update writableRows[0];
        } catch (DmlException e) {
            throw new AuraHandledException('Unable to persist uploaded files: ' + e.getDmlMessage(0));
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Unexpected error while updating uploaded files: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<AssessmentFileWrapper> getAssessmentFiles(Id assessmentId) {
        try {
            if (assessmentId == null) {
                throw new AuraHandledException('assessmentId is required.');
            }

            if (!Schema.sObjectType.ContentDocumentLink.isAccessible()) {
                throw new AuraHandledException('You do not have access to linked files.');
            }

            List<ContentDocumentLink> links = [
                SELECT
                    ContentDocumentId,
                    ContentDocument.Title,
                    ContentDocument.FileType,
                    ContentDocument.LastModifiedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :assessmentId
                ORDER BY ContentDocument.LastModifiedDate DESC
            ];

            List<AssessmentFileWrapper> response = new List<AssessmentFileWrapper>();
            for (ContentDocumentLink linkRow : links) {
                AssessmentFileWrapper row = new AssessmentFileWrapper();
                row.contentDocumentId = linkRow.ContentDocumentId;
                row.title = linkRow.ContentDocument.Title;
                row.fileType = linkRow.ContentDocument.FileType;
                row.lastModifiedDate = linkRow.ContentDocument.LastModifiedDate;
                row.viewUrl = '/lightning/r/ContentDocument/' + String.valueOf(linkRow.ContentDocumentId) + '/view';
                response.add(row);
            }
            return response;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load assessment files: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static AssessmentContextWrapper getAssessmentContext(Id applicationId) {
        try {
            if (applicationId == null) {
                throw new AuraHandledException('applicationId is required.');
            }
            if (!Schema.sObjectType.Job_Application__c.isAccessible()) {
                throw new AuraHandledException('You do not have access to Job Application.');
            }

            List<Job_Application__c> appRows = [
                SELECT Id, Candidate__c, Job_Posting__r.Department__c, Job_Posting__r.Role_Type__c
                FROM Job_Application__c
                WHERE Id = :applicationId
                LIMIT 1
            ];
            if (appRows.isEmpty()) {
                throw new AuraHandledException('Job Application not found or inaccessible.');
            }

            Job_Application__c app = appRows[0];
            AssessmentContextWrapper ctx = new AssessmentContextWrapper();
            ctx.applicationId = app.Id;
            ctx.candidateId = app.Candidate__c;
            ctx.department = app.Job_Posting__r != null ? app.Job_Posting__r.Department__c : null;
            ctx.roleType = app.Job_Posting__r != null ? app.Job_Posting__r.Role_Type__c : null;
            return ctx;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to load assessment context: ' + e.getMessage());
        }
    }

    private static Id parseId(Object value) {
        if (value == null) {
            return null;
        }
        String idValue = String.valueOf(value);
        return String.isBlank(idValue) ? null : (Id) idValue;
    }

    private static Decimal parseDecimal(Object value) {
        if (value == null) {
            return null;
        }
        String numberValue = String.valueOf(value);
        return String.isBlank(numberValue) ? null : Decimal.valueOf(numberValue);
    }

    private static Date parseDate(Object value) {
        if (value == null) {
            return null;
        }
        String dateValue = String.valueOf(value);
        if (String.isBlank(dateValue)) {
            return null;
        }
        String normalized = dateValue.contains('T') ? dateValue.substring(0, 10) : dateValue;
        return Date.valueOf(normalized);
    }

    private static Datetime parseDatetime(Object value) {
        if (value == null) {
            return null;
        }
        String dtValue = String.valueOf(value);
        if (String.isBlank(dtValue)) {
            return null;
        }
        return (Datetime) JSON.deserialize('"' + dtValue + '"', Datetime.class);
    }
}