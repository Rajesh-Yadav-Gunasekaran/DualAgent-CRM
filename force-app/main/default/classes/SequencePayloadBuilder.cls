public with sharing class SequencePayloadBuilder {
    public static String build(Lead ld) {
        Map<String, Object> payload = new Map<String, Object>();

        payload.put('leadId', ld.Id);

        payload.put('lead', new Map<String, Object>{
            'name' => buildName(ld.FirstName, ld.LastName),
            'company' => ld.Company,
            'title' => ld.Title,
            'email' => ld.Email,
            'leadSource' => ld.LeadSource,
            'description' => ld.Description
        });

        payload.put('agentforce_recommendation', new Map<String, Object>{
            'priority_bucket' => ld.AI_Priority_Bucket__c,
            'next_action' => ld.AI_Next_Action__c,
            'talking_points' => splitBullets(ld.AI_Talking_Points__c),
            'reason_summary' => splitBullets(ld.AI_Reason_Summary__c)
        });

        payload.put('generation_rules', new Map<String, Object>{
            'agentforce_decision_is_authoritative' => true,
            'do_not_override_next_action' => true,
            'do_not_change_priority_bucket' => true,
            'touches' => 3,
            'tones' => new List<String>{ 'professional', 'executive', 'friendly' }
        });

        return JSON.serialize(payload);
    }

    private static List<String> splitBullets(String value) {
        if (String.isBlank(value)) return new List<String>();

        List<String> lines = value.split('\n');
        List<String> cleaned = new List<String>();

        for (String line : lines) {
            if (String.isBlank(line)) continue;
            String trimmed = line.trim();
            if (trimmed.startsWith('•')) {
                trimmed = trimmed.substring(1).trim();
            } else if (trimmed.startsWith('-')) {
                trimmed = trimmed.substring(1).trim();
            }
            cleaned.add(trimmed);
        }
        return cleaned;
    }

    private static String buildName(String firstName, String lastName) {
        String fullName = '';
        if (!String.isBlank(firstName)) fullName += firstName;
        if (!String.isBlank(lastName)) {
            if (!String.isBlank(fullName)) fullName += ' ';
            fullName += lastName;
        }
        return fullName;
    }
}