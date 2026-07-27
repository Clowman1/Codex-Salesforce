import { LightningElement, api, wire } from 'lwc';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';

const NAME_FIELD = 'Lead.Name';
const OPTIONAL_FIELDS = [
    'Lead.Phone',
    'Lead.Email',
    'Lead.Status',
    'Lead.LeadSource',
    'Lead.Rating',
    'Lead.Loan_Purpose__c',
    'Lead.Owner.Name',
    'Lead.Loan_Partner__r.Name',
    'Lead.Biz_Dev__c',
    'Lead.Realtor_Buying_Agent__r.Name'
];

export default class LeadRecordHero extends LightningElement {
    @api recordId;
    leadRecord;
    error;

    @wire(getRecord, { recordId: '$recordId', fields: [NAME_FIELD], optionalFields: OPTIONAL_FIELDS })
    wiredLead({ data, error }) {
        if (data) {
            this.leadRecord = data;
            this.error = undefined;
        } else if (error) {
            this.leadRecord = undefined;
            this.error = error;
        }
    }

    get isLoading() {
        return !this.error && !this.leadRecord;
    }

    get name() {
        return this.fieldValue(NAME_FIELD);
    }

    get phone() {
        return this.fieldValue('Lead.Phone');
    }

    get email() {
        return this.fieldValue('Lead.Email');
    }

    get chips() {
        return [
            this.fieldValue('Lead.Status'),
            this.fieldValue('Lead.LeadSource'),
            this.fieldValue('Lead.Rating'),
            this.fieldValue('Lead.Loan_Purpose__c')
        ].filter(Boolean);
    }

    get ownerName() {
        return this.fieldValue('Lead.Owner.Name') || 'Not assigned';
    }

    get loanPartnerName() {
        return this.fieldValue('Lead.Loan_Partner__r.Name') || 'Not assigned';
    }

    get bizDev() {
        return this.fieldValue('Lead.Biz_Dev__c') || 'Not assigned';
    }

    get buyersAgentName() {
        return this.fieldValue('Lead.Realtor_Buying_Agent__r.Name') || 'PLACE Holder';
    }

    fieldValue(fieldName) {
        return this.leadRecord ? getFieldValue(this.leadRecord, fieldName) : null;
    }
}
