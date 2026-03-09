# Referral Feature Runbook

## Purpose
Operate and support the referral feature that generates shareable referral links, tracks shares, and records referral conversions for `Candidate__c`.

## Feature Components
- Apex: `CandidateReferralController`
- UI: `candidateProfileHub`, `viralReferralPanel`
- Labels: `Referral_Base_Url`, `Referral_Landing_Path`
- Data model:
  - `Candidate__c.Referral_Code__c`
  - `Candidate__c.Referral_Link__c`
  - `Candidate__c.Referral_Shares__c`
  - `Candidate__c.Referral_Conversions__c`
  - `Candidate__c.Referral_Points__c`
  - `Candidate__c.Last_Referral_Activity__c`
  - `Referral_Conversion__c`

## Configuration
### Custom Labels
- `Referral_Base_Url`
  - Default deployed value: `USE_ORG_DOMAIN`
  - Meaning: use the current org domain automatically
  - If set to an external site URL, the feature uses that URL instead
- `Referral_Landing_Path`
  - Default deployed value: `/`
  - If the value contains `{ref}`, the referral code is injected into that path
  - If `{ref}` is not present, the feature appends `?ref=<code>` or `&ref=<code>`

### Recommended Settings
- Internal org-hosted landing page:
  - `Referral_Base_Url = USE_ORG_DOMAIN`
  - `Referral_Landing_Path = /`
- External landing page with query string:
  - `Referral_Base_Url = https://your-site.example.com`
  - `Referral_Landing_Path = /apply`
- External landing page with path placeholder:
  - `Referral_Base_Url = https://your-site.example.com`
  - `Referral_Landing_Path = /register/{ref}`

## How the Feature Works
1. A referral code is generated for a candidate if one does not exist.
2. A referral link is built from the two labels above.
3. Share actions from the UI increment share metrics.
4. Conversion events create `Referral_Conversion__c` records.
5. Candidate rollup-style counters are updated on the referring candidate.

## Admin SOP
1. Open a candidate record in the `KT Onboarding` app.
2. Confirm the referral panel renders and shows a referral link.
3. Use one of the share channels and confirm share count increments.
4. Confirm `Referral_Code__c` and `Referral_Link__c` are populated.
5. Confirm `Last_Referral_Activity__c` updates after share or conversion activity.

## Conversion Verification SOP
1. Identify the referring candidate and note `Referral_Code__c`.
2. Trigger a referral conversion through the feature flow or integration path.
3. Verify a `Referral_Conversion__c` record is created.
4. Verify these fields on the conversion record:
   - `Referrer__c`
   - `Referred_Candidate__c`
   - `Channel__c`
   - `Conversion_Status__c`
   - `Reward_Points__c`
   - `Conversion_Date__c`
5. Verify the referrer counters update:
   - `Referral_Conversions__c`
   - `Referral_Points__c`

## Troubleshooting
### Referral link points to the wrong site
- Check `Referral_Base_Url`
- Check `Referral_Landing_Path`
- If the feature should use the current org host, set `Referral_Base_Url` to `USE_ORG_DOMAIN`

### Referral link format is wrong
- If you need a path-based route, include `{ref}` in `Referral_Landing_Path`
- If you need a query-string route, remove `{ref}` and the controller will append `ref=<code>`

### Share count does not change
- Verify the UI action completed without toast errors
- Check browser popup blocking for share windows
- Re-run with browser console open and inspect Apex/network failures

### Conversion record not created
- Verify the referral code exists on the referrer
- Verify the referred candidate id is valid
- Check debug logs for `CandidateReferralController.recordConversion`

### Deployment to another org fails
- If `Candidate__c.Name` is not writable in that org, keep the test without `Name` assignment
- If a blank custom label value is rejected, use `USE_ORG_DOMAIN`

## Regression Test
- Apex test to run: `CandidateReferralControllerTest`
- Expected result: `2` tests passing with no failures

## Deployment Reference
- Commit reviewed: `ff40016b92c2b19e6a6be46fc2e7fcc9fc5ab979`
- Successful `onb` deployment id: `0Afam00002TVg2rCAD`
