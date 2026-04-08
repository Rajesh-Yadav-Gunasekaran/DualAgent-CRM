public with sharing class GenerateOutreachSequenceJob implements Queueable, Database.AllowsCallouts {
    private final List<Id> leadIds;

    public GenerateOutreachSequenceJob(List<Id> leadIds)  {
        this.leadIds = (leadIds == null)? new List<Id>() : leadIds;
    }

    public void execute(QueueableContext context) {
        if (leadIds.isEmpty()) return;

        List<Lead> leads = [SELECT Id, FirstName, LastName, Company, Title, Email, LeadSource, Description,
                   AI_Priority_Bucket__c, AI_Next_Action__c, AI_Talking_Points__c, AI_Reason_Summary__c,
                   AWS_Sequence_Status__c
            FROM Lead
            WHERE Id IN :leadIds];

        List<Lead_Outreach_Draft__c> draftsToInsert = new List<Lead_Outreach_Draft__c>();
        List<Lead> leadsToUpdate = new List<Lead>();

        // Optional: clear older drafts so only latest sequence remains
        List<Lead_Outreach_Draft__c> existingDrafts = [
            SELECT Id
            FROM Lead_Outreach_Draft__c
            WHERE Lead__c IN :leadIds
        ];
        if (!existingDrafts.isEmpty()) {
            delete existingDrafts;
        }



        for (Lead ld : leads) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('callout:AWS_BEDROCK_API/lead-sequence');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setTimeout(20000);
                req.setBody(SequencePayloadBuilder.build(ld));

                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                    leadsToUpdate.add(new Lead(
                        Id = ld.Id,
                        AWS_Sequence_Status__c = 'Failed',
                        AWS_Sequence_Error__c = 'HTTP ' + res.getStatusCode() + ': ' + res.getBody()
                    ));
                    continue;
                }

                OutreachSequenceResponse dto = OutreachSequenceParser.parse(res.getBody());

                if (dto != null && dto.items != null) {
                    for (OutreachSequenceResponse.SequenceItem item : dto.items) {
                        draftsToInsert.add(new Lead_Outreach_Draft__c(
                            Lead__c = ld.Id,
                            Touch_Number__c = item.touch,
                            Channel__c = item.channel,
                            Send_Offset_Days__c = item.send_offset_days,
                            Subject_Options__c = item.subject_options == null ? null : String.join(item.subject_options, '\n'),
                            Body_Professional__c = item.body_professional,
                            Body_Executive__c = item.body_executive,
                            Body_Friendly__c = item.body_friendly,
                            Call_Opener__c = item.call_opener,
                            Voicemail__c = item.voicemail,
                            Fallback_Email_Subject__c = item.fallback_email_subject,
                            Fallback_Email_Body__c = item.fallback_email_body,
                            Sequence_Version__c = dto.sequence_version
                        ));
                    }
                }

                leadsToUpdate.add(new Lead(
                    Id = ld.Id,
                    AWS_Sequence_Status__c = 'Complete',
                    AWS_Sequence_Generated_On__c = System.now(),
                    AWS_Sequence_Error__c = null
                ));

            } catch (Exception ex) {
                leadsToUpdate.add(new Lead(
                    Id = ld.Id,
                    AWS_Sequence_Status__c = 'Failed',
                    AWS_Sequence_Error__c = ex.getMessage()
                ));
            }
        }

        if (!draftsToInsert.isEmpty()) {
            insert draftsToInsert;
        }

        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
        }
    }

}