/**
 * @description Apex controller for Medical Recruitment Dashboard
 * @author Salesforce Architect
 * @date 2026
 */
public with sharing class MedicalRecruitmentController {
    
    /**
     * @description Fetches all active job postings with key details
     * @param searchKey Optional search term for job title filtering
     * @return List of Job Posting records
     */
    @AuraEnabled(cacheable=true)
    public static List<Job_Posting__c> getJobPostings(String searchKey) {
        try {
            String query = 'SELECT Id, Name, Job_Title__c, Location__c, Department__c, ' +
                          'Role_Type__c, Employment_Type__c, Number_of_Positions__c, ' +
                          'Start_Date__c, End_Date__c, Specialization__c, Experience_Level__c ' +
                          'FROM Job_Posting__c ';
            
            if (String.isNotBlank(searchKey)) {
                String searchPattern = '%' + String.escapeSingleQuotes(searchKey) + '%';
                query += 'WHERE Job_Title__c LIKE :searchPattern OR Name LIKE :searchPattern ';
            }
            
            query += 'ORDER BY CreatedDate DESC LIMIT 1000';
            
            return Database.query(query);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching job postings: ' + e.getMessage());
        }
    }
    
    /**
     * @description Fetches all applications for a specific job posting
     * @param jobPostingId The Job Posting record ID
     * @return List of Job Application records with candidate details
     */
    @AuraEnabled(cacheable=true)
    public static List<ApplicationWrapper> getJobApplications(Id jobPostingId) {
        try {
            if (jobPostingId == null) {
                throw new AuraHandledException('Job Posting ID is required');
            }
            
            List<Job_Application__c> applications = [
                SELECT Id, Name, Status__c, Application_Date__c, 
                       Eligibility_Score__c, Screening_Score__c, Screening_Result__c,
                       Candidate__c, Candidate__r.Name, Candidate__r.Full_Name__c,
                       Candidate__r.Email__c, Candidate__r.Phone__c, 
                       Candidate__r.Role__c, Candidate__r.Specialty__c,
                       Candidate__r.Years_of_Experience__c, Candidate__r.Status__c,
                       Job_Posting__c, Job_Posting__r.Job_Title__c
                FROM Job_Application__c
                WHERE Job_Posting__c = :jobPostingId
                ORDER BY Application_Date__c DESC
            ];
            
            List<ApplicationWrapper> wrappers = new List<ApplicationWrapper>();
            for (Job_Application__c app : applications) {
                wrappers.add(new ApplicationWrapper(app));
            }
            
            return wrappers;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching applications: ' + e.getMessage());
        }
    }
    
    /**
     * @description Fetches detailed candidate information for a specific application
     * @param applicationId The Job Application record ID
     * @return Detailed candidate wrapper with all related data
     */
    @AuraEnabled
    public static CandidateDetailWrapper getCandidateDetails(Id applicationId) {
        try {
            if (applicationId == null) {
                throw new AuraHandledException('Application ID is required');
            }
            
            Job_Application__c application = [
                SELECT Id, Name, Status__c, Application_Date__c, Applied_From__c,
                       Eligibility_Score__c, Eligibility_Summary__c, 
                       Eligibility_Pros__c, Eligibility_Cons__c,
                       Screening_Score__c, Screening_Result__c, Auto_Routed__c,
                       Candidate__c, Candidate__r.Name, Candidate__r.Full_Name__c,
                       Candidate__r.Email__c, Candidate__r.Phone__c,
                       Candidate__r.Role__c, Candidate__r.Specialty__c, Candidate__r.Gender__c,
                       Candidate__r.Date_of_Birth__c, Candidate__r.Nationality__c,
                       Candidate__r.Years_of_Experience__c, Candidate__r.Status__c,
                       Candidate__r.Street_Address__c, Candidate__r.City__c, 
                       Candidate__r.State__c, Candidate__r.Location__c,
                       Candidate__r.Skills__c, Candidate__r.Pass_Rate__c,
                       Job_Posting__c, Job_Posting__r.Name, Job_Posting__r.Job_Title__c,
                       Job_Posting__r.Department__c, Job_Posting__r.Location__c
                FROM Job_Application__c
                WHERE Id = :applicationId
                LIMIT 1
            ];
            
            // Fetch related records
            List<Education__c> educations = [
                SELECT Id, Name, Degree__c, Institution__c, Field_of_Study__c,
                       Start_Year__c, End_Year__c, Education_Level__c, Verified__c
                FROM Education__c
                WHERE Candidate__c = :application.Candidate__c
                ORDER BY End_Year__c DESC NULLS LAST
                LIMIT 10
            ];
            
            List<License_Certification__c> licenses = [
                SELECT Id, Name, License_Number__c, Type__c, Issuing_Authority__c,
                       Issue_Date__c, Expiry_Date__c, Verification_Status__c
                FROM License_Certification__c
                WHERE Candidate__c = :application.Candidate__c
                ORDER BY Issue_Date__c DESC NULLS LAST
                LIMIT 10
            ];
            
            List<Work_Experience__c> experiences = [
                SELECT Id, Name, Role__c, Organization__c, Department__c,
                       Start_Date__c, End_Date__c, Is_Current__c, Clinical_Role__c
                FROM Work_Experience__c
                WHERE Candidate__c = :application.Candidate__c
                ORDER BY Start_Date__c DESC NULLS LAST
                LIMIT 10
            ];
            
            List<Clinical_Skill__c> clinicalSkills = [
                SELECT Id, Name, Proficiency_Level__c, Skill_Category__c, 
                       Verified__c, Last_Verified_Date__c
                FROM Clinical_Skill__c
                WHERE Candidate__c = :application.Candidate__c
                ORDER BY Proficiency_Level__c DESC
                LIMIT 20
            ];
            
            return new CandidateDetailWrapper(
                application, educations, licenses, experiences, clinicalSkills
            );
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching candidate details: ' + e.getMessage());
        }
    }
    
    /**
     * @description Updates application status with stage comments
     * @param applicationId The Job Application record ID
     * @param newStatus The new status value
     * @param comments Optional stage comments
     * @return Updated Job Application record
     */
    @AuraEnabled
    public static Job_Application__c updateApplicationStatus(
        Id applicationId, 
        String newStatus, 
        String comments
    ) {
        try {
            if (applicationId == null || String.isBlank(newStatus)) {
                throw new AuraHandledException('Application ID and Status are required');
            }
            
            Job_Application__c application = [
                SELECT Id, Status__c
                FROM Job_Application__c
                WHERE Id = :applicationId
                LIMIT 1
            ];
            
            application.Status__c = newStatus;
            
            update application;
            
            // Return refreshed record with all details
            return [
                SELECT Id, Name, Status__c, Application_Date__c,
                       Candidate__r.Full_Name__c, Job_Posting__r.Job_Title__c
                FROM Job_Application__c
                WHERE Id = :applicationId
                LIMIT 1
            ];
            
        } catch (Exception e) {
            throw new AuraHandledException('Error updating application: ' + e.getMessage());
        }
    }

    // ─── LICENSE VERIFICATION ────────────────────────────────────────────────

    /**
     * @description Get License Verification records for a candidate
     */
    @AuraEnabled(cacheable=false)
    public static List<LicenseVerification__c> getLicenseVerifications(Id candidateId) {
        try {
            return [
                SELECT Id, Name, 
                       LicenseNumber__c, 
                       IssuingAuthority__c, 
                       ExpirationDate__c,
                       Provider__c,
                       Provider__r.Name,
                       Status__c,
                       Name_Match_AI_Decision__c,
                       Name_Match_AI_Score__c,
                       Name_Match_AI_Reason__c,
                       Name_On_License__c,
                       Requires_Manual_Review__c,
                       Candidate__c
                FROM LicenseVerification__c
                WHERE Candidate__c = :candidateId
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching license verifications: ' + e.getMessage());
        }
    }

    /**
     * @description Update a License Verification record with proper type casting
     */
    @AuraEnabled
    public static void updateLicenseVerification(Id licenseId, Map<String, Object> fieldValues) {
        try {
            LicenseVerification__c license = new LicenseVerification__c(Id = licenseId);

            Map<String, Schema.SObjectField> fieldMap =
                Schema.SObjectType.LicenseVerification__c.fields.getMap();

            for (String fieldName : fieldValues.keySet()) {
                if (!fieldMap.containsKey(fieldName)) continue;

                Object value = fieldValues.get(fieldName);
                if (value == null) continue;

                Schema.DescribeFieldResult d = fieldMap.get(fieldName).getDescribe();
                Schema.DisplayType dtype = d.getType();
                String stringVal = String.valueOf(value);

                if (dtype == Schema.DisplayType.Date) {
                    // Accept 'YYYY-MM-DD' — strip any time component just in case
                    license.put(fieldName, Date.valueOf(stringVal.split('T')[0]));
                } else if (dtype == Schema.DisplayType.DateTime) {
                    license.put(fieldName, Datetime.valueOf(stringVal));
                } else if (dtype == Schema.DisplayType.Boolean) {
                    license.put(fieldName, Boolean.valueOf(stringVal));
                } else if (dtype == Schema.DisplayType.Currency ||
                           dtype == Schema.DisplayType.Double ||
                           dtype == Schema.DisplayType.Percent) {
                    license.put(fieldName, Decimal.valueOf(stringVal));
                } else if (dtype == Schema.DisplayType.Integer) {
                    license.put(fieldName, Integer.valueOf(stringVal));
                } else {
                    // Text, Picklist, Lookup (Reference), etc.
                    license.put(fieldName, value);
                }
            }

            update license;

        } catch (Exception e) {
            throw new AuraHandledException('Error updating license verification: ' + e.getMessage());
        }
    }

    /**
     * @description Create a new License Verification record with proper type casting
     */
    @AuraEnabled
    public static Id createLicenseVerification(Id candidateId, Map<String, Object> fieldValues) {
        try {
            LicenseVerification__c license = new LicenseVerification__c(
                Candidate__c = candidateId
            );

            Map<String, Schema.SObjectField> fieldMap =
                Schema.SObjectType.LicenseVerification__c.fields.getMap();

            for (String fieldName : fieldValues.keySet()) {
                if (!fieldMap.containsKey(fieldName)) continue;

                Object value = fieldValues.get(fieldName);
                if (value == null) continue;

                Schema.DescribeFieldResult d = fieldMap.get(fieldName).getDescribe();
                Schema.DisplayType dtype = d.getType();
                String stringVal = String.valueOf(value);

                if (dtype == Schema.DisplayType.Date) {
                    license.put(fieldName, Date.valueOf(stringVal.split('T')[0]));
                } else if (dtype == Schema.DisplayType.DateTime) {
                    license.put(fieldName, Datetime.valueOf(stringVal));
                } else if (dtype == Schema.DisplayType.Boolean) {
                    license.put(fieldName, Boolean.valueOf(stringVal));
                } else if (dtype == Schema.DisplayType.Currency ||
                           dtype == Schema.DisplayType.Double ||
                           dtype == Schema.DisplayType.Percent) {
                    license.put(fieldName, Decimal.valueOf(stringVal));
                } else if (dtype == Schema.DisplayType.Integer) {
                    license.put(fieldName, Integer.valueOf(stringVal));
                } else {
                    license.put(fieldName, value);
                }
            }

            insert license;
            return license.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Error creating license verification: ' + e.getMessage());
        }
    }

    // ─── CONTACTS LOOKUP ─────────────────────────────────────────────────────

    /**
     * @description Returns active Contacts as label/value pairs for Provider__c lookup
     * Adjust the WHERE clause to match whichever Contact subset you need
     * (e.g. filter by RecordType, Account, or a custom field).
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getContacts() {
        try {
            List<Map<String, String>> options = new List<Map<String, String>>();

            List<Contact> contacts = [
                SELECT Id, Name
                FROM Contact
                ORDER BY Name ASC
                LIMIT 500
            ];

            for (Contact c : contacts) {
                options.add(new Map<String, String>{
                    'label' => c.Name,
                    'value' => c.Id
                });
            }

            return options;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching contacts: ' + e.getMessage());
        }
    }

    // ─── INTERVIEW DETAIL ────────────────────────────────────────────────────

    /**
     * @description Get Interview Detail records for a candidate
     */
    @AuraEnabled(cacheable=false)
    public static List<Interview_Detail__c> getInterviewDetails(Id candidateId) {
        try {
            return [
                SELECT Id, Name,
                       External_Interviewer_Name__c,
                       External_Interviewer_Email__c,
                       Interviewer_User__c,
                       Interviewer_User__r.Name,
                       Interviewer_Type__c,
                       Meeting_Type__c,
                       Meeting_Link__c,
                       Interview_Date__c,
                       Interview_Time__c,
                       Feedback__c,
                       Job_Application__c,
                       Candidate__c
                FROM Interview_Detail__c
                WHERE Candidate__c = :candidateId
                ORDER BY CreatedDate DESC
                LIMIT 10
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching interview details: ' + e.getMessage());
        }
    }

    /**
     * @description Update an Interview Detail record with proper type casting
     */
    @AuraEnabled
    public static void updateInterviewDetail(Id interviewId, Map<String, Object> fieldValues) {
        try {
            System.debug('Incoming fieldValues: ' + fieldValues);

            Interview_Detail__c interview = new Interview_Detail__c(Id = interviewId);

            Map<String, Schema.SObjectField> fieldMap =
                Schema.SObjectType.Interview_Detail__c.fields.getMap();

            for (String fieldName : fieldValues.keySet()) {
                if (!fieldMap.containsKey(fieldName)) continue;

                Object value = fieldValues.get(fieldName);
                if (value == null) continue;

                Schema.DescribeFieldResult d = fieldMap.get(fieldName).getDescribe();
                Schema.DisplayType dtype = d.getType();
                String stringVal = String.valueOf(value);

                if (dtype == Schema.DisplayType.Date) {
                    interview.put(fieldName, Date.valueOf(stringVal.split('T')[0]));
                } else if (dtype == Schema.DisplayType.DateTime) {
                    interview.put(fieldName, Datetime.valueOf(stringVal));
                } else if (dtype == Schema.DisplayType.Time) {
                    // Handles '09:30', '09:30:00', or '09:30:00.000'
                    String t = stringVal.contains('.') ? stringVal.substringBefore('.') : stringVal;
                    List<String> parts = t.split(':');
                    Integer hh = Integer.valueOf(parts[0]);
                    Integer mm = Integer.valueOf(parts[1]);
                    Integer ss = parts.size() > 2 ? Integer.valueOf(parts[2]) : 0;
                    interview.put(fieldName, Time.newInstance(hh, mm, ss, 0));
                } else if (dtype == Schema.DisplayType.Boolean) {
                    interview.put(fieldName, Boolean.valueOf(stringVal));
                } else if (dtype == Schema.DisplayType.Currency ||
                           dtype == Schema.DisplayType.Double ||
                           dtype == Schema.DisplayType.Percent) {
                    interview.put(fieldName, Decimal.valueOf(stringVal));
                } else if (dtype == Schema.DisplayType.Integer) {
                    interview.put(fieldName, Integer.valueOf(stringVal));
                } else {
                    interview.put(fieldName, value);
                }
            }

            update interview;

        } catch (Exception e) {
            throw new AuraHandledException('Error updating interview detail: ' + e.getMessage());
        }
    }

    /**
     * @description Create a new Interview Detail record with proper type casting
     */
    @AuraEnabled
    public static Id createInterviewDetail(Id candidateId, Id applicationId, Map<String, Object> fieldValues) {
        try {
            Interview_Detail__c interview = new Interview_Detail__c(
                Candidate__c = candidateId,
                Job_Application__c = applicationId
            );

            Map<String, Schema.SObjectField> fieldMap =
                Schema.SObjectType.Interview_Detail__c.fields.getMap();

            for (String fieldName : fieldValues.keySet()) {
                if (!fieldMap.containsKey(fieldName)) continue;

                Object value = fieldValues.get(fieldName);
                if (value == null) continue;

                Schema.DescribeFieldResult d = fieldMap.get(fieldName).getDescribe();
                Schema.DisplayType dtype = d.getType();
                String stringVal = String.valueOf(value);

                if (dtype == Schema.DisplayType.Date) {
                    interview.put(fieldName, Date.valueOf(stringVal.split('T')[0]));
                } else if (dtype == Schema.DisplayType.DateTime) {
                    interview.put(fieldName, Datetime.valueOf(stringVal));
                } else if (dtype == Schema.DisplayType.Time) {
                    String t = stringVal.contains('.') ? stringVal.substringBefore('.') : stringVal;
                    List<String> parts = t.split(':');
                    Integer hh = Integer.valueOf(parts[0]);
                    Integer mm = Integer.valueOf(parts[1]);
                    Integer ss = parts.size() > 2 ? Integer.valueOf(parts[2]) : 0;
                    interview.put(fieldName, Time.newInstance(hh, mm, ss, 0));
                } else if (dtype == Schema.DisplayType.Boolean) {
                    interview.put(fieldName, Boolean.valueOf(stringVal));
                } else if (dtype == Schema.DisplayType.Currency ||
                           dtype == Schema.DisplayType.Double ||
                           dtype == Schema.DisplayType.Percent) {
                    interview.put(fieldName, Decimal.valueOf(stringVal));
                } else if (dtype == Schema.DisplayType.Integer) {
                    interview.put(fieldName, Integer.valueOf(stringVal));
                } else {
                    interview.put(fieldName, value);
                }
            }

            insert interview;
            return interview.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Error creating interview detail: ' + e.getMessage());
        }
    }

    // ─── USERS ───────────────────────────────────────────────────────────────

    /**
     * @description Returns active Users as label/value pairs
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getActiveUsers() {
        try {
            List<Map<String, String>> userOptions = new List<Map<String, String>>();
            
            List<User> activeUsers = [
                SELECT Id, Name
                FROM User
                WHERE IsActive = true
                ORDER BY Name
                LIMIT 200
            ];
            
            for (User u : activeUsers) {
                userOptions.add(new Map<String, String>{
                    'label' => u.Name,
                    'value' => u.Id
                });
            }
            
            return userOptions;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching active users: ' + e.getMessage());
        }
    }

    // ─── EMAIL HELPERS ───────────────────────────────────────────────────────

    /**
     * @description Send interview scheduling emails to candidate and interviewer
     */
    @AuraEnabled
    public static void sendInterviewEmails(
        Id applicationId,
        String interviewerType,
        Id interviewerUserId,
        String externalInterviewerEmail,
        String meetingType,
        String meetingLink,
        String zoomStartUrl
    ) {
        try {
            Job_Application__c application = [
                SELECT Id, 
                       Candidate__c,
                       Candidate__r.Full_Name__c,
                       Candidate__r.Email__c,
                       Job_Posting__r.Job_Title__c,
                       Job_Posting__r.Department__c,
                       Job_Posting__r.Location__c
                FROM Job_Application__c
                WHERE Id = :applicationId
                LIMIT 1
            ];
            
            String candidateName = application.Candidate__r.Full_Name__c;
            String candidateEmail = application.Candidate__r.Email__c;
            String jobTitle = application.Job_Posting__r.Job_Title__c;
            String department = application.Job_Posting__r.Department__c;
            String location = application.Job_Posting__r.Location__c;
            
            String interviewerName = '';
            String interviewerEmail = '';
            
            if (interviewerType == 'User' && interviewerUserId != null) {
                User interviewer = [SELECT Name, Email FROM User WHERE Id = :interviewerUserId LIMIT 1];
                interviewerName = interviewer.Name;
                interviewerEmail = interviewer.Email;
            } else if (interviewerType == 'External') {
                interviewerName = 'External Interviewer';
                interviewerEmail = externalInterviewerEmail;
            }
            
            String meetingDetails = buildMeetingDetails(meetingType, meetingLink, location);
            
            sendCandidateEmail(candidateEmail, candidateName, jobTitle, department, interviewerName, meetingDetails);
            
            if (String.isNotBlank(interviewerEmail)) {
                sendInterviewerEmail(interviewerEmail, interviewerName, candidateName, application.Id, jobTitle, department, meetingDetails);
            }
            
            if (String.isNotBlank(zoomStartUrl) && meetingType == 'Virtual') {
                sendHostEmail('pavankumarpavan874@gmail.com', candidateName, jobTitle, zoomStartUrl, meetingLink);
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error sending interview emails: ' + e.getMessage());
        }
    }

    private static String buildMeetingDetails(String meetingType, String meetingLink, String location) {
        String details = '<p><strong>Meeting Type:</strong> ' + meetingType + '</p>';
        if (meetingType == 'Virtual' && String.isNotBlank(meetingLink)) {
            details += '<p><strong>Meeting Link:</strong> <a href="' + meetingLink + '">' + meetingLink + '</a></p>';
            details += '<p><em>Please click the link above to join the virtual interview at the scheduled time.</em></p>';
        } else if (meetingType == 'In-Person') {
            details += '<p><strong>Location:</strong> ' + location + '</p>';
            details += '<p><em>Please arrive 10 minutes early for check-in.</em></p>';
        } else if (meetingType == 'Phone') {
            details += '<p><em>You will receive a phone call at the scheduled time.</em></p>';
        }
        return details;
    }

    private static void sendCandidateEmail(
        String candidateEmail, String candidateName, String jobTitle,
        String department, String interviewerName, String meetingDetails
    ) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { candidateEmail });
        mail.setSubject('Interview Scheduled - ' + jobTitle);
        String htmlBody = '<html><body style="font-family: Arial, sans-serif;">';
        htmlBody += '<div style="max-width: 600px; margin: 0 auto; padding: 20px;">';
        htmlBody += '<h2 style="color: #635bff;">Interview Scheduled</h2>';
        htmlBody += '<p>Dear ' + candidateName + ',</p>';
        htmlBody += '<p>We are pleased to inform you that an interview has been scheduled for the position of <strong>' + jobTitle + '</strong>.</p>';
        htmlBody += '<div style="background: #f7f9fc; padding: 20px; border-radius: 8px; margin: 20px 0;">';
        htmlBody += '<h3 style="margin-top: 0; color: #1a1f36;">Interview Details</h3>';
        htmlBody += '<p><strong>Position:</strong> ' + jobTitle + '</p>';
        htmlBody += '<p><strong>Department:</strong> ' + department + '</p>';
        htmlBody += '<p><strong>Interviewer:</strong> ' + interviewerName + '</p>';
        htmlBody += meetingDetails;
        htmlBody += '</div>';
        htmlBody += '<p>Please confirm your availability by replying to this email.</p>';
        htmlBody += '<p>Best regards,<br/>Recruitment Team</p>';
        htmlBody += '</div></body></html>';
        mail.setHtmlBody(htmlBody);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }

    private static void sendInterviewerEmail(
        String interviewerEmail, String interviewerName, String candidateName,
        String applicationId, String jobTitle, String department, String meetingDetails
    ) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { interviewerEmail });
        mail.setSubject('Interview Assignment - ' + candidateName + ' for ' + jobTitle);
        String htmlBody = '<html><body style="font-family: Arial, sans-serif;">';
        htmlBody += '<div style="max-width: 600px; margin: 0 auto; padding: 20px;">';
        htmlBody += '<h2 style="color: #635bff;">Interview Assignment</h2>';
        htmlBody += '<p>Dear ' + interviewerName + ',</p>';
        htmlBody += '<p>You have been assigned to interview a candidate for the <strong>' + jobTitle + '</strong> position.</p>';
        htmlBody += '<div style="background: #f7f9fc; padding: 20px; border-radius: 8px; margin: 20px 0;">';
        htmlBody += '<h3 style="margin-top: 0; color: #1a1f36;">Interview Details</h3>';
        htmlBody += '<p><strong>Candidate:</strong> ' + candidateName + '</p>';
        htmlBody += '<p><strong>Position:</strong> ' + jobTitle + '</p>';
        htmlBody += '<p><strong>Department:</strong> ' + department + '</p>';
        htmlBody += meetingDetails;
        htmlBody += '</div>';
        htmlBody += '<p>Please review the candidate\'s profile before the interview.</p>';
        htmlBody += '<p>Best regards,<br/>Recruitment Team</p>';
        htmlBody += '</div></body></html>';
        mail.setHtmlBody(htmlBody);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }

    private static void sendHostEmail(
        String hostEmail, String candidateName, String jobTitle,
        String startUrl, String joinUrl
    ) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { hostEmail });
        mail.setSubject('Zoom Meeting Created - Interview with ' + candidateName);
        String htmlBody = '<html><body style="font-family: Arial, sans-serif;">';
        htmlBody += '<div style="max-width: 600px; margin: 0 auto; padding: 20px;">';
        htmlBody += '<h2 style="color: #635bff;">Zoom Meeting Created Successfully</h2>';
        htmlBody += '<p>A Zoom meeting has been scheduled for interviewing <strong>' + candidateName + '</strong> for the <strong>' + jobTitle + '</strong> position.</p>';
        htmlBody += '<div style="background: #f7f9fc; padding: 20px; border-radius: 8px; margin: 20px 0;">';
        htmlBody += '<h3 style="margin-top: 0; color: #1a1f36;">Your Meeting Links</h3>';
        htmlBody += '<p><strong>🎥 Start Meeting (Host):</strong><br/>';
        htmlBody += '<a href="' + startUrl + '" style="color: #635bff; word-break: break-all;">' + startUrl + '</a></p>';
        htmlBody += '<p style="margin-top: 15px;"><strong>🔗 Join URL (Share with others):</strong><br/>';
        htmlBody += '<a href="' + joinUrl + '" style="color: #635bff; word-break: break-all;">' + joinUrl + '</a></p>';
        htmlBody += '</div>';
        htmlBody += '<p><strong>Note:</strong> Use the <strong>Start Meeting</strong> link to begin the meeting as the host.</p>';
        htmlBody += '<p>Best regards,<br/>Recruitment System</p>';
        htmlBody += '</div></body></html>';
        mail.setHtmlBody(htmlBody);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }

    // ─── WRAPPER CLASSES ─────────────────────────────────────────────────────

    public class ApplicationWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Date applicationDate { get; set; }
        @AuraEnabled public String candidateName { get; set; }
        @AuraEnabled public String candidateEmail { get; set; }
        @AuraEnabled public String candidatePhone { get; set; }
        @AuraEnabled public String candidateRole { get; set; }
        @AuraEnabled public String candidateSpecialty { get; set; }
        @AuraEnabled public Decimal eligibilityScore { get; set; }
        @AuraEnabled public Decimal screeningScore { get; set; }
        @AuraEnabled public String screeningResult { get; set; }
        @AuraEnabled public Integer yearsExperience { get; set; }
        
        public ApplicationWrapper(Job_Application__c app) {
            this.id = app.Id;
            this.name = app.Name;
            this.status = app.Status__c;
            this.applicationDate = app.Application_Date__c;
            this.candidateName = app.Candidate__r.Full_Name__c != null ? 
                                 app.Candidate__r.Full_Name__c : app.Candidate__r.Name;
            this.candidateEmail = app.Candidate__r.Email__c;
            this.candidatePhone = app.Candidate__r.Phone__c;
            this.candidateRole = app.Candidate__r.Role__c;
            this.candidateSpecialty = app.Candidate__r.Specialty__c;
            this.eligibilityScore = app.Eligibility_Score__c;
            this.screeningScore = app.Screening_Score__c;
            this.screeningResult = app.Screening_Result__c;
            this.yearsExperience = app.Candidate__r.Years_of_Experience__c != null ? 
                                   Integer.valueOf(app.Candidate__r.Years_of_Experience__c) : 0;
        }
    }
    
    public class CandidateDetailWrapper {
        @AuraEnabled public Job_Application__c application { get; set; }
        @AuraEnabled public List<Education__c> educations { get; set; }
        @AuraEnabled public List<License_Certification__c> licenses { get; set; }
        @AuraEnabled public List<Work_Experience__c> experiences { get; set; }
        @AuraEnabled public List<Clinical_Skill__c> clinicalSkills { get; set; }
        
        public CandidateDetailWrapper(
            Job_Application__c app,
            List<Education__c> edus,
            List<License_Certification__c> lics,
            List<Work_Experience__c> exps,
            List<Clinical_Skill__c> skills
        ) {
            this.application = app;
            this.educations = edus;
            this.licenses = lics;
            this.experiences = exps;
            this.clinicalSkills = skills;
        }
    }
}