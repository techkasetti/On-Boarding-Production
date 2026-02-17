// // =====================================================
// // SCREENING DATA LOADER - FINAL CORRECTED VERSION
// // Uses YOUR actual relationship names
// // =====================================================

// public class ScreeningDataLoader {
    
//     public static Candidate__c loadCandidateWithAllRelations(Id candidateId) {
//         return [
//             SELECT Id, Name, Years_of_Experience__c, Location__c,
                   
//                    // License/Certifications - verify this name with script
//                    (SELECT Id, Name, Type__c, Issue_Date__c, Expiry_Date__c, Notes__c
//                     FROM License_Certifications__r),
                   
//                    // Clinical Skills - verify this name with script
//                    (SELECT Id, Name, Skill_Type__c, Description__c
//                     FROM Clinical_Skills__r),
                   
//                    // Work Experiences - verify this name with script
//                    (SELECT Id, Organization__c, Role__c, Duration_Text__c, 
//                            Start_Date__c, End_Date__c, Is_Current__c, Responsibilities__c
//                     FROM Work_Experiences__r),
                   
//                    // Internships - verify this name with script
//                    (SELECT Id, Organization__c, Duration_Text__c, Start_Date__c, End_Date__c
//                     FROM Internships__r),
                   
//                    // Education - verify this name with script
//                    (SELECT Id, Degree__c, Institution__c, Duration_Text__c,
//                            Start_Year__c, End_Year__c, Details__c
//                     FROM Educations__r),
                   
//                    // Procedures - verify this name with script
//                    (SELECT Id, Name, Category__c, Notes__c
//                     FROM Procedures__r),
                   
//                    // Research/Publications - CORRECTED: Research_and_Publications__r
//                    (SELECT Id, Title__c, Type__c, Description__c, Publication_Date__c
//                     FROM Research_and_Publications__r),
                   
//                    // Technical Skills - verify this name with script
//                    (SELECT Id, Name, Category__c, Description__c
//                     FROM Technical_Skills__r),
                   
//                    // Memberships - verify this name with script
//                    (SELECT Id, Organization_Name__c, Membership_Type__c, 
//                            Member_Id__c, Member_Since__c
//                     FROM Memberships__r)
                   
//             FROM Candidate__c 
//             WHERE Id = :candidateId 
//             LIMIT 1
//         ];
//     }
    
//     public static List<Candidate__c> loadCandidatesWithAllRelations(Set<Id> candidateIds) {
//         return [
//             SELECT Id, Name, Years_of_Experience__c, Location__c,
                   
//                    (SELECT Id, Name, Type__c, Issue_Date__c, Expiry_Date__c, Notes__c
//                     FROM License_Certifications__r),
                   
//                    (SELECT Id, Name, Skill_Type__c, Description__c
//                     FROM Clinical_Skills__r),
                   
//                    (SELECT Id, Organization__c, Role__c, Duration_Text__c, 
//                            Start_Date__c, End_Date__c, Is_Current__c, Responsibilities__c
//                     FROM Work_Experiences__r),
                   
//                    (SELECT Id, Organization__c, Duration_Text__c, Start_Date__c, End_Date__c
//                     FROM Internships__r),
                   
//                    (SELECT Id, Degree__c, Institution__c, Duration_Text__c,
//                            Start_Year__c, End_Year__c, Details__c
//                     FROM Educations__r),
                   
//                    (SELECT Id, Name, Category__c, Notes__c
//                     FROM Procedures__r),
                   
//                    // CORRECTED: Research_and_Publications__r (with underscores)
//                    (SELECT Id, Title__c, Type__c, Description__c, Publication_Date__c
//                     FROM Research_and_Publications__r),
                   
//                    (SELECT Id, Name, Category__c, Description__c
//                     FROM Technical_Skills__r),
                   
//                    (SELECT Id, Organization_Name__c, Membership_Type__c, 
//                            Member_Id__c, Member_Since__c
//                     FROM Memberships__r)
                   
//             FROM Candidate__c 
//             WHERE Id IN :candidateIds
//         ];
//     }
// }


///////////////////////////////////////////////////////////////////////////////////////////////////
// =====================================================
// FIXED SCREENING DATA LOADER
// CRITICAL FIX: Add Name field to License query!
// =====================================================

// public class ScreeningDataLoader {
    
//     public static Candidate__c loadCandidateWithAllRelations(Id candidateId) {
//         return [
//             SELECT Id, Name, Years_of_Experience__c, Location__c,
                   
//                    // 🔥 FIX: Include Name field in License_Certifications query!
//                    (SELECT Id, Name, Type__c, Issue_Date__c, Expiry_Date__c, Notes__c
//                     FROM License_Certifications__r),
                   
//                    (SELECT Id, Name, Skill_Type__c, Description__c
//                     FROM Clinical_Skills__r),
                   
//                    (SELECT Id, Name, Organization__c, Role__c, Duration_Text__c, 
//                            Start_Date__c, End_Date__c, Is_Current__c, Responsibilities__c
//                     FROM Work_Experiences__r),
                   
//                    (SELECT Id, Name, Organization__c, Duration_Text__c, Start_Date__c, End_Date__c
//                     FROM Internships__r),
                   
//                    (SELECT Id, Name, Degree__c, Institution__c, Duration_Text__c,
//                            Start_Year__c, End_Year__c, Details__c
//                     FROM Educations__r),
                   
//                    (SELECT Id, Name, Category__c, Notes__c
//                     FROM Procedures__r),
                   
//                    (SELECT Id, Name, Title__c, Type__c, Description__c, Publication_Date__c
//                     FROM Research_and_Publications__r),
                   
//                    (SELECT Id, Name, Category__c, Description__c
//                     FROM Technical_Skills__r),
                   
//                    (SELECT Id, Name, Organization_Name__c, Membership_Type__c, 
//                            Member_Id__c, Member_Since__c
//                     FROM Memberships__r)
                   
//             FROM Candidate__c 
//             WHERE Id = :candidateId 
//             LIMIT 1
//         ];
//     }
    
//     public static List<Candidate__c> loadCandidatesWithAllRelations(Set<Id> candidateIds) {
//         return [
//             SELECT Id, Name, Years_of_Experience__c, Location__c,
                   
//                    // 🔥 FIX: Include Name in all child queries
//                    (SELECT Id, Name, Type__c, Issue_Date__c, Expiry_Date__c, Notes__c
//                     FROM License_Certifications__r),
                   
//                    (SELECT Id, Name, Skill_Type__c, Description__c
//                     FROM Clinical_Skills__r),
                   
//                    (SELECT Id, Name, Organization__c, Role__c, Duration_Text__c, 
//                            Start_Date__c, End_Date__c, Is_Current__c, Responsibilities__c
//                     FROM Work_Experiences__r),
                   
//                    (SELECT Id, Name, Organization__c, Duration_Text__c, Start_Date__c, End_Date__c
//                     FROM Internships__r),
                   
//                    (SELECT Id, Name, Degree__c, Institution__c, Duration_Text__c,
//                            Start_Year__c, End_Year__c, Details__c
//                     FROM Educations__r),
                   
//                    (SELECT Id, Name, Category__c, Notes__c
//                     FROM Procedures__r),
                   
//                    (SELECT Id, Name, Title__c, Type__c, Description__c, Publication_Date__c
//                     FROM Research_and_Publications__r),
                   
//                    (SELECT Id, Name, Category__c, Description__c
//                     FROM Technical_Skills__r),
                   
//                    (SELECT Id, Name, Organization_Name__c, Membership_Type__c, 
//                            Member_Id__c, Member_Since__c
//                     FROM Memberships__r)
                   
//             FROM Candidate__c 
//             WHERE Id IN :candidateIds
//         ];
//     }
// }

public class ScreeningDataLoader {
    
    /**
     * Load candidate with all related records for AI analysis
     
     */
    public static Candidate__c loadCandidateWithAllRelations(Id candidateId) {
        if (candidateId == null) {
            throw new IllegalArgumentException('Candidate ID cannot be null');
        }
        
        // Query candidate with all necessary fields and child relationships
        List<Candidate__c> candidates = [
            SELECT Id, Name, 
                   Phone__c,
                   Email__c,
                   Years_of_Experience__c, 
                   Location__c,
                   Interested_In_Job__c,
                   Interested_In_Job__r.Name,
                   Interested_In_Job__r.Description__c,
                   Interested_In_Job__r.Location__c,
                   Interested_In_Job__r.Specialization__c,
                   
                   // License & Certifications - FIXED: Added Issue_Date__c and Expiry_Date__c
                   (SELECT Id, Name, Type__c, Issue_Date__c, Expiry_Date__c, Notes__c
                    FROM License_Certifications__r
                    ORDER BY Name),
                   
                   // Clinical Skills
                   (SELECT Id, Name, Skill_Type__c, Description__c
                    FROM Clinical_Skills__r
                    ORDER BY Name),
                   
                   // Work Experience
                   (SELECT Id, Name, Role__c, Organization__c, Duration_Text__c, 
                           Start_Date__c, End_Date__c, Is_Current__c, Responsibilities__c
                    FROM Work_Experiences__r
                    ORDER BY Name DESC),
                   
                   // Internships
                   (SELECT Id, Name, Organization__c, Duration_Text__c, Start_Date__c, End_Date__c
                    FROM Internships__r
                    ORDER BY Name),
                   
                   // Internship Rotations (if needed)
                   (SELECT Id, Name, Department_Name__c
                    FROM Internship_Rotations__r
                    ORDER BY Name),
                   
                   // Education
                   (SELECT Id, Name, Degree__c, Institution__c, Duration_Text__c, 
                           Start_Year__c, End_Year__c, Details__c
                    FROM Educations__r
                    ORDER BY Name DESC),
                   
                   // Procedures Performed
                   (SELECT Id, Name, Category__c, Notes__c
                    FROM Procedures__r
                    ORDER BY Name),
                   
                   // Research & Publications
                   (SELECT Id, Name, Title__c, Type__c, Description__c, Publication_Date__c
                    FROM Research_and_Publications__r
                    ORDER BY Name),
                   
                   // Technical Skills
                   (SELECT Id, Name, Category__c, Description__c
                    FROM Technical_Skills__r
                    ORDER BY Name),
                   
                   // Professional Memberships
                   (SELECT Id, Name, Organization_Name__c, Membership_Type__c, 
                           Member_Id__c, Member_Since__c
                    FROM Memberships__r
                    ORDER BY Name)
                   
            FROM Candidate__c
            WHERE Id = :candidateId
            LIMIT 1
        ];
        
        if (candidates.isEmpty()) {
            throw new NoDataFoundException('Candidate not found with ID: ' + candidateId);
        }
        
        return candidates[0];
    }
    
    /**
     * Load multiple candidates with all relations
     * FIXED: Added Issue_Date__c and Expiry_Date__c to License query
     */
    public static List<Candidate__c> loadCandidatesWithAllRelations(Set<Id> candidateIds) {
        if (candidateIds == null || candidateIds.isEmpty()) {
            return new List<Candidate__c>();
        }
        
        return [
            SELECT Id, Name, Phone__c, Email__c, Years_of_Experience__c, Location__c,
                   Interested_In_Job__c,
                   
                   // FIXED: Added Issue_Date__c and Expiry_Date__c
                   (SELECT Id, Name, Type__c, Issue_Date__c, Expiry_Date__c, Notes__c
                    FROM License_Certifications__r),
                   
                   (SELECT Id, Name, Skill_Type__c, Description__c
                    FROM Clinical_Skills__r),
                   
                   (SELECT Id, Name, Role__c, Organization__c, Duration_Text__c, 
                           Start_Date__c, End_Date__c, Is_Current__c, Responsibilities__c
                    FROM Work_Experiences__r),
                   
                   (SELECT Id, Name, Organization__c, Duration_Text__c, Start_Date__c, End_Date__c
                    FROM Internships__r),
                   
                   (SELECT Id, Name, Department_Name__c
                    FROM Internship_Rotations__r),
                   
                   (SELECT Id, Name, Degree__c, Institution__c, Duration_Text__c, 
                           Start_Year__c, End_Year__c, Details__c
                    FROM Educations__r),
                   
                   (SELECT Id, Name, Category__c, Notes__c
                    FROM Procedures__r),
                   
                   (SELECT Id, Name, Title__c, Type__c, Description__c, Publication_Date__c
                    FROM Research_and_Publications__r),
                   
                   (SELECT Id, Name, Category__c, Description__c
                    FROM Technical_Skills__r),
                   
                   (SELECT Id, Name, Organization_Name__c, Membership_Type__c, 
                           Member_Id__c, Member_Since__c
                    FROM Memberships__r)
                   
            FROM Candidate__c 
            WHERE Id IN :candidateIds
        ];
    }
    
    /**
     * Load candidates with basic info only
     */
    public static List<Candidate__c> loadCandidatesBasic(Set<Id> candidateIds) {
        if (candidateIds == null || candidateIds.isEmpty()) {
            return new List<Candidate__c>();
        }
        
        return [
            SELECT Id, Name, Phone__c, Email__c, Years_of_Experience__c, 
                   Location__c, Interested_In_Job__c
            FROM Candidate__c
            WHERE Id IN :candidateIds
        ];
    }
    
    /**
     * Exception class for no data found scenarios
     */
    public class NoDataFoundException extends Exception {}
}