import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import STATUS_FIELD from '@salesforce/schema/Transaction__c.Status__c';
import MERS_MIN_FIELD from '@salesforce/schema/Transaction__c.MERS_Min__c';
import USER_NAME_FIELD from '@salesforce/schema/User.Name';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';

const FIELDS = [STATUS_FIELD, MERS_MIN_FIELD];
const USER_FIELDS = [USER_NAME_FIELD, PROFILE_NAME_FIELD];

const WIRE_CALCULATOR_USERS = ['Christopher Lowman', 'Jamie Martinez', 'Monica Quintero'];

const ACTIONS = [
    { label: 'Wire Calculator', apiName: 'Transaction__c.Wire_Calculator', tone: 'green', visibleForUsers: WIRE_CALCULATOR_USERS },
    { label: 'Order Appraisal', apiName: 'Transaction__c.Order_Appraisal_Direct', tone: 'blue', hideForLoanOfficer: true },
    { label: 'COC Request', apiName: 'Transaction__c.Change_of_Circumstances', tone: 'slate' },
    { label: 'Cancel Loan', apiName: 'Transaction__c.Cancel_Loan', tone: 'red', hideForLoanOfficer: true },
    { label: 'Closing Portal', apiName: 'Transaction__c.Closing_Portal', tone: 'blue', hideForLoanOfficer: true },
    { label: 'Fetch ValueLink', apiName: 'Transaction__c.Fetch_ValueLink_Reports', tone: 'slate', hideForLoanOfficer: true },
    { label: 'Create Title Agent', apiName: 'Transaction__c.Create_Title_Agent', tone: 'orange', hideForLoanOfficer: true },
    { label: 'Update UWM', apiName: 'Transaction__c.Update_Data_From_UWM', tone: 'blue' },
    { label: 'Commitment Letter', apiName: 'Transaction__c.Commitment_Letter', tone: 'slate', hideForLoanOfficer: true },
    { label: 'Sync ARIVE', apiName: 'Transaction__c.Sync_With_Arive', tone: 'blue' },
    { label: 'Application Template', apiName: 'Transaction__c.Application_Template', tone: 'orange' },
    { label: 'Submission Form', apiName: 'Transaction__c.Submission_Form_Modern', tone: 'orange', status: 'TRID Application' },
    { label: 'Create DPA 2nd', apiName: 'Transaction__c.Create_DPA_Second_Transaction', tone: 'slate', hideForLoanOfficer: true },
    { label: 'Back Under Contract', apiName: 'Transaction__c.Back_Under_Contract', tone: 'green', status: 'Cancelled' },
    { label: 'Revert to Closing', apiName: 'Transaction__c.Revert_To_Closing', tone: 'slate', status: 'Funding' },
    { label: 'MERS Min Capture', apiName: 'Transaction__c.MERS_Min_Capture', tone: 'orange', showWhenMersBlank: true, hideForProcessor: true },
    { label: 'Add to Closing Queue', apiName: 'Transaction__c.Add_to_Closing_Queue', tone: 'green', hideForLoanOfficer: true },
    { label: 'Exclude From MCR', apiName: 'Transaction__c.Exclude_From_MCR', tone: 'red', adminOnly: true }
];

export default class TransactionQuickActions extends NavigationMixin(LightningElement) {
    @api recordId;

    status;
    mersMin;
    userName;
    profileName;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data }) {
        if (!data) {
            return;
        }

        this.status = data.fields.Status__c?.value;
        this.mersMin = data.fields.MERS_Min__c?.value;
    }

    @wire(getRecord, { recordId: USER_ID, fields: USER_FIELDS })
    wiredUser({ data }) {
        if (!data) {
            return;
        }

        this.userName = data.fields.Name?.value || '';
        const profile = data.fields.Profile;
        this.profileName = profile?.displayValue || profile?.value?.fields?.Name?.value || '';
    }

    get isLoanOfficerProfile() {
        return (this.profileName || '').toLowerCase().includes('loan officer');
    }

    get isProcessorProfile() {
        return (this.profileName || '').toLowerCase().includes('processor');
    }

    get isAdminProfile() {
        const normalizedProfile = (this.profileName || '').toLowerCase();
        return normalizedProfile.includes('admin');
    }

    get visibleActions() {
        return ACTIONS
            .filter((action) => {
                if (action.visibleForUsers && !action.visibleForUsers.includes(this.userName)) {
                    return false;
                }
                if (action.adminOnly && !this.isAdminProfile) {
                    return false;
                }
                if (action.hideForLoanOfficer && this.isLoanOfficerProfile) {
                    return false;
                }
                if (action.hideForProcessor && this.isProcessorProfile) {
                    return false;
                }
                if (action.status && action.status !== this.status) {
                    return false;
                }
                if (action.showWhenMersBlank && this.mersMin) {
                    return false;
                }
                return true;
            })
            .map((action) => ({
                ...action,
                className: `pill pill-${action.tone}`
            }));
    }

    openQuickAction(event) {
        const apiName = event.currentTarget.dataset.api;
        if (!apiName) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName
            },
            state: {
                recordId: this.recordId
            }
        });
    }
}
