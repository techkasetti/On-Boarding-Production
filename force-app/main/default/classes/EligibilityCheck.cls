public without sharing class EligibilityCheck {

    /* ============================================================
       RESPONSE WRAPPER
    ============================================================ */
    public class EligibilityResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Decimal score;
        @AuraEnabled public String summary;
        @AuraEnabled public String pros;
        @AuraEnabled public String cons;
        @AuraEnabled public String error;
        
        public EligibilityResult() { 
            success = false; 
            score = 0;
        }
    }

    /* ============================================================
       MAIN ENTRY POINT
    ============================================================ */
    @AuraEnabled
    public static EligibilityResult checkEligibility(Id jobApplicationId) {
        
        EligibilityResult result = new EligibilityResult();
        
        try {
            
            System.debug('=== Eligibility Check START ===');
            
            // 1️⃣ Fetch Job Application
            Job_Application__c app = [
                SELECT Id, Candidate__c, Job_Posting__c
                FROM Job_Application__c
                WHERE Id = :jobApplicationId
                LIMIT 1
            ];
            
            if (app.Candidate__c == null || app.Job_Posting__c == null) {
                result.error = 'Missing Candidate or Job Posting';
                return result;
            }
            
            // 2️⃣ Gather Data
            JobRequirements jobReq = gatherJobRequirements(app.Job_Posting__c);
            CandidateQualifications cand = gatherCandidateQualifications(app.Candidate__c);
            
            if (jobReq == null || cand == null) {
                result.error = 'Unable to gather job or candidate data';
                return result;
            }
            
            // 3️⃣ Perform Matching Analysis
            MatchAnalysis analysis = performMatching(jobReq, cand);
            
            // 4️⃣ Calculate Final Score
            Decimal finalScore = calculateScore(analysis);
            
            // 5️⃣ Generate Summary
            String summary = generateSummary(analysis, finalScore);
            String pros = generatePros(analysis);
            String cons = generateCons(analysis);
            
            // 6️⃣ Determine Status
            String status = (finalScore > 70) ? 'Eligibility Passed' : 'Eligibility Failed';
            
            // 7️⃣ Update Job Application
            app.Eligibility_Score__c = finalScore.setScale(2);
            app.Eligibility_Summary__c = summary;
            app.Eligibility_Pros__c = pros;
            app.Eligibility_Cons__c = cons;
            app.Status__c = status;
            
            update app;
            
            // 8️⃣ Return Result
            result.success = true;
            result.score = finalScore;
            result.summary = summary;
            result.pros = pros;
            result.cons = cons;
            
            System.debug('=== CHECK COMPLETE: Score = ' + finalScore + ' ===');
            
            return result;
            
        } catch (Exception e) {
            result.error = e.getMessage();
            System.debug('Exception: ' + e.getMessage());
            return result;
        }
    }

    /* ============================================================
       DATA STRUCTURES
    ============================================================ */
    public class JobRequirements {
        public String title;
        public Decimal minExp;
        public Decimal maxExp;
        public String description;
        public List<String> education = new List<String>();
        public List<String> licenses = new List<String>();
        public List<String> certifications = new List<String>();
        public List<String> skills = new List<String>();
        public List<String> procedures = new List<String>();
    }
    
    public class CandidateQualifications {
        public List<String> education = new List<String>();
        public List<String> licenses = new List<String>();
        public List<String> certifications = new List<String>();
        public List<String> skills = new List<String>();
        public List<String> techSkills = new List<String>();
        public List<String> experience = new List<String>();
        public List<String> procedures = new List<String>();
        public Decimal totalYearsExp = 0;
    }
    
    public class MatchAnalysis {
        // Match counts
        public Integer eduMatched = 0;
        public Integer eduRequired = 0;
        public Integer licenseMatched = 0;
        public Integer licenseRequired = 0;
        public Integer certMatched = 0;
        public Integer certRequired = 0;
        public Integer skillMatched = 0;
        public Integer skillRequired = 0;
        public Integer procedureMatched = 0;
        public Integer procedureRequired = 0;
        
        // Experience
        public Boolean expInRange = false;
        public Decimal expYears = 0;
        public Decimal minExpReq = 0;
        public Decimal maxExpReq = 0;
        
        // Details
        public List<String> matchedItems = new List<String>();
        public List<String> missingItems = new List<String>();
        public List<String> extraItems = new List<String>();
    }

    /* ============================================================
       MATCHING LOGIC
    ============================================================ */
    private static MatchAnalysis performMatching(JobRequirements job, CandidateQualifications cand) {
        
        MatchAnalysis analysis = new MatchAnalysis();
        
        // EDUCATION MATCHING
        analysis.eduRequired = job.education.size();
        for (String reqEdu : job.education) {
            if (hasMatch(cand.education, reqEdu)) {
                analysis.eduMatched++;
                analysis.matchedItems.add('Education: ' + reqEdu);
            } else {
                analysis.missingItems.add('Education: ' + reqEdu);
            }
        }
        
        // LICENSE MATCHING
        analysis.licenseRequired = job.licenses.size();
        for (String reqLic : job.licenses) {
            if (hasMatch(cand.licenses, reqLic)) {
                analysis.licenseMatched++;
                analysis.matchedItems.add('License: ' + reqLic);
            } else {
                analysis.missingItems.add('License: ' + reqLic);
            }
        }
        
        // CERTIFICATION MATCHING
        analysis.certRequired = job.certifications.size();
        for (String reqCert : job.certifications) {
            if (hasMatch(cand.certifications, reqCert)) {
                analysis.certMatched++;
                analysis.matchedItems.add('Certification: ' + reqCert);
            } else {
                analysis.missingItems.add('Certification: ' + reqCert);
            }
        }
        
        // SKILL MATCHING
        analysis.skillRequired = job.skills.size();
        for (String reqSkill : job.skills) {
            if (hasMatch(cand.skills, reqSkill)) {
                analysis.skillMatched++;
                analysis.matchedItems.add('Skill: ' + reqSkill);
            } else {
                analysis.missingItems.add('Skill: ' + reqSkill);
            }
        }
        
        // PROCEDURE MATCHING
        analysis.procedureRequired = job.procedures.size();
        for (String reqProc : job.procedures) {
            if (hasMatch(cand.procedures, reqProc)) {
                analysis.procedureMatched++;
                analysis.matchedItems.add('Procedure: ' + reqProc);
            } else {
                analysis.missingItems.add('Procedure: ' + reqProc);
            }
        }
        
        // EXPERIENCE MATCHING - Using actual calculated years from dates
        analysis.expYears = cand.totalYearsExp;
        analysis.minExpReq = job.minExp != null ? job.minExp : 0;
        analysis.maxExpReq = job.maxExp != null ? job.maxExp : 999;
        
        if (cand.totalYearsExp >= analysis.minExpReq && cand.totalYearsExp <= analysis.maxExpReq) {
            analysis.expInRange = true;
            analysis.matchedItems.add('Experience: ' + cand.totalYearsExp + ' years (within ' + 
                                     analysis.minExpReq + '-' + analysis.maxExpReq + ' range)');
        } else {
            analysis.missingItems.add('Experience: ' + cand.totalYearsExp + ' years (requires ' + 
                                     analysis.minExpReq + '-' + analysis.maxExpReq + ')');
        }
        
        return analysis;
    }

    /* ============================================================
       SMART MATCHING WITH EQUIVALENCY
    ============================================================ */
    private static Boolean hasMatch(List<String> candidateList, String requirement) {
        
        if (candidateList == null || candidateList.isEmpty()) {
            return false;
        }
        
        String normalizedReq = normalizeString(requirement);
        
        for (String candItem : candidateList) {
            String normalizedCand = normalizeString(candItem);
            
            // EXACT MATCH (after normalization)
            if (normalizedReq.equals(normalizedCand)) {
                return true;
            }
            
            // CONTAINS MATCH (e.g., "ACLS" in "Advanced Cardiac Life Support (ACLS)")
            if (normalizedCand.contains(normalizedReq) || normalizedReq.contains(normalizedCand)) {
                return true;
            }
            
            // EQUIVALENCY CHECK
            if (areEquivalent(normalizedReq, normalizedCand)) {
                return true;
            }
        }
        
        return false;
    }
    
    /* ============================================================
       STRING NORMALIZATION
    ============================================================ */
    private static String normalizeString(String input) {
        if (String.isBlank(input)) return '';
        
        return input.toLowerCase()
                   .trim()
                   .replaceAll('[^a-z0-9\\s]', '') // Remove special chars
                   .replaceAll('\\s+', ' ');       // Normalize spaces
    }
    
    /* ============================================================
       EQUIVALENCY RULES
    ============================================================ */
    private static Boolean areEquivalent(String term1, String term2) {
        
        // Build equivalency map
        Map<String, Set<String>> equivalencies = new Map<String, Set<String>>{
            'acls' => new Set<String>{'acls', 'advanced cardiac life support'},
            'bls' => new Set<String>{'bls', 'basic life support'},
            'pals' => new Set<String>{'pals', 'pediatric advanced life support'},
            'nrp' => new Set<String>{'nrp', 'neonatal resuscitation program'},
            'mbbs' => new Set<String>{'mbbs', 'bachelor of medicine bachelor of surgery', 'md'},
            'md' => new Set<String>{'md', 'doctor of medicine', 'mbbs'},
            'rn' => new Set<String>{'rn', 'registered nurse'},
            'lpn' => new Set<String>{'lpn', 'licensed practical nurse'},
            'cna' => new Set<String>{'cna', 'certified nursing assistant'},
            'cpr' => new Set<String>{'cpr', 'cardiopulmonary resuscitation'},
            'emr' => new Set<String>{'emr', 'electronic medical record', 'ehr', 'electronic health record'},
            'ehr' => new Set<String>{'ehr', 'electronic health record', 'emr', 'electronic medical record'}
        };
        
        // Check if terms belong to same equivalency group
        for (Set<String> eqGroup : equivalencies.values()) {
            if (eqGroup.contains(term1) && eqGroup.contains(term2)) {
                return true;
            }
        }
        
        return false;
    }

    /* ============================================================
       SCORING ALGORITHM
    ============================================================ */
    private static Decimal calculateScore(MatchAnalysis analysis) {
        
        Decimal totalScore = 0;
        
        // EDUCATION (30 points) - CRITICAL
        if (analysis.eduRequired > 0) {
            Decimal eduScore = (Decimal.valueOf(analysis.eduMatched) / analysis.eduRequired) * 30;
            totalScore += eduScore;
        } else {
            totalScore += 30; // No requirements = full points
        }
        
        // LICENSES (25 points) - CRITICAL
        if (analysis.licenseRequired > 0) {
            Decimal licScore = (Decimal.valueOf(analysis.licenseMatched) / analysis.licenseRequired) * 25;
            totalScore += licScore;
        } else {
            totalScore += 25;
        }
        
        // CERTIFICATIONS (15 points)
        if (analysis.certRequired > 0) {
            Decimal certScore = (Decimal.valueOf(analysis.certMatched) / analysis.certRequired) * 15;
            totalScore += certScore;
        } else {
            totalScore += 15;
        }
        
        // SKILLS (15 points)
        if (analysis.skillRequired > 0) {
            Decimal skillScore = (Decimal.valueOf(analysis.skillMatched) / analysis.skillRequired) * 15;
            totalScore += skillScore;
        } else {
            totalScore += 15;
        }
        
        // PROCEDURES (10 points)
        if (analysis.procedureRequired > 0) {
            Decimal procScore = (Decimal.valueOf(analysis.procedureMatched) / analysis.procedureRequired) * 10;
            totalScore += procScore;
        } else {
            totalScore += 10;
        }
        
        // EXPERIENCE (5 points)
        if (analysis.expInRange) {
            totalScore += 5;
        }
        
        return totalScore.setScale(2);
    }

    /* ============================================================
       SUMMARY GENERATION
    ============================================================ */
    private static String generateSummary(MatchAnalysis analysis, Decimal score) {
        
        String summary = '';
        
        if (score >= 90) {
            summary = 'Excellent match. Candidate meets or exceeds all major requirements.';
        } else if (score >= 75) {
            summary = 'Strong match. Candidate meets core requirements with minor gaps.';
        } else if (score >= 60) {
            summary = 'Moderate match. Candidate shows partial alignment with requirements.';
        } else {
            summary = 'Weak match. Candidate has significant qualification gaps.';
        }
        
        return summary;
    }
    
    private static String generatePros(MatchAnalysis analysis) {
        
        List<String> pros = new List<String>();
        
        if (analysis.eduMatched > 0) {
            pros.add('✓ Education requirements met (' + analysis.eduMatched + '/' + analysis.eduRequired + ')');
        }
        
        if (analysis.licenseMatched > 0) {
            pros.add('✓ License requirements met (' + analysis.licenseMatched + '/' + analysis.licenseRequired + ')');
        }
        
        if (analysis.certMatched > 0) {
            pros.add('✓ Certifications aligned (' + analysis.certMatched + '/' + analysis.certRequired + ')');
        }
        
        if (analysis.skillMatched > 0) {
            pros.add('✓ Clinical skills matched (' + analysis.skillMatched + '/' + analysis.skillRequired + ')');
        }
        
        if (analysis.procedureMatched > 0) {
            pros.add('✓ Procedures matched (' + analysis.procedureMatched + '/' + analysis.procedureRequired + ')');
        }
        
        if (analysis.expInRange) {
            pros.add('✓ Experience within required range (' + analysis.expYears + ' years)');
        }
        
        return pros.isEmpty() ? 'None identified' : String.join(pros, '\n');
    }
    
    private static String generateCons(MatchAnalysis analysis) {
        
        List<String> cons = new List<String>();
        
        if (analysis.eduRequired > 0 && analysis.eduMatched < analysis.eduRequired) {
            cons.add('✗ Missing education requirements (' + (analysis.eduRequired - analysis.eduMatched) + ' gaps)');
        }
        
        if (analysis.licenseRequired > 0 && analysis.licenseMatched < analysis.licenseRequired) {
            cons.add('✗ Missing required licenses (' + (analysis.licenseRequired - analysis.licenseMatched) + ' gaps)');
        }
        
        if (analysis.certRequired > 0 && analysis.certMatched < analysis.certRequired) {
            cons.add('✗ Missing certifications (' + (analysis.certRequired - analysis.certMatched) + ' gaps)');
        }
        
        if (analysis.skillRequired > 0 && analysis.skillMatched < analysis.skillRequired) {
            cons.add('✗ Skill gaps identified (' + (analysis.skillRequired - analysis.skillMatched) + ' missing)');
        }
        
        if (analysis.procedureRequired > 0 && analysis.procedureMatched < analysis.procedureRequired) {
            cons.add('✗ Missing procedure experience (' + (analysis.procedureRequired - analysis.procedureMatched) + ')');
        }
        
        if (!analysis.expInRange) {
            cons.add('✗ Experience outside required range (has ' + analysis.expYears + ' years, needs ' + 
                    analysis.minExpReq + '-' + analysis.maxExpReq + ')');
        }
        
        return cons.isEmpty() ? 'None identified' : String.join(cons, '\n');
    }

    /* ============================================================
       DATA GATHERING - JOB
    ============================================================ */
    private static JobRequirements gatherJobRequirements(Id jobPostingId) {
        
        Job_Posting__c jp = [
            SELECT Job_Title__c, Min_Experience_Years__c, 
                   Max_Experience_Years__c, Description__c
            FROM Job_Posting__c
            WHERE Id = :jobPostingId
            LIMIT 1
        ];
        
        JobRequirements req = new JobRequirements();
        req.title = jp.Job_Title__c;
        req.minExp = jp.Min_Experience_Years__c;
        req.maxExp = jp.Max_Experience_Years__c;
        req.description = jp.Description__c;
        
        for (Job_Education_Requirement__c e : 
            [SELECT Degree_Name__c FROM Job_Education_Requirement__c 
             WHERE Job_Posting__c = :jobPostingId]) {
            req.education.add(e.Degree_Name__c);
        }
        
        for (Job_License_Requirement__c l : 
            [SELECT License_Name__c FROM Job_License_Requirement__c 
             WHERE Job_Posting__c = :jobPostingId]) {
            req.licenses.add(l.License_Name__c);
        }
        
        for (Job_Certification_Requirement__c c : 
            [SELECT Certification_Name__c FROM Job_Certification_Requirement__c 
             WHERE Job_Posting__c = :jobPostingId]) {
            req.certifications.add(c.Certification_Name__c);
        }
        
        for (Job_Clinical_Skill__c s : 
            [SELECT Skill_Name__c FROM Job_Clinical_Skill__c 
             WHERE Job_Posting__c = :jobPostingId]) {
            req.skills.add(s.Skill_Name__c);
        }
        
        for (Job_Procedure_Requirement__c p : 
            [SELECT Procedure_Name__c FROM Job_Procedure_Requirement__c 
             WHERE Job_Posting__c = :jobPostingId]) {
            req.procedures.add(p.Procedure_Name__c);
        }
        
        return req;
    }

    /* ============================================================
       DATA GATHERING - CANDIDATE
    ============================================================ */
    private static CandidateQualifications gatherCandidateQualifications(Id candidateId) {
        
        CandidateQualifications c = new CandidateQualifications();
        
        for (Education__c e : 
            [SELECT Degree__c, Institution__c FROM Education__c 
             WHERE Candidate__c = :candidateId]) {
            c.education.add(e.Degree__c + ' - ' + e.Institution__c);
        }
        
        for (License_Certification__c l : 
            [SELECT Name FROM License_Certification__c 
             WHERE Candidate__c = :candidateId]) {
            c.licenses.add(l.Name);
        }
        
        for (Clinical_Skill__c s : 
            [SELECT Name FROM Clinical_Skill__c 
             WHERE Candidate__c = :candidateId]) {
            c.skills.add(s.Name);
        }
        
        for (Technical_Skill__c t : 
            [SELECT Name FROM Technical_Skill__c 
             WHERE Candidate__c = :candidateId]) {
            c.techSkills.add(t.Name);
        }
        
        // CALCULATE ACTUAL EXPERIENCE FROM DATES
        Decimal totalYears = 0;
        
        for (Work_Experience__c w : 
            [SELECT Role__c, Organization__c, Start_Date__c, End_Date__c, 
                    Is_Current__c, Duration_Text__c 
             FROM Work_Experience__c 
             WHERE Candidate__c = :candidateId]) {
            
            c.experience.add(w.Role__c + ' at ' + w.Organization__c);
            
            // Calculate duration for this work experience
            if (w.Start_Date__c != null) {
                
                Date endDate;
                
                // If currently working, use today's date
                if (w.Is_Current__c == true) {
                    endDate = Date.today();
                } 
                // Otherwise use the End_Date__c
                else if (w.End_Date__c != null) {
                    endDate = w.End_Date__c;
                }
                
                // Calculate years between start and end
                if (endDate != null) {
                    Integer daysBetween = w.Start_Date__c.daysBetween(endDate);
                    Decimal yearsForThisJob = Decimal.valueOf(daysBetween) / 365.0;
                    totalYears += yearsForThisJob;
                }
            }
        }
        
        c.totalYearsExp = totalYears.setScale(1); // Round to 1 decimal place
        
        for (Procedure__c p : 
            [SELECT Name FROM Procedure__c 
             WHERE Candidate__c = :candidateId]) {
            c.procedures.add(p.Name);
        }
        
        return c;
    }
}