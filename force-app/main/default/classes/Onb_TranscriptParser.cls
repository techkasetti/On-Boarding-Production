public with sharing class Onb_TranscriptParser {
    public class ChatMessage {
        public String author;
        public String text;
        public Datetime at;
        public String channel;
    }

    public static List<ChatMessage> parseMessages(String transcriptJson) {
        List<ChatMessage> out = new List<ChatMessage>();
        if (String.isBlank(transcriptJson)) return out;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(transcriptJson);
            if (root.containsKey('messages')) {
                for (Object o : (List<Object>) root.get('messages')) {
                    Map<String,Object> m = (Map<String,Object>) o;
                    ChatMessage cm = new ChatMessage();
                    cm.author = (String) m.get('author');
                    cm.text = (String) m.get('text');
                    cm.channel = (String) m.get('channel');
                    if (m.containsKey('at') && m.get('at') != null) {
                        cm.at = Datetime.valueOfGmt((String) m.get('at'));
                    } else {
                        cm.at = Datetime.now();
                    }
                    out.add(cm);
                }
            }
        } catch (Exception e) {
            // swallow and return empty
        }
        return out;
    }

    public static String appendMessage(String transcriptJson, String author, String text, String channel) {
        Map<String, Object> root;
        if (String.isBlank(transcriptJson)) {
            root = new Map<String, Object>{ 'messages' => new List<Object>() };
        } else {
            try {
                root = (Map<String, Object>) JSON.deserializeUntyped(transcriptJson);
                if (!root.containsKey('messages')) root.put('messages', new List<Object>());
            } catch (Exception e) {
                root = new Map<String, Object>{ 'messages' => new List<Object>() };
            }
        }
        List<Object> msgs = (List<Object>) root.get('messages');
        Map<String,Object> m = new Map<String,Object>{ 
            'author' => author, 
            'text' => text, 
            'channel' => channel,
            'at' => Datetime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
        };
        msgs.add(m);
        root.put('messages', msgs);
        return JSON.serialize(root);
    }
}
