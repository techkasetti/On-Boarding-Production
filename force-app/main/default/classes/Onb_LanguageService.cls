public with sharing class Onb_LanguageService {
    public class DetectResult {
        public String language;
        public Decimal confidence;
    }

    /**
     * Detect language using Named Credential TranslateAPI.
     * Returns language code (e.g. 'en', 'hi').
     * Note: this method performs an HTTP callout; must be called from a context allowing callouts (Queueable with AllowsCallouts or a @future(callout=true) etc).
     */
    public static DetectResult detectLanguage(String text) {
        DetectResult dr = new DetectResult();
        dr.language = 'en';
        dr.confidence = 0;
        if (String.isBlank(text)) return dr;

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        // Using Named Credential with callout: prefix — the path appended depends on provider API.
        req.setEndpoint('callout:TranslateAPI/detect');
        req.setMethod('POST');
        req.setHeader('Content-Type','application/json');
        Map<String,Object> payload = new Map<String,Object>{ 'q' => text };
        req.setBody(JSON.serialize(payload));

        HttpResponse res = http.send(req);
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            try {
                Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
                // adapt to provider structure - try common keys
                if (root.containsKey('language')) dr.language = String.valueOf(root.get('language'));
                else if (root.containsKey('data')) {
                    // e.g., Google structure: data.detections[0][0].language
                    Map<String,Object> data = (Map<String,Object>) root.get('data');
                    if (data.containsKey('detections')) {
                        Object dets = data.get('detections');
                        // best-effort extraction
                        // skip deep parsing for brevity
                    }
                }
                // optional confidence
                if (root.containsKey('confidence')) {
                    dr.confidence = Decimal.valueOf(String.valueOf(root.get('confidence')));
                }
            } catch (Exception e) {
                // ignore parse errors: return default
            }
        }
        return dr;
    }

    /**
     * Translate entire text into targetLang (e.g. 'en').
     * Returns translated text or original if translation fails.
     */
    public static String translateText(String text, String targetLang) {
        if (String.isBlank(text) || String.isBlank(targetLang)) return text;
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:TranslateAPI/translate');
        req.setMethod('POST');
        req.setHeader('Content-Type','application/json');
        req.setBody(JSON.serialize(new Map<String,Object>{ 'q' => text, 'target' => targetLang }));

        HttpResponse res = http.send(req);
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            try {
                Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
                // Provider-specific: try common keys
                if (root.containsKey('translatedText')) return String.valueOf(root.get('translatedText'));
                if (root.containsKey('data')) {
                    Map<String,Object> data = (Map<String,Object>) root.get('data');
                    if (data.containsKey('translations')) {
                        List<Object> translations = (List<Object>) data.get('translations');
                        if (!translations.isEmpty()) {
                            Map<String,Object> t = (Map<String,Object>) translations[0];
                            if (t.containsKey('translatedText')) return String.valueOf(t.get('translatedText'));
                        }
                    }
                }
                // fallback: return full body
                return res.getBody();
            } catch (Exception e) {
                return text;
            }
        }
        return text;
    }
}
