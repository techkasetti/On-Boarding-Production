public with sharing class CandidateReferralController {
  public class ReferralDashboardDto {
    @AuraEnabled
    public Id candidateId;
    @AuraEnabled
    public String referralCode;
    @AuraEnabled
    public String referralLink;
    @AuraEnabled
    public Decimal totalShares;
    @AuraEnabled
    public Decimal totalConversions;
    @AuraEnabled
    public Decimal rewardPoints;
    @AuraEnabled
    public Datetime lastActivity;
    @AuraEnabled
    public List<Referral_Conversion__c> recentConversions;
  }

  @AuraEnabled(cacheable=true)
  public static ReferralDashboardDto getReferralDashboard(Id candidateId) {
    if (candidateId == null) {
      throw new AuraHandledException('Candidate Id is required');
    }

    Candidate__c candidate = [
      SELECT
        Id,
        Referral_Code__c,
        Referral_Link__c,
        Referral_Shares__c,
        Referral_Conversions__c,
        Referral_Points__c,
        Last_Referral_Activity__c
      FROM Candidate__c
      WHERE Id = :candidateId
      LIMIT 1
    ];

    ReferralDashboardDto dto = new ReferralDashboardDto();
    dto.candidateId = candidate.Id;
    dto.referralCode = candidate.Referral_Code__c;
    dto.referralLink = candidate.Referral_Link__c;
    dto.totalShares = candidate.Referral_Shares__c == null
      ? 0
      : candidate.Referral_Shares__c;
    dto.totalConversions = candidate.Referral_Conversions__c == null
      ? 0
      : candidate.Referral_Conversions__c;
    dto.rewardPoints = candidate.Referral_Points__c == null
      ? 0
      : candidate.Referral_Points__c;
    dto.lastActivity = candidate.Last_Referral_Activity__c;
    dto.recentConversions = [
      SELECT
        Id,
        Name,
        Channel__c,
        Conversion_Status__c,
        Reward_Points__c,
        Conversion_Date__c,
        Referred_Candidate__c
      FROM Referral_Conversion__c
      WHERE Referrer__c = :candidateId
      ORDER BY CreatedDate DESC
      LIMIT 10
    ];
    return dto;
  }

  @AuraEnabled
  public static ReferralDashboardDto generateReferralLink(Id candidateId) {
    if (candidateId == null) {
      throw new AuraHandledException('Candidate Id is required');
    }

    Candidate__c candidate = [
      SELECT Id, Referral_Code__c, Referral_Link__c
      FROM Candidate__c
      WHERE Id = :candidateId
      LIMIT 1
      FOR UPDATE
    ];

    if (String.isBlank(candidate.Referral_Code__c)) {
      candidate.Referral_Code__c = buildReferralCode(candidate.Id);
    }

    String baseUrl = URL.getOrgDomainUrl().toExternalForm();
    candidate.Referral_Link__c =
      baseUrl +
      '/s/register?ref=' +
      EncodingUtil.urlEncode(candidate.Referral_Code__c, 'UTF-8');
    candidate.Last_Referral_Activity__c = System.now();
    update candidate;

    return getReferralDashboard(candidateId);
  }

  @AuraEnabled
  public static ReferralDashboardDto trackShare(
    Id candidateId,
    String channel
  ) {
    if (candidateId == null) {
      throw new AuraHandledException('Candidate Id is required');
    }

    Candidate__c candidate = [
      SELECT Id, Referral_Shares__c
      FROM Candidate__c
      WHERE Id = :candidateId
      LIMIT 1
      FOR UPDATE
    ];

    Decimal shares = candidate.Referral_Shares__c == null
      ? 0
      : candidate.Referral_Shares__c;
    candidate.Referral_Shares__c = shares + 1;
    candidate.Last_Referral_Activity__c = System.now();
    update candidate;

    insert new Referral_Conversion__c(
      Name = 'Share - ' + (String.isBlank(channel) ? 'Direct' : channel),
      Referrer__c = candidateId,
      Channel__c = String.isBlank(channel) ? 'Direct' : channel,
      Conversion_Status__c = 'Shared'
    );

    return getReferralDashboard(candidateId);
  }

  @AuraEnabled
  public static void recordConversion(
    String referralCode,
    Id referredCandidateId,
    String channel,
    String status
  ) {
    if (String.isBlank(referralCode)) {
      throw new AuraHandledException('Referral code is required');
    }

    Candidate__c referrer = [
      SELECT Id, Referral_Conversions__c, Referral_Points__c
      FROM Candidate__c
      WHERE Referral_Code__c = :referralCode
      LIMIT 1
      FOR UPDATE
    ];

    Decimal conversionCount = referrer.Referral_Conversions__c == null
      ? 0
      : referrer.Referral_Conversions__c;
    Decimal rewardPoints = referrer.Referral_Points__c == null
      ? 0
      : referrer.Referral_Points__c;
    Decimal incrementalReward = (status == 'Hired') ? 50 : 10;

    referrer.Referral_Conversions__c = conversionCount + 1;
    referrer.Referral_Points__c = rewardPoints + incrementalReward;
    referrer.Last_Referral_Activity__c = System.now();
    update referrer;

    insert new Referral_Conversion__c(
      Name = 'Conversion - ' + (String.isBlank(status) ? 'Applied' : status),
      Referrer__c = referrer.Id,
      Referred_Candidate__c = referredCandidateId,
      Channel__c = String.isBlank(channel) ? 'Direct' : channel,
      Conversion_Status__c = String.isBlank(status) ? 'Applied' : status,
      Reward_Points__c = incrementalReward,
      Conversion_Date__c = Date.today()
    );
  }

  private static String buildReferralCode(Id candidateId) {
    String seed = String.valueOf(candidateId).right(6).toUpperCase();
    String randomPart = String.valueOf(Crypto.getRandomLong())
      .replace('-', '')
      .left(4);
    return seed + randomPart;
  }
}
