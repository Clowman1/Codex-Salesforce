import { LightningElement, api, wire } from 'lwc';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';

const NAME_FIELD = 'Account.Name';
const OPTIONAL_FIELDS = [
    'Account.IsPersonAccount',
    'Account.Phone',
    'Account.PersonEmail',
    'Account.Type',
    'Account.Type__c',
    'Account.Company__c',
    'Account.Realtor_Group__r.Name',
    'Account.Borrower_Rating__c',
    'Account.Owner.Name',
    'Account.Preferred_LO__r.Name',
    'Account.Follow_Up_LO__r.Name',
    'Account.Last_RC_SMS__c'
];

export default class AccountRecordHero extends LightningElement {
    @api recordId;
    accountRecord;
    error;

    @wire(getRecord, { recordId: '$recordId', fields: [NAME_FIELD], optionalFields: OPTIONAL_FIELDS })
    wiredAccount({ data, error }) {
        if (data) {
            this.accountRecord = data;
            this.error = undefined;
        } else if (error) {
            this.accountRecord = undefined;
            this.error = error;
        }
    }

    get isLoading() {
        return !this.error && !this.accountRecord;
    }

    get name() {
        return this.fieldValue(NAME_FIELD) || 'Person Account';
    }

    get phone() {
        return this.fieldValue('Account.Phone');
    }

    get email() {
        return this.fieldValue('Account.PersonEmail');
    }

    get chips() {
        return [
            this.fieldValue('Account.Type__c') || this.fieldValue('Account.Type'),
            this.fieldValue('Account.Company__c') || this.fieldValue('Account.Realtor_Group__r.Name'),
            this.fieldValue('Account.Borrower_Rating__c')
        ].filter(Boolean);
    }

    get ownerName() {
        return this.fieldValue('Account.Owner.Name') || 'Not assigned';
    }

    get preferredLoName() {
        return this.fieldValue('Account.Preferred_LO__r.Name') || 'Not assigned';
    }

    get followUpLoName() {
        return this.fieldValue('Account.Follow_Up_LO__r.Name') || 'Not assigned';
    }

    get lastSms() {
        return this.fieldValue('Account.Last_RC_SMS__c') || 'None logged';
    }

    fieldValue(fieldName) {
        return this.accountRecord ? getFieldValue(this.accountRecord, fieldName) : null;
    }
}
