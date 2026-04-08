public with sharing class OutreachSequenceParser {
    public static OutreachSequenceResponse parse(String responseBody) {
        try{
            return (OutreachSequenceResponse) JSON.deserialize(responseBody, OutreachSequenceResponse.class);
        }
        catch(Exception ex)
        {
            throw new AuraHandledException('Failed to parse AWS Outreach Sequence Response: ' + ex.getMessage());
        }
        
    }
}