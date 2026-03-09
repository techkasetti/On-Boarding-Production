public with sharing class JobCandidateMatcherController {

    public JobCandidateMatcherController() {

    }

    @AuraEnabled(cacheable=true)
    public static List<CandidateMatchWrapper> getMatchedCandidates(Id jobPostingId) {

        Job_Posting__c job = [
            SELECT Id, Role_Type__c, Min_Experience_Years__c, Max_Experience_Years__c
            FROM Job_Posting__c
            WHERE Id = :jobPostingId
        ];

        // Job requirements
        Set<String> requiredSkills = new Set<String>();
        for (Job_Clinical_Skill__c js :
            [SELECT Skill_Name__c FROM Job_Clinical_Skill__c WHERE Job_Posting__c = :jobPostingId]
        ) {
            requiredSkills.add(js.Skill_Name__c);
        }

        Set<String> requiredProcedures = new Set<String>();
        for (Job_Procedure_Requirement__c jp :
            [SELECT Procedure_Name__c FROM Job_Procedure_Requirement__c WHERE Job_Posting__c = :jobPostingId]
        ) {
            requiredProcedures.add(jp.Procedure_Name__c);
        }

        Set<String> requiredLicenses = new Set<String>();
        for (Job_License_Requirement__c jl :
            [SELECT License_Name__c FROM Job_License_Requirement__c WHERE Job_Posting__c = :jobPostingId]
        ) {
            requiredLicenses.add(jl.License_Name__c);
        }

        Set<Id> eligibleCandidateIds = new Set<Id>();

        for (Work_Experience__c we : [
            SELECT Candidate__c
            FROM Work_Experience__c
            WHERE Role__c = :job.Role_Type__c
        ]) {
            eligibleCandidateIds.add(we.Candidate__c);
        }
        // Candidates (role + eligibility pre-filter)
        List<Candidate__c> candidates = [
            SELECT Id, Name, Years_of_Experience__c
            FROM Candidate__c
            WHERE Id IN :eligibleCandidateIds
            //AND Clinical_Eligibility_Status__c = 'Eligible'
        ];  

        List<CandidateMatchWrapper> results = new List<CandidateMatchWrapper>();

        for (Candidate__c c : candidates) {

            Decimal score = 0;

            // 1️⃣ Role Match (20%)
            score += 20;

            // 2️⃣ Experience (15%)
            if (c.Years_of_Experience__c >= job.Min_Experience_Years__c &&
                c.Years_of_Experience__c <= job.Max_Experience_Years__c) {
                score += 15;
            }

            // 3️⃣ Licenses (25%) — mandatory gate
            Set<String> candidateLicenses = new Set<String>();
            for (License_Certification__c lc :
                [SELECT Name FROM License_Certification__c WHERE Candidate__c = :c.Id AND Status__c = 'Active']
            ) {
                candidateLicenses.add(lc.Name);
            }

            if (!candidateLicenses.containsAll(requiredLicenses)) {
                continue; // hard fail
            }
            score += 25;

            // 4️⃣ Clinical Skills (25%)
            Set<String> candidateSkills = new Set<String>();
            for (Clinical_Skill__c cs :
                [SELECT Name FROM Clinical_Skill__c WHERE Candidate__c = :c.Id AND Verified__c = true]
            ) {
                candidateSkills.add(cs.Name);
            }

            Integer matchedSkills = 0;
            for (String rs : requiredSkills) {
                if (candidateSkills.contains(rs)) matchedSkills++;
            }
            if (!requiredSkills.isEmpty()) {
                score += (Decimal.valueOf(matchedSkills) / requiredSkills.size()) * 25;
            }

            // 5️⃣ Procedures (15%)
            Set<String> candidateProcedures = new Set<String>();
            for (Procedure__c p :
                [SELECT Name FROM Procedure__c WHERE Candidate__c = :c.Id AND Verified__c = true]
            ) {
                candidateProcedures.add(p.Name);
            }

            Integer matchedProcedures = 0;
            for (String rp : requiredProcedures) {
                if (candidateProcedures.contains(rp)) matchedProcedures++;
            }
            if (!requiredProcedures.isEmpty()) {
                score += (Decimal.valueOf(matchedProcedures) / requiredProcedures.size()) * 15;
            }

            CandidateMatchWrapper w = new CandidateMatchWrapper();
            w.candidateId = c.Id;
            w.candidateName = c.Name;
            w.score = score.setScale(2);
            w.scoreLabel = score >= 80 ? 'Excellent'
                         : score >= 60 ? 'Good'
                         : 'Average';

            results.add(w);
        }

        results.sort(new CandidateScoreComparator());
        return results;
    }
}