public without sharing class JobPostingController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getJobPostings(
        String keyword, 
        String location, 
        String datePosted, 
        String experienceLevel
    ) {
        try {
            String query = 'SELECT Id, Name, Job_Title__c, Category__c, Department__c, ' +
                          'Role_Type__c, Employment_Type__c, Shift_Type__c, ' +
                          'Facility_Name__c, City__c, State__c, Country__c, ' +
                          'Min_Experience_Years__c, Max_Experience_Years__c, ' +
                          'Description__c, Privilege_Scope__c, ' +
                          'Start_Date__c, End_Date__c, Job_Status__c, ' +
                          'CreatedDate, CreatedBy.Name ' +
                          'FROM Job_Posting__c ' +
                          'WHERE Job_Status__c = \'Open\'';
            
            Map<String, Object> bindVars = new Map<String, Object>();
            
            if (String.isNotBlank(keyword)) {
                String searchTerm = '%' + String.escapeSingleQuotes(keyword) + '%';
                query += ' AND (Name LIKE :searchTerm OR Job_Title__c LIKE :searchTerm OR Category__c LIKE :searchTerm)';
                bindVars.put('searchTerm', searchTerm);
            }
            
            if (String.isNotBlank(location)) {
                String locationTerm = '%' + String.escapeSingleQuotes(location) + '%';
                query += ' AND (City__c LIKE :locationTerm OR State__c LIKE :locationTerm OR Facility_Name__c LIKE :locationTerm)';
                bindVars.put('locationTerm', locationTerm);
            }
            
            if (String.isNotBlank(datePosted) && datePosted != 'all') {
                if (datePosted == '24h') {
                    query += ' AND CreatedDate >= LAST_N_DAYS:1';
                } else if (datePosted == 'week') {
                    query += ' AND CreatedDate >= LAST_N_DAYS:7';
                } else if (datePosted == 'month') {
                    query += ' AND CreatedDate >= LAST_N_DAYS:30';
                }
            }
            
            if (String.isNotBlank(experienceLevel) && experienceLevel != 'all') {
                Decimal expLevel = Decimal.valueOf(experienceLevel);
                query += ' AND Min_Experience_Years__c <= :expLevel AND Max_Experience_Years__c >= :expLevel';
                bindVars.put('expLevel', expLevel);
            }
            
            query += ' ORDER BY CreatedDate DESC LIMIT 100';
            
            List<Job_Posting__c> jobs = Database.query(query);
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('jobs', jobs);
            result.put('count', jobs.size());
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching job postings: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getJobDetails(Id jobId) {
        try {
            // Main job posting
            Job_Posting__c job = [
                SELECT Id, Name, Job_Title__c, Category__c, Department__c, 
                       Role_Type__c, Employment_Type__c, Shift_Type__c,
                       Facility_Name__c, City__c, State__c, Country__c,
                       Min_Experience_Years__c, Max_Experience_Years__c,
                       Description__c, Privilege_Scope__c,
                       Start_Date__c, End_Date__c, Job_Status__c,
                       Credentialing_Required__c,
                       CreatedDate, CreatedBy.Name
                FROM Job_Posting__c
                WHERE Id = :jobId
                LIMIT 1
            ];
            
            // Education requirements
            List<Job_Education_Requirement__c> educationReqs = [
                SELECT Id, Degree_Name__c, Mandatory__c
                FROM Job_Education_Requirement__c
                WHERE Job_Posting__c = :jobId
                ORDER BY Mandatory__c DESC, Degree_Name__c ASC
            ];
            
            // License requirements
            List<Job_License_Requirement__c> licenseReqs = [
                SELECT Id, License_Name__c, Issuing_Authority__c, 
                       Active_Required__c, Expiry_Check_Required__c
                FROM Job_License_Requirement__c
                WHERE Job_Posting__c = :jobId
                ORDER BY License_Name__c ASC
            ];
            
            // Certification requirements
            List<Job_Certification_Requirement__c> certReqs = [
                SELECT Id, Certification_Name__c, Mandatory__c
                FROM Job_Certification_Requirement__c
                WHERE Job_Posting__c = :jobId
                ORDER BY Mandatory__c DESC, Certification_Name__c ASC
            ];
            
            // Clinical skills
            List<Job_Clinical_Skill__c> clinicalSkills = [
                SELECT Id, Skill_Name__c, Skill_Level__c, Mandatory__c
                FROM Job_Clinical_Skill__c
                WHERE Job_Posting__c = :jobId
                ORDER BY Mandatory__c DESC, Skill_Name__c ASC
            ];
            
            // Procedures
            List<Job_Procedure_Requirement__c> procedures = [
                SELECT Id, Procedure_Name__c, Critical__c
                FROM Job_Procedure_Requirement__c
                WHERE Job_Posting__c = :jobId
                ORDER BY Critical__c DESC, Procedure_Name__c ASC
            ];
            
            // Compliance requirements
            List<Job_Compliance_Requirement__c> complianceReqs = [
                SELECT Id, Compliance_Name__c, Mandatory__c
                FROM Job_Compliance_Requirement__c
                WHERE Job_Posting__c = :jobId
                ORDER BY Mandatory__c DESC, Compliance_Name__c ASC
            ];
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('job', job);
            result.put('educationRequirements', educationReqs);
            result.put('licenseRequirements', licenseReqs);
            result.put('certificationRequirements', certReqs);
            result.put('clinicalSkills', clinicalSkills);
            result.put('procedures', procedures);
            result.put('complianceRequirements', complianceReqs);
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching job details: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean isGuestUser() {
        try {
            Id currentUserId = UserInfo.getUserId();
            User currentUser = [SELECT Id, IsPortalEnabled, ContactId, UserType, Username 
                               FROM User 
                               WHERE Id = :currentUserId 
                               LIMIT 1];
            
            Boolean isGuest = currentUser.UserType == 'Guest' || currentUser.ContactId == null;
            return isGuest;
            
        } catch (Exception e) {
            return true;
        }
    }
    
    @AuraEnabled
    public static Map<String, String> getCandidateIdForCurrentUser() {
        try {
            Map<String, String> result = new Map<String, String>();
            Id currentUserId = UserInfo.getUserId();
            
            List<User> users = [SELECT Id, ContactId, Username, UserType 
                               FROM User 
                               WHERE Id = :currentUserId 
                               LIMIT 1];
            
            if (users.isEmpty()) {
                throw new AuraHandledException('User not found');
            }
            
            User currentUser = users[0];
            
            if (currentUser.ContactId == null) {
                throw new AuraHandledException('No contact associated with this user. Please contact administrator to link your account.');
            }
            
            List<Candidate__c> candidates = [SELECT Id, Name,Full_Name__c, Email__c, Phone__c, Location__c
                                            FROM Candidate__c 
                                            WHERE Contact__c = :currentUser.ContactId 
                                            LIMIT 1];
            
            if (candidates.isEmpty()) {
                throw new AuraHandledException('No candidate profile found for this user. Please contact administrator to create your candidate profile.');
            }
            
            Candidate__c candidate = candidates[0];
            result.put('candidateId', candidate.Id);
            result.put('candidateName', candidate.Full_Name__c);
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching candidate data: ' + e.getMessage());
        }
    }
    
    /**
     * Create a job application record
     */
    @AuraEnabled
    public static Map<String, Object> createJobApplication(Id jobPostingId, Id candidateId) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            // Check for duplicate application
            List<Job_Application__c> existingApps = [
                SELECT Id, Status__c 
                FROM Job_Application__c 
                WHERE Candidate__c = :candidateId 
                AND Job_Posting__c = :jobPostingId 
                LIMIT 1
            ];
            
            if (!existingApps.isEmpty()) {
                result.put('success', false);
                result.put('message', 'You have already applied for this job.');
                result.put('existingStatus', existingApps[0].Status__c);
                return result;
            }
            
            // Create new application
            Job_Application__c application = new Job_Application__c(
                Candidate__c = candidateId,
                Job_Posting__c = jobPostingId,
                Status__c = 'Application Received',
                Application_Date__c = Date.today(),
                Applied_From__c = 'Experience Cloud'
            );
            
            insert application;
            
            result.put('success', true);
            result.put('message', 'Application submitted successfully!');
            result.put('applicationId', application.Id);
            
            return result;
            
        } catch (Exception e) {
            result.put('success', false);
            result.put('message', 'Error creating application: ' + e.getMessage());
            return result;
        }
    }
    
    /**
     * Get all job applications for a candidate
     */
    @AuraEnabled(cacheable=false)
    public static List<Job_Application__c> getCandidateApplications(Id candidateId) {
        try {
            return [
                SELECT Id, Name, Application_Date__c, Status__c,
                       Job_Posting__c,
                       Job_Posting__r.Job_Title__c,
                       Job_Posting__r.Category__c,
                       Job_Posting__r.Department__c,
                       Job_Posting__r.City__c,
                       Job_Posting__r.State__c,
                       Job_Posting__r.Facility_Name__c,
                       Job_Posting__r.Description__c
                FROM Job_Application__c
                WHERE Candidate__c = :candidateId
                ORDER BY Application_Date__c DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching applications: ' + e.getMessage());
        }
    }
    /**
 * Check if candidate profile meets minimum requirements for job application
 */
@AuraEnabled(cacheable=false)
public static Map<String, Object> checkCandidateEligibility(Id candidateId) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
        // Query candidate with resume fields
        List<Candidate__c> candidates = [
            SELECT Id, Name, Email__c, Phone__c, Location__c, 
                   S3_Resume_URL__c, Resume_Status__c
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];
        
        if (candidates.isEmpty()) {
            result.put('eligible', false);
            result.put('message', 'Candidate profile not found.');
            result.put('completeness', 0);
            return result;
        }
        
        Candidate__c candidate = candidates[0];
        
        // Check required profile sections
        Integer totalSections = 8;
        Integer completedSections = 0;
        List<String> missingSections = new List<String>();
        
        // 1. Basic Info (Email, Phone, Location)
        if (String.isNotBlank(candidate.Email__c) && 
            String.isNotBlank(candidate.Phone__c) && 
            String.isNotBlank(candidate.Location__c)) {
            completedSections++;
        } else {
            missingSections.add('Basic Information (Email, Phone, Location)');
        }
        
        // 2. Resume (REQUIRED)
        Boolean hasResume = false;
        List<ContentDocumentLink> resumeDocs = [
            SELECT Id 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :candidateId 
            AND ContentDocument.FileExtension IN ('pdf', 'doc', 'docx')
            LIMIT 1
        ];
        
        if (!resumeDocs.isEmpty() || candidate.Resume_Status__c == true) {
            completedSections++;
            hasResume = true;
        } else {
            missingSections.add('Resume');
        }
        
        // 3. Education (REQUIRED - at least 1)
        Integer educationCount = [
            SELECT COUNT() 
            FROM Education__c 
            WHERE Candidate__c = :candidateId
        ];
        
        if (educationCount > 0) {
            completedSections++;
        } else {
            missingSections.add('Education');
        }
        
        // 4. Work Experience
        Integer workExpCount = [
            SELECT COUNT() 
            FROM Work_Experience__c 
            WHERE Candidate__c = :candidateId
        ];
        
        if (workExpCount > 0) {
            completedSections++;
        } else {
            missingSections.add('Work Experience');
        }
        
        // 5. Clinical Skills (REQUIRED - at least 1)
        Integer clinicalSkillsCount = [
            SELECT COUNT() 
            FROM Clinical_Skill__c 
            WHERE Candidate__c = :candidateId
        ];
        
        if (clinicalSkillsCount > 0) {
            completedSections++;
        } else {
            missingSections.add('Clinical Skills');
        }
        
        // 6. Technical Skills
        Integer techSkillsCount = [
            SELECT COUNT() 
            FROM Technical_Skill__c 
            WHERE Candidate__c = :candidateId
        ];
        
        if (techSkillsCount > 0) {
            completedSections++;
        } else {
            missingSections.add('Technical Skills');
        }
        
        // 7. Licenses/Certifications
        Integer licenseCount = [
            SELECT COUNT() 
            FROM License_Certification__c 
            WHERE Candidate__c = :candidateId
        ];
        
        if (licenseCount > 0) {
            completedSections++;
        } else {
            missingSections.add('Licenses/Certifications');
        }
        
        // 8. Procedures
        Integer procedureCount = [
            SELECT COUNT() 
            FROM Procedure__c 
            WHERE Candidate__c = :candidateId
        ];
        
        if (procedureCount > 0) {
            completedSections++;
        }
        
        // Calculate completion percentage
        Integer completenessPercentage = (Integer) Math.round((Decimal.valueOf(completedSections) / Decimal.valueOf(totalSections)) * 100);
        
        // Check eligibility: Must have Resume + Education + Skills + 75% completion
        Boolean eligible = hasResume && 
                          educationCount > 0 && 
                          clinicalSkillsCount > 0 && 
                          completenessPercentage >= 75;
        
        result.put('eligible', eligible);
        result.put('completeness', completenessPercentage);
        result.put('missingSections', missingSections);
        result.put('hasResume', hasResume);
        result.put('hasEducation', educationCount > 0);
        result.put('hasSkills', clinicalSkillsCount > 0);
        
        if (!eligible) {
            String message = 'Profile incomplete. Required: ';
            List<String> required = new List<String>();
            
            if (!hasResume) required.add('Resume');
            if (educationCount == 0) required.add('Education');
            if (clinicalSkillsCount == 0) required.add('Clinical Skills');
            if (completenessPercentage < 75) required.add(String.valueOf(75 - completenessPercentage) + '% more profile completion');
            
            message += String.join(required, ', ');
            result.put('message', message);
        } else {
            result.put('message', 'Profile meets all requirements.');
        }
        
        return result;
        
    } catch (Exception e) {
        result.put('eligible', false);
        result.put('message', 'Error checking eligibility: ' + e.getMessage());
        result.put('completeness', 0);
        return result;
    }
}
}