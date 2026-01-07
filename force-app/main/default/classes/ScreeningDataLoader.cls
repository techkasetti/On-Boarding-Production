// =====================================================
// SCREENING DATA LOADER - FINAL CORRECTED VERSION
// Uses YOUR actual relationship names
// =====================================================

public class ScreeningDataLoader {
    
    public static Candidate__c loadCandidateWithAllRelations(Id candidateId) {
        return [
            SELECT Id, Name, Years_of_Experience__c, Location__c,
                   
                   // License/Certifications - verify this name with script
                   (SELECT Id, Name, Type__c, Issue_Date__c, Expiry_Date__c, Notes__c
                    FROM License_Certifications__r),
                   
                   // Clinical Skills - verify this name with script
                   (SELECT Id, Name, Skill_Type__c, Description__c
                    FROM Clinical_Skills__r),
                   
                   // Work Experiences - verify this name with script
                   (SELECT Id, Organization__c, Role__c, Duration_Text__c, 
                           Start_Date__c, End_Date__c, Is_Current__c, Responsibilities__c
                    FROM Work_Experiences__r),
                   
                   // Internships - verify this name with script
                   (SELECT Id, Organization__c, Duration_Text__c, Start_Date__c, End_Date__c
                    FROM Internships__r),
                   
                   // Education - verify this name with script
                   (SELECT Id, Degree__c, Institution__c, Duration_Text__c,
                           Start_Year__c, End_Year__c, Details__c
                    FROM Educations__r),
                   
                   // Procedures - verify this name with script
                   (SELECT Id, Name, Category__c, Notes__c
                    FROM Procedures__r),
                   
                   // Research/Publications - CORRECTED: Research_and_Publications__r
                   (SELECT Id, Title__c, Type__c, Description__c, Publication_Date__c
                    FROM Research_and_Publications__r),
                   
                   // Technical Skills - verify this name with script
                   (SELECT Id, Name, Category__c, Description__c
                    FROM Technical_Skills__r),
                   
                   // Memberships - verify this name with script
                   (SELECT Id, Organization_Name__c, Membership_Type__c, 
                           Member_Id__c, Member_Since__c
                    FROM Memberships__r)
                   
            FROM Candidate__c 
            WHERE Id = :candidateId 
            LIMIT 1
        ];
    }
    
    public static List<Candidate__c> loadCandidatesWithAllRelations(Set<Id> candidateIds) {
        return [
            SELECT Id, Name, Years_of_Experience__c, Location__c,
                   
                   (SELECT Id, Name, Type__c, Issue_Date__c, Expiry_Date__c, Notes__c
                    FROM License_Certifications__r),
                   
                   (SELECT Id, Name, Skill_Type__c, Description__c
                    FROM Clinical_Skills__r),
                   
                   (SELECT Id, Organization__c, Role__c, Duration_Text__c, 
                           Start_Date__c, End_Date__c, Is_Current__c, Responsibilities__c
                    FROM Work_Experiences__r),
                   
                   (SELECT Id, Organization__c, Duration_Text__c, Start_Date__c, End_Date__c
                    FROM Internships__r),
                   
                   (SELECT Id, Degree__c, Institution__c, Duration_Text__c,
                           Start_Year__c, End_Year__c, Details__c
                    FROM Educations__r),
                   
                   (SELECT Id, Name, Category__c, Notes__c
                    FROM Procedures__r),
                   
                   // CORRECTED: Research_and_Publications__r (with underscores)
                   (SELECT Id, Title__c, Type__c, Description__c, Publication_Date__c
                    FROM Research_and_Publications__r),
                   
                   (SELECT Id, Name, Category__c, Description__c
                    FROM Technical_Skills__r),
                   
                   (SELECT Id, Organization_Name__c, Membership_Type__c, 
                           Member_Id__c, Member_Since__c
                    FROM Memberships__r)
                   
            FROM Candidate__c 
            WHERE Id IN :candidateIds
        ];
    }
}

// =====================================================
// IMPORTANT: RUN THE VERIFICATION SCRIPT FIRST!
// =====================================================

/*
Before using this class, run the script in the previous artifact
to get ALL your actual relationship names. 

You may have other naming variations like:
- License_and_Certifications__r
- Work_and_Experience__r
- etc.

The script will show you EXACTLY what names to use!
*/