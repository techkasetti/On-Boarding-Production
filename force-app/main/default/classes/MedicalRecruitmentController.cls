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
    
    /**
     * @description Wrapper class for Job Application data
     */
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
    
    /**
     * @description Wrapper class for detailed candidate information
     */
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
 * Update License Verification record
 */
@AuraEnabled
public static void updateLicenseVerification(Id licenseId, Map<String, Object> fieldValues) {
    try {
        LicenseVerification__c license = new LicenseVerification__c(Id = licenseId);
        
        // Dynamically set field values
        for (String fieldName : fieldValues.keySet()) {
            Object value = fieldValues.get(fieldName);
            
            // Handle different data types
            if (value != null) {
                if (fieldName.endsWith('__c') || fieldName == 'Name') {
                    license.put(fieldName, value);
                }
            }
        }
        
        update license;
        
    } catch (Exception e) {
        throw new AuraHandledException('Error updating license verification: ' + e.getMessage());
    }
}

/**
 * Create new License Verification record
 */
@AuraEnabled
public static Id createLicenseVerification(Id candidateId, Map<String, Object> fieldValues) {
    try {
        LicenseVerification__c license = new LicenseVerification__c(
            Candidate__c = candidateId
        );
        
        // Dynamically set field values
        for (String fieldName : fieldValues.keySet()) {
            Object value = fieldValues.get(fieldName);
            if (value != null && fieldName.endsWith('__c')) {
                license.put(fieldName, value);
            }
        }
        
        insert license;
        return license.Id;
        
    } catch (Exception e) {
        throw new AuraHandledException('Error creating license verification: ' + e.getMessage());
    }
}


/**
 * Get Interview Detail records for a candidate
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
 * Update Interview Detail record
 */
@AuraEnabled
public static void updateInterviewDetail(Id interviewId, Map<String, Object> fieldValues) {
    try {
        Interview_Detail__c interview = new Interview_Detail__c(Id = interviewId);
        
        for (String fieldName : fieldValues.keySet()) {
            Object value = fieldValues.get(fieldName);
            if (value != null) {
                if (fieldName.endsWith('__c') || fieldName == 'Name') {
                    interview.put(fieldName, value);
                }
            }
        }
        
        update interview;
    } catch (Exception e) {
        throw new AuraHandledException('Error updating interview detail: ' + e.getMessage());
    }
}

/**
 * Create new Interview Detail record
 */
@AuraEnabled
public static Id createInterviewDetail(Id candidateId, Id applicationId, Map<String, Object> fieldValues) {
    try {
        Interview_Detail__c interview = new Interview_Detail__c(
            Candidate__c = candidateId,
            Job_Application__c = applicationId
        );
        
        for (String fieldName : fieldValues.keySet()) {
            Object value = fieldValues.get(fieldName);
            if (value != null && fieldName.endsWith('__c')) {
                interview.put(fieldName, value);
            }
        }
        
        insert interview;
        return interview.Id;
    } catch (Exception e) {
        throw new AuraHandledException('Error creating interview detail: ' + e.getMessage());
    }
}



}