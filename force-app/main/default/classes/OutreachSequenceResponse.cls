public with sharing class OutreachSequenceResponse {
    public String sequence_version;
    public List<SequenceItem> items;

    public class SequenceItem {
        public Integer touch;
        public String channel;
        public Integer send_offset_days;
        public List<String> subject_options;
        public String body_professional;
        public String body_executive;
        public String body_friendly;
        public String call_opener;
        public String voicemail;
        public String fallback_email_subject;
        public String fallback_email_body;
    }
}