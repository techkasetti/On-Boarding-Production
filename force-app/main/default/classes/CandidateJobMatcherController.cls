public with sharing class CandidateJobMatcherController {

    public class JobMatchResult implements Comparable {
        @AuraEnabled public Job_Posting__c jobPosting;
        @AuraEnabled public Decimal matchScore;
        @AuraEnabled public String scoreLabel;
        @AuraEnabled public List<String> reasons;

        public Integer compareTo(Object otherObj) {
            JobMatchResult other = (JobMatchResult) otherObj;
            Decimal left = this.matchScore == null ? 0 : this.matchScore;
            Decimal right = other.matchScore == null ? 0 : other.matchScore;
            if (left == right) return 0;
            return left > right ? -1 : 1;
        }
    }

    private class CandidateSnapshot {
        public Decimal yearsOfExperience;
        public String location;
        public Set<String> roles = new Set<String>();
        public Set<String> allSkills = new Set<String>();
        public Set<String> clinicalSkills = new Set<String>();
        public Set<String> credentials = new Set<String>();
        public Boolean hasResume = false;
    }

    @AuraEnabled(cacheable=true)
    public static List<Job_Posting__c> getAllJobPostings() {
        return [
            SELECT Id, Name, Job_Title__c, Description__c, Category__c, Department__c,
                   Role_Type__c, Employment_Type__c, Shift_Type__c,
                   Min_Experience_Years__c, Max_Experience_Years__c,
                   Facility_Name__c, City__c, State__c, Country__c,
                   Start_Date__c, End_Date__c, Job_Status__c, CreatedDate
            FROM Job_Posting__c
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<JobMatchResult> getAiMatchedJobs(Id candidateId, Integer maxResults) {
        if (candidateId == null) {
            throw new AuraHandledException('Candidate ID is required.');
        }

        Integer safeLimit = (maxResults == null || maxResults <= 0) ? 25 : Math.min(maxResults, 100);

        CandidateSnapshot candidate = buildCandidateSnapshot(candidateId);
        if (!isCandidateEligibleForMatching(candidate)) {
            return new List<JobMatchResult>();
        }
        List<Job_Posting__c> jobs = getAllJobPostings();

        if (jobs.isEmpty()) {
            return new List<JobMatchResult>();
        }

        Set<Id> jobIds = new Set<Id>();
        for (Job_Posting__c job : jobs) {
            jobIds.add(job.Id);
        }

        Map<Id, Set<String>> jobLicenses = new Map<Id, Set<String>>();
        Map<Id, Set<String>> jobCertifications = new Map<Id, Set<String>>();
        Map<Id, Set<String>> jobClinicalSkills = new Map<Id, Set<String>>();
        Map<Id, Set<String>> jobProcedures = new Map<Id, Set<String>>();

        for (Job_License_Requirement__c item : [
            SELECT Job_Posting__c, License_Name__c
            FROM Job_License_Requirement__c
            WHERE Job_Posting__c IN :jobIds
        ]) {
            addToJobRequirementMap(jobLicenses, item.Job_Posting__c, item.License_Name__c);
        }

        for (Job_Certification_Requirement__c item : [
            SELECT Job_Posting__c, Certification_Name__c
            FROM Job_Certification_Requirement__c
            WHERE Job_Posting__c IN :jobIds
        ]) {
            addToJobRequirementMap(jobCertifications, item.Job_Posting__c, item.Certification_Name__c);
        }

        for (Job_Clinical_Skill__c item : [
            SELECT Job_Posting__c, Skill_Name__c
            FROM Job_Clinical_Skill__c
            WHERE Job_Posting__c IN :jobIds
        ]) {
            addToJobRequirementMap(jobClinicalSkills, item.Job_Posting__c, item.Skill_Name__c);
        }

        for (Job_Procedure_Requirement__c item : [
            SELECT Job_Posting__c, Procedure_Name__c
            FROM Job_Procedure_Requirement__c
            WHERE Job_Posting__c IN :jobIds
        ]) {
            addToJobRequirementMap(jobProcedures, item.Job_Posting__c, item.Procedure_Name__c);
        }

        List<JobMatchResult> scored = new List<JobMatchResult>();

        for (Job_Posting__c job : jobs) {
            JobMatchResult result = scoreJob(
                job,
                candidate,
                jobLicenses.get(job.Id),
                jobCertifications.get(job.Id),
                jobClinicalSkills.get(job.Id),
                jobProcedures.get(job.Id)
            );

            if (result.matchScore > 0) {
                scored.add(result);
            }
        }

        scored.sort();
        if (scored.size() > safeLimit) {
            List<JobMatchResult> trimmed = new List<JobMatchResult>();
            for (Integer i = 0; i < safeLimit; i++) {
                trimmed.add(scored[i]);
            }
            scored = trimmed;
        }
        return scored;
    }

    private static CandidateSnapshot buildCandidateSnapshot(Id candidateId) {
        Candidate__c candidate = [
            SELECT Id, Location__c, Years_of_Experience__c
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];

        CandidateSnapshot snapshot = new CandidateSnapshot();
        snapshot.location = candidate.Location__c;
        snapshot.yearsOfExperience = candidate.Years_of_Experience__c;

        for (Work_Experience__c work : [
            SELECT Role__c
            FROM Work_Experience__c
            WHERE Candidate__c = :candidateId
        ]) {
            if (String.isNotBlank(work.Role__c)) {
                snapshot.roles.add(normalize(work.Role__c));
            }
        }

        for (Clinical_Skill__c skill : [
            SELECT Name
            FROM Clinical_Skill__c
            WHERE Candidate__c = :candidateId
        ]) {
            String normalized = normalize(skill.Name);
            if (String.isNotBlank(normalized)) {
                snapshot.clinicalSkills.add(normalized);
                snapshot.allSkills.add(normalized);
            }
        }

        for (Technical_Skill__c skill : [
            SELECT Name
            FROM Technical_Skill__c
            WHERE Candidate__c = :candidateId
        ]) {
            String normalized = normalize(skill.Name);
            if (String.isNotBlank(normalized)) {
                snapshot.allSkills.add(normalized);
            }
        }

        for (Procedure__c item : [
            SELECT Name
            FROM Procedure__c
            WHERE Candidate__c = :candidateId
        ]) {
            String normalized = normalize(item.Name);
            if (String.isNotBlank(normalized)) {
                snapshot.allSkills.add(normalized);
            }
        }

        for (License_Certification__c item : [
            SELECT Name
            FROM License_Certification__c
            WHERE Candidate__c = :candidateId
        ]) {
            String normalized = normalize(item.Name);
            if (String.isNotBlank(normalized)) {
                snapshot.credentials.add(normalized);
            }
        }

        // Detect whether candidate has uploaded a likely resume file.
        Integer resumeCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :candidateId
            AND ContentDocument.FileType IN ('PDF', 'WORD_X', 'WORD')
        ];
        snapshot.hasResume = resumeCount > 0;

        return snapshot;
    }

    private static JobMatchResult scoreJob(
        Job_Posting__c job,
        CandidateSnapshot candidate,
        Set<String> licenseReqs,
        Set<String> certificationReqs,
        Set<String> clinicalReqs,
        Set<String> procedureReqs
    ) {
        Decimal score = 0;
        List<String> reasons = new List<String>();
        Boolean hasRealMatch = false;

        String normalizedJobRole = normalize(job.Role_Type__c);
        if (String.isNotBlank(normalizedJobRole)) {
            if (candidate.roles.contains(normalizedJobRole)) {
                score += 30;
                reasons.add('Role alignment: direct match for ' + job.Role_Type__c);
                hasRealMatch = true;
            } else if (hasTokenOverlap(candidate.roles, normalizedJobRole)) {
                score += 15;
                reasons.add('Role alignment: partial role overlap');
                hasRealMatch = true;
            }
        }

        score += scoreExperience(candidate.yearsOfExperience, job.Min_Experience_Years__c, job.Max_Experience_Years__c, reasons);
        if (scoreLocation(candidate.location, job.City__c, job.State__c, job.Country__c, reasons) > 0) {
            hasRealMatch = true;
            score += 10;
        }

        Set<String> requiredSkills = (procedureReqs == null) ? new Set<String>() : procedureReqs;
        Decimal skillsScore = scoreRatio(requiredSkills, candidate.allSkills, 20, 'Required skills', reasons);
        score += skillsScore;
        if (requiredSkills != null && !requiredSkills.isEmpty() && countNormalizedMatches(requiredSkills, candidate.allSkills) > 0) {
            hasRealMatch = true;
        }

        Set<String> requiredClinical = (clinicalReqs == null) ? new Set<String>() : clinicalReqs;
        Decimal clinicalScore = scoreRatio(requiredClinical, candidate.clinicalSkills, 10, 'Clinical skills', reasons);
        score += clinicalScore;
        if (requiredClinical != null && !requiredClinical.isEmpty() && countNormalizedMatches(requiredClinical, candidate.clinicalSkills) > 0) {
            hasRealMatch = true;
        }

        Set<String> requiredCredentials = new Set<String>();
        if (licenseReqs != null) requiredCredentials.addAll(licenseReqs);
        if (certificationReqs != null) requiredCredentials.addAll(certificationReqs);
        Decimal credentialScore = scoreRatio(requiredCredentials, candidate.credentials, 15, 'Certifications/Licenses', reasons);
        score += credentialScore;
        if (!requiredCredentials.isEmpty() && countNormalizedMatches(requiredCredentials, candidate.credentials) > 0) {
            hasRealMatch = true;
        }

        if (!hasRealMatch) {
            JobMatchResult noMatch = new JobMatchResult();
            noMatch.jobPosting = job;
            noMatch.matchScore = 0;
            noMatch.scoreLabel = 'Low';
            noMatch.reasons = new List<String>{ 'No direct skill/role/location/credential match.' };
            return noMatch;
        }

        JobMatchResult result = new JobMatchResult();
        result.jobPosting = job;
        result.matchScore = score.setScale(2);
        result.scoreLabel = getScoreLabel(result.matchScore);
        result.reasons = reasons;
        return result;
    }

    private static Decimal scoreExperience(Decimal candidateExp, Decimal minExp, Decimal maxExp, List<String> reasons) {
        if (minExp == null && maxExp == null) {
            reasons.add('Experience: no minimum/maximum restriction');
            return 15;
        }

        if (candidateExp == null) {
            return 0;
        }

        Decimal minVal = (minExp == null) ? 0 : minExp;
        Decimal maxVal = (maxExp == null) ? 999 : maxExp;

        if (candidateExp >= minVal && candidateExp <= maxVal) {
            reasons.add('Experience: within required range (' + String.valueOf(minVal) + '-' + String.valueOf(maxVal) + ' years)');
            return 15;
        }

        if ((candidateExp + 1) >= minVal && (candidateExp - 1) <= maxVal) {
            reasons.add('Experience: close to required range');
            return 7;
        }

        return 0;
    }

    private static Decimal scoreLocation(String candidateLocation, String city, String state, String country, List<String> reasons) {
        String candidateLoc = normalize(candidateLocation);
        if (String.isBlank(candidateLoc)) {
            return 0;
        }

        List<String> jobLocations = new List<String>{ city, state, country };
        for (String value : jobLocations) {
            String normalized = normalize(value);
            if (String.isNotBlank(normalized) && (candidateLoc.contains(normalized) || normalized.contains(candidateLoc))) {
                reasons.add('Location compatibility: ' + value);
                return 10;
            }
        }
        return 0;
    }

    private static Decimal scoreRatio(Set<String> required, Set<String> candidateSet, Decimal maxPoints, String factorName, List<String> reasons) {
        if (required == null || required.isEmpty()) {
            reasons.add(factorName + ': no mandatory requirements defined (0 points)');
            return 0;
        }

        Integer matched = countNormalizedMatches(required, candidateSet);

        Decimal value = (Decimal.valueOf(matched) / required.size()) * maxPoints;
        reasons.add(factorName + ': matched ' + matched + ' of ' + required.size());
        return value;
    }

    private static Integer countNormalizedMatches(Set<String> required, Set<String> candidateSet) {
        if (required == null || required.isEmpty() || candidateSet == null || candidateSet.isEmpty()) {
            return 0;
        }

        Integer matched = 0;
        for (String req : required) {
            if (containsNormalized(candidateSet, req)) {
                matched++;
            }
        }
        return matched;
    }

    private static Boolean isCandidateEligibleForMatching(CandidateSnapshot snapshot) {
        if (snapshot == null) return false;
        Boolean hasSkills = snapshot.allSkills != null && !snapshot.allSkills.isEmpty();
        Boolean hasExperience = (snapshot.yearsOfExperience != null) || (snapshot.roles != null && !snapshot.roles.isEmpty());

        // Hard gate: if no resume + no skills + no experience, do not return matches.
        if (!snapshot.hasResume && !hasSkills && !hasExperience) {
            return false;
        }
        return true;
    }

    private static Boolean containsNormalized(Set<String> values, String requirement) {
        String req = normalize(requirement);
        if (String.isBlank(req) || values == null || values.isEmpty()) {
            return false;
        }

        if (values.contains(req)) {
            return true;
        }

        for (String value : values) {
            if (value.contains(req) || req.contains(value)) {
                return true;
            }
        }

        return false;
    }

    private static Boolean hasTokenOverlap(Set<String> candidateRoles, String jobRole) {
        if (candidateRoles == null || candidateRoles.isEmpty() || String.isBlank(jobRole)) {
            return false;
        }

        Set<String> jobTokens = toTokens(jobRole);
        if (jobTokens.isEmpty()) {
            return false;
        }

        for (String role : candidateRoles) {
            Set<String> roleTokens = toTokens(role);
            Set<String> overlap = new Set<String>(jobTokens);
            overlap.retainAll(roleTokens);
            if (!overlap.isEmpty()) {
                return true;
            }
        }

        return false;
    }

    private static Set<String> toTokens(String value) {
        Set<String> tokens = new Set<String>();
        String normalized = normalize(value);
        if (String.isBlank(normalized)) {
            return tokens;
        }

        for (String token : normalized.split(' ')) {
            if (String.isNotBlank(token)) {
                tokens.add(token);
            }
        }

        return tokens;
    }

    private static void addToJobRequirementMap(Map<Id, Set<String>> target, Id jobId, String rawValue) {
        if (jobId == null) return;

        String normalized = normalize(rawValue);
        if (String.isBlank(normalized)) return;

        if (!target.containsKey(jobId)) {
            target.put(jobId, new Set<String>());
        }
        target.get(jobId).add(normalized);
    }

    private static String normalize(String input) {
        if (String.isBlank(input)) return '';
        return input.toLowerCase().trim().replaceAll('[^a-z0-9\\s]', ' ').replaceAll('\\s+', ' ');
    }

    private static String getScoreLabel(Decimal score) {
        Decimal val = score == null ? 0 : score;
        if (val >= 80) return 'Excellent';
        if (val >= 60) return 'Good';
        if (val >= 40) return 'Fair';
        return 'Low';
    }
}
