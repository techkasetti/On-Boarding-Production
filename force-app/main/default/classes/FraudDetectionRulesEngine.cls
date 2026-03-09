public with sharing class FraudDetectionRulesEngine {

    /* ============================================================
     * ENTRY POINT
     * Called from SignatureRequestController.submitSignature()
     *
     * Flow:
     *   1. Check which toggles were ON (Fraud_Rules_To_Run__c)
     *   2. Find the FIRST previous signed record from same email = baseline
     *   3. If no baseline → 1st time signer → always LOW (data stored for next time)
     *   4. If baseline exists → 2nd time → compare each active toggle
     *      - Match    → LOW
     *      - Mismatch → CRITICAL
     * ============================================================ */
    public static FraudAnalysisResult runSelectedChecks(Signature_Request__c sigRequest) {

        System.debug('=== FraudDetectionRulesEngine START ===');
        System.debug('Request Id   : ' + sigRequest.Id);
        System.debug('Signer Email : ' + sigRequest.SignerEmail__c);
        System.debug('Rules To Run : ' + sigRequest.Fraud_Rules_To_Run__c);
        System.debug('IP Address   : ' + sigRequest.IPAddress__c);
        System.debug('IP Country   : ' + sigRequest.IP_Country__c);
        System.debug('Location     : ' + sigRequest.SigningLocation__c);
        System.debug('Time to Sign : ' + sigRequest.Time_To_Complete_Seconds__c);

        // No request → LOW
        if (sigRequest == null) {
            return new FraudAnalysisResult(false, 'LOW', 0, new List<String>(), new List<String>());
        }

        // No toggles turned ON → skip all checks → LOW
        if (String.isBlank(sigRequest.Fraud_Rules_To_Run__c)) {
            System.debug('No rules toggled ON → LOW');
            return new FraudAnalysisResult(false, 'LOW', 0, new List<String>(), new List<String>());
        }

        String rulesToRun = sigRequest.Fraud_Rules_To_Run__c;

        // ── Find the FIRST previous signed record from this email ──────────
        // ORDER BY CompletedDate__c ASC → oldest = 1st time they ever signed
        // Exclude the current request
        List<Signature_Request__c> previousList = [
            SELECT Id,
                   IPAddress__c,
                   IP_Country__c,
                   SigningLocation__c,
                   Time_To_Complete_Seconds__c,
                   CompletedDate__c
            FROM Signature_Request__c
            WHERE SignerEmail__c = :sigRequest.SignerEmail__c
              AND Status__c      = 'Signed'
              AND Id            != :sigRequest.Id
            ORDER BY CompletedDate__c ASC
            LIMIT 1
        ];

        System.debug('Previous signed records found: ' + previousList.size());

        // ── FIRST TIME this email has signed ───────────────────────────────
        // No history to compare against → always LOW
        // All toggled fields (IP, country, time) are already stored on
        // this record by SignatureRequestController before this method runs
        // → they become the baseline for the NEXT signature
        if (previousList.isEmpty()) {
            System.debug('First time signer → baseline stored on this record → LOW');
            return new FraudAnalysisResult(false, 'LOW', 0, new List<String>(), new List<String>());
        }

        // ── SECOND TIME or more — compare against baseline ─────────────────
        Signature_Request__c baseline = previousList[0];
        System.debug('Baseline Id      : ' + baseline.Id);
        System.debug('Baseline IP      : ' + baseline.IPAddress__c);
        System.debug('Baseline Country : ' + baseline.IP_Country__c);
        System.debug('Baseline Time    : ' + baseline.Time_To_Complete_Seconds__c);

        List<RiskFactor> detectedRisks = new List<RiskFactor>();

        // Only run checks for toggles that were ON when the doc was sent
        if (rulesToRun.contains('IP_ANOMALY')) {
            RiskFactor rf = checkIpAnomaly(sigRequest, baseline);
            if (rf != null) detectedRisks.add(rf);
        }

        if (rulesToRun.contains('LOCATION_ANOMALY')) {
            RiskFactor rf = checkLocationAnomaly(sigRequest, baseline);
            if (rf != null) detectedRisks.add(rf);
        }

        if (rulesToRun.contains('BEHAVIORAL_ANOMALY')) {
            RiskFactor rf = checkBehavioralAnomaly(sigRequest, baseline);
            if (rf != null) detectedRisks.add(rf);
        }

        FraudAnalysisResult result = compileFinalResult(detectedRisks);
        System.debug('Final Risk Level : ' + result.riskLevel + ' | Score: ' + result.overallRiskScore);
        System.debug('=== FraudDetectionRulesEngine END ===');
        return result;
    }

    /* ============================================================
     * IP ADDRESS CHECK
     *
     * Toggle: IP_ANOMALY
     * Stored: IPAddress__c (captured at signing time if toggle ON)
     * Compare: current IP vs baseline IP
     * Flag if: different IP → CRITICAL
     * ============================================================ */
    private static RiskFactor checkIpAnomaly(
        Signature_Request__c current,
        Signature_Request__c baseline
    ) {
        System.debug('--- IP Check ---');
        System.debug('Current IP  : ' + current.IPAddress__c);
        System.debug('Baseline IP : ' + baseline.IPAddress__c);

        // Baseline has no IP → toggle was OFF when they signed 1st time → skip
        if (String.isBlank(baseline.IPAddress__c)) {
            System.debug('IP Check skipped — no baseline IP (toggle was OFF on 1st sign)');
            return null;
        }

        // Current has no IP → capture failed → skip
        if (String.isBlank(current.IPAddress__c)) {
            System.debug('IP Check skipped — current IP not captured');
            return null;
        }

        if (current.IPAddress__c.trim() == baseline.IPAddress__c.trim()) {
            System.debug('IP Check → PASS (same IP)');
            return null;
        }

        System.debug('IP Check → CRITICAL (IP changed)');
        return new RiskFactor(
            'IP_ANOMALY',
            'The signature was completed from a different IP address than previously observed. '
            + 'Previous: ' + baseline.IPAddress__c + ' | Current: ' + current.IPAddress__c + '.',
            100
        );
    }

    /* ============================================================
     * LOCATION CHECK — COUNTRY BASED
     *
     * Toggle: LOCATION_ANOMALY
     * Stored: IP_Country__c (from geo lookup if toggle ON)
     * Compare: current country vs baseline country
     * Flag if: different country → CRITICAL
     * ============================================================ */
    private static RiskFactor checkLocationAnomaly(
        Signature_Request__c current,
        Signature_Request__c baseline
    ) {
        System.debug('--- Location Check ---');
        System.debug('Current Country  : ' + current.IP_Country__c);
        System.debug('Baseline Country : ' + baseline.IP_Country__c);

        // Baseline has no country → toggle was OFF when they signed 1st time → skip
        if (String.isBlank(baseline.IP_Country__c) || baseline.IP_Country__c == 'Unknown') {
            System.debug('Location Check skipped — no baseline country (toggle was OFF on 1st sign)');
            return null;
        }

        // Current has no country → geo lookup failed → skip
        if (String.isBlank(current.IP_Country__c) || current.IP_Country__c == 'Unknown') {
            System.debug('Location Check skipped — current country not captured');
            return null;
        }

        if (current.IP_Country__c.trim().equalsIgnoreCase(baseline.IP_Country__c.trim())) {
            System.debug('Location Check → PASS (same country: ' + current.IP_Country__c + ')');
            return null;
        }

        System.debug('Location Check → CRITICAL (country changed: ' + baseline.IP_Country__c + ' → ' + current.IP_Country__c + ')');
        return new RiskFactor(
            'LOCATION_ANOMALY',
            'The signing location differs from the signer\'s previously recorded location. '
            + 'Previously signed from ' + baseline.IP_Country__c
            + ', now signing from ' + current.IP_Country__c + '.',
            100
        );
    }

    /* ============================================================
     * BEHAVIOURAL CHECK
     *
     * Toggle: BEHAVIORAL_ANOMALY
     * Stored: Time_To_Complete_Seconds__c (captured if toggle ON)
     * Compare: current time vs baseline time
     * Flag if:
     *   - Under 10s absolute (bot/robotic)
     *   - Less than 50% of baseline (too fast vs their normal)
     *   - More than 200% of baseline (too slow vs their normal)
     * ============================================================ */
    private static RiskFactor checkBehavioralAnomaly(
    Signature_Request__c current,
    Signature_Request__c baseline
) {
    System.debug('--- Behaviour Check ---');
    System.debug('Current Time  : ' + current.Time_To_Complete_Seconds__c + 's');
    System.debug('Baseline Time : ' + baseline.Time_To_Complete_Seconds__c + 's');

    // ── CHECK 1: Signing duration ──────────────────────────────────

    if (current.Time_To_Complete_Seconds__c != null) {

        // Absolute — under 10s always suspicious
        if (current.Time_To_Complete_Seconds__c < 10) {
            System.debug('Behaviour Check → CRITICAL (under 10s absolute)');
            return new RiskFactor(
                'BEHAVIORAL_ANOMALY',
                'Extremely fast signing detected ('
                + current.Time_To_Complete_Seconds__c.setScale(0)
                + 's). Possible bot activity.',
                100
            );
        }

        // Relative — compare vs baseline
        if (baseline.Time_To_Complete_Seconds__c != null) {
            Decimal baseTime = baseline.Time_To_Complete_Seconds__c;
            Decimal currTime = current.Time_To_Complete_Seconds__c;

            if (currTime < baseTime * 0.5) {
                System.debug('Behaviour Check → CRITICAL (too fast vs baseline)');
                return new RiskFactor(
                    'BEHAVIORAL_ANOMALY',
                    'Signing completed significantly faster than the signer\'s previous record. '
                    + 'Previous: ' + baseTime.setScale(0) + 's | Current: ' + currTime.setScale(0) + 's.',
                    100
                );
            }

            if (currTime > baseTime * 2) {
                System.debug('Behaviour Check → CRITICAL (too slow vs baseline)');
                return new RiskFactor(
                    'BEHAVIORAL_ANOMALY',
                    'Signing took significantly longer than the signer\'s previous record. '
                    + 'Previous: ' + baseTime.setScale(0) + 's | Current: ' + currTime.setScale(0) + 's.',
                    100
                );
            }
        }
    }

    // ── CHECK 2: Unusual signing hour ─────────────────────────────
    // Normal business hours = 6 AM to 10 PM (6 to 22)
    // Anything outside that = unusual → flag as suspicious

    Integer currentHour = System.now().hour(); // 0–23 in UTC
    System.debug('Signing hour (UTC) : ' + currentHour);

if (currentHour < 3 || currentHour > 15) { // IST adjusted (UTC+5:30)        System.debug('Behaviour Check → CRITICAL (unusual hour: ' + currentHour + ')');
        return new RiskFactor(
            'BEHAVIORAL_ANOMALY',
            'Document signed at an unusual hour ('
            + currentHour + ':00 UTC). '
            + 'Expected signing between 06:00 and 22:00.',
            100
        );
    }

    System.debug('Behaviour Check → PASS');
    return null;
}

    /* ============================================================
     * COMPILE FINAL RESULT
     * Any risk detected → CRITICAL
     * No risks → LOW
     * ============================================================ */
    private static FraudAnalysisResult compileFinalResult(List<RiskFactor> detectedRisks) {
        Decimal totalScore   = 0;
        List<String> rules   = new List<String>();
        List<String> reasons = new List<String>();

        for (RiskFactor r : detectedRisks) {
            totalScore += r.score;
            rules.add(r.ruleName);
            reasons.add(r.reason);
        }

        String  riskLevel = totalScore > 0 ? 'CRITICAL' : 'LOW';
        Boolean isFraud   = totalScore > 0;

        return new FraudAnalysisResult(isFraud, riskLevel, totalScore, rules, reasons);
    }

    /* ============================================================
     * DASHBOARD DATA — used by docflowsecurity LWC
     * ============================================================ */
    @AuraEnabled(cacheable=false)
    public static List<Signature_Request__c> getSecurityDashboardData() {
        return [
            SELECT Id,
                   SignerName__c,
                   SignerEmail__c,
                   Status__c,
                   IPAddress__c,
                   SigningLocation__c,
                   IP_Country__c,
                   IP_Country_Code__c,
                   IP_Region_Name__c,
                   IP_City__c,
                   Time_To_Complete_Seconds__c,
                   CompletedDate__c,
                   Fraud_Risk_Level__c,
                   Fraud_Score__c,
                   Fraud_Analysis_Details__c,
                   Fraud_Rules_To_Run__c,
                   Document_Lifecycle_Configuration__c,
                   Document_Lifecycle_Configuration__r.Name
            FROM Signature_Request__c
            WHERE Status__c IN ('Signed', 'Completed')
            ORDER BY CompletedDate__c DESC NULLS LAST
            LIMIT 200
        ];
    }

    /* ============================================================
     * INNER CLASSES
     * ============================================================ */
    public class RiskFactor {
        public String  ruleName  { get; private set; }
        public String  reason    { get; private set; }
        public Decimal score     { get; private set; }

        public RiskFactor(String ruleName, String reason, Decimal score) {
            this.ruleName = ruleName;
            this.reason   = reason;
            this.score    = score;
        }
    }

    public class FraudAnalysisResult {
        @AuraEnabled public Boolean        isFraudDetected  { get; private set; }
        @AuraEnabled public String         riskLevel        { get; private set; }
        @AuraEnabled public Decimal        overallRiskScore { get; private set; }
        @AuraEnabled public List<String>   triggeredRules   { get; private set; }
        @AuraEnabled public List<String>   reasons          { get; private set; }

        public FraudAnalysisResult(Boolean detected, String level, Decimal score,
                                   List<String> rules, List<String> reasons) {
            this.isFraudDetected  = detected;
            this.riskLevel        = level;
            this.overallRiskScore = score;
            this.triggeredRules   = rules;
            this.reasons          = reasons;
        }
    }
}