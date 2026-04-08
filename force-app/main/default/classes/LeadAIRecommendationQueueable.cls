public with sharing class LeadAIRecommendationQueueable implements Queueable, Database.AllowsCallouts {
    private final List<Id> leadIds;

    public LeadAIRecommendationQueueable(List<Id> leadIds) {
        this.leadIds = (leadIds == null) ? new List<Id>() : leadIds;
    }

    public void execute(QueueableContext qc) {
        if (leadIds.isEmpty()) return;

        // Query only what we need (and the guard field)
        List<Lead> leads = [
            SELECT Id, AI_Last_Generated__c
            FROM Lead
            WHERE Id IN :leadIds
        ];

        List<Lead> updates = new List<Lead>();
        List<Id> awsLeadIds = new List<Id>();

        for (Lead l : leads) {
            // Safe guard: only auto-generate once on create
            if (l.AI_Last_Generated__c != null) continue;

            try{
            LeadAIRecommendationService.RecommendationDTO dto =
                LeadAIRecommendationService.getRecommendation(l.Id);

            updates.add(new Lead(
                Id = l.Id,
                AI_Priority_Bucket__c = dto.priorityBucket,
                AI_Next_Action__c     = dto.nextAction,
                AI_Talking_Points__c  = LeadAIRecommendationService.formatBullets(dto.talkingPoints),
                AI_Reason_Summary__c  = LeadAIRecommendationService.formatBullets(dto.reasonSummary),
                AI_Last_Generated__c  = System.now(),
                AWS_Sequence_Status__c = 'Queued',
                AWS_Sequence_Error__c = null
            ));
            awsLeadIds.add(l.Id);
            }
            catch (Exception ex) {
                updates.add(new Lead(
                    Id = l.Id,
                    AWS_Sequence_Status__c = 'Failed',
                    AWS_Sequence_Error__c = 'Agentforce recommendation failed: ' + ex.getMessage()
                ));
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
        if (!awsLeadIds.isEmpty()) {
            System.enqueueJob(new GenerateOutreachSequenceJob(awsLeadIds));
        }
    }
}