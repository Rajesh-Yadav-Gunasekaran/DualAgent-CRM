import { LightningElement, api, wire } from 'lwc';
import getRecommendation from '@salesforce/apex/LeadAIRecommendationService.getRecommendation';
import applyRecommendationToLead from '@salesforce/apex/LeadAIRecommendationService.applyRecommendation';
import getDrafts from '@salesforce/apex/LeadOutreachDraftController.getDrafts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';

import AI_PRIORITY_BUCKET from '@salesforce/schema/Lead.AI_Priority_Bucket__c';
import AI_NEXT_ACTION from '@salesforce/schema/Lead.AI_Next_Action__c';
import AI_TALKING_POINTS from '@salesforce/schema/Lead.AI_Talking_Points__c';
import AI_REASON_SUMMARY from '@salesforce/schema/Lead.AI_Reason_Summary__c';
import AI_LAST_GENERATED from '@salesforce/schema/Lead.AI_Last_Generated__c';

import AWS_SEQUENCE_STATUS from '@salesforce/schema/Lead.AWS_Sequence_Status__c';
import AWS_SEQUENCE_ERROR from '@salesforce/schema/Lead.AWS_Sequence_Error__c';
import AWS_SEQUENCE_GENERATED_ON from '@salesforce/schema/Lead.AWS_Sequence_Generated_On__c';

const LEAD_FIELDS = [
    AI_PRIORITY_BUCKET,
    AI_NEXT_ACTION,
    AI_TALKING_POINTS,
    AI_REASON_SUMMARY,
    AI_LAST_GENERATED,
    AWS_SEQUENCE_STATUS,
    AWS_SEQUENCE_ERROR,
    AWS_SEQUENCE_GENERATED_ON
];

export default class LeadActionCoach extends LightningElement {
    @api recordId;
    isBusy = false;
    error;
    recommendation;
    leadRecord;
    drafts = [];

    wiredLeadResult;
    wiredDraftsResult;

    @wire(getRecord, { recordId: '$recordId', fields: LEAD_FIELDS })
    wiredLead(result) {
        this.wiredLeadResult = result;
        if (result.data) {
            this.leadRecord = result.data;
        } else if (result.error) {
            this.error = this.normalizeError(result.error);
        }
    }

    @wire(getDrafts, { leadId: '$recordId' })
    wiredDrafts(result) {
        this.wiredDraftsResult = result;
        if (result.data) {
            this.drafts = result.data.map(draft => {
                return {
                    ...draft,
                    isEmail: draft.Channel__c === 'EMAIL',
                    isCall: draft.Channel__c === 'CALL',
                    subjectOptionsList: draft.Subject_Options__c
                        ? draft.Subject_Options__c.split('\n').filter(x => x)
                        : []
                };
            });
        } else if (result.error) {
            this.error = this.normalizeError(result.error);
            this.drafts = [];
        }
    }

    async handleGenerate() {
        this.isBusy = true;
        this.error = null;

        try {
            this.recommendation = await getRecommendation({ leadId: this.recordId });

            if (!this.recommendation) {
                throw new Error('AI response was not valid JSON. Check your prompt to return ONLY JSON.');
            }

            this.toast('Recommendation generated', 'Success', 'success');
        } catch (e) {
            this.error = this.normalizeError(e);
        } finally {
            this.isBusy = false;
        }
    }

    async handleApply() {
        this.error = null;
        this.isBusy = true;

        try {
            await applyRecommendationToLead({
                leadId: this.recordId,
                recommendationJson: JSON.stringify(this.recommendation)
            });

            await Promise.all([
                refreshApex(this.wiredLeadResult),
                refreshApex(this.wiredDraftsResult)
            ]);

            this.toast('Recommendation applied to Lead fields', 'Success', 'success');
        } catch (e) {
            this.error = this.normalizeError(e);
        } finally {
            this.isBusy = false;
        }
    }

    async handleClear() {
        this.error = null;
        this.recommendation = null;

        await Promise.all([
            refreshApex(this.wiredLeadResult),
            refreshApex(this.wiredDraftsResult)
        ]);
    }

    get recommendationToShow() {
        if (this.recommendation) {
            return this.recommendation;
        }

        const bucket = getFieldValue(this.leadRecord, AI_PRIORITY_BUCKET);
        const nextAction = getFieldValue(this.leadRecord, AI_NEXT_ACTION);
        const talkingPoints = this.toBulletList(getFieldValue(this.leadRecord, AI_TALKING_POINTS));
        const reasonSummary = this.toBulletList(getFieldValue(this.leadRecord, AI_REASON_SUMMARY));

        if (!bucket && !nextAction) {
            return null;
        }

        return {
            priorityBucket: bucket,
            nextAction: nextAction,
            talkingPoints: talkingPoints,
            reasonSummary: reasonSummary
        };
    }

    get savedRecommendationTimestamp() {
        return getFieldValue(this.leadRecord, AI_LAST_GENERATED);
    }

    get awsSequenceStatus() {
        return getFieldValue(this.leadRecord, AWS_SEQUENCE_STATUS);
    }

    get awsSequenceError() {
        return getFieldValue(this.leadRecord, AWS_SEQUENCE_ERROR);
    }

    get awsSequenceGeneratedOn() {
        return getFieldValue(this.leadRecord, AWS_SEQUENCE_GENERATED_ON);
    }

    get hasDrafts() {
        return this.drafts && this.drafts.length > 0;
    }

    get isApplyDisabled() {
        return this.isBusy || !this.recommendation;
    }

    get isClearDisabled() {
        return this.isBusy || (!this.recommendation && !this.hasDrafts && !this.recommendationToShow);
    }

    toBulletList(value) {
        if (!value) return [];
        return value
            .split('\n')
            .map(line => line.replace(/^[-•]\s*/, '').trim())
            .filter(line => line);
    }

    normalizeError(e) {
        if (Array.isArray(e?.body)) return e.body.map(x => x.message).join(', ');
        return e?.body?.message || e?.message || 'Unknown error';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}