@IsTest
private class ParsedJsonNormalizerTest {
    @IsTest
    static void testNormalize_WithCertsAndExperience() {
        Map<String, Object> parsed = new Map<String, Object>{
            'licensesAndCertifications' => new Map<String, Object>{
                'value' => new List<Object>{
                    'Medical Council Registration',
                    'BLS Provider',
                    'ACLS'
                }
            },
            'workExperience' => new Map<String, Object>{
                'value' => new Map<String, Object>{
                    'duration' => 'Jan 2021 - Present'
                }
            }
        };

        Map<String, Object> normalized = ParsedJsonNormalizer.normalize(parsed);

        System.assertEquals(true, normalized.get('has_med_registration'));
        System.assertEquals(true, normalized.get('has_bls'));
        System.assertEquals(true, normalized.get('has_acls'));
        System.assert(((Integer) normalized.get('experience_years_calculated')) >= 1);
    }

    @IsTest
    static void testNormalize_NullAndInvalidShape() {
        Map<String, Object> normalizedNull = ParsedJsonNormalizer.normalize(null);
        System.assertEquals(false, normalizedNull.get('has_med_registration'));
        System.assertEquals(false, normalizedNull.get('has_bls'));
        System.assertEquals(false, normalizedNull.get('has_acls'));
        System.assertEquals(0, normalizedNull.get('experience_years_calculated'));

        Map<String, Object> malformed = new Map<String, Object>{
            'licensesAndCertifications' => 'unexpected',
            'workExperience' => new Map<String, Object>{
                'value' => new Map<String, Object>{ 'duration' => 'N/A' }
            }
        };
        Map<String, Object> normalizedMalformed = ParsedJsonNormalizer.normalize(malformed);
        System.assertEquals(false, normalizedMalformed.get('has_med_registration'));
        System.assertEquals(0, normalizedMalformed.get('experience_years_calculated'));
    }
}
