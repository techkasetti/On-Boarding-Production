@IsTest
private class CandidateReferralControllerTest {
  private static Candidate__c createCandidate(String emailPrefix) {
    Candidate__c candidate = new Candidate__c(
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
      null
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

    List<Referral_Conversion__c> conversions = [
      SELECT Channel__c, Conversion_Status__c
      FROM Referral_Conversion__c
      WHERE Referrer__c = :candidate.Id
    ];
    System.assertEquals(1, conversions.size(), 'Share tracking should write a conversion row');
    System.assertEquals('Direct', conversions[0].Channel__c, 'Blank channel should default to Direct');
    System.assertEquals('Shared', conversions[0].Conversion_Status__c, 'Track share status should be Shared');
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
      null,
      null
    );
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
    System.assertEquals(2, updatedReferrer.Referral_Conversions__c);
    System.assertEquals(60, updatedReferrer.Referral_Points__c);

    List<Referral_Conversion__c> conversions = [
      SELECT Channel__c, Conversion_Status__c, Reward_Points__c
      FROM Referral_Conversion__c
      WHERE Referrer__c = :referrer.Id
      ORDER BY CreatedDate ASC
    ];
    System.assertEquals(2, conversions.size(), 'Two conversion rows should be created');
    System.assertEquals('Direct', conversions[0].Channel__c);
    System.assertEquals('Applied', conversions[0].Conversion_Status__c);
    System.assertEquals(10, conversions[0].Reward_Points__c);
    System.assertEquals('WhatsApp', conversions[1].Channel__c);
    System.assertEquals('Hired', conversions[1].Conversion_Status__c);
    System.assertEquals(50, conversions[1].Reward_Points__c);
  }

  @IsTest
  static void testBuildReferralLink_EncodesRefValue() {
    String rawCode = 'AB C/12';
    String encoded = EncodingUtil.urlEncode(rawCode, 'UTF-8');
    String link = CandidateReferralController.buildReferralLink(rawCode);

    System.assertNotEquals(null, link, 'Referral link should be generated');
    System.assert(link.contains(encoded), 'Link should contain encoded referral code');
  }

  @IsTest
  static void testNullInputGuards() {
    try {
      CandidateReferralController.getReferralDashboard(null);
      System.assert(false, 'Expected exception for null candidate id');
    } catch (Exception e) {
      System.assertNotEquals(null, e);
    }

    try {
      CandidateReferralController.generateReferralLink(null);
      System.assert(false, 'Expected exception for null candidate id');
    } catch (Exception e) {
      System.assertNotEquals(null, e);
    }

    try {
      CandidateReferralController.trackShare(null, 'LinkedIn');
      System.assert(false, 'Expected exception for null candidate id');
    } catch (Exception e) {
      System.assertNotEquals(null, e);
    }

    try {
      CandidateReferralController.recordConversion(null, null, null, null);
      System.assert(false, 'Expected exception for blank referral code');
    } catch (Exception e) {
      System.assertNotEquals(null, e);
    }
  }
}
