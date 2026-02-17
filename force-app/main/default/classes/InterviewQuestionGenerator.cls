public with sharing class InterviewQuestionGenerator {
    
 
    @AuraEnabled
    public static Map<String, Object> generateQuestions(Id jobPostingId) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            System.debug('=== Generating Questions for Job Posting ===');
            System.debug('Job Posting ID: ' + jobPostingId);
            
            // Validate input
            if (jobPostingId == null) {
                result.put('success', false);
                result.put('message', 'Job Posting ID is required');
                return result;
            }
            
            // Step 1: Fetch Job Posting and all requirements
            JobPostingContext context = fetchJobPostingContext(jobPostingId);
            
            if (context == null) {
                result.put('success', false);
                result.put('message', 'Job Posting not found');
                return result;
            }
            
            System.debug('✅ Job Posting loaded: ' + context.jobPosting.Job_Title__c);
            
            // Step 2: Build comprehensive prompt
            String prompt = buildPrompt(context);
            System.debug('📝 Prompt created (length: ' + prompt.length() + ')');
            
            // Step 3: Call Gemini API
            GeminiAPIService.GeminiResponse geminiResponse = GeminiAPIService.callGeminiAPIWithPrompt(prompt);
            
            if (!geminiResponse.success) {
                result.put('success', false);
                result.put('message', 'AI generation failed: ' + geminiResponse.errorMessage);
                System.debug('❌ Gemini API Error: ' + geminiResponse.errorMessage);
                return result;
            }
            
            System.debug('✅ AI response received');
            
            // Step 4: Extract response text
            String responseText = GeminiAPIService.extractContent(geminiResponse);
            
            if (String.isBlank(responseText)) {
                result.put('success', false);
                result.put('message', 'Empty response from AI');
                return result;
            }
            
            System.debug('Response text length: ' + responseText.length());
            
            // Step 5: Parse questions
            List<String> questions = parseQuestions(responseText);
            
            if (questions.isEmpty()) {
                result.put('success', false);
                result.put('message', 'No questions could be parsed from AI response');
                return result;
            }
            
            System.debug('✅ Parsed ' + questions.size() + ' questions');
            
            // Step 6: Create Interview_Question__c records
            List<Interview_Question__c> questionsToInsert = new List<Interview_Question__c>();
            
            for (String questionText : questions) {
                Interview_Question__c iq = new Interview_Question__c(
                    Job_Posting__c = jobPostingId,
                    Question__c = questionText
                );
                questionsToInsert.add(iq);
            }
            
            // Step 7: Insert records
            if (!questionsToInsert.isEmpty()) {
                insert questionsToInsert;
                System.debug('✅ Inserted ' + questionsToInsert.size() + ' questions');
            }
            
            // Step 8: Return success
            result.put('success', true);
            result.put('message', 'Successfully generated ' + questionsToInsert.size() + ' questions');
            result.put('questionsCount', questionsToInsert.size());
            
            return result;
            
        } catch (Exception e) {
            System.debug('❌ Error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            result.put('success', false);
            result.put('message', 'Error: ' + e.getMessage());
            return result;
        }
    }
    
    /**
     * Fetch Job Posting with all requirements
     */
    private static JobPostingContext fetchJobPostingContext(Id jobPostingId) {
        // Get Job Posting
        List<Job_Posting__c> jobPostings = [
            SELECT Id, Name, Job_Title__c, Category__c, Department__c,
                   Role_Type__c, Description__c, 
                   Min_Experience_Years__c, Max_Experience_Years__c,
                   Employment_Type__c, Shift_Type__c, Privilege_Scope__c
            FROM Job_Posting__c
            WHERE Id = :jobPostingId
            LIMIT 1
        ];
        
        if (jobPostings.isEmpty()) {
            return null;
        }
        
        Job_Posting__c jobPosting = jobPostings[0];
        JobPostingContext context = new JobPostingContext();
        context.jobPosting = jobPosting;
        
        System.debug('📋 Job Posting: ' + jobPosting.Job_Title__c);
        
        // Fetch all requirements
        context.educationRequirements = [
            SELECT Id, Degree_Name__c, Mandatory__c
            FROM Job_Education_Requirement__c
            WHERE Job_Posting__c = :jobPostingId
            ORDER BY Mandatory__c DESC, Degree_Name__c ASC
        ];
        System.debug('📚 Education Requirements: ' + context.educationRequirements.size());
        
        context.licenseRequirements = [
            SELECT Id, License_Name__c, Issuing_Authority__c, 
                   Active_Required__c, Expiry_Check_Required__c
            FROM Job_License_Requirement__c
            WHERE Job_Posting__c = :jobPostingId
            ORDER BY License_Name__c ASC
        ];
        System.debug('📜 License Requirements: ' + context.licenseRequirements.size());
        
        context.certificationRequirements = [
            SELECT Id, Certification_Name__c, Mandatory__c
            FROM Job_Certification_Requirement__c
            WHERE Job_Posting__c = :jobPostingId
            ORDER BY Mandatory__c DESC, Certification_Name__c ASC
        ];
        System.debug('🎓 Certification Requirements: ' + context.certificationRequirements.size());
        
        context.clinicalSkillsRequired = [
            SELECT Id, Skill_Name__c, Skill_Level__c, Mandatory__c
            FROM Job_Clinical_Skill__c
            WHERE Job_Posting__c = :jobPostingId
            ORDER BY Mandatory__c DESC, Skill_Name__c ASC
        ];
        System.debug('🩺 Clinical Skills Required: ' + context.clinicalSkillsRequired.size());
        
        context.proceduresRequired = [
            SELECT Id, Procedure_Name__c, Critical__c
            FROM Job_Procedure_Requirement__c
            WHERE Job_Posting__c = :jobPostingId
            ORDER BY Critical__c DESC, Procedure_Name__c ASC
        ];
        System.debug('⚕️ Procedures Required: ' + context.proceduresRequired.size());
        
        context.complianceRequirements = [
            SELECT Id, Compliance_Name__c, Mandatory__c
            FROM Job_Compliance_Requirement__c
            WHERE Job_Posting__c = :jobPostingId
            ORDER BY Mandatory__c DESC
        ];
        System.debug('✅ Compliance Requirements: ' + context.complianceRequirements.size());
        
        return context;
    }
    
    /**
 * Build prompt for 50 questions
 */
private static String buildPrompt(JobPostingContext ctx) {
    Job_Posting__c job = ctx.jobPosting;
    
    String prompt = 'You are an expert medical recruiter. Generate comprehensive interview questions for this position.\n\n';
    
    // JOB DETAILS
    prompt += '# JOB POSITION\n';
    prompt += '**Title:** ' + job.Job_Title__c + '\n';
    prompt += '**Category:** ' + job.Category__c + '\n';
    prompt += '**Department:** ' + job.Department__c + '\n';
    prompt += '**Role Type:** ' + job.Role_Type__c + '\n';
    
    if (job.Min_Experience_Years__c != null) {
        prompt += '**Experience Required:** ' + job.Min_Experience_Years__c;
        if (job.Max_Experience_Years__c != null) {
            prompt += '-' + job.Max_Experience_Years__c;
        }
        prompt += ' years\n';
    }
    
    if (String.isNotBlank(job.Employment_Type__c)) {
        prompt += '**Employment Type:** ' + job.Employment_Type__c + '\n';
    }
    
    if (String.isNotBlank(job.Shift_Type__c)) {
        prompt += '**Shift:** ' + job.Shift_Type__c + '\n';
    }
    
    if (String.isNotBlank(job.Description__c)) {
        String description = job.Description__c.length() > 1000 
            ? job.Description__c.substring(0, 1000) + '...' 
            : job.Description__c;
        prompt += '\n**Job Description:**\n' + description + '\n';
    }
    
    prompt += '\n';
    
    // JOB REQUIREMENTS
    prompt += '# JOB REQUIREMENTS\n\n';
    
    if (!ctx.educationRequirements.isEmpty()) {
        prompt += '## Education Requirements\n';
        for (Job_Education_Requirement__c edu : ctx.educationRequirements) {
            prompt += '- ' + edu.Degree_Name__c;
            if (edu.Mandatory__c) prompt += ' **(MANDATORY)**';
            prompt += '\n';
        }
        prompt += '\n';
    }
    
    if (!ctx.licenseRequirements.isEmpty()) {
        prompt += '## License Requirements\n';
        for (Job_License_Requirement__c lic : ctx.licenseRequirements) {
            prompt += '- ' + lic.License_Name__c;
            if (String.isNotBlank(lic.Issuing_Authority__c)) {
                prompt += ' (Issued by: ' + lic.Issuing_Authority__c + ')';
            }
            if (lic.Active_Required__c) {
                prompt += ' **(Must be active)**';
            }
            prompt += '\n';
        }
        prompt += '\n';
    }
    
    if (!ctx.certificationRequirements.isEmpty()) {
        prompt += '## Certification Requirements\n';
        for (Job_Certification_Requirement__c cert : ctx.certificationRequirements) {
            prompt += '- ' + cert.Certification_Name__c;
            if (cert.Mandatory__c) prompt += ' **(MANDATORY)**';
            prompt += '\n';
        }
        prompt += '\n';
    }
    
    if (!ctx.clinicalSkillsRequired.isEmpty()) {
        prompt += '## Required Clinical Skills\n';
        for (Job_Clinical_Skill__c skill : ctx.clinicalSkillsRequired) {
            prompt += '- ' + skill.Skill_Name__c;
            if (String.isNotBlank(skill.Skill_Level__c)) {
                prompt += ' (Level: ' + skill.Skill_Level__c + ')';
            }
            if (skill.Mandatory__c) prompt += ' **(MANDATORY)**';
            prompt += '\n';
        }
        prompt += '\n';
    }
    
    if (!ctx.proceduresRequired.isEmpty()) {
        prompt += '## Required Procedures\n';
        for (Job_Procedure_Requirement__c proc : ctx.proceduresRequired) {
            prompt += '- ' + proc.Procedure_Name__c;
            if (proc.Critical__c) prompt += ' **(CRITICAL)**';
            prompt += '\n';
        }
        prompt += '\n';
    }
    
    if (!ctx.complianceRequirements.isEmpty()) {
        prompt += '## Compliance Requirements\n';
        for (Job_Compliance_Requirement__c comp : ctx.complianceRequirements) {
            prompt += '- ' + comp.Compliance_Name__c;
            if (comp.Mandatory__c) prompt += ' **(MANDATORY)**';
            prompt += '\n';
        }
        prompt += '\n';
    }
    
    // INSTRUCTIONS
    prompt += '# TASK\n';
    prompt += 'Generate exactly **50** comprehensive interview questions for this position.\n\n';
    
    prompt += '**Question Distribution:**\n';
    prompt += '- 15 questions: Technical/Clinical competency (focus on MANDATORY skills)\n';
    prompt += '- 10 questions: Behavioral (STAR method)\n';
    prompt += '- 10 questions: Situational/Scenario-based\n';
    prompt += '- 8 questions: Experience verification\n';
    prompt += '- 7 questions: Problem-solving and critical thinking\n\n';
    
    prompt += '**Guidelines:**\n';
    prompt += '- Each question on a new line\n';
    prompt += '- Return ONLY questions, no numbering or bullets\n';
    prompt += '- No introduction or conclusion text\n';
    prompt += '- Mix difficulty levels (easy, medium, hard)\n';
    prompt += '- Focus on role-specific requirements\n';
    prompt += '- Include questions about licenses, certifications, and compliance\n\n';
    
    prompt += 'Questions:';
    
    return prompt;
}
    /**
     * Parse questions from AI response
     */
    private static List<String> parseQuestions(String responseText) {
        List<String> questions = new List<String>();
        
        if (String.isBlank(responseText)) {
            return questions;
        }
        
        String[] lines = responseText.split('\n');
        
        for (String line : lines) {
            String cleanLine = line.trim();
            
            if (String.isBlank(cleanLine)) {
                continue;
            }
            
            // Remove question numbering
            cleanLine = cleanLine.replaceAll('^\\d+\\.\\s*', '');
            cleanLine = cleanLine.replaceAll('^Q\\d+[:\\.]\\s*', '');
            cleanLine = cleanLine.replaceAll('^\\d+\\)\\s*', '');
            cleanLine = cleanLine.replaceAll('^[\\-\\*]\\s*', '');
            
            cleanLine = cleanLine.trim();
            
            if (cleanLine.length() > 10) {
                questions.add(cleanLine);
            }
        }
        
        return questions;
    }
    
    /**
     * Get all questions for a Job Posting
     */
    @AuraEnabled(cacheable=true)
    public static List<Interview_Question__c> getQuestions(Id jobPostingId) {
        return [
            SELECT Id, Name, Question__c, CreatedDate
            FROM Interview_Question__c
            WHERE Job_Posting__c = :jobPostingId
            ORDER BY CreatedDate ASC
        ];
    }
    
    /**
     * Delete all questions for a Job Posting
     */
    @AuraEnabled
    public static Map<String, Object> deleteAllQuestions(Id jobPostingId) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            List<Interview_Question__c> questionsToDelete = [
                SELECT Id
                FROM Interview_Question__c
                WHERE Job_Posting__c = :jobPostingId
            ];
            
            if (!questionsToDelete.isEmpty()) {
                delete questionsToDelete;
                result.put('success', true);
                result.put('message', 'Deleted ' + questionsToDelete.size() + ' questions');
            } else {
                result.put('success', true);
                result.put('message', 'No questions to delete');
            }
            
        } catch (Exception e) {
            result.put('success', false);
            result.put('message', 'Error: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Context holder class
     */
    private class JobPostingContext {
        public Job_Posting__c jobPosting;
        public List<Job_Education_Requirement__c> educationRequirements;
        public List<Job_License_Requirement__c> licenseRequirements;
        public List<Job_Certification_Requirement__c> certificationRequirements;
        public List<Job_Clinical_Skill__c> clinicalSkillsRequired;
        public List<Job_Procedure_Requirement__c> proceduresRequired;
        public List<Job_Compliance_Requirement__c> complianceRequirements;
    }
  
@AuraEnabled
public static Map<String, Object> generateQuestionsForCandidate(Id candidateId) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
        System.debug('=== Generating Questions for Candidate ===');
        System.debug('Candidate ID: ' + candidateId);
        
        // Validate input
        if (candidateId == null) {
            result.put('success', false);
            result.put('message', 'Candidate ID is required');
            return result;
        }
        
        // Step 1: Fetch Candidate Profile
        CandidateContext context = fetchCandidateContext(candidateId);
        
        if (context == null) {
            result.put('success', false);
            result.put('message', 'Candidate not found');
            return result;
        }
        
        System.debug('✅ Candidate loaded: ' + context.candidate.Name);
        
        // Step 2: Build candidate-focused prompt
        String prompt = buildCandidatePrompt(context);
        System.debug('📝 Candidate prompt created (length: ' + prompt.length() + ')');
        
        // Step 3: Call Gemini API
        GeminiAPIService.GeminiResponse geminiResponse = GeminiAPIService.callGeminiAPIWithPrompt(prompt);
        
        if (!geminiResponse.success) {
            result.put('success', false);
            result.put('message', 'AI generation failed: ' + geminiResponse.errorMessage);
            System.debug('❌ Gemini API Error: ' + geminiResponse.errorMessage);
            return result;
        }
        
        System.debug('✅ AI response received');
        
        // Step 4: Extract response text
        String responseText = GeminiAPIService.extractContent(geminiResponse);
        
        if (String.isBlank(responseText)) {
            result.put('success', false);
            result.put('message', 'Empty response from AI');
            return result;
        }
        
        System.debug('Response text length: ' + responseText.length());
        
        // Step 5: Parse questions
        List<String> questions = parseQuestions(responseText);
        
        if (questions.isEmpty()) {
            result.put('success', false);
            result.put('message', 'No questions could be parsed from AI response');
            return result;
        }
        
        System.debug('✅ Parsed ' + questions.size() + ' questions');
        
        // Step 6: Create Interview_Question__c records
        List<Interview_Question__c> questionsToInsert = new List<Interview_Question__c>();
        
        for (String questionText : questions) {
            Interview_Question__c iq = new Interview_Question__c(
                Candidate__c = candidateId,
                Question__c = questionText
            );
            questionsToInsert.add(iq);
        }
        
        // Step 7: Insert records
        if (!questionsToInsert.isEmpty()) {
            insert questionsToInsert;
            System.debug('✅ Inserted ' + questionsToInsert.size() + ' questions');
        }
        
        // Step 8: Return success
        result.put('success', true);
        result.put('message', 'Successfully generated ' + questionsToInsert.size() + ' candidate-focused questions');
        result.put('questionsCount', questionsToInsert.size());
        
        return result;
        
    } catch (Exception e) {
        System.debug('❌ Error: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        
        result.put('success', false);
        result.put('message', 'Error: ' + e.getMessage());
        return result;
    }
}

/**
 * Fetch Candidate Profile with all details
 */
private static CandidateContext fetchCandidateContext(Id candidateId) {
    // Get Candidate
    List<Candidate__c> candidates = [
        SELECT Id, Name, Email__c, Phone__c, Location__c
        FROM Candidate__c
        WHERE Id = :candidateId
        LIMIT 1
    ];
    
    if (candidates.isEmpty()) {
        return null;
    }
    
    Candidate__c candidate = candidates[0];
    CandidateContext context = new CandidateContext();
    context.candidate = candidate;
    
    System.debug('👤 Candidate: ' + candidate.Name);
    
    // Fetch Work Experience
    context.workExperience = [
        SELECT Id, Role__c, Organization__c, Start_Date__c, End_Date__c, 
               Is_Current__c, Responsibilities__c
        FROM Work_Experience__c
        WHERE Candidate__c = :candidateId
        ORDER BY Start_Date__c DESC NULLS LAST
    ];
    System.debug('💼 Work Experience: ' + context.workExperience.size());
    
    // Fetch Education
    context.education = [
        SELECT Id, Degree__c, Institution__c, Start_Year__c, End_Year__c, Details__c
        FROM Education__c
        WHERE Candidate__c = :candidateId
        ORDER BY Start_Year__c DESC NULLS LAST
    ];
    System.debug('🎓 Education: ' + context.education.size());
    
    // Fetch Licenses & Certifications
    context.licenses = [
        SELECT Id, Name, Type__c, Issue_Date__c, Expiry_Date__c, Notes__c
        FROM License_Certification__c
        WHERE Candidate__c = :candidateId
        ORDER BY Issue_Date__c DESC NULLS LAST
    ];
    System.debug('📜 Licenses: ' + context.licenses.size());
    
    // Fetch Clinical Skills
    context.clinicalSkills = [
        SELECT Id, Name, Skill_Type__c, Description__c
        FROM Clinical_Skill__c
        WHERE Candidate__c = :candidateId
        ORDER BY Name ASC
    ];
    System.debug('🩺 Clinical Skills: ' + context.clinicalSkills.size());
    
    // Fetch Technical Skills
    context.technicalSkills = [
        SELECT Id, Name, Category__c, Description__c
        FROM Technical_Skill__c
        WHERE Candidate__c = :candidateId
        ORDER BY Name ASC
    ];
    System.debug('💻 Technical Skills: ' + context.technicalSkills.size());
    
    // Fetch Procedures
    context.procedures = [
        SELECT Id, Name, Category__c, Notes__c
        FROM Procedure__c
        WHERE Candidate__c = :candidateId
        ORDER BY Name ASC
    ];
    System.debug('⚕️ Procedures: ' + context.procedures.size());
    
    // Fetch Internships
    context.internships = [
        SELECT Id, Organization__c, Start_Date__c, End_Date__c
        FROM Internship__c
        WHERE Candidate__c = :candidateId
        ORDER BY Start_Date__c DESC NULLS LAST
    ];
    System.debug('🏥 Internships: ' + context.internships.size());
    
    // Fetch Research & Publications
    context.researchPublications = [
        SELECT Id, Title__c, Type__c, Publication_Date__c, Description__c
        FROM Research_Publication__c
        WHERE Candidate__c = :candidateId
        ORDER BY Publication_Date__c DESC NULLS LAST
    ];
    System.debug('📚 Research: ' + context.researchPublications.size());
    
    // Fetch Professional Memberships
    context.memberships = [
        SELECT Id, Organization_Name__c, Membership_Type__c, Member_Since__c
        FROM Membership__c
        WHERE Candidate__c = :candidateId
        ORDER BY Organization_Name__c ASC
    ];
    System.debug('🏛️ Memberships: ' + context.memberships.size());
    
    return context;
}

/**
 * Build prompt focused on candidate's profile
 */
private static String buildCandidatePrompt(CandidateContext ctx) {
    Candidate__c candidate = ctx.candidate;
    
    String prompt = 'You are an expert medical recruiter conducting a skills assessment interview. ';
    prompt += 'Generate comprehensive interview questions based on this candidate\'s profile.\n\n';
    
    // CANDIDATE PROFILE
    prompt += '# CANDIDATE PROFILE: ' + candidate.Name + '\n\n';
    
    if (String.isNotBlank(candidate.Email__c)) {
        prompt += '**Email:** ' + candidate.Email__c + '\n';
    }
    if (String.isNotBlank(candidate.Location__c)) {
        prompt += '**Location:** ' + candidate.Location__c + '\n';
    }
    
    prompt += '\n';
    
    // Work Experience
    if (!ctx.workExperience.isEmpty()) {
        prompt += '## Work Experience\n';
        for (Work_Experience__c work : ctx.workExperience) {
            prompt += '### ' + work.Role__c + ' at ' + work.Organization__c;
            if (work.Is_Current__c) {
                prompt += ' (Current Position)';
            }
            prompt += '\n';
            
            if (work.Start_Date__c != null) {
                prompt += '**Duration:** ';
                prompt += String.valueOf(work.Start_Date__c.year());
                if (work.End_Date__c != null) {
                    prompt += ' - ' + String.valueOf(work.End_Date__c.year());
                } else if (work.Is_Current__c) {
                    prompt += ' - Present';
                }
                prompt += '\n';
            }
            
            if (String.isNotBlank(work.Responsibilities__c)) {
                String responsibilities = work.Responsibilities__c.length() > 300 
                    ? work.Responsibilities__c.substring(0, 300) + '...' 
                    : work.Responsibilities__c;
                prompt += '**Responsibilities:** ' + responsibilities + '\n';
            }
            prompt += '\n';
        }
    }
    
    // Education
    if (!ctx.education.isEmpty()) {
        prompt += '## Education\n';
        for (Education__c edu : ctx.education) {
            prompt += '- **' + edu.Degree__c + '** from ' + edu.Institution__c;
            if (edu.Start_Year__c != null) {
                prompt += ' (' + edu.Start_Year__c.intValue();
                if (edu.End_Year__c != null) {
                    prompt += '-' + edu.End_Year__c.intValue();
                }
                prompt += ')';
            }
            prompt += '\n';
            
            if (String.isNotBlank(edu.Details__c)) {
                prompt += '  ' + edu.Details__c + '\n';
            }
        }
        prompt += '\n';
    }
    
    // Licenses & Certifications
    if (!ctx.licenses.isEmpty()) {
        prompt += '## Licenses & Certifications\n';
        for (License_Certification__c lic : ctx.licenses) {
            prompt += '- **' + lic.Name + '**';
            if (String.isNotBlank(lic.Type__c)) {
                prompt += ' (' + lic.Type__c + ')';
            }
            
            if (lic.Issue_Date__c != null) {
                prompt += ' - Issued: ' + String.valueOf(lic.Issue_Date__c.year());
            }
            if (lic.Expiry_Date__c != null) {
                prompt += ', Expires: ' + String.valueOf(lic.Expiry_Date__c.year());
            }
            prompt += '\n';
        }
        prompt += '\n';
    }
    
    // Clinical Skills
    if (!ctx.clinicalSkills.isEmpty()) {
        prompt += '## Clinical Skills\n';
        List<String> skillNames = new List<String>();
        for (Clinical_Skill__c skill : ctx.clinicalSkills) {
            String skillText = skill.Name;
            if (String.isNotBlank(skill.Skill_Type__c)) {
                skillText += ' (' + skill.Skill_Type__c + ')';
            }
            skillNames.add(skillText);
        }
        prompt += String.join(skillNames, ', ') + '\n\n';
    }
    
    // Technical Skills
    if (!ctx.technicalSkills.isEmpty()) {
        prompt += '## Technical Skills\n';
        List<String> techNames = new List<String>();
        for (Technical_Skill__c tech : ctx.technicalSkills) {
            String techText = tech.Name;
            if (String.isNotBlank(tech.Category__c)) {
                techText += ' (' + tech.Category__c + ')';
            }
            techNames.add(techText);
        }
        prompt += String.join(techNames, ', ') + '\n\n';
    }
    
    // Procedures
    if (!ctx.procedures.isEmpty()) {
        prompt += '## Procedures Performed\n';
        List<String> procNames = new List<String>();
        for (Procedure__c proc : ctx.procedures) {
            String procText = proc.Name;
            if (String.isNotBlank(proc.Category__c)) {
                procText += ' (' + proc.Category__c + ')';
            }
            procNames.add(procText);
        }
        prompt += String.join(procNames, ', ') + '\n\n';
    }
    
    // Internships
    if (!ctx.internships.isEmpty()) {
        prompt += '## Internships / Clinical Rotations\n';
        for (Internship__c intern : ctx.internships) {
            prompt += '- ' + intern.Organization__c;
            if (intern.Start_Date__c != null) {
                prompt += ' (' + String.valueOf(intern.Start_Date__c.year());
                if (intern.End_Date__c != null) {
                    prompt += '-' + String.valueOf(intern.End_Date__c.year());
                }
                prompt += ')';
            }
            prompt += '\n';
        }
        prompt += '\n';
    }
    
    // Research & Publications
    if (!ctx.researchPublications.isEmpty()) {
        prompt += '## Research & Publications\n';
        for (Research_Publication__c research : ctx.researchPublications) {
            prompt += '- **' + research.Title__c + '**';
            if (String.isNotBlank(research.Type__c)) {
                prompt += ' (' + research.Type__c + ')';
            }
            if (research.Publication_Date__c != null) {
                prompt += ' - ' + String.valueOf(research.Publication_Date__c.year());
            }
            prompt += '\n';
        }
        prompt += '\n';
    }
    
    // Professional Memberships
    if (!ctx.memberships.isEmpty()) {
        prompt += '## Professional Memberships\n';
        for (Membership__c member : ctx.memberships) {
            prompt += '- ' + member.Organization_Name__c;
            if (String.isNotBlank(member.Membership_Type__c)) {
                prompt += ' (' + member.Membership_Type__c + ')';
            }
            prompt += '\n';
        }
        prompt += '\n';
    }
    
    // INSTRUCTIONS
    prompt += '# TASK\n';
    prompt += 'Generate exactly **20** interview questions based on this candidate\'s profile.\n\n';
    
    prompt += '**Question Focus:**\n';
    prompt += '- 8 questions: Deep dive into work experience and responsibilities\n';
    prompt += '- 4 questions: Verify and explore clinical skills mentioned\n';
    prompt += '- 3 questions: Behavioral questions (STAR method) based on their background\n';
    prompt += '- 3 questions: Situational questions related to their experience level\n';
    prompt += '- 2 questions: Career goals and motivation\n\n';
    
    prompt += '**Guidelines:**\n';
    prompt += '- Each question on a new line\n';
    prompt += '- Return ONLY questions, no numbering or bullets\n';
    prompt += '- No introduction or conclusion text\n';
    prompt += '- Reference specific items from their profile in questions\n';
    prompt += '- Ask about gaps in employment if any\n';
    prompt += '- Explore areas where more detail is needed\n';
    prompt += '- Questions should help assess fit for medical/clinical roles\n\n';
    
    prompt += 'Questions:';
    
    return prompt;
}

/**
 * Get questions for a Candidate
 */
@AuraEnabled(cacheable=true)
public static List<Interview_Question__c> getQuestionsForCandidate(Id candidateId) {
    return [
        SELECT Id, Name, Question__c, CreatedDate
        FROM Interview_Question__c
        WHERE Candidate__c = :candidateId
        ORDER BY CreatedDate ASC
    ];
}

/**
 * Delete all questions for a Candidate
 */
@AuraEnabled
public static Map<String, Object> deleteQuestionsForCandidate(Id candidateId) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
        List<Interview_Question__c> questionsToDelete = [
            SELECT Id
            FROM Interview_Question__c
            WHERE Candidate__c = :candidateId
        ];
        
        if (!questionsToDelete.isEmpty()) {
            delete questionsToDelete;
            result.put('success', true);
            result.put('message', 'Deleted ' + questionsToDelete.size() + ' questions');
        } else {
            result.put('success', true);
            result.put('message', 'No questions to delete');
        }
        
    } catch (Exception e) {
        result.put('success', false);
        result.put('message', 'Error: ' + e.getMessage());
    }
    
    return result;
}

/**
 * Candidate Context holder class
 */
private class CandidateContext {
    public Candidate__c candidate;
    public List<Work_Experience__c> workExperience;
    public List<Education__c> education;
    public List<License_Certification__c> licenses;
    public List<Clinical_Skill__c> clinicalSkills;
    public List<Technical_Skill__c> technicalSkills;
    public List<Procedure__c> procedures;
    public List<Internship__c> internships;
    public List<Research_Publication__c> researchPublications;
    public List<Membership__c> memberships;
}
}