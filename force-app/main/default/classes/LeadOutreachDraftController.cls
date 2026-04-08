public with sharing class LeadOutreachDraftController {
    @AuraEnabled(cacheable=true)
    public static List<Lead_Outreach_Draft__c> getDrafts(Id leadId) {
        if (leadId == null) {
            return new List<Lead_Outreach_Draft__c>();
        }

        return [
            SELECT Id,
                   Touch_Number__c,
                   Channel__c,
                   Send_Offset_Days__c,
                   Subject_Options__c,
                   Body_Professional__c,
                   Body_Executive__c,
                   Body_Friendly__c,
                   Call_Opener__c,
                   Voicemail__c,
                   Fallback_Email_Subject__c,
                   Fallback_Email_Body__c,
                   Sequence_Version__c
            FROM Lead_Outreach_Draft__c
            WHERE Lead__c = :leadId
            ORDER BY Touch_Number__c ASC
        ];
    }
}