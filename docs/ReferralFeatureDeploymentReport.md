# Referral Feature Deployment Report

## Scope
- Source commit reviewed: `ff40016b92c2b19e6a6be46fc2e7fcc9fc5ab979`
- Feature: referral link generation and referral conversion tracking
- Target org alias: `onb`
- Deployment date: `2026-03-09`

## Commit Metadata Reviewed
- `CandidateReferralController`
- `CandidateReferralControllerTest`
- `CustomLabels.labels-meta.xml`
- `candidateProfileHub`
- `viralReferralPanel`
- `Candidate__c` referral fields
- `Referral_Conversion__c` object and fields

## Validation Result
- Dry-run deploy status: `Succeeded`
- Validation deploy id: `0Afam00002TVfzdCAD`
- Components: `20/20` succeeded
- Tests run: `2`
- Test failures: `0`
- Test class: `CandidateReferralControllerTest`

## Deployment Result
- Final deploy status: `Succeeded`
- Deployment id: `0Afam00002TVg2rCAD`
- Started: `2026-03-09T05:52:05Z`
- Completed: `2026-03-09T05:52:23Z`
- Components deployed: `20/20`
- Component errors: `0`
- Tests run: `2`
- Test failures: `0`

## Org Compatibility Fixes Required
The exact commit content did not validate in `onb`. Two adjustments were required before deployment:

1. `CandidateReferralControllerTest` attempted to write `Candidate__c.Name`, which is read-only in this org.
2. `Referral_Base_Url` custom label used an empty value, which this org rejected as missing required label content.

## Final Code Adjustments Deployed
- `CandidateReferralController` now treats label value `USE_ORG_DOMAIN` as "use `URL.getOrgDomainUrl()`".
- `Referral_Base_Url` label value was set to `USE_ORG_DOMAIN`.
- `CandidateReferralControllerTest` no longer writes `Candidate__c.Name`.

## Changed vs Unchanged Components During Deploy
Changed:
- `CandidateReferralController`
- `CandidateReferralControllerTest`
- `Candidate__c.Last_Referral_Activity__c`
- `Candidate__c.Referral_Code__c`
- `Candidate__c.Referral_Link__c`
- `Referral_Conversion__c.Conversion_Date__c`
- `Referral_Base_Url`
- `Referral_Landing_Path`
- `Referral_Conversion__c`
- `candidateProfileHub`
- `viralReferralPanel`

Unchanged but included in deployment:
- `Candidate__c.Referral_Conversions__c`
- `Candidate__c.Referral_Points__c`
- `Candidate__c.Referral_Shares__c`
- `Referral_Conversion__c.Channel__c`
- `Referral_Conversion__c.Conversion_Status__c`
- `Referral_Conversion__c.Referred_Candidate__c`
- `Referral_Conversion__c.Referrer__c`
- `Referral_Conversion__c.Reward_Points__c`
- `CustomLabels`

## Coverage Note
- `CandidateReferralController`: `84/97` covered locations during deploy test execution, about `86.6%`

## Outcome
All referral feature metadata from the reviewed commit has now been successfully deployed to the `onb` org, with the org-specific fixes above applied so the package validates and deploys cleanly.
