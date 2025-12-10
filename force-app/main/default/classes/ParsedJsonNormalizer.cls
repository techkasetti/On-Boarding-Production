// public with sharing class ParsedJsonNormalizer {
//     // Normalize the parsedJson map in-place and return it.
//     public static Map<String,Object> normalize(Map<String,Object> parsedJson) {
//         if (parsedJson == null) parsedJson = new Map<String,Object>();

//         // 1) certifications list: common path is parsed_json.licensesAndCertifications.value which may be List<Object>
//         List<Object> certs = null;
//         try {
//             if (parsedJson.containsKey('licensesAndCertifications')) {
//                 Object lic = parsedJson.get('licensesAndCertifications');
//                 if (lic instanceof Map<String,Object>) {
//                     Map<String,Object> licMap = (Map<String,Object>) lic;
//                     if (licMap.containsKey('value')) {
//                         Object val = licMap.get('value');
//                         if (val instanceof List<Object>) certs = (List<Object>) val;
//                         else if (val instanceof String) certs = new List<Object>{ val };
//                     }
//                 }
//             }
//         } catch (Exception ex) {
//             // ignore parse errors
//         }
//         if (certs == null) certs = new List<Object>();

//         // 2) create booleans for common certs
//         Boolean hasMedReg = false;
//         Boolean hasBLS = false;
//         Boolean hasACLS = false;
//         for (Object it : certs) {
//             if (it == null) continue;
//             String s = String.valueOf(it).toLowerCase();
//             if (s.contains('medical council registration')) hasMedReg = true;
//             if (s.contains('basic life support') || s.contains('bls')) hasBLS = true;
//             if (s.contains('advanced cardiac life support') || s.contains('acls')) hasACLS = true;
//         }
//         parsedJson.put('certifications_list', certs);
//         parsedJson.put('has_med_registration', hasMedReg);
//         parsedJson.put('has_bls', hasBLS);
//         parsedJson.put('has_acls', hasACLS);

//         // 3) compute experience_years best-effort from workExperience.duration or internship.duration
//         Integer years = null;
//         try {
//             if (parsedJson.containsKey('workExperience')) {
//                 Object we = parsedJson.get('workExperience');
//                 if (we instanceof Map<String,Object>) {
//                     Map<String,Object> wem = (Map<String,Object>) we;
//                     if (wem.containsKey('value')) {
//                         // some parsers place object under 'value'; handle both
//                         Object val = wem.get('value');
//                         if (val instanceof Map<String,Object>) wem = (Map<String,Object>) val;
//                     }
//                     if (wem.containsKey('duration')) {
//                         String dur = String.valueOf(wem.get('duration'));
//                         Integer est = estimateYearsFromDurationString(dur);
//                         if (est != null) years = est;
//                     }
//                 }
//             }
//         } catch (Exception ex) {}

//         // Fallback: if no workExperience found but internship has duration
//         if (years == null) {
//             try {
//                 if (parsedJson.containsKey('internship')) {
//                     Object itn = parsedJson.get('internship');
//                     if (itn instanceof Map<String,Object>) {
//                         Map<String,Object> im = (Map<String,Object>) itn;
//                         if (im.containsKey('value')) {
//                             Object val = im.get('value');
//                             if (val instanceof Map<String,Object>) im = (Map<String,Object>) val;
//                         }
//                         if (im.containsKey('duration')) {
//                             Integer est2 = estimateYearsFromDurationString(String.valueOf(im.get('duration')));
//                             if (est2 != null) years = est2;
//                         }
//                     }
//                 }
//             } catch (Exception ex) {}
//         }

//         parsedJson.put('experience_years', years == null ? 0 : years);

//         return parsedJson;
//     }

//     // // very lightweight parser: looks for years explicitly (YYYY or 'Present' -> estimate)
//     // public static Integer estimateYearsFromDurationString(String dur) {
//     //     if (String.isBlank(dur)) return null;
//     //     // Example formats: "Jan 2021 – Present", "2018 – 2020", "Jan 2019 - Dec 2020"
//     //     try {
//     //         // Extract all 4-digit numbers as years
//     //         List<Integer> years = new List<Integer>();
//     //         Matcher m = Pattern.compile('\\d{4}').matcher(dur);
//     //         while (m.find()) {
//     //             String g = m.group();
//     //             years.add(Integer.valueOf(g));
//     //         }
//     //         if (!years.isEmpty()) {
//     //             Integer minY = years[0];
//     //             Integer maxY = years[years.size()-1];
//     //             Integer nowYear = Date.today().year();
//     //             if (dur.toLowerCase().contains('present') || dur.toLowerCase().contains('current')) {
//     //                 // approximate from first year to now
//     //                 return Math.max(0, nowYear - minY);
//     //             } else {
//     //                 // approximate as difference between first and last year (+1)
//     //                 return Math.max(0, (maxY - minY) + 1);
//     //             }
//     //         }
//     //         // fallback: if string contains a single year like "2021" return small value
//     //         Matcher m2 = Pattern.compile('\\d{4}').matcher(dur);
//     //         if (m2.find()) {
//     //             return 1;
//     //         }
//     //     } catch (Exception ex) {}
//     //     return null;
//     // }
//     public static Integer estimateYearsFromDurationString(String dur) {
//     if (String.isBlank(dur)) return null;
//     try {
//         // Normalize separators and remove weird unicode spaces
//         String s = dur.trim();
//         s = s.replaceAll('[\\u2013\\u2014\\u2012]', '-'); // en-dash/em-dash to hyphen
//         s = s.replaceAll('[\\u00A0]', ' '); // non-breaking space
//         s = s.replaceAll('\\s+',' ');

//         // Lowercase for 'present' checks
//         String slow = s.toLowerCase();

//         // Extract all 4-digit year tokens
//         List<Integer> years = new List<Integer>();
//         Pattern p = Pattern.compile('\\\\b(19|20)\\\\d{2}\\\\b');
//         Matcher m = p.matcher(s);
//         while (m.find()) {
//             String g = m.group();
//             try { years.add(Integer.valueOf(g)); } catch (Exception e) {}
//         }

//         Integer nowYear = Date.today().year();

//         if (!years.isEmpty()) {
//             Integer first = years[0];
//             Integer last = years[years.size()-1];

//             // If 'present' or 'ongoing' appears, estimate from first year to now
//             if (slow.contains('present') || slow.contains('current') || slow.contains('ongoing')) {
//                 Integer diff = Math.max(0, nowYear - first);
//                 // if same year as now treat as 1 year minimum
//                 return diff == 0 ? 1 : diff;
//             } else {
//                 Integer diff = Math.max(0, (last - first) + 1);
//                 return diff == 0 ? 1 : diff;
//             }
//         }

//         // If no 4-digit years, try to extract simple patterns like "Jan 2021" or "2021"
//         Pattern p2 = Pattern.compile('(19|20)\\\\d{2}');
//         Matcher m2 = p2.matcher(s);
//         if (m2.find()) return 1;

//     } catch (Exception ex) {
//         // swallow - return null so caller can fall back
//         System.debug('estimateYearsFromDurationString failed: ' + ex.getMessage());
//     }
//     return null;
// }

// }
public with sharing class ParsedJsonNormalizer {
    public static Map<String,Object> normalize(Map<String,Object> parsedJson) {
        if (parsedJson == null) parsedJson = new Map<String,Object>();

        // --- CERTIFICATES ---
        List<Object> certs = new List<Object>();
        try {
            if (parsedJson.containsKey('licensesAndCertifications')) {
                Object lic = parsedJson.get('licensesAndCertifications');
                if (lic instanceof Map<String,Object>) {
                    Map<String,Object> licMap = (Map<String,Object>) lic;
                    if (licMap.containsKey('value')) {
                        Object val = licMap.get('value');
                        if (val instanceof List<Object>) certs.addAll((List<Object>)val);
                        else if (val instanceof String) certs.add(val);
                    } else {
                        // fallback: the map might directly contain entries
                        for (Object v : licMap.values()) {
                            if (v instanceof List<Object>) certs.addAll((List<Object>)v);
                            else certs.add(v);
                        }
                    }
                } else if (lic instanceof List<Object>) {
                    certs = (List<Object>) lic;
                } else if (lic instanceof String) {
                    // maybe JSON-stringified
                    String s = (String) lic;
                    try {
                        Object parsed = JSON.deserializeUntyped(s);
                        if (parsed instanceof List<Object>) certs = (List<Object>) parsed;
                        else certs.add(s);
                    } catch (Exception e) { certs.add(s); }
                }
            }
        } catch (Exception ex) {
            // ignore, keep empty
        }

        // Normalize list: trim strings
        List<Object> normCerts = new List<Object>();
        for (Object o : certs) {
            if (o == null) continue;
            String s = String.valueOf(o).trim();
            if (s != '') normCerts.add(s);
        }
        parsedJson.put('certifications_list', normCerts);

        // Certification booleans
        Boolean hasMedReg = false;
        Boolean hasBLS = false;
        Boolean hasACLS = false;
        for (Object it : normCerts) {
            String s = String.valueOf(it).toLowerCase();
            if (s.contains('medical council registration')) hasMedReg = true;
            if (s.contains('basic life support') || s.contains('bls')) hasBLS = true;
            if (s.contains('advanced cardiac life support') || s.contains('acls')) hasACLS = true;
        }
        parsedJson.put('has_med_registration', hasMedReg);
        parsedJson.put('has_bls', hasBLS);
        parsedJson.put('has_acls', hasACLS);

        // --- EXPERIENCE: try to extract months for workExperience and internship and sum them ---
        Integer workMonths = extractMonthsFromSection(parsedJson, 'workExperience');
        Integer internMonths = extractMonthsFromSection(parsedJson, 'internship');

        Integer totalMonths = 0;
        if (workMonths != null) totalMonths += workMonths;
        if (internMonths != null) totalMonths += internMonths;

        // fallback: if no months found check for experience_years key already present
        if (totalMonths == 0) {
            if (parsedJson.containsKey('experience_years')) {
                try {
                    Object exv = parsedJson.get('experience_years');
                    if (exv instanceof Decimal) parsedJson.put('experience_years', ((Decimal)exv).intValue());
                    else parsedJson.put('experience_years', Integer.valueOf(String.valueOf(exv)));
                } catch (Exception e) {
                    parsedJson.put('experience_years', 0);
                }
            } else {
                parsedJson.put('experience_years', 0);
            }
        } else {
            Integer years = totalMonths / 12;
            parsedJson.put('experience_years', years);
            parsedJson.put('experience_months_total', totalMonths);
        }

        // Keep the normalized parsedJson returned
        return parsedJson;
    }

    private static Integer extractMonthsFromSection(Map<String,Object> parsedJson, String sectionKey) {
        try {
            if (!parsedJson.containsKey(sectionKey)) return 0;
            Object sec = parsedJson.get(sectionKey);
            Map<String,Object> secMap = null;
            if (sec instanceof Map<String,Object>) {
                secMap = (Map<String,Object>) sec;
                // Some parsers put 'value' node with the actual object
                if (secMap.containsKey('value') && secMap.get('value') instanceof Map<String,Object>) {
                    secMap = (Map<String,Object>) secMap.get('value');
                }
            } else {
                return 0;
            }
            if (secMap == null) return 0;

            // Most common: secMap.duration exists and is a string
            if (secMap.containsKey('duration')) {
                String dur = String.valueOf(secMap.get('duration'));
                Integer months = estimateMonthsFromDurationString(dur);
                if (months != null) return months;
            }

            // If there are multiple entries (list), try to sum their durations
            if (secMap.containsKey('value') && secMap.get('value') instanceof List<Object>) {
                Integer total = 0;
                for (Object it : (List<Object>) secMap.get('value')) {
                    if (it instanceof Map<String,Object>) {
                        Map<String,Object> m = (Map<String,Object>) it;
                        if (m.containsKey('duration')) {
                            Integer mm = estimateMonthsFromDurationString(String.valueOf(m.get('duration')));
                            if (mm != null) total += mm;
                        }
                    }
                }
                return total;
            }

        } catch (Exception e) {
            // ignore
        }
        return 0;
    }

    public static Integer estimateMonthsFromDurationString(String dur) {
        if (String.isBlank(dur)) return null;
        try {
            // Normalize dashes
            String normalized = dur.replace('–','-').replace('—','-').trim();
            // handle "Jan 2021 – Present" or "2018 – 2020" or "Aug 2025 - Present"
            List<String> parts = normalized.split('-');
            String startPart = parts.size() > 0 ? parts[0].trim() : '';
            String endPart = parts.size() > 1 ? parts[1].trim() : '';

            // parse start
            Date startDate = parseApproximateDate(startPart);
            Date endDate = null;
            if (String.isBlank(endPart)) {
                endDate = Date.today();
            } else {
                String epLow = endPart.toLowerCase();
                if (epLow.contains('present') || epLow.contains('current')) {
                    endDate = Date.today();
                } else {
                    endDate = parseApproximateDate(endPart);
                    if (endDate == null) endDate = Date.today();
                }
            }

            if (startDate == null) return null;
            if (endDate == null) endDate = Date.today();
            // months difference approximation
            Integer months = (endDate.year() - startDate.year()) * 12 + (endDate.month() - startDate.month());
            if (months < 0) months = 0;
            return months;
        } catch (Exception ex) {
            return null;
        }
    }

    private static Date parseApproximateDate(String s) {
        if (String.isBlank(s)) return null;
        try {
            s = s.trim();
            // if contains 4-digit year
            Matcher m = Pattern.compile('(\\d{4})').matcher(s);
            if (m.find()) {
                Integer year = Integer.valueOf(m.group(1));
                // try find month word before the year
                Matcher m2 = Pattern.compile('([A-Za-z]{3,})\\s+\\d{4}').matcher(s);
                Integer month = 1;
                if (m2.find()) {
                    month = monthStringToInt(m2.group(1));
                }
                return Date.newInstance(year, month, 1);
            }
            // try parse month year like "Aug 2025"
            Matcher m3 = Pattern.compile('([A-Za-z]{3,})\\s+(\\d{4})').matcher(s);
            if (m3.find()) {
                Integer year = Integer.valueOf(m3.group(2));
                Integer month = monthStringToInt(m3.group(1));
                return Date.newInstance(year, month, 1);
            }
        } catch (Exception e) {}
        return null;
    }

    private static Integer monthStringToInt(String s) {
        if (s == null) return 1;
        s = s.trim().toLowerCase();
        if (s.startsWith('jan')) return 1;
        if (s.startsWith('feb')) return 2;
        if (s.startsWith('mar')) return 3;
        if (s.startsWith('apr')) return 4;
        if (s.startsWith('may')) return 5;
        if (s.startsWith('jun')) return 6;
        if (s.startsWith('jul')) return 7;
        if (s.startsWith('aug')) return 8;
        if (s.startsWith('sep')) return 9;
        if (s.startsWith('oct')) return 10;
        if (s.startsWith('nov')) return 11;
        if (s.startsWith('dec')) return 12;
        return 1;
    }
}
