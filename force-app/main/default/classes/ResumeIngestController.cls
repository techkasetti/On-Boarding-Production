@RestResource(urlMapping='/resumeIngest/*')
global with sharing class ResumeIngestController {

    @HttpPost
    global static String ingestResume() {

        Map<String, Object> inputJson =
            (Map<String, Object>) JSON.deserializeUntyped(
                RestContext.request.requestBody.toString()
            );

        // -------------------------------
        // 1. SERVICE TYPE (required)
        // -------------------------------
        if (!inputJson.containsKey('serviceType')) {
            return error('400', 'serviceType is mandatory');
        }

        // -------------------------------
        // 2. CANDIDATE (INSERT OR UPDATE)
        // -------------------------------
        Candidate__c candidate;

        if (inputJson.containsKey('candidateId') &&
            inputJson.get('candidateId') != null) {

            candidate = [
                SELECT Id FROM Candidate__c
                WHERE Id = :String.valueOf(inputJson.get('candidateId'))
                LIMIT 1
            ];
        } else {
            candidate = new Candidate__c();
        }

        candidate.Name_As_Per_Resume__c   = (String) inputJson.get('Candidate_Name');
        candidate.Email_As_Per_Resume__c  = (String) inputJson.get('Candidate_Email');
        candidate.Phone__c                = (String) inputJson.get('Candidate_Phone');
        candidate.Gender__c               = (String) inputJson.get('Gender');
        candidate.Date_of_Birth__c        = parseDate(inputJson.get('Date_of_Birth'));
        candidate.Years_of_Experience__c  = parseDecimal(inputJson.get('Candidate_Years_of_Experience'));

        upsert candidate;

        // -------------------------------
        // 3. LICENSE / CERTIFICATION
        // -------------------------------
        if (inputJson.containsKey('License_Certification_Name')) {
            insert new License_Certification__c(
                Candidate__c = candidate.Id,
                Name         = (String) inputJson.get('License_Certification_Name'),
                Type__c      = (String) inputJson.get('License_Certification_Type'),
                Notes__c     = (String) inputJson.get('License_Certification_Notes')
            );
        }

        // -------------------------------
        // 4. CLINICAL SKILL
        // -------------------------------
        if (inputJson.containsKey('Clinical_Skill_Name')) {
            insert new Clinical_Skill__c(
                Candidate__c = candidate.Id,
                Name         = (String) inputJson.get('Clinical_Skill_Name'),
                Skill_Type__c= (String) inputJson.get('Clinical_Skill_Skill_Type'),
                Description__c =
                    (String) inputJson.get('Clinical_Skill_Description')
            );
        }

        // -------------------------------
        // 5. WORK EXPERIENCE
        // -------------------------------
        if (inputJson.containsKey('Work_Experience_Role')) {
            insert new Work_Experience__c(
                Candidate__c      = candidate.Id,
                Role__c           = (String) inputJson.get('Work_Experience_Role'),
                Organization__c   = (String) inputJson.get('Work_Experience_Organization'),
                Duration_Text__c  = (String) inputJson.get('Work_Experience_Duration_Text'),
                Responsibilities__c =
                    (String) inputJson.get('Work_Experience_Responsibilities'),
                Start_Date__c     = parseDate(inputJson.get('Work_Experience_Start_Date')),
                End_Date__c       = parseDate(inputJson.get('Work_Experience_End_Date')),
                Is_Current__c     = parseBoolean(inputJson.get('Work_Experience_Is_Current'))
            );
        }

        // -------------------------------
        // 6. INTERNSHIP + ROTATION
        // -------------------------------
        if (inputJson.containsKey('Internship_Organization')) {
            Internship__c internship = new Internship__c(
                Candidate__c = candidate.Id,
                Organization__c =
                    (String) inputJson.get('Internship_Organization'),
                Start_Date__c =
                    parseDate(inputJson.get('Internship_Start_Date')),
                End_Date__c =
                    parseDate(inputJson.get('Internship_End_Date'))
            );
            insert internship;

            if (inputJson.containsKey('Internship_Rotation_Department_Name')) {
                insert new Internship_Rotation__c(
                    Internship__c = internship.Id,
                    Department__c =
                        (String) inputJson.get('Internship_Rotation_Department_Name')
                );
            }
        }

        // -------------------------------
        // 7. EDUCATION
        // -------------------------------
        if (inputJson.containsKey('Education_Degree')) {
            insert new Education__c(
                Candidate__c = candidate.Id,
                Degree__c    = (String) inputJson.get('Education_Degree'),
                Institution__c =
                    (String) inputJson.get('Education_Institution'),
                Duration_Text__c =
                    (String) inputJson.get('Education_Duration_Text'),
                Details__c =
                    (String) inputJson.get('Education_Details'),
                Start_Year__c =
                    parseDecimal(inputJson.get('Education_Start_Year')),
                End_Year__c =
                    parseDecimal(inputJson.get('Education_End_Year'))
            );
        }

        // -------------------------------
        // 8. PROCEDURE
        // -------------------------------
        if (inputJson.containsKey('Procedure_Name')) {
            insert new Procedure__c(
                Candidate__c = candidate.Id,
                Name         = (String) inputJson.get('Procedure_Name'),
                Category__c  = (String) inputJson.get('Procedure_Category'),
                Notes__c     = (String) inputJson.get('Procedure_Notes')
            );
        }

        // -------------------------------
        // 9. RESEARCH / PUBLICATION
        // -------------------------------
        if (inputJson.containsKey('Research_Publication_Title')) {
            insert new Research_Publication__c(
                Candidate__c = candidate.Id,
                Title__c     =
                    (String) inputJson.get('Research_Publication_Title'),
                Type__c      =
                    (String) inputJson.get('Research_Publication_Type'),
                Description__c =
                    (String) inputJson.get('Research_Publication_Description')
            );
        }

        // -------------------------------
        // 10. TECHNICAL SKILL
        // -------------------------------
        if (inputJson.containsKey('Technical_Skill_Name')) {
            insert new Technical_Skill__c(
                Candidate__c = candidate.Id,
                Name         =
                    (String) inputJson.get('Technical_Skill_Name'),
                Category__c  =
                    (String) inputJson.get('Technical_Skill_Category'),
                Description__c =
                    (String) inputJson.get('Technical_Skill_Description')
            );
        }

        // -------------------------------
        // 11. MEMBERSHIP
        // -------------------------------
        if (inputJson.containsKey('Membership_Organization_Name')) {
            insert new Membership__c(
                Candidate__c = candidate.Id,
                Organization_Name__c =
                    (String) inputJson.get('Membership_Organization_Name'),
                Membership_Type__c =
                    (String) inputJson.get('Membership_Membership_Type'),
                Member_Id__c =
                    (String) inputJson.get('Membership_Member_Id')
            );
        }

        return success(candidate.Id);
    }

    // ===============================
    // HELPERS
    // ===============================
    private static Date parseDate(Object o) {
        return o == null ? null : Date.valueOf(String.valueOf(o));
    }

    private static Decimal parseDecimal(Object o) {
        return o == null ? null : Decimal.valueOf(String.valueOf(o));
    }

    private static Boolean parseBoolean(Object o) {
        return o == null ? false : Boolean.valueOf(String.valueOf(o));
    }

    private static String success(Id candidateId) {
        return JSON.serialize(new Map<String, Object>{
            'status' => 'SUCCESS',
            'candidateId' => candidateId
        });
    }

    private static String error(String code, String message) {
        return JSON.serialize(new Map<String, Object>{
            'code' => code,
            'message' => message
        });
    }
}
