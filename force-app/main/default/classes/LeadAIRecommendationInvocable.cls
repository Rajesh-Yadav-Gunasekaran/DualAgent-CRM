public with sharing class LeadAIRecommendationInvocable {
    public class Request {
        @InvocableVariable(required=true)
        public Id leadId;
    }
    @InvocableMethod(
        label='Enqueue AI Recommendation (Lead)'
        description='Enqueues async job to generate and store AI recommendation fields on Lead.'
    )
    public static void enqueue(List<Request> requests) {
        Set<Id> leadIds = new Set<Id>();
        for (Request r : requests) {
            if (r != null && r.leadId != null) leadIds.add(r.leadId);
        }
        if (!leadIds.isEmpty()) { 
            System.enqueueJob(new LeadAIRecommendationQueueable(new List<Id>(leadIds)));
        }
    }
}