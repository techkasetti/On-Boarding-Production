@IsTest
private class CandidateReferralControllerTest {
  private static Candidate__c createCandidate(String emailPrefix) {
    Candidate__c candidate = new Candidate__c(
      Name = emailPrefix,
      Full_Name__c = emailPrefix + ' Test',
      Email__c = emailPrefix + '@example.com'
    );
    insert candidate;
    return candidate;
  }

  @IsTest
  static void testGenerateAndTrackReferral() {
    Candidate__c candidate = createCandidate('referrer');

    Test.startTest();
    CandidateReferralController.ReferralDashboardDto generated = CandidateReferralController.generateReferralLink(
      candidate.Id
    );
    CandidateReferralController.ReferralDashboardDto shared = CandidateReferralController.trackShare(
      candidate.Id,
      'LinkedIn'
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      generated.referralCode,
      'Referral code should be generated'
    );
    System.assert(
      generated.referralLink.contains(generated.referralCode),
      'Referral link should embed code'
    );
    System.assertEquals(1, shared.totalShares, 'Shares should increment');
  }

  @IsTest
  static void testRecordConversion() {
    Candidate__c referrer = createCandidate('referrer2');
    Candidate__c referred = createCandidate('referred2');
    referrer.Referral_Code__c = 'ABC1234';
    update referrer;

    Test.startTest();
    CandidateReferralController.recordConversion(
      'ABC1234',
      referred.Id,
      'WhatsApp',
      'Hired'
    );
    Test.stopTest();

    Candidate__c updatedReferrer = [
      SELECT Referral_Conversions__c, Referral_Points__c
      FROM Candidate__c
      WHERE Id = :referrer.Id
    ];
    System.assertEquals(1, updatedReferrer.Referral_Conversions__c);
    System.assertEquals(50, updatedReferrer.Referral_Points__c);

    Referral_Conversion__c conversion = [
      SELECT Channel__c, Conversion_Status__c, Reward_Points__c
      FROM Referral_Conversion__c
      WHERE Referrer__c = :referrer.Id
      LIMIT 1
    ];
    System.assertEquals('WhatsApp', conversion.Channel__c);
    System.assertEquals('Hired', conversion.Conversion_Status__c);
    System.assertEquals(50, conversion.Reward_Points__c);
  }
}
