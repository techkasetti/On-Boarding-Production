public with sharing class ResumeParsingJob implements Queueable {

    private Id candidateId;

    public ResumeParsingJob(Id candidateId) {
        this.candidateId = candidateId;
    }

    public void execute(QueueableContext qc) {
        if (candidateId == null) {
            return;
        }

        try {
            // Get parsed resume from your webhook
            ResumeWebhookService.ResumePayload payload =
                ResumeWebhookService.callWebhookAndParse();

            if (payload == null) {
                updateCandidateStatus(candidateId, 'RESUME_PARSED_FAILED');
                return;
            }

            applyPayloadToCandidate(candidateId, payload);
            updateCandidateStatus(candidateId, 'RESUME_PARSED_SUCCESS');

        } catch (Exception ex) {
            Onb_ErrorLogService.logError('ResumeParsingJob.execute', ex);
            updateCandidateStatus(candidateId, 'RESUME_PARSED_FAILED');
        }
    }

    @TestVisible
    static void applyPayloadToCandidate(
        Id candId,
        ResumeWebhookService.ResumePayload payload
    ) {
        if (candId == null || payload == null) {
            return;
        }

        // Update Candidate__c
        Candidate__c cand = new Candidate__c(Id = candId);

        if (payload.name != null) {
            cand.FirstName__c = payload.name.firstName;
            cand.LastName__c  = payload.name.lastName;
        }

        if (payload.email != null) {
            cand.Email__c = payload.email;
        }

        if (payload.phone != null) {
            cand.Phone__c = payload.phone;
        }

        // If you later add a Years_Experience__c field, you can re-enable this:
        // if (payload.years_experience != null) {
        //     cand.Years_Experience__c = payload.years_experience;
        // }

        update cand;

        // Licenses & Certifications → Candidate_Credential__c
        List<Candidate_Credential__c> credentials = new List<Candidate_Credential__c>();

        if (payload.licenses != null) {
            for (ResumeWebhookService.LicenseWrapper lic : payload.licenses) {
                Candidate_Credential__c c = new Candidate_Credential__c();
                c.Candidate__c    = candId;
                c.Category__c     = 'License';
                c.Type__c         = lic.type;
                c.Name            = lic.number1;
                c.Issuing_Body__c = lic.state;

                if (!String.isBlank(lic.expiry)) {
                    try {
                        c.Expiration_Date__c = Date.valueOf(lic.expiry);
                    } catch (Exception ignore) {
                        // ignore bad date formats
                    }
                }

                credentials.add(c);
            }
        }

        if (payload.certifications != null) {
            for (ResumeWebhookService.CertificationWrapper cert : payload.certifications) {
                Candidate_Credential__c c = new Candidate_Credential__c();
                c.Candidate__c    = candId;
                c.Category__c     = 'Certification';
                c.Type__c         = cert.type;
                c.Issuing_Body__c = cert.issuer;

                if (!String.isBlank(cert.expiry)) {
                    try {
                        c.Expiration_Date__c = Date.valueOf(cert.expiry);
                    } catch (Exception ignore) {
                        // ignore bad date formats
                    }
                }

                credentials.add(c);
            }
        }

        if (!credentials.isEmpty()) {
            insert credentials;
        }

        // Skills → Candidate_Skill__c
        List<Candidate_Skill__c> skills = new List<Candidate_Skill__c>();

        if (payload.skills != null) {
            for (ResumeWebhookService.SkillWrapper s : payload.skills) {
                Candidate_Skill__c sk = new Candidate_Skill__c();
                sk.Candidate__c      = candId;
                sk.Name              = s.name;
                sk.Skill_Category__c = s.category;

                skills.add(sk);
            }
        }

        if (!skills.isEmpty()) {
            insert skills;
        }

        // Experience, education, languages can be added here later.
    }

    @TestVisible
    static void updateCandidateStatus(Id candId, String status) {
        if (candId == null || String.isBlank(status)) {
            return;
        }

        Candidate__c c = new Candidate__c(
            Id = candId,
            Status__c = status
        );

        update c;
    }
}
