// FILE: ParsedJsonNormalizer.cls
public with sharing class ParsedJsonNormalizer {
    /**
     * @description Accepts a raw JSON map from a resume and adds simple,
     * normalized fields for easier rule evaluation.
     */
    public static Map<String,Object> normalize(Map<String,Object> parsedJson) {
        if (parsedJson == null) {
            parsedJson = new Map<String,Object>();
        }

        // --- Normalize Certifications and create simple boolean flags ---
        Boolean hasMedReg = false;
        Boolean hasBLS = false;
        Boolean hasACLS = false;
        try {
            if (parsedJson.containsKey('licensesAndCertifications') && parsedJson.get('licensesAndCertifications') instanceof Map<String, Object>) {
                Map<String, Object> licSection = (Map<String, Object>) parsedJson.get('licensesAndCertifications');
                if (licSection.containsKey('value') && licSection.get('value') instanceof List<Object>) {
                    List<Object> rawCerts = (List<Object>) licSection.get('value');
                    for (Object certObj : rawCerts) {
                        String certStr = String.valueOf(certObj).toLowerCase();
                        if (certStr.contains('medical council registration')) hasMedReg = true;
                        if (certStr.contains('basic life support') || certStr.contains('bls')) hasBLS = true;
                        if (certStr.contains('advanced cardiac life support') || certStr.contains('acls')) hasACLS = true;
                    }
                }
            }
        } catch(Exception e) {
            System.debug('Error parsing certifications: ' + e.getMessage());
        }
        parsedJson.put('has_med_registration', hasMedReg);
        parsedJson.put('has_bls', hasBLS);
        parsedJson.put('has_acls', hasACLS);

        // --- Calculate years of experience from the workExperience duration string ---
        Integer calculatedYears = 0;
        try {
            if (parsedJson.containsKey('workExperience') && parsedJson.get('workExperience') instanceof Map<String, Object>) {
                Map<String, Object> expSection = (Map<String, Object>) parsedJson.get('workExperience');
                if (expSection.containsKey('value') && expSection.get('value') instanceof Map<String, Object>) {
                    Map<String, Object> expValue = (Map<String, Object>) expSection.get('value');
                    if (expValue.containsKey('duration')) {
                        String duration = String.valueOf(expValue.get('duration')); // e.g., "Jan 2021 – Present"
                        String normalizedDuration = duration.replace('–','-').replace('—','-');
                        List<String> parts = normalizedDuration.split('-');

                        if (!parts.isEmpty()) {
                            Pattern yearPattern = Pattern.compile('\\d{4}');
                            Matcher startMatcher = yearPattern.matcher(parts[0]);
                            if (startMatcher.find()) {
                                Integer startYear = Integer.valueOf(startMatcher.group(0));
                                Integer endYear = startYear;

                                if (normalizedDuration.toLowerCase().contains('present')) {
                                    endYear = Date.today().year();
                                } else if (parts.size() > 1) {
                                    Matcher endMatcher = yearPattern.matcher(parts[1]);
                                    if(endMatcher.find()) {
                                        endYear = Integer.valueOf(endMatcher.group(0));
                                    }
                                }
                                calculatedYears = Math.max(1, endYear - startYear + 1);
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            calculatedYears = 0; // Default to 0 on error
            System.debug('Error parsing experience duration: ' + e.getMessage());
        }
        parsedJson.put('experience_years_calculated', calculatedYears);

        return parsedJson;
    }
}