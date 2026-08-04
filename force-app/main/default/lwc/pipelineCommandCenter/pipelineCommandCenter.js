import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDashboardData from '@salesforce/apex/PipelineCommandCenterController.getDashboardData';
import getPastClientRowsByYear from '@salesforce/apex/PipelineCommandCenterController.getPastClientRowsByYear';
import getNickleyRealtorRows from '@salesforce/apex/PipelineCommandCenterController.getNickleyRealtorRows';
import passPreApprovalFollowUp from '@salesforce/apex/PipelineCommandCenterController.passPreApprovalFollowUp';
import getListViewOptions from '@salesforce/apex/PipelineCommandCenterController.getListViewOptions';
import getRealtorPartnerFormOptions from '@salesforce/apex/PipelineCommandCenterController.getRealtorPartnerFormOptions';
import getNewLeadFormOptions from '@salesforce/apex/PipelineCommandCenterController.getNewLeadFormOptions';
import saveUserQuickButtons from '@salesforce/apex/PipelineCommandCenterController.saveUserQuickButtons';
import saveProcessorNote from '@salesforce/apex/PipelineCommandCenterController.saveProcessorNote';
import saveManagerNote from '@salesforce/apex/PipelineCommandCenterController.saveManagerNote';
import saveAccountNote from '@salesforce/apex/PipelineCommandCenterController.saveAccountNote';
import saveLeadNote from '@salesforce/apex/PipelineCommandCenterController.saveLeadNote';
import createTransactionEvent from '@salesforce/apex/PipelineCommandCenterController.createTransactionEvent';
import createAccountEvent from '@salesforce/apex/PipelineCommandCenterController.createAccountEvent';
import createLeadEvent from '@salesforce/apex/PipelineCommandCenterController.createLeadEvent';
import markBrokerCheckReceived from '@salesforce/apex/PipelineCommandCenterController.markBrokerCheckReceived';
import clearAccountPhoneNumber from '@salesforce/apex/PipelineCommandCenterController.clearAccountPhoneNumber';
import markAccountPropertySold from '@salesforce/apex/PipelineCommandCenterController.markAccountPropertySold';
import createRealtorPartner from '@salesforce/apex/PipelineCommandCenterController.createRealtorPartner';
import createConsumerLead from '@salesforce/apex/PipelineCommandCenterController.createConsumerLead';
import createRealtorLead from '@salesforce/apex/PipelineCommandCenterController.createRealtorLead';
import createTitleAgentAccount from '@salesforce/apex/PipelineCommandCenterController.createTitleAgentAccount';
import saveUserColumnPreferences from '@salesforce/apex/PipelineCommandCenterController.saveUserColumnPreferences';

const OBJECT_OPTIONS = [
    { label: 'Transactions', value: 'Transaction__c' },
    { label: 'Leads', value: 'Lead' },
    { label: 'Accounts', value: 'Account' },
    { label: 'Cases', value: 'Case' },
    { label: 'Conditions', value: 'TransactionCondition__c' }
];
const DASHBOARD_REFRESH_INTERVAL_MS = 300000;
const DASHBOARD_FOCUS_REFRESH_STALE_MS = 120000;
const TAB_ORDER_STORAGE_PREFIX = 'reach-pcc-tab-order';
const MASTER_GROUP_ORDER_STORAGE_PREFIX = 'reach-pcc-master-group-order';
const ADAM_STEPHENS_USER_ID = '005f2000009BuuaAAC';
const MAX_SELECTED_COLUMNS = 14;

const COMMAND_CENTER_COLUMNS = [
    { key: 'name', label: 'Name', objects: ['Lead', 'Transaction__c', 'Account'], required: true },
    { key: 'status', label: 'Status', objects: ['Lead', 'Transaction__c'] },
    { key: 'phone', label: 'Phone', objects: ['Lead', 'Transaction__c', 'Account'] },
    { key: 'email', label: 'Email', objects: ['Lead', 'Transaction__c', 'Account'] },
    { key: 'createdDate', label: 'Created Date', objects: ['Lead'] },
    { key: 'lastActivityDate', label: 'Last Activity Date', objects: ['Lead'] },
    { key: 'appointmentDateTime', label: 'Next Appointment Date', objects: ['Lead'] },
    { key: 'leadSource', label: 'Lead Source', objects: ['Lead'] },
    { key: 'bizDev', label: 'Biz Dev', objects: ['Lead', 'Transaction__c'] },
    { key: 'loanPartnerName', label: 'Loan Partner', objects: ['Lead', 'Transaction__c'] },
    { key: 'realtorBuyingAgent', label: 'Realtor - Buying Agent', objects: ['Lead'] },
    { key: 'loanDetails', label: 'Loan Details', objects: ['Lead'] },
    { key: 'loanPurpose', label: 'Purpose', objects: ['Lead', 'Transaction__c', 'Account'] },
    { key: 'loanAmount', label: 'Amount', objects: ['Lead', 'Transaction__c'] },
    { key: 'closingDate', label: 'Closing Date', objects: ['Transaction__c', 'Account'] },
    { key: 'fundingDate', label: 'Funding Date', objects: ['Transaction__c'] },
    { key: 'processorName', label: 'Processor', objects: ['Transaction__c'] },
    { key: 'detail', label: 'Processor Note', objects: ['Transaction__c'] },
    { key: 'lastProcessorSms', label: 'Last Processor SMS', objects: ['Transaction__c'] },
    { key: 'lastProcessorCall', label: 'Last Processor Call', objects: ['Transaction__c'] },
    { key: 'lenderName', label: 'Lender', objects: ['Transaction__c'] },
    { key: 'loanOfficerName', label: 'Loan Officer', objects: ['Transaction__c'] },
    { key: 'ownerName', label: 'Owner', objects: ['Lead', 'Transaction__c'] },
    { key: 'propertyAddress', label: 'Property Address', objects: ['Transaction__c'] },
    { key: 'loanType', label: 'Loan Type', objects: ['Transaction__c', 'Account'] },
    { key: 'rateLockExpDate', label: 'Rate Lock Exp Date', objects: ['Transaction__c'] },
    { key: 'easeLink', label: 'EASE Link', objects: ['Transaction__c'] },
    { key: 'lastContacted', label: 'Last Contacted', objects: ['Account'] },
    { key: 'benLastCall', label: 'Ben Last Call', objects: ['Account'] },
    { key: 'address', label: 'Mailing Address', objects: ['Account'] },
    { key: 'birthday', label: 'Birthday', objects: ['Account'] },
    { key: 'rating', label: 'Rating', objects: ['Account'] }
];

export default class PipelineCommandCenter extends NavigationMixin(LightningElement) {
    statusCards = [];
    pipelineRows = [];
    pipelineTabs = [];
    activePipelineTabKey = 'assigned';
    headerTitle = 'Pipeline Command Center';
    headerSubtitle = 'A focused view for production queues, upcoming closings, and daily review work.';
    isCeoDashboard = false;
    isPastClientDashboard = false;
    isRhettDelaney = false;
    canCreateLead = false;
    canAssignNewLeadOwner = false;
    pipelineTitle = 'Upcoming Pipeline';
    pipelineSubtitle = 'Assigned work ordered by priority.';
    pipelineObjectApiName = 'Transaction__c';
    currentUserId;
    canEditPipelineTabRows = false;
    canEditQuickButtons = true;
    canCreateTitleAgent = false;
    quickButtons = [];
    queueShortcuts = [];
    editableButtons = [];
    columnPreferences = {};
    editableColumns = [];
    listViewOptions = [];
    error;
    editorError;
    rowEditorError;
    columnEditorError;
    isLoading = true;
    isEditorOpen = false;
    isRowEditorOpen = false;
    isColumnEditorOpen = false;
    isProcessorNoteEditorOpen = false;
    isEventEditorOpen = false;
    isBrokerCheckConfirmOpen = false;
    isPastClientConfirmOpen = false;
    isTextPreviewOpen = false;
    isNewLeadFlowOpen = false;
    isNewRealtorPartnerOpen = false;
    isNewRealtorLeadOpen = false;
    isNewTitleAgentOpen = false;
    isSaving = false;
    isNewLeadSaving = false;
    isRowSaving = false;
    isProcessorNoteSaving = false;
    isEventSaving = false;
    isBrokerCheckSaving = false;
    isPastClientActionSaving = false;
    isRealtorPartnerSaving = false;
    isRealtorLeadSaving = false;
    isTitleAgentSaving = false;
    newLeadError;
    hasLoadedNewLeadFormOptions = false;
    newLeadFirstName = '';
    newLeadLastName = '';
    newLeadPhone = '';
    newLeadEmail = '';
    newLeadSource = '';
    newLeadLoanPurpose = '';
    newLeadBizDev = '';
    newLeadOwnerId = '';
    newLeadSourceOptions = [];
    newLeadLoanPurposeOptions = [];
    newLeadBizDevOptions = [];
    newLeadOwnerOptions = [];
    rowEditorTitle = '';
    rowEditorRecordId;
    rowEditorObjectApiName = 'Transaction__c';
    rowEditorFields = [];
    processorNoteError;
    processorNoteTitle = '';
    processorNoteRecordId;
    processorNoteText = '';
    processorNoteMode = 'processor';
    eventEditorError;
    eventEditorTitle = '';
    eventEditorRecordId;
    eventSubject = '';
    eventStartDateTime = '';
    brokerCheckConfirmTitle = '';
    brokerCheckRecordId;
    brokerCheckError;
    pastClientConfirmTitle = '';
    pastClientConfirmMessage = '';
    pastClientConfirmButtonLabel = 'Confirm';
    pastClientConfirmAction = '';
    pastClientConfirmRecordId;
    pastClientConfirmError;
    textPreviewTitle = '';
    textPreviewBody = '';
    realtorPartnerError;
    realtorPartnerFirstName = '';
    realtorPartnerLastName = '';
    realtorPartnerMobilePhone = '';
    realtorPartnerEmail = '';
    realtorPartnerBizDevDesignation = '';
    realtorPartnerBrokerage = '';
    realtorPartnerGroup = '';
    realtorPartnerTransactionCoordinatorId;
    realtorPartnerIndividualLicenseNumber = '';
    realtorPartnerCompanyLicenseNumber = '';
    realtorPartnerBizDevOptions = [];
    realtorPartnerGroupOptions = [];
    realtorLeadError;
    realtorLeadFirstName = '';
    realtorLeadLastName = '';
    realtorLeadPhone = '';
    realtorLeadEmail = '';
    realtorLeadSource = '';
    realtorLeadNotes = '';
    titleAgentError;
    titleAgentName = '';
    titleAgentPhone = '';
    titleAgentEmail = '';
    sortField = 'displayDateTime';
    sortDirection = 'asc';
    wiredDashboardResult;
    refreshTimer;
    boundWindowFocusHandler;
    boundVisibilityChangeHandler;
    isRefreshingDashboard = false;
    lastDashboardRefreshAt = 0;
    draggedTabKey;
    draggedMasterGroupKey;
    draggedMasterGroupType;
    pastClientLoadingTabs = new Set();
    nickleyRealtorTabLoading = false;
    selectedBenMasterGroupKey = '';
    selectedJoeyMasterGroupKey = '';

    connectedCallback() {
        this.boundWindowFocusHandler = this.handleWindowFocus.bind(this);
        this.boundVisibilityChangeHandler = this.handleVisibilityChange.bind(this);
        window.addEventListener('focus', this.boundWindowFocusHandler);
        document.addEventListener('visibilitychange', this.boundVisibilityChangeHandler);
        this.startAutoRefresh();
    }

    disconnectedCallback() {
        window.removeEventListener('focus', this.boundWindowFocusHandler);
        document.removeEventListener('visibilitychange', this.boundVisibilityChangeHandler);
        this.stopAutoRefresh();
    }

    get objectOptions() {
        return OBJECT_OPTIONS;
    }

    @wire(getDashboardData)
    wiredDashboard(result) {
        this.wiredDashboardResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.lastDashboardRefreshAt = Date.now();
            this.isCeoDashboard = data.isCeoDashboard === true;
            this.isPastClientDashboard = data.isPastClientDashboard === true;
            this.isRhettDelaney = data.isRhettDelaney === true;
            this.statusCards = this.decorateStatusCards(data.statusCards || []);
            this.quickButtons = this.decorateButtons(data.quickButtons || []);
            this.queueShortcuts = this.decorateShortcutButtons(data.queueShortcuts || []);
            this.headerTitle = data.headerTitle || 'Pipeline Command Center';
            this.headerSubtitle =
                data.headerSubtitle || 'A focused view for production queues, upcoming closings, and daily review work.';
            this.pipelineTitle = data.pipelineTitle || 'Upcoming Pipeline';
            this.pipelineSubtitle = data.pipelineSubtitle || 'Assigned work ordered by priority.';
            this.pipelineObjectApiName = data.pipelineObjectApiName || 'Transaction__c';
            this.currentUserId = data.currentUserId;
            this.canEditPipelineTabRows = data.canEditPipelineTabRows === true;
            this.canEditQuickButtons = data.canEditQuickButtons !== false;
            this.canCreateLead = data.canCreateLead === true;
            this.canAssignNewLeadOwner = data.canAssignNewLeadOwner === true;
            this.canCreateTitleAgent = data.canCreateTitleAgent === true;
            this.columnPreferences = this.parseColumnPreferences(data.columnPreferencesJson);
            this.pipelineRows = (data.pipelineRows || []).map((row) => this.decoratePipelineRow(row));
            this.pipelineTabs = this.decorateTabs(this.applySavedTabOrder(data.pipelineTabs || []));
            if (!this.pipelineTabs.some((tab) => tab.key === this.activePipelineTabKey)) {
                this.activePipelineTabKey = this.pipelineTabs[0]?.key || 'assigned';
            }
            if (this.isPastClientDashboard && !this.selectedBenMasterGroupKey) {
                this.selectedBenMasterGroupKey = this.benGroupKeyForTab(this.activePipelineTabKey) || 'pastClients';
            }
            if (this.showJoeyMasterGroups) {
                const activeJoeyGroupKey = this.joeyGroupKeyForTab(this.activePipelineTabKey);
                this.selectedJoeyMasterGroupKey = activeJoeyGroupKey || this.selectedJoeyMasterGroupKey || 'joeOlmsted';
            }
            this.loadActivePastClientTab();
            this.loadActiveNickleyRealtorTab();
            this.error = undefined;
        } else if (error) {
            this.error = this.extractError(error);
            this.statusCards = [];
            this.quickButtons = [];
            this.queueShortcuts = [];
            this.pipelineRows = [];
            this.pipelineTabs = [];
            this.canEditPipelineTabRows = false;
            this.canEditQuickButtons = true;
            this.canCreateLead = false;
            this.canAssignNewLeadOwner = false;
            this.canCreateTitleAgent = false;
            this.isCeoDashboard = false;
            this.isPastClientDashboard = false;
            this.isRhettDelaney = false;
        }
    }

    @wire(getListViewOptions)
    wiredListViews({ data, error }) {
        if (data) {
            this.listViewOptions = data;
        } else if (error) {
            this.error = this.extractError(error);
        }
    }

    @wire(getRealtorPartnerFormOptions)
    wiredRealtorPartnerFormOptions({ data, error }) {
        if (data) {
            this.realtorPartnerBizDevOptions = data.bizDevDesignation || [];
            this.realtorPartnerGroupOptions = data.realtorGroup || [];
        } else if (error) {
            this.error = this.extractError(error);
        }
    }

    openListView(event) {
        const objectApiName = event.currentTarget.dataset.object;
        const filterName = event.currentTarget.dataset.filter;
        if (!objectApiName || !filterName) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName,
                actionName: 'list'
            },
            state: {
                filterName
            }
        });
    }

    openNewLeadFlow() {
        this.resetNewLeadForm();
        this.isNewLeadFlowOpen = true;
        if (this.canAssignNewLeadOwner && !this.hasLoadedNewLeadFormOptions) {
            this.loadNewLeadFormOptions();
        }
    }

    closeNewLeadFlow() {
        this.isNewLeadFlowOpen = false;
        this.isNewLeadSaving = false;
        this.newLeadError = undefined;
    }

    handleNewLeadFlowStatus(event) {
        if (event.detail.status === 'FINISHED' || event.detail.status === 'FINISHED_SCREEN') {
            this.isNewLeadFlowOpen = false;
            refreshApex(this.wiredDashboardResult);
        }
    }

    get usesCustomNewLeadForm() {
        return this.canAssignNewLeadOwner;
    }

    get newLeadSaveLabel() {
        return this.isNewLeadSaving ? 'Creating Lead...' : 'Create Lead';
    }

    async loadNewLeadFormOptions() {
        try {
            const data = await getNewLeadFormOptions();
            this.newLeadSourceOptions = data?.leadSourceOptions || [];
            this.newLeadLoanPurposeOptions = data?.loanPurposeOptions || [];
            this.newLeadBizDevOptions = data?.bizDevOptions || [];
            this.newLeadOwnerOptions = data?.ownerOptions || [];
            this.hasLoadedNewLeadFormOptions = true;
        } catch (error) {
            this.newLeadError = this.extractError(error);
        }
    }

    resetNewLeadForm() {
        this.newLeadError = undefined;
        this.isNewLeadSaving = false;
        this.newLeadFirstName = '';
        this.newLeadLastName = '';
        this.newLeadPhone = '';
        this.newLeadEmail = '';
        this.newLeadSource = '';
        this.newLeadLoanPurpose = '';
        this.newLeadBizDev = '';
        this.newLeadOwnerId = this.currentUserId || '';
    }

    handleNewLeadInput(event) {
        const fieldName = event.currentTarget.dataset.field;
        this[fieldName] = event.detail.value;
    }

    submitNewLeadForm() {
        this.saveNewLead();
    }

    async saveNewLead() {
        const inputs = [...this.template.querySelectorAll('[data-new-lead-input="true"]')];
        const valid = inputs.reduce((isValid, input) => {
            input.reportValidity();
            return isValid && input.checkValidity();
        }, true);

        if (!valid) {
            this.newLeadError = 'Complete the required Lead fields before creating the record.';
            return;
        }

        const realtorLookup = this.template.querySelector('c-flow-realtor-account-lookup[data-id="new-lead-realtor-lookup"]');
        if (realtorLookup?.validate) {
            realtorLookup.validate();
        }

        this.isNewLeadSaving = true;
        this.newLeadError = undefined;

        try {
            const recordId = await createConsumerLead({
                firstName: this.newLeadFirstName,
                lastName: this.newLeadLastName,
                phone: this.newLeadPhone,
                email: this.newLeadEmail,
                leadSource: this.newLeadSource,
                loanPurpose: this.newLeadLoanPurpose,
                bizDev: this.newLeadBizDev,
                realtorBuyingAgentId: realtorLookup?.selectedRecordId || null,
                ownerId: this.newLeadOwnerId || null
            });

            this.isNewLeadSaving = false;
            this.isNewLeadFlowOpen = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Lead created',
                    message: 'The new Lead is ready.',
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredDashboardResult);
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId,
                    objectApiName: 'Lead',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.isNewLeadSaving = false;
            this.newLeadError = this.extractError(error);
        }
    }

    openNewRealtorPartner() {
        this.realtorPartnerError = undefined;
        this.realtorPartnerFirstName = '';
        this.realtorPartnerLastName = '';
        this.realtorPartnerMobilePhone = '';
        this.realtorPartnerEmail = '';
        this.realtorPartnerBizDevDesignation = '';
        this.realtorPartnerBrokerage = '';
        this.realtorPartnerGroup = '';
        this.realtorPartnerTransactionCoordinatorId = undefined;
        this.realtorPartnerIndividualLicenseNumber = '';
        this.realtorPartnerCompanyLicenseNumber = '';
        this.isNewRealtorPartnerOpen = true;
    }

    closeNewRealtorPartner() {
        this.isNewRealtorPartnerOpen = false;
        this.isRealtorPartnerSaving = false;
        this.realtorPartnerError = undefined;
    }

    submitRealtorPartnerForm() {
        this.saveRealtorPartner();
    }

    handleRealtorPartnerInput(event) {
        const fieldName = event.currentTarget.dataset.field;
        const value = event.detail.value;
        if (fieldName === 'transactionCoordinatorId') {
            this.realtorPartnerTransactionCoordinatorId = event.detail.recordId;
            return;
        }
        this[fieldName] = value;
    }

    async saveRealtorPartner() {
        this.isRealtorPartnerSaving = true;
        this.realtorPartnerError = undefined;

        try {
            const recordId = await createRealtorPartner({
                firstName: this.realtorPartnerFirstName,
                lastName: this.realtorPartnerLastName,
                mobilePhone: this.realtorPartnerMobilePhone,
                email: this.realtorPartnerEmail,
                bizDevDesignation: this.realtorPartnerBizDevDesignation,
                brokerage: this.realtorPartnerBrokerage,
                realtorGroup: this.realtorPartnerGroup,
                transactionCoordinatorId: this.realtorPartnerTransactionCoordinatorId,
                realtorIndividualLicenseNumber: this.realtorPartnerIndividualLicenseNumber,
                companyLicenseNumber: this.realtorPartnerCompanyLicenseNumber
            });

            this.isRealtorPartnerSaving = false;
            this.isNewRealtorPartnerOpen = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Realtor Partner created',
                    message: 'The new Realtor Partner account is ready.',
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredDashboardResult);
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.isRealtorPartnerSaving = false;
            this.realtorPartnerError = this.extractError(error);
        }
    }

    openNewRealtorLead() {
        this.realtorLeadError = undefined;
        this.realtorLeadFirstName = '';
        this.realtorLeadLastName = '';
        this.realtorLeadPhone = '';
        this.realtorLeadEmail = '';
        this.realtorLeadSource = '';
        this.realtorLeadNotes = '';
        this.isNewRealtorLeadOpen = true;
    }

    closeNewRealtorLead() {
        this.isNewRealtorLeadOpen = false;
        this.isRealtorLeadSaving = false;
        this.realtorLeadError = undefined;
    }

    handleRealtorLeadInput(event) {
        const fieldName = event.currentTarget.dataset.field;
        if (fieldName === 'firstName') {
            this.realtorLeadFirstName = event.detail.value;
        } else if (fieldName === 'lastName') {
            this.realtorLeadLastName = event.detail.value;
        } else if (fieldName === 'phone') {
            this.realtorLeadPhone = event.detail.value;
        } else if (fieldName === 'email') {
            this.realtorLeadEmail = event.detail.value;
        } else if (fieldName === 'leadSource') {
            this.realtorLeadSource = event.detail.value;
        } else if (fieldName === 'notes') {
            this.realtorLeadNotes = event.detail.value;
        }
    }

    async saveRealtorLead() {
        const inputs = [...this.template.querySelectorAll('[data-realtor-lead-input="true"]')];
        const allValid = inputs.reduce((validSoFar, input) => {
            input.reportValidity();
            return validSoFar && input.checkValidity();
        }, true);
        if (!allValid) {
            return;
        }
        this.isRealtorLeadSaving = true;
        this.realtorLeadError = undefined;
        try {
            const recordId = await createRealtorLead({
                firstName: this.realtorLeadFirstName,
                lastName: this.realtorLeadLastName,
                phone: this.realtorLeadPhone,
                email: this.realtorLeadEmail,
                leadSource: this.realtorLeadSource,
                notes: this.realtorLeadNotes
            });
            this.isRealtorLeadSaving = false;
            this.isNewRealtorLeadOpen = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Realtor Lead created',
                    message: 'The new Realtor Lead is in Ben\'s Working tab.',
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredDashboardResult);
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId,
                    objectApiName: 'Lead',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.isRealtorLeadSaving = false;
            this.realtorLeadError = this.extractError(error);
        }
    }

    openNewTitleAgent() {
        this.titleAgentError = undefined;
        this.titleAgentName = '';
        this.titleAgentPhone = '';
        this.titleAgentEmail = '';
        this.isNewTitleAgentOpen = true;
    }

    closeNewTitleAgent() {
        this.isNewTitleAgentOpen = false;
        this.isTitleAgentSaving = false;
        this.titleAgentError = undefined;
    }

    handleTitleAgentInput(event) {
        const fieldName = event.currentTarget.dataset.field;
        if (fieldName === 'name') {
            this.titleAgentName = event.detail.value;
        } else if (fieldName === 'phone') {
            this.titleAgentPhone = event.detail.value;
        } else if (fieldName === 'email') {
            this.titleAgentEmail = event.detail.value;
        }
    }

    async createTitleAgent() {
        const inputs = [...this.template.querySelectorAll('[data-title-agent-input="true"]')];
        const allValid = inputs.reduce((validSoFar, input) => {
            input.reportValidity();
            return validSoFar && input.checkValidity();
        }, true);
        if (!allValid) {
            return;
        }
        this.isTitleAgentSaving = true;
        this.titleAgentError = undefined;
        try {
            const recordId = await createTitleAgentAccount({
                accountName: this.titleAgentName,
                phoneNumber: this.titleAgentPhone,
                email: this.titleAgentEmail
            });
            this.isTitleAgentSaving = false;
            this.isNewTitleAgentOpen = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Title Agent created',
                    message: 'The new Title Agent account is ready.',
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredDashboardResult);
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.isTitleAgentSaving = false;
            this.titleAgentError = this.extractError(error);
        }
    }

    async selectPipelineTab(event) {
        this.activePipelineTabKey = event.currentTarget.dataset.key;
        if (this.isPastClientDashboard) {
            this.selectedBenMasterGroupKey = this.benGroupKeyForTab(this.activePipelineTabKey) || this.selectedBenMasterGroupKey;
        }
        if (this.showJoeyMasterGroups) {
            this.selectedJoeyMasterGroupKey =
                this.joeyGroupKeyForTab(this.activePipelineTabKey) || this.selectedJoeyMasterGroupKey;
        }
        this.pipelineTabs = this.decorateTabs(this.pipelineTabs);
        await this.loadActivePastClientTab();
        await this.loadActiveNickleyRealtorTab();
    }

    async selectBenMasterGroup(event) {
        const groupKey = event.currentTarget.dataset.key;
        if (!groupKey) {
            return;
        }
        this.selectedBenMasterGroupKey = groupKey;
        const firstTab = this.benTabsForGroup(groupKey)[0];
        if (firstTab) {
            this.activePipelineTabKey = firstTab.key;
            this.pipelineTabs = this.decorateTabs(this.pipelineTabs);
            await this.loadActivePastClientTab();
        }
    }

    selectJoeyMasterGroup(event) {
        const groupKey = event.currentTarget.dataset.key;
        if (!groupKey) {
            return;
        }
        this.selectedJoeyMasterGroupKey = groupKey;
        const firstTab = this.joeyTabsForGroup(groupKey)[0];
        if (firstTab) {
            this.activePipelineTabKey = firstTab.key;
            this.pipelineTabs = this.decorateTabs(this.pipelineTabs);
        }
    }

    handleTabDragStart(event) {
        this.draggedTabKey = event.currentTarget.dataset.key;
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', this.draggedTabKey);
    }

    handleTabDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
    }

    handleTabDrop(event) {
        event.preventDefault();
        const droppedTabKey = event.currentTarget.dataset.key;
        const draggedTabKey = this.draggedTabKey || event.dataTransfer.getData('text/plain');
        if (!draggedTabKey || !droppedTabKey || draggedTabKey === droppedTabKey) {
            this.draggedTabKey = undefined;
            return;
        }
        const tabs = [...this.pipelineTabs];
        const fromIndex = tabs.findIndex((tab) => tab.key === draggedTabKey);
        const toIndex = tabs.findIndex((tab) => tab.key === droppedTabKey);
        if (fromIndex < 0 || toIndex < 0) {
            this.draggedTabKey = undefined;
            return;
        }
        const [movedTab] = tabs.splice(fromIndex, 1);
        tabs.splice(toIndex, 0, movedTab);
        this.pipelineTabs = this.decorateTabs(tabs);
        this.saveTabOrder();
        this.draggedTabKey = undefined;
    }

    handleTabDragEnd() {
        this.draggedTabKey = undefined;
    }

    handleMasterGroupDragStart(event) {
        this.draggedMasterGroupKey = event.currentTarget.dataset.key;
        this.draggedMasterGroupType = event.currentTarget.dataset.masterType;
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', this.draggedMasterGroupKey);
    }

    handleMasterGroupDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
    }

    handleMasterGroupDrop(event) {
        event.preventDefault();
        const droppedGroupKey = event.currentTarget.dataset.key;
        const droppedGroupType = event.currentTarget.dataset.masterType;
        const draggedGroupKey = this.draggedMasterGroupKey || event.dataTransfer.getData('text/plain');
        const draggedGroupType = this.draggedMasterGroupType;
        if (
            !draggedGroupKey ||
            !droppedGroupKey ||
            draggedGroupKey === droppedGroupKey ||
            !draggedGroupType ||
            draggedGroupType !== droppedGroupType
        ) {
            this.clearDraggedMasterGroup();
            return;
        }

        const groups = droppedGroupType === 'ben' ? [...this.benMasterGroups] : [...this.joeyMasterGroups];
        const fromIndex = groups.findIndex((group) => group.key === draggedGroupKey);
        const toIndex = groups.findIndex((group) => group.key === droppedGroupKey);
        if (fromIndex < 0 || toIndex < 0) {
            this.clearDraggedMasterGroup();
            return;
        }

        const [movedGroup] = groups.splice(fromIndex, 1);
        groups.splice(toIndex, 0, movedGroup);
        this.saveMasterGroupOrder(droppedGroupType, groups);
        this.pipelineTabs = this.decorateTabs(this.pipelineTabs);
        this.clearDraggedMasterGroup();
    }

    handleMasterGroupDragEnd() {
        this.clearDraggedMasterGroup();
    }

    clearDraggedMasterGroup() {
        this.draggedMasterGroupKey = undefined;
        this.draggedMasterGroupType = undefined;
    }

    handleWindowFocus() {
        this.refreshDashboardIfStale();
    }

    handleVisibilityChange() {
        if (!document.hidden) {
            this.refreshDashboardIfStale();
        }
    }

    startAutoRefresh() {
        this.stopAutoRefresh();
        this.refreshTimer = window.setInterval(() => {
            if (!document.hidden) {
                this.refreshDashboard();
            }
        }, DASHBOARD_REFRESH_INTERVAL_MS);
    }

    stopAutoRefresh() {
        if (this.refreshTimer) {
            window.clearInterval(this.refreshTimer);
            this.refreshTimer = undefined;
        }
    }

    async refreshDashboard() {
        if (!this.wiredDashboardResult || this.isSaving || this.isRefreshingDashboard) {
            return;
        }
        this.isRefreshingDashboard = true;
        try {
            await refreshApex(this.wiredDashboardResult);
        } catch (error) {
            this.error = this.extractError(error);
        } finally {
            this.isRefreshingDashboard = false;
        }
    }

    refreshDashboardIfStale() {
        if (Date.now() - this.lastDashboardRefreshAt >= DASHBOARD_FOCUS_REFRESH_STALE_MS) {
            this.refreshDashboard();
        }
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (this.sortField === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDirection = 'asc';
        }
    }

    openEditor() {
        this.editorError = undefined;
        this.editableButtons = this.quickButtons.map((button, index) => ({
            ...button,
            key: `button-${index}`,
            index,
            displayNumber: index + 1,
            listViewOptions: this.optionsForObject(button.objectApiName)
        }));
        this.isEditorOpen = true;
    }

    closeEditor() {
        this.isEditorOpen = false;
        this.editableButtons = [];
        this.editorError = undefined;
    }

    openColumnEditor() {
        if (!this.showEditColumnsButton) {
            return;
        }
        this.columnEditorError = undefined;
        this.editableColumns = this.columnEditorOptions;
        this.isColumnEditorOpen = true;
    }

    closeColumnEditor() {
        this.isColumnEditorOpen = false;
        this.editableColumns = [];
        this.columnEditorError = undefined;
    }

    handleColumnToggle(event) {
        const columnKey = event.currentTarget.dataset.key;
        const checked = event.target.checked;
        this.columnEditorError = undefined;
        this.editableColumns = this.editableColumns.map((column) => {
            if (column.key !== columnKey) {
                return column;
            }
            return {
                ...column,
                selected: checked || column.required,
                className: checked || column.required ? 'pcc-column-choice pcc-column-choice-selected' : 'pcc-column-choice'
            };
        });
        if (this.editableColumns.filter((column) => column.selected).length > MAX_SELECTED_COLUMNS) {
            this.columnEditorError = `Choose up to ${MAX_SELECTED_COLUMNS} columns. Remove one before adding another.`;
            this.editableColumns = this.editableColumns.map((column) => {
                if (column.key === columnKey && !column.required) {
                    return {
                        ...column,
                        selected: false,
                        className: 'pcc-column-choice'
                    };
                }
                return column;
            });
        }
    }

    async saveColumnEditor() {
        const selectedKeys = this.editableColumns.filter((column) => column.selected).map((column) => column.key);
        if (!selectedKeys.length) {
            this.columnEditorError = 'Choose at least one column.';
            return;
        }
        if (selectedKeys.length > MAX_SELECTED_COLUMNS) {
            this.columnEditorError = `Choose up to ${MAX_SELECTED_COLUMNS} columns.`;
            return;
        }

        this.isSaving = true;
        this.columnEditorError = undefined;
        const nextPreferences = {
            ...this.columnPreferences,
            [this.activePipelineTabKey]: selectedKeys
        };
        try {
            const savedPreferences = await saveUserColumnPreferences({
                columnPreferencesJson: JSON.stringify(nextPreferences)
            });
            this.columnPreferences = this.parseColumnPreferences(savedPreferences);
            this.pipelineTabs = this.decorateTabs(this.pipelineTabs);
            this.closeColumnEditor();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Columns updated',
                    message: 'Your Command Center columns were saved for this tab.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.columnEditorError = this.extractError(error);
        } finally {
            this.isSaving = false;
        }
    }

    async resetColumnEditor() {
        const nextPreferences = { ...this.columnPreferences };
        delete nextPreferences[this.activePipelineTabKey];
        this.isSaving = true;
        this.columnEditorError = undefined;
        try {
            const savedPreferences = await saveUserColumnPreferences({
                columnPreferencesJson: JSON.stringify(nextPreferences)
            });
            this.columnPreferences = this.parseColumnPreferences(savedPreferences);
            this.pipelineTabs = this.decorateTabs(this.pipelineTabs);
            this.editableColumns = this.columnEditorOptions;
        } catch (error) {
            this.columnEditorError = this.extractError(error);
        } finally {
            this.isSaving = false;
        }
    }

    openRowEditor(event) {
        if (!this.canEditPipelineTabRows) {
            return;
        }
        const rowId = event.currentTarget.dataset.recordId;
        const row = this.activePipelineRows.find((candidate) => candidate.id === rowId);
        if (!row) {
            return;
        }
        const columnsByKey = new Map((this.activeCustomColumns || []).map((column) => [column.key, column]));
        const editableFields = (row.customCells || [])
            .filter((cell) => cell.editable && cell.fieldApiName)
            .map((cell) => ({
                key: `${row.id}-${cell.fieldApiName}`,
                fieldApiName: cell.fieldApiName,
                label: columnsByKey.get(cell.rawKey)?.label || cell.fieldApiName
            }));

        this.rowEditorRecordId = row.id;
        this.rowEditorObjectApiName = this.activePipelineObjectApiName;
        this.rowEditorTitle = `Edit ${row.name}`;
        this.rowEditorFields = editableFields;
        this.rowEditorError = undefined;
        this.isRowEditorOpen = true;
    }

    closeRowEditor() {
        this.isRowEditorOpen = false;
        this.rowEditorRecordId = undefined;
        this.rowEditorTitle = '';
        this.rowEditorFields = [];
        this.rowEditorError = undefined;
    }

    submitRowEditor() {
        this.isRowSaving = true;
        this.rowEditorError = undefined;
        this.template.querySelector('lightning-record-edit-form[data-form="row-editor"]')?.submit();
    }

    async handleRowEditorSuccess() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Record updated',
                message: 'The Home Screen row was updated.',
                variant: 'success'
            })
        );
        this.closeRowEditor();
        this.isRowSaving = false;
        await refreshApex(this.wiredDashboardResult);
    }

    handleRowEditorError(event) {
        this.rowEditorError = this.extractError(event.detail);
        this.isRowSaving = false;
    }

    openProcessorNoteEditor(event) {
        const rowId = event.currentTarget.dataset.recordId;
        const row = this.activePipelineRows.find((candidate) => candidate.id === rowId);
        if (!row) {
            return;
        }
        this.processorNoteRecordId = row.id;
        this.processorNoteMode = this.isAccountPipelineTab
            ? 'account'
            : (this.isLeadActionTab ? 'lead' : (this.isManagerNoteTab ? 'manager' : 'processor'));
        const noteTypeLabel =
            this.processorNoteMode === 'account'
                ? 'Past Client'
                : this.processorNoteMode === 'lead'
                  ? 'Lead'
                : this.processorNoteMode === 'manager'
                  ? 'Manager'
                  : 'Processor';
        this.processorNoteTitle = `New ${noteTypeLabel} Note - ${row.name}`;
        this.processorNoteText = '';
        this.processorNoteError = undefined;
        this.isProcessorNoteEditorOpen = true;
    }

    handlePastClientBadPhone(event) {
        const accountId = event.currentTarget.dataset.recordId;
        if (!accountId) {
            return;
        }
        this.openPastClientConfirm({
            accountId,
            action: 'badPhone',
            title: 'Confirm Bad #',
            message:
                "This will clear the phone number from the Person Account and remove the client from Ben's past client lists.",
            buttonLabel: 'Clear Phone'
        });
    }

    handlePastClientNoBrownies(event) {
        const accountId = event.currentTarget.dataset.recordId;
        if (!accountId) {
            return;
        }
        this.openPastClientConfirm({
            accountId,
            action: 'noBrownies',
            title: 'Confirm No Brownies',
            message: 'This will check Property Sold on the Person Account and notify Bianca to remove this client from SOC.',
            buttonLabel: 'Confirm No Brownies'
        });
    }

    openPastClientConfirm({ accountId, action, title, message, buttonLabel }) {
        this.pastClientConfirmRecordId = accountId;
        this.pastClientConfirmAction = action;
        this.pastClientConfirmTitle = title;
        this.pastClientConfirmMessage = message;
        this.pastClientConfirmButtonLabel = buttonLabel;
        this.pastClientConfirmError = undefined;
        this.isPastClientActionSaving = false;
        this.isPastClientConfirmOpen = true;
    }

    closePastClientConfirm() {
        this.isPastClientConfirmOpen = false;
        this.pastClientConfirmRecordId = undefined;
        this.pastClientConfirmAction = '';
        this.pastClientConfirmTitle = '';
        this.pastClientConfirmMessage = '';
        this.pastClientConfirmButtonLabel = 'Confirm';
        this.pastClientConfirmError = undefined;
        this.isPastClientActionSaving = false;
    }

    async confirmPastClientAction() {
        if (!this.pastClientConfirmRecordId) {
            this.pastClientConfirmError = 'A Person Account is required.';
            return;
        }
        this.isPastClientActionSaving = true;
        this.pastClientConfirmError = undefined;
        try {
            if (this.pastClientConfirmAction === 'badPhone') {
                await clearAccountPhoneNumber({ accountId: this.pastClientConfirmRecordId });
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Phone number removed',
                        message: "The Person Account phone number was cleared and the client will fall out of Ben's past client lists.",
                        variant: 'success'
                    })
                );
            } else if (this.pastClientConfirmAction === 'noBrownies') {
                await markAccountPropertySold({ accountId: this.pastClientConfirmRecordId });
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'No Brownies notification sent',
                        message: 'Property Sold was checked and Bianca was notified to remove this client from SOC.',
                        variant: 'success'
                    })
                );
            } else {
                this.pastClientConfirmError = 'Choose a past client action before confirming.';
                return;
            }
            this.closePastClientConfirm();
            await refreshApex(this.wiredDashboardResult);
        } catch (error) {
            this.pastClientConfirmError = this.extractError(error);
        } finally {
            this.isPastClientActionSaving = false;
        }
    }

    closeProcessorNoteEditor() {
        this.isProcessorNoteEditorOpen = false;
        this.processorNoteRecordId = undefined;
        this.processorNoteTitle = '';
        this.processorNoteText = '';
        this.processorNoteMode = 'processor';
        this.processorNoteError = undefined;
    }

    handleProcessorNoteTextChange(event) {
        this.processorNoteText = event.detail.value;
    }

    openTextPreview(event) {
        this.textPreviewTitle = event.currentTarget.dataset.title || 'Full Note';
        this.textPreviewBody = event.currentTarget.dataset.text || '';
        this.isTextPreviewOpen = true;
    }

    closeTextPreview() {
        this.isTextPreviewOpen = false;
        this.textPreviewTitle = '';
        this.textPreviewBody = '';
    }

    async saveProcessorNoteFromEditor() {
        this.isProcessorNoteSaving = true;
        this.processorNoteError = undefined;
        try {
            if (this.processorNoteMode === 'account') {
                await saveAccountNote({
                    accountId: this.processorNoteRecordId,
                    noteText: this.processorNoteText
                });
            } else if (this.processorNoteMode === 'lead') {
                await saveLeadNote({
                    leadId: this.processorNoteRecordId,
                    noteText: this.processorNoteText
                });
            } else {
                const saveNote = this.processorNoteMode === 'manager' ? saveManagerNote : saveProcessorNote;
                await saveNote({
                    transactionId: this.processorNoteRecordId,
                    noteText: this.processorNoteText
                });
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title:
                        this.processorNoteMode === 'account'
                            ? 'Past client note saved'
                            : this.processorNoteMode === 'lead'
                              ? 'Lead note saved'
                            : this.processorNoteMode === 'manager'
                              ? 'Manager note saved'
                              : 'Processor note saved',
                    message:
                        this.processorNoteMode === 'account'
                            ? 'The note was added to the Person Account.'
                            : this.processorNoteMode === 'lead'
                              ? 'The note was added to the Lead.'
                            : this.processorNoteMode === 'manager'
                              ? 'The latest manager note was updated.'
                              : 'The latest processor note was updated.',
                    variant: 'success'
                })
            );
            this.closeProcessorNoteEditor();
            await refreshApex(this.wiredDashboardResult);
        } catch (error) {
            this.processorNoteError = this.extractError(error);
        } finally {
            this.isProcessorNoteSaving = false;
        }
    }

    openEventEditor(event) {
        const rowId = event.currentTarget.dataset.recordId;
        const row = this.activePipelineRows.find((candidate) => candidate.id === rowId);
        if (!row) {
            return;
        }
        this.eventEditorRecordId = row.id;
        this.eventEditorTitle = `Set New Event - ${row.name}`;
        this.eventSubject = '';
        this.eventStartDateTime = this.defaultEventStartDateTime();
        this.eventEditorError = undefined;
        this.isEventEditorOpen = true;
    }

    closeEventEditor() {
        this.isEventEditorOpen = false;
        this.eventEditorRecordId = undefined;
        this.eventEditorTitle = '';
        this.eventSubject = '';
        this.eventStartDateTime = '';
        this.eventEditorError = undefined;
    }

    handleEventSubjectChange(event) {
        this.eventSubject = event.detail.value;
    }

    handleEventStartDateTimeChange(event) {
        this.eventStartDateTime = event.detail.value;
    }

    async saveEventFromEditor() {
        if (!this.eventSubject || !this.eventStartDateTime) {
            this.eventEditorError = 'Enter an event name and date/time before saving.';
            return;
        }
        const startDate = new Date(this.eventStartDateTime);
        if (Number.isNaN(startDate.getTime())) {
            this.eventEditorError = 'Choose a valid event date and time before saving.';
            return;
        }
        this.isEventSaving = true;
        this.eventEditorError = undefined;
        try {
            if (this.isAccountPipelineTab) {
                await createAccountEvent({
                    accountId: this.eventEditorRecordId,
                    subject: this.eventSubject,
                    startDateTime: startDate.toISOString()
                });
            } else if (this.isLeadActionTab) {
                await createLeadEvent({
                    leadId: this.eventEditorRecordId,
                    subject: this.eventSubject,
                    startDateTime: startDate.toISOString()
                });
            } else {
                await createTransactionEvent({
                    transactionId: this.eventEditorRecordId,
                    subject: this.eventSubject,
                    startDateTime: startDate.toISOString()
                });
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Event created',
                    message: this.isAccountPipelineTab
                        ? 'The scheduled appointment was added to the Person Account and your calendar.'
                        : this.isLeadActionTab
                          ? 'The scheduled appointment was added to the Lead and your calendar.'
                          : 'The scheduled appointment was added to the transaction and your calendar.',
                    variant: 'success'
                })
            );
            this.closeEventEditor();
            await refreshApex(this.wiredDashboardResult);
        } catch (error) {
            this.eventEditorError = this.extractError(error);
        } finally {
            this.isEventSaving = false;
        }
    }

    openBrokerCheckConfirm(event) {
        const rowId = event.currentTarget.dataset.recordId;
        const row = this.activePipelineRows.find((candidate) => candidate.id === rowId);
        if (!row) {
            return;
        }
        this.brokerCheckRecordId = row.id;
        this.brokerCheckConfirmTitle = `Check Received - ${row.name}`;
        this.brokerCheckError = undefined;
        this.isBrokerCheckConfirmOpen = true;
    }

    closeBrokerCheckConfirm() {
        this.isBrokerCheckConfirmOpen = false;
        this.brokerCheckRecordId = undefined;
        this.brokerCheckConfirmTitle = '';
        this.brokerCheckError = undefined;
    }

    async handlePassFollowUp(event) {
        const leadId = event.currentTarget.dataset.recordId;
        if (!leadId) {
            return;
        }
        this.isLoading = true;
        try {
            await passPreApprovalFollowUp({ leadId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Passed',
                    message: 'This lead will cycle back into your follow-up queue after the next call window.',
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredDashboardResult);
        } catch (error) {
            this.error = this.extractError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async confirmBrokerCheckReceived() {
        if (!this.brokerCheckRecordId) {
            this.brokerCheckError = 'A Transaction is required.';
            return;
        }
        this.isBrokerCheckSaving = true;
        this.brokerCheckError = undefined;
        try {
            await markBrokerCheckReceived({ transactionId: this.brokerCheckRecordId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Broker check received',
                    message: 'The Broker Check Received box was checked on the transaction.',
                    variant: 'success'
                })
            );
            this.closeBrokerCheckConfirm();
            await refreshApex(this.wiredDashboardResult);
        } catch (error) {
            this.brokerCheckError = this.extractError(error);
        } finally {
            this.isBrokerCheckSaving = false;
        }
    }

    handleButtonObjectChange(event) {
        const index = Number(event.currentTarget.dataset.index);
        const objectApiName = event.detail.value;
        this.editableButtons = this.editableButtons.map((button, rowIndex) => {
            if (rowIndex !== index) {
                return button;
            }
            const options = this.optionsForObject(objectApiName);
            const firstOption = options[0] || { label: '', value: '' };
            return {
                ...button,
                objectApiName,
                filterName: firstOption.value,
                label: firstOption.label,
                index: rowIndex,
                listViewOptions: options
            };
        });
    }

    handleButtonListViewChange(event) {
        const index = Number(event.currentTarget.dataset.index);
        const filterName = event.detail.value;
        this.editableButtons = this.editableButtons.map((button, rowIndex) => {
            if (rowIndex !== index) {
                return button;
            }
            const option = this.listViewOptions.find((viewOption) => {
                return viewOption.objectApiName === button.objectApiName && viewOption.filterName === filterName;
            });
            return {
                ...button,
                filterName,
                label: option ? option.label : button.label
            };
        });
    }

    async saveButtons() {
        this.isSaving = true;
        this.error = undefined;
        this.editorError = undefined;
        try {
            const buttonsToSave = this.editableButtons.map((button) => ({
                label: button.label,
                objectApiName: button.objectApiName,
                filterName: button.filterName
            }));
            const savedButtons = await saveUserQuickButtons({ buttons: buttonsToSave });
            this.quickButtons = this.decorateButtons(savedButtons || []);
            this.closeEditor();
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Buttons saved',
                    message: 'Your Command Center quick buttons were updated.',
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredDashboardResult);
        } catch (error) {
            this.editorError = this.extractError(error);
        } finally {
            this.isSaving = false;
        }
    }

    decorateStatusCards(cards) {
        return cards.map((card, index) => ({
            ...card,
            key: `${card.label}-${card.objectApiName || ''}-${card.filterName || ''}`,
            className: [
                card.objectApiName && card.filterName
                    ? 'pcc-stat-card pcc-stat-card-clickable'
                    : 'pcc-stat-card',
                this.isCeoDashboard ? `pcc-ceo-stat pcc-ceo-stat-${(index % 4) + 1}` : ''
            ]
                .filter(Boolean)
                .join(' ')
        }));
    }

    decorateButtons(buttons) {
        return buttons.map((button, index) => ({
            ...button,
            key: `${button.objectApiName}-${button.filterName}-${index}`,
            className: 'pcc-button pcc-button-primary'
        }));
    }

    decorateShortcutButtons(buttons) {
        return buttons.map((button, index) => ({
            ...button,
            key: `shortcut-${button.objectApiName}-${button.filterName}-${index}`
        }));
    }

    pastClientYearFromKey(tabKey) {
        const match = /^benPastClients(\d{4})$/.exec(tabKey || '');
        return match ? Number(match[1]) : null;
    }

    async loadActivePastClientTab() {
        if (!this.isPastClientTab) {
            return;
        }
        const activeTab = this.pipelineTabs.find((tab) => tab.key === this.activePipelineTabKey);
        const closingYear = this.pastClientYearFromKey(this.activePipelineTabKey);
        if (!activeTab || !closingYear || activeTab.rowsLoaded || this.pastClientLoadingTabs.has(activeTab.key)) {
            return;
        }
        this.pastClientLoadingTabs.add(activeTab.key);
        try {
            const rows = await getPastClientRowsByYear({ closingYear });
            this.pipelineTabs = this.decorateTabs(
                this.pipelineTabs.map((tab) =>
                    tab.key === activeTab.key
                        ? {
                              ...tab,
                              rows,
                              rowsLoaded: true,
                              count: rows.length || tab.count
                          }
                        : tab
                )
            );
        } catch (error) {
            this.error = this.extractError(error);
        } finally {
            this.pastClientLoadingTabs.delete(activeTab.key);
        }
    }

    async loadActiveNickleyRealtorTab() {
        if (this.activePipelineTabKey !== 'myNickleyRealtors' || this.nickleyRealtorTabLoading) {
            return;
        }
        const activeTab = this.pipelineTabs.find((tab) => tab.key === 'myNickleyRealtors');
        if (!activeTab || activeTab.rowsLoaded) {
            return;
        }
        this.nickleyRealtorTabLoading = true;
        try {
            const rows = await getNickleyRealtorRows();
            this.pipelineTabs = this.decorateTabs(
                this.pipelineTabs.map((tab) =>
                    tab.key === 'myNickleyRealtors'
                        ? {
                              ...tab,
                              rows,
                              rowsLoaded: true,
                              count: rows.length || tab.count
                          }
                        : tab
                )
            );
        } catch (error) {
            this.error = this.extractError(error);
        } finally {
            this.nickleyRealtorTabLoading = false;
        }
    }

    decorateTabs(tabs) {
        return tabs.map((tab, index) => ({
            ...tab,
            className: [
                'pcc-tab',
                this.tabPaletteClass(index),
                tab.key === this.activePipelineTabKey ? 'pcc-tab-active' : ''
            ]
                .filter(Boolean)
                .join(' '),
            metricRows: (tab.metricRows || []).map((row) => ({
                ...row,
                key: row.loanOfficerId,
                formattedNewToPreApprovalPercent: this.formatPercent(row.newToPreApprovalPercent),
                formattedPreApprovalToTransactionPercent: this.formatPercent(row.preApprovalToTransactionPercent),
                formattedNewToPostClosedPercent: this.formatPercent(row.newToPostClosedPercent),
                formattedAverageActiveDays: this.formatNumber(row.averageActiveDays)
            })),
            customColumns: (tab.customColumns || []).map((column) => ({
                ...column,
                displayLabel: this.customColumnLabel(tab.key, column),
                sortField: `custom:${column.key}`,
                sortClass: this.sortClass(`custom:${column.key}`),
                sortIndicator: this.sortIndicator(`custom:${column.key}`)
            })),
            rows: this.decorateRows(tab.key, tab.rows || [])
        }));
    }

    decorateRows(tabKey, rows) {
        return (rows || []).map((row) => ({
            ...this.decoratePipelineRow(row),
            key: this.rowKey(row),
            rowClass: this.rowClass(tabKey, row),
            detail: this.cleanRichText(row.detail),
            closerNotes: this.cleanRichText(row.closerNotes),
            customCells: (row.customCells || []).map((cell) => {
                const cleanValue = this.cleanRichText(cell.value);
                const isPhoneLink = this.isPhoneCell(cell.key, cleanValue);
                return {
                    ...cell,
                    rawKey: cell.key,
                    key: `${row.id}-${cell.key}`,
                    value: cleanValue,
                    hasValue: !!cleanValue,
                    isPhoneLink,
                    phoneHref: isPhoneLink ? this.phoneHref(cleanValue) : '',
                    isPreviewable: this.isPreviewableCustomCell(cell.key, cleanValue)
                };
            }),
            hasDetail: !!this.cleanRichText(row.detail),
            hasCloserNotes: !!this.cleanRichText(row.closerNotes),
            formattedDisplayDate: this.formatDateTimeOrDate(row.displayDateTime, row.displayDate),
            formattedCdSentDate: this.formatDateTimeOrDate(null, row.cdSentDate),
            formattedTridDateTime: this.formatDateTimeOrDate(row.tridDateTime, null),
            formattedDisclosuresOutDate: this.formatDateTimeOrDate(row.disclosuresOutDate, null),
            formattedDisclosuresSignedDate: this.formatDateTimeOrDate(row.disclosuresSignedDate, null),
            formattedFundingDate: this.formatDateTimeOrDate(null, row.fundingDate),
            formattedAppraisalOrderedDate: this.formatDateTimeOrDate(null, row.appraisalOrderedDate),
            formattedValueLinkOrderedDate: this.formatDateTimeOrDate(row.valueLinkOrderedDate, null),
            formattedAppraisalDueDate: this.formatDateTimeOrDate(null, row.appraisalDueDate),
            formattedCreatedDateTime: this.formatDateTimeOrDate(row.createdDateTime, null),
            formattedLastActivityDate: this.formatDateTimeOrDate(null, row.lastActivityDate),
            formattedAppointmentDateTime: this.formatDateTimeOrDate(row.appointmentDateTime, null),
            formattedLastProcessorSms: this.formatDateTimeOrDate(row.lastProcessorSms, null),
            formattedLastProcessorCall: this.formatDateTimeOrDate(row.lastProcessorCall, null),
            formattedAmount: this.formatCurrency(row.loanAmount),
            phoneHref: this.phoneHref(row.phone),
            hasPhone: !!this.phoneHref(row.phone),
            hasEaseLink: this.hasEaseLink(row)
        }));
    }

    decoratePipelineRow(row) {
        const recordId = String((row && (row.id || row.recordId)) || '');
        return {
            ...row,
            recordId,
            formattedDisplayDate: this.formatDateTimeOrDate(row.displayDateTime, row.displayDate),
            formattedCdSentDate: this.formatDateTimeOrDate(null, row.cdSentDate),
            formattedTridDateTime: this.formatDateTimeOrDate(row.tridDateTime, null),
            formattedDisclosuresOutDate: this.formatDateTimeOrDate(row.disclosuresOutDate, null),
            formattedDisclosuresSignedDate: this.formatDateTimeOrDate(row.disclosuresSignedDate, null),
            formattedFundingDate: this.formatDateTimeOrDate(null, row.fundingDate),
            formattedAppraisalOrderedDate: this.formatDateTimeOrDate(null, row.appraisalOrderedDate),
            formattedValueLinkOrderedDate: this.formatDateTimeOrDate(row.valueLinkOrderedDate, null),
            formattedAppraisalDueDate: this.formatDateTimeOrDate(null, row.appraisalDueDate),
            formattedCreatedDateTime: this.formatDateTimeOrDate(row.createdDateTime, null),
            formattedLastActivityDate: this.formatDateTimeOrDate(null, row.lastActivityDate),
            formattedAppointmentDateTime: this.formatDateTimeOrDate(row.appointmentDateTime, null),
            formattedLastProcessorSms: this.formatDateTimeOrDate(row.lastProcessorSms, null),
            formattedLastProcessorCall: this.formatDateTimeOrDate(row.lastProcessorCall, null),
            formattedAmount: this.formatCurrency(row.loanAmount),
            phoneHref: this.phoneHref(row.phone),
            hasPhone: !!this.phoneHref(row.phone),
            propertyAddress: row.propertyAddress || '',
            hasEaseLink: this.hasEaseLink(row),
            statusLabel: this.statusLabel(row.status),
            statusClass: this.statusClass(row.status)
        };
    }

    applySavedTabOrder(tabs) {
        const savedOrder = this.savedTabOrder();
        if (!savedOrder.length) {
            return tabs;
        }
        const tabsByKey = new Map(tabs.map((tab) => [tab.key, tab]));
        const orderedTabs = savedOrder
            .map((key) => tabsByKey.get(key))
            .filter(Boolean);
        const remainingTabs = tabs.filter((tab) => !savedOrder.includes(tab.key));
        return [...orderedTabs, ...remainingTabs];
    }

    savedTabOrder() {
        try {
            const rawValue = window.localStorage.getItem(this.tabOrderStorageKey);
            const parsedValue = rawValue ? JSON.parse(rawValue) : [];
            return Array.isArray(parsedValue) ? parsedValue : [];
        } catch (error) {
            return [];
        }
    }

    saveTabOrder() {
        try {
            window.localStorage.setItem(
                this.tabOrderStorageKey,
                JSON.stringify(this.pipelineTabs.map((tab) => tab.key))
            );
        } catch (error) {
            // Local storage can be unavailable in restricted browser contexts.
        }
    }

    get tabOrderStorageKey() {
        return `${TAB_ORDER_STORAGE_PREFIX}-${this.currentUserId || 'unknown'}`;
    }

    applySavedMasterGroupOrder(masterType, groups) {
        const savedOrder = this.savedMasterGroupOrder(masterType);
        if (!savedOrder.length) {
            return groups;
        }
        const groupsByKey = new Map(groups.map((group) => [group.key, group]));
        const orderedGroups = savedOrder
            .map((key) => groupsByKey.get(key))
            .filter(Boolean);
        const remainingGroups = groups.filter((group) => !savedOrder.includes(group.key));
        return [...orderedGroups, ...remainingGroups];
    }

    savedMasterGroupOrder(masterType) {
        try {
            const rawValue = window.localStorage.getItem(this.masterGroupOrderStorageKey(masterType));
            const parsedValue = rawValue ? JSON.parse(rawValue) : [];
            return Array.isArray(parsedValue) ? parsedValue : [];
        } catch (error) {
            return [];
        }
    }

    saveMasterGroupOrder(masterType, groups) {
        try {
            window.localStorage.setItem(
                this.masterGroupOrderStorageKey(masterType),
                JSON.stringify((groups || []).map((group) => group.key))
            );
        } catch (error) {
            // Local storage can be unavailable in restricted browser contexts.
        }
    }

    masterGroupOrderStorageKey(masterType) {
        return `${MASTER_GROUP_ORDER_STORAGE_PREFIX}-${masterType}-${this.currentUserId || 'unknown'}`;
    }

    hasEaseLink(row) {
        return row?.lenderName === 'UWM' && !!row?.easeLink;
    }

    isPhoneCell(key, value) {
        const normalizedKey = String(key || '').toLowerCase();
        return !!value && (normalizedKey.includes('phone') || normalizedKey.includes('mobile'));
    }

    phoneHref(value) {
        const dialable = String(value || '').replace(/[^\d+]/g, '');
        return dialable ? `tel:${dialable}` : '';
    }

    get rootClass() {
        return this.isCeoDashboard ? 'pcc pcc-ceo' : 'pcc';
    }

    get showCeoHubHomeOverride() {
        return this.currentUserId === ADAM_STEPHENS_USER_ID && this.isCeoDashboard;
    }

    get showHeroActions() {
        return true;
    }

    get showCreateLeadButton() {
        return this.canCreateLead && !this.isPastClientDashboard;
    }

    get showRealtorLeadButton() {
        return this.isPastClientDashboard;
    }

    get realtorAccountButtonLabel() {
        return this.isPastClientDashboard ? 'Create New Realtor Account' : 'Create New Realtor Partner';
    }

    get showQuickButtons() {
        return !this.isPastClientDashboard;
    }

    get showEditButtons() {
        return this.canEditQuickButtons && !this.isCeoDashboard && !this.isPastClientDashboard;
    }

    get showRhettRingCentralVerifier() {
        return false;
    }

    cleanRichText(value) {
        if (!value) {
            return '';
        }
        const withLineBreaks = String(value)
            .replace(/<\s*br\s*\/?>/gi, ' ')
            .replace(/<\s*\/p\s*>/gi, ' ')
            .replace(/<[^>]*>/g, ' ');
        const decoder = document.createElement('textarea');
        decoder.innerHTML = withLineBreaks;
        return decoder.value.replace(/\s+/g, ' ').trim();
    }

    isPreviewableCustomCell(cellKey, value) {
        if (!value) {
            return false;
        }
        const previewKeys = ['managerNotes', 'detail', 'closerNotes', 'processorNote', 'actionRequiredReason', 'comments'];
        return previewKeys.includes(cellKey) && value.length > 80;
    }

    customColumnLabel(tabKey, column) {
        if (
            tabKey !== 'funderActionRequired' &&
            tabKey !== 'fundingQueue' &&
            tabKey !== 'benPreApprovalZachAged' &&
            !(tabKey || '').startsWith('benConsumerWebinar') &&
            !this.isPreApprovalCallsTab(tabKey)
        ) {
            return column.label;
        }
        const benAgedPreApprovalLabels = {
            name: 'Client',
            phone: 'Phone',
            scheduledEvent: 'Event',
            preApprovalDate: 'Pre-App',
            loanAmount: 'Amount',
            realtorBuyingAgent: 'Agent',
            zachLastCall: 'Zach Call',
            benLastCall: 'Ben Call'
        };
        const benWebinarLabels = {
            name: 'Client',
            phone: 'Phone',
            createdDate: 'Created',
            mostRecentEvent: 'Recent Event',
            nextScheduledEvent: 'Next Event',
            status: 'Status',
            loanAmount: 'Amount',
            loanPurpose: 'Purpose',
            realtorBuyingAgent: 'Agent',
            leadSource: 'Source',
            appointmentDateTime: 'Appointment',
            loanDetails: 'Details'
        };
        const preApprovalCallsLabels = {
            name: 'Name',
            phone: 'Phone',
            status: 'Status',
            createdDate: 'Created',
            lastActivityDate: 'Last Activity',
            appointmentDateTime: 'Appointment',
            preApprovalDate: 'Pre-App Date',
            loanDetails: 'Details',
            loanPurpose: 'Purpose',
            loanAmount: 'Amount',
            bizDev: 'Biz Dev',
            realtorBuyingAgent: 'Agent'
        };
        const funderActionLabels = {
            actionRequiredReason: 'Action Req',
            closingType: 'Close Type',
            closingDate: 'Close',
            fundingDate: 'Fund',
            rateLockExpDate: 'Lock Exp',
            warehouseBankName: 'Warehouse',
            mersActivated: 'MERS',
            fundingAuthorization: 'Fund Auth',
            mersUploadedActivated: 'MERS Upload',
            managerNotes: 'Mgr Notes'
        };
        const fundingQueueLabels = {
            loanPurpose: 'Purpose',
            fundingDate: 'Fund',
            closingDate: 'Close',
            rateLockExpDate: 'Lock Exp',
            warehouseBankName: 'Warehouse',
            mersRegistrationComplete: 'MERS Reg',
            closingType: 'Close Type',
            fundingWireRequested: 'Wire Req',
            federalReferenceNumber: 'Fed Ref #',
            fundingAuthorization: 'Fund Auth',
            mersUploadedActivated: 'MERS Upload',
            noteReceivedDate: 'Note Rec',
            easeLink: 'EASE'
        };
        if (this.isPreApprovalCallsTab(tabKey)) {
            return preApprovalCallsLabels[column.key] || column.label;
        }
        if (tabKey === 'benPreApprovalZachAged') {
            return benAgedPreApprovalLabels[column.key] || column.label;
        }
        if ((tabKey || '').startsWith('benConsumerWebinar')) {
            return benWebinarLabels[column.key] || column.label;
        }
        const compactLabels = tabKey === 'fundingQueue' ? fundingQueueLabels : funderActionLabels;
        return compactLabels[column.key] || column.label;
    }

    tabPaletteClass(index) {
        const palette = [
            'pcc-tab-blue',
            'pcc-tab-slate',
            'pcc-tab-sky',
            'pcc-tab-steel',
            'pcc-tab-ice',
            'pcc-tab-navy'
        ];
        return palette[index % palette.length];
    }

    optionsForObject(objectApiName) {
        return this.listViewOptions
            .filter((viewOption) => viewOption.objectApiName === objectApiName)
            .map((viewOption) => ({
                label: viewOption.label,
                value: viewOption.filterName
            }));
    }

    rowKey(row) {
        return [
            row.id,
            row.displayDateTime || row.displayDate || '',
            row.detail || ''
        ].join('-');
    }

    rowClass(tabKey, row) {
        const classes = ['pcc-row'];
        if (tabKey === 'locksExpiring' && this.isTodayDate(row.displayDate)) {
            classes.push('pcc-row-urgent');
        }
        return classes.join(' ');
    }

    isTodayDate(dateValue) {
        if (!dateValue) {
            return false;
        }
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        return String(dateValue) === `${yyyy}-${mm}-${dd}`;
    }

    openRecord(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.recordId,
                objectApiName: this.activePipelineObjectApiName,
                actionName: 'view'
            }
        });
    }

    openReport(event) {
        const reportUrl = event.currentTarget.dataset.reportUrl;
        if (!reportUrl) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: reportUrl
            }
        });
    }

    get activePipelineTab() {
        if (this.showBenEmptyGroup) {
            return {
                key: `ben-empty-${this.activeBenMasterGroupKey}`,
                label: this.activeBenMasterGroup.label,
                subtitle: this.activeBenMasterGroup.subtitle,
                rows: [],
                objectApiName: ''
            };
        }
        return this.pipelineTabs.find((tab) => tab.key === this.activePipelineTabKey) || this.pipelineTabs[0];
    }

    get showBenMasterGroups() {
        return this.isPastClientDashboard;
    }

    get showJoeyMasterGroups() {
        return !this.isPastClientDashboard && this.pipelineTabs.some((tab) => this.joeyGroupKeyForTab(tab.key));
    }

    get showPipelineTabRows() {
        return this.pipelineTabRows.length > 0;
    }

    get activeBenMasterGroupKey() {
        return this.selectedBenMasterGroupKey || this.benGroupKeyForTab(this.activePipelineTabKey) || 'pastClients';
    }

    get activeBenMasterGroup() {
        return this.benMasterGroups.find((group) => group.key === this.activeBenMasterGroupKey) || this.benMasterGroups[0];
    }

    get showBenEmptyGroup() {
        return this.isPastClientDashboard && !this.benTabsForGroup(this.activeBenMasterGroupKey).length;
    }

    get benEmptyGroupMessage() {
        return `${this.activeBenMasterGroup.label} tabs have not been configured yet.`;
    }

    get benMasterGroups() {
        return this.applySavedMasterGroupOrder('ben', [
            this.buildBenMasterGroup(
                'pastClients',
                'Past Clients',
                'Closed borrower follow-up by closing year.',
                'pcc-ben-master-past'
            ),
            this.buildBenMasterGroup(
                'realtorLeads',
                'Realtor Leads',
                'Realtor pipeline grouped by status.',
                'pcc-ben-master-realtor'
            ),
            this.buildBenMasterGroup(
                'preApprovalClients',
                'Pre-Approval Clients',
                'Pre-approved client follow-up views.',
                'pcc-ben-master-preapproval'
            ),
            this.buildBenMasterGroup(
                'consumerWebinarLeads',
                'Consumer Webinar Leads',
                'Webinar lead follow-up views.',
                'pcc-ben-master-webinar'
            )
        ]);
    }

    buildBenMasterGroup(key, label, subtitle, paletteClass) {
        const count = this.benTabsForGroup(key).reduce((total, tab) => total + (Number(tab.count) || 0), 0);
        return {
            key,
            label,
            subtitle,
            count,
            className: [
                'pcc-ben-master-tab',
                paletteClass,
                key === this.activeBenMasterGroupKey ? 'pcc-ben-master-active' : ''
            ]
                .filter(Boolean)
                .join(' ')
        };
    }

    benGroupKeyForTab(tabKey) {
        if ((tabKey || '').startsWith('benPastClients') || (tabKey || '').startsWith('benPastClient')) {
            return 'pastClients';
        }
        if ((tabKey || '').startsWith('benRealtor')) {
            return 'realtorLeads';
        }
        if ((tabKey || '').startsWith('benPreApproval')) {
            return 'preApprovalClients';
        }
        if ((tabKey || '').startsWith('benConsumerWebinar')) {
            return 'consumerWebinarLeads';
        }
        return '';
    }

    benTabsForGroup(groupKey) {
        return this.pipelineTabs.filter((tab) => this.benGroupKeyForTab(tab.key) === groupKey);
    }

    get activeJoeyMasterGroupKey() {
        return this.selectedJoeyMasterGroupKey || this.joeyGroupKeyForTab(this.activePipelineTabKey) || (this.usesMeganMasterGroups ? 'myLeads' : 'joeOlmsted');
    }

    get joeyMasterGroups() {
        if (this.usesMeganMasterGroups) {
            return this.applySavedMasterGroupOrder('joey', [
                this.buildJoeyMasterGroup('myLeads', 'My Leads', 'pcc-joey-master-joe'),
                this.buildJoeyMasterGroup('brandonLeads', 'Brandon\'s Leads', 'pcc-joey-master-zach'),
                this.buildJoeyMasterGroup('zachLeads', 'Zach\'s Leads', 'pcc-joey-master-rhett'),
                this.buildJoeyMasterGroup('preApprovalFollowUps', 'Pre-Approval Follow Ups', 'pcc-joey-master-berkeley')
            ].filter((group) => group.hasTabs));
        }
        return this.applySavedMasterGroupOrder('joey', [
            this.buildJoeyMasterGroup('joeOlmsted', 'Joe Olmsted', 'pcc-joey-master-joe'),
            this.buildJoeyMasterGroup('zachFritz', 'Zach Fritz', 'pcc-joey-master-zach'),
            this.buildJoeyMasterGroup('berkeleyPeterson', 'Berkeley Peterson', 'pcc-joey-master-berkeley'),
            this.buildJoeyMasterGroup('rhettDelaney', 'Rhett Delaney', 'pcc-joey-master-rhett')
        ].filter((group) => group.hasTabs));
    }

    buildJoeyMasterGroup(key, label, paletteClass) {
        const tabs = this.joeyTabsForGroup(key);
        const count = this.joeyMasterActiveLeadCount(tabs);
        return {
            key,
            label,
            count,
            hasTabs: tabs.length > 0,
            className: [
                'pcc-ben-master-tab',
                paletteClass,
                key === this.activeJoeyMasterGroupKey ? 'pcc-ben-master-active' : ''
            ]
                .filter(Boolean)
                .join(' ')
        };
    }

    joeyMasterActiveLeadCount(tabs) {
        const activeLeadTab = (tabs || []).find((tab) => this.isJoeyMasterActiveLeadCountTab(tab.key));
        if (activeLeadTab) {
            return Number(activeLeadTab.count) || 0;
        }
        return (tabs || []).reduce((total, tab) => total + (Number(tab.count) || 0), 0);
    }

    isJoeyMasterActiveLeadCountTab(tabKey) {
        const key = tabKey || '';
        return key === 'assigned' || key.endsWith('ActiveLeads');
    }

    joeyGroupKeyForTab(tabKey) {
        const key = tabKey || '';
        if (this.usesMeganMasterGroups) {
            if (key.startsWith('meganPreApprovalFollowUps')) {
                return 'preApprovalFollowUps';
            }
            if (key.startsWith('brandon')) {
                return 'brandonLeads';
            }
            if (key.startsWith('zachFritz')) {
                return 'zachLeads';
            }
            if (this.isMeganOwnMasterTabKey(key)) {
                return 'myLeads';
            }
            return '';
        }
        if (key.startsWith('joeOlmsted')) {
            return 'joeOlmsted';
        }
        if (key.startsWith('zachFritz')) {
            return 'zachFritz';
        }
        if (key.startsWith('berkeleyPeterson')) {
            return 'berkeleyPeterson';
        }
        if (key.startsWith('rhettDelaney')) {
            return 'rhettDelaney';
        }
        return '';
    }

    isMeganOwnMasterTabKey(tabKey) {
        return [
            'assigned',
            'newLeadAlerts',
            'stagnant',
            'activePreApprovals',
            'stagnantPreApprovals',
            'preApprovalCallsToday',
            'attention',
            'eventsToday',
            'disclosuresNeedingSigned',
            'loanOfficerActiveTransactions',
            'loanOfficerClosedThisMonth'
        ].includes(tabKey || '');
    }

    get usesMeganMasterGroups() {
        const tabKeys = this.pipelineTabs.map((tab) => tab.key || '');
        const hasMeganOwnTabs = tabKeys.some((key) => this.isMeganOwnMasterTabKey(key));
        const hasMeganPartnerTabs = tabKeys.some((key) => key.startsWith('brandon') || key.startsWith('zachFritz'));
        const hasJoeyAssistantTabs = tabKeys.some(
            (key) => key.startsWith('joeOlmsted') || key.startsWith('berkeleyPeterson') || key.startsWith('rhettDelaney')
        );
        return hasMeganOwnTabs && hasMeganPartnerTabs && !hasJoeyAssistantTabs;
    }

    joeyTabsForGroup(groupKey) {
        return this.pipelineTabs.filter((tab) => this.joeyGroupKeyForTab(tab.key) === groupKey);
    }

    get pipelineTabRows() {
        if (this.isPastClientDashboard) {
            const tabs = this.benTabsForGroup(this.activeBenMasterGroupKey);
            return tabs.length
                ? [
                      {
                          key: `ben-${this.activeBenMasterGroupKey}-tabs`,
                          tabs
                      }
                  ]
                : [];
        }
        if (this.showJoeyMasterGroups) {
            const tabs = this.joeyTabsForGroup(this.activeJoeyMasterGroupKey);
            return tabs.length
                ? [
                      {
                          key: `joey-${this.activeJoeyMasterGroupKey}-tabs`,
                          tabs
                      }
                  ]
                : [];
        }
        const pastClientTabs = this.pipelineTabs.filter((tab) => (tab.key || '').startsWith('benPastClients'));
        const realtorTabs = this.pipelineTabs.filter((tab) => (tab.key || '').startsWith('benRealtor'));
        if (pastClientTabs.length || realtorTabs.length) {
            const rows = [];
            if (pastClientTabs.length) {
                rows.push({
                    key: 'ben-past-client-tabs',
                    tabs: pastClientTabs
                });
            }
            if (realtorTabs.length) {
                rows.push({
                    key: 'ben-realtor-tabs',
                    tabs: realtorTabs
                });
            }
            const remainingTabs = this.pipelineTabs.filter(
                (tab) => !(tab.key || '').startsWith('benPastClients') && !(tab.key || '').startsWith('benRealtor')
            );
            if (remainingTabs.length) {
                rows.push({
                    key: 'ben-other-tabs',
                    tabs: remainingTabs
                });
            }
            return rows;
        }
        const assistantGroups = [
            { key: 'joe-olmsted-tabs', prefix: 'joeOlmsted' },
            { key: 'zach-fritz-tabs', prefix: 'zachFritz' },
            { key: 'berkeley-peterson-tabs', prefix: 'berkeleyPeterson' },
            { key: 'rhett-delaney-tabs', prefix: 'rhettDelaney' }
        ]
            .map((group) => ({
                key: group.key,
                tabs: this.pipelineTabs.filter((tab) => (tab.key || '').startsWith(group.prefix))
            }))
            .filter((group) => group.tabs.length);
        if (assistantGroups.length) {
            return assistantGroups;
        }
        return [
            {
                key: 'pipeline-tabs',
                tabs: this.pipelineTabs
            }
        ];
    }

    get activePipelineTitle() {
        if (this.showBenEmptyGroup) {
            return this.activeBenMasterGroup.label;
        }
        return this.activePipelineTab?.label || this.pipelineTitle;
    }

    get activePipelineSubtitle() {
        if (this.showBenEmptyGroup) {
            return this.activeBenMasterGroup.subtitle;
        }
        return this.activePipelineTab?.subtitle || this.pipelineSubtitle;
    }

    get activePipelineRows() {
        if (this.showBenEmptyGroup) {
            return [];
        }
        return this.sortRows(this.activePipelineTab?.rows || this.pipelineRows).map((row) => ({
            ...row,
            formattedOpenerDate: this.formattedOpenerDate(row),
            visibleCustomCells: this.activeDisplayColumns.map((column) => this.cellForColumn(row, column))
        }));
    }

    get activeMetricRows() {
        return this.activePipelineTab?.metricRows || [];
    }

    get rawActiveCustomColumns() {
        return this.activePipelineTab?.customColumns || [];
    }

    get activeCustomColumns() {
        return this.rawActiveCustomColumns;
    }

    get activeDisplayColumns() {
        return this.selectedColumnsForTab(this.activePipelineTab);
    }

    get showEditColumnsButton() {
        return this.isGenericCustomColumnTab;
    }

    get selectedColumnCountText() {
        return `${this.activeDisplayColumns.length} / ${MAX_SELECTED_COLUMNS} columns`;
    }

    get columnEditorTitle() {
        return `Edit Columns - ${this.activePipelineTitle}`;
    }

    get columnEditorSubtitle() {
        return `Choose up to ${MAX_SELECTED_COLUMNS} columns for this tab. Your choices are saved only for you.`;
    }

    get columnEditorCountText() {
        return `${this.editableColumns.filter((column) => column.selected).length} / ${MAX_SELECTED_COLUMNS} selected`;
    }

    get columnEditorOptions() {
        const selectedKeys = new Set(this.activeDisplayColumns.map((column) => column.key));
        return this.availableColumnsForTab(this.activePipelineTab).map((column) => {
            const selected = selectedKeys.has(column.key);
            return {
                ...column,
                selected,
                disabled: column.required,
                className: selected ? 'pcc-column-choice pcc-column-choice-selected' : 'pcc-column-choice'
            };
        });
    }

    get shouldShowPhoneInCustomTable() {
        return (
            !!this.rawActiveCustomColumns.length &&
            ['Lead', 'Transaction__c'].includes(this.activePipelineObjectApiName)
        );
    }

    get customPhoneColumnLabel() {
        return this.activePipelineObjectApiName === 'Transaction__c' ? 'Borrower Phone' : 'Phone';
    }

    parseColumnPreferences(preferencesJson) {
        if (!preferencesJson) {
            return {};
        }
        try {
            const parsed = JSON.parse(preferencesJson);
            return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
        } catch (error) {
            return {};
        }
    }

    selectedColumnsForTab(tab) {
        if (!tab) {
            return [];
        }
        const availableColumns = this.availableColumnsForTab(tab);
        const availableByKey = new Map(availableColumns.map((column) => [column.key, column]));
        const defaultKeys = this.defaultColumnKeysForTab(tab);
        const requestedKeys = Array.isArray(this.columnPreferences?.[tab.key])
            ? this.columnPreferences[tab.key]
            : defaultKeys;
        const requiredKeys = availableColumns.filter((column) => column.required).map((column) => column.key);
        const selectedKeys = [...requiredKeys, ...requestedKeys]
            .filter((key, index, keys) => key && keys.indexOf(key) === index && availableByKey.has(key))
            .slice(0, MAX_SELECTED_COLUMNS);
        return selectedKeys.map((key) => this.decorateColumnForDisplay(availableByKey.get(key)));
    }

    defaultColumnKeysForTab(tab) {
        const customKeys = (tab?.customColumns || []).map((column) => column.key);
        if (customKeys.length) {
            return customKeys;
        }
        const tabKey = tab?.key || this.activePipelineTabKey;
        const objectApiName = tab?.objectApiName || this.pipelineObjectApiName;
        if (objectApiName === 'Lead') {
            return [
                'name',
                'status',
                'phone',
                'email',
                'bizDev',
                'leadSource',
                'realtorBuyingAgent',
                'lastActivityDate',
                'appointmentDateTime',
                'loanDetails'
            ];
        }
        if (objectApiName === 'Transaction__c') {
            const columns = [
                'name',
                ['assigned', 'myActivePipeline'].includes(tabKey) ? 'propertyAddress' : 'phone',
                'status',
                'closingDate',
                'detail'
            ];
            if (['assigned', 'filesInClosing', 'approachingCommitments', 'newFilesNotSubmitted24', 'claFilesNotContacted24'].includes(tabKey)) {
                columns.push('processorName');
            }
            if (['assigned', 'myActivePipeline', 'claFilesNotContacted24'].includes(tabKey)) {
                columns.push('lastProcessorSms', 'lastProcessorCall');
            }
            columns.push('lenderName', 'loanPurpose');
            if (!['assigned', 'filesInClosing'].includes(tabKey)) {
                columns.push('ownerName');
            }
            columns.push('loanOfficerName', 'loanAmount', 'easeLink');
            return columns;
        }
        return ['name', 'phone', 'email'];
    }

    availableColumnsForTab(tab) {
        if (!tab) {
            return [];
        }
        const objectApiName = tab.objectApiName || this.pipelineObjectApiName;
        const columnsByKey = new Map();
        (tab.customColumns || []).forEach((column) => {
            columnsByKey.set(column.key, {
                key: column.key,
                label: this.customColumnLabel(tab.key, column),
                required: column.key === 'name'
            });
        });
        COMMAND_CENTER_COLUMNS.filter((column) => column.objects.includes(objectApiName)).forEach((column) => {
            if (!columnsByKey.has(column.key)) {
                columnsByKey.set(column.key, column);
            }
        });
        return Array.from(columnsByKey.values()).map((column) => this.decorateColumnForDisplay(column));
    }

    decorateColumnForDisplay(column) {
        return {
            ...column,
            displayLabel: column.displayLabel || column.label,
            sortField: `custom:${column.key}`,
            sortClass: this.sortClass(`custom:${column.key}`),
            sortIndicator: this.sortIndicator(`custom:${column.key}`)
        };
    }

    cellForColumn(row, column) {
        const customCell = (row.customCells || []).find((cell) => cell.rawKey === column.key || cell.key === column.key);
        if (customCell) {
            return {
                ...customCell,
                key: `${row.id}-${column.key}`
            };
        }
        const cell = this.standardCellForColumn(row, column);
        return {
            ...cell,
            key: `${row.id}-${column.key}`,
            rawKey: column.key,
            hasValue: !!cell.value,
            isStatus: column.key === 'status',
            statusClass: column.key === 'status' ? row.statusClass : '',
            isPhoneLink: cell.isPhoneLink === true,
            phoneHref: cell.phoneHref || '',
            isPreviewable: this.isPreviewableCustomCell(column.key, cell.value)
        };
    }

    standardCellForColumn(row, column) {
        const key = column.key;
        let value = '';
        let sortValue = '';
        let isRecordLink = false;
        let isExternalLink = false;
        let isPhoneLink = false;
        let phoneHref = '';
        let url = '';

        if (key === 'name') {
            value = row.name || '';
            sortValue = value;
            isRecordLink = true;
        } else if (key === 'status') {
            value = row.statusLabel || row.status || '';
            sortValue = value;
        } else if (key === 'phone') {
            value = row.phone || '';
            sortValue = value;
            phoneHref = this.phoneHref(value);
            isPhoneLink = !!phoneHref;
        } else if (key === 'email') {
            value = row.email || '';
            sortValue = value;
        } else if (key === 'createdDate') {
            value = row.formattedCreatedDateTime || '';
            sortValue = row.createdDateTime || '';
        } else if (key === 'lastActivityDate') {
            value = row.formattedLastActivityDate || '';
            sortValue = row.lastActivityDate || '';
        } else if (key === 'appointmentDateTime') {
            value = row.formattedAppointmentDateTime || '';
            sortValue = row.appointmentDateTime || '';
        } else if (key === 'closingDate') {
            value = row.formattedDisplayDate || '';
            sortValue = row.displayDate || row.displayDateTime || '';
        } else if (key === 'fundingDate') {
            value = row.formattedFundingDate || '';
            sortValue = row.fundingDate || '';
        } else if (key === 'lastProcessorSms') {
            value = row.formattedLastProcessorSms || '';
            sortValue = row.lastProcessorSms || '';
        } else if (key === 'lastProcessorCall') {
            value = row.formattedLastProcessorCall || '';
            sortValue = row.lastProcessorCall || '';
        } else if (key === 'rateLockExpDate') {
            value = this.formatDateTimeOrDate(null, row.rateLockExpDate);
            sortValue = row.rateLockExpDate || '';
        } else if (key === 'loanAmount') {
            value = row.formattedAmount || '';
            sortValue = row.loanAmount === null || row.loanAmount === undefined ? '' : String(row.loanAmount);
        } else if (key === 'easeLink') {
            value = row.hasEaseLink ? 'EASE' : '';
            sortValue = value;
            url = row.easeLink || '';
            isExternalLink = !!url;
        } else if (key === 'detail') {
            value = row.detail || '';
            sortValue = value;
        } else if (key === 'realtorBuyingAgent') {
            value = row.realtorBuyingAgentName || '';
            sortValue = value;
        } else {
            value = row[key] || '';
            sortValue = value;
        }

        return {
            value,
            sortValue,
            isRecordLink,
            isExternalLink,
            isPhoneLink,
            phoneHref,
            url
        };
    }

    get standardPhoneColumnLabel() {
        return this.activePipelineObjectApiName === 'Transaction__c' ? 'Borrower Phone' : 'Phone';
    }

    get showsStandardPropertyAddressColumn() {
        return this.activePipelineObjectApiName === 'Transaction__c' && ['assigned', 'myActivePipeline'].includes(this.activePipelineTabKey);
    }

    get standardPrimaryColumnLabel() {
        return this.showsStandardPropertyAddressColumn ? 'Property Address' : this.standardPhoneColumnLabel;
    }

    get standardPrimaryColumnSortField() {
        return this.showsStandardPropertyAddressColumn ? 'propertyAddress' : 'phone';
    }

    get standardPrimaryColumnSortClass() {
        return this.sortClass(this.standardPrimaryColumnSortField);
    }

    get standardPrimaryColumnSortIndicator() {
        return this.sortIndicator(this.standardPrimaryColumnSortField);
    }

    withPhoneCustomColumn(columns) {
        const safeColumns = columns || [];
        if (!this.shouldShowPhoneInCustomTable || this.hasPhoneCustomKey(safeColumns)) {
            return safeColumns;
        }
        const phoneColumn = {
            key: 'phone',
            label: this.customPhoneColumnLabel,
            displayLabel: this.customPhoneColumnLabel,
            sortField: 'custom:phone',
            sortClass: this.sortClass('custom:phone'),
            sortIndicator: this.sortIndicator('custom:phone')
        };
        return this.insertAfterFirstColumn(safeColumns, phoneColumn);
    }

    withPhoneCustomCell(row, cells) {
        const safeCells = cells || [];
        if (!this.shouldShowPhoneInCustomTable || this.hasPhoneCustomKey(safeCells)) {
            return safeCells;
        }
        const cleanPhone = this.cleanRichText(row?.phone);
        const phoneCell = {
            rawKey: 'phone',
            key: `${row?.id || 'row'}-phone`,
            value: cleanPhone,
            sortValue: cleanPhone,
            hasValue: !!cleanPhone,
            isRecordLink: false,
            isExternalLink: false,
            isPhoneLink: !!this.phoneHref(cleanPhone),
            phoneHref: this.phoneHref(cleanPhone),
            isPreviewable: false,
            url: ''
        };
        return this.insertAfterFirstColumn(safeCells, phoneCell);
    }

    hasPhoneCustomKey(items) {
        return (items || []).some((item) => {
            const normalizedKey = String(item?.rawKey || item?.key || '').toLowerCase();
            const normalizedLabel = String(item?.label || item?.displayLabel || '').toLowerCase();
            return (
                normalizedKey === 'phone' ||
                normalizedKey.includes('phone') ||
                normalizedKey.includes('mobile') ||
                normalizedLabel === 'phone' ||
                normalizedLabel.includes('phone') ||
                normalizedLabel.includes('mobile')
            );
        });
    }

    insertAfterFirstColumn(items, itemToInsert) {
        const safeItems = items || [];
        const insertIndex = safeItems.length ? 1 : 0;
        return [
            ...safeItems.slice(0, insertIndex),
            itemToInsert,
            ...safeItems.slice(insertIndex)
        ];
    }

    get customTableClass() {
        if (this.activePipelineTabKey === 'funderActionRequired') {
            return 'pcc-table pcc-compact-custom-table pcc-funder-action-table';
        }
        if (this.activePipelineTabKey === 'fundingQueue') {
            return 'pcc-table pcc-compact-custom-table pcc-funding-queue-table';
        }
        if (this.isPreApprovalCallsTab(this.activePipelineTabKey)) {
            return 'pcc-table pcc-compact-custom-table pcc-preapproval-calls-table';
        }
        if (this.activePipelineTabKey === 'benPreApprovalZachAged') {
            return 'pcc-table pcc-compact-custom-table pcc-ben-aged-preapproval-table';
        }
        if ((this.activePipelineTabKey || '').startsWith('benRealtor')) {
            return 'pcc-table pcc-compact-custom-table pcc-realtor-lead-table';
        }
        if ((this.activePipelineTabKey || '').startsWith('benConsumerWebinar')) {
            return 'pcc-table pcc-compact-custom-table pcc-ben-webinar-table';
        }
        if (this.isPastClientTab) {
            return 'pcc-table pcc-compact-custom-table pcc-past-client-table';
        }
        return 'pcc-table';
    }

    get activePipelineObjectApiName() {
        return this.activePipelineTab?.objectApiName || this.pipelineObjectApiName;
    }

    get isTransactionPipelineTab() {
        return this.activePipelineObjectApiName === 'Transaction__c';
    }

    get isAccountPipelineTab() {
        return this.activePipelineObjectApiName === 'Account';
    }

    get isPastClientTab() {
        const tabKey = this.activePipelineTabKey || '';
        return tabKey.startsWith('benPastClients') || tabKey.startsWith('benPastClient');
    }

    get pastClientActionLabel() {
        return this.isPastClientTab ? 'Bad #' : 'Note';
    }

    get isLeadActionTab() {
        return ['benPreApprovalZachAged', 'benConsumerWebinarAssigned', 'preApprovalCallsToday', 'brandonPreApprovalCallsToday'].includes(this.activePipelineTabKey);
    }

    isPreApprovalCallsTab(tabKey) {
        return ['preApprovalCallsToday', 'brandonPreApprovalCallsToday'].includes(tabKey);
    }

    get showPassAction() {
        return this.activePipelineTabKey === 'meganPreApprovalFollowUps';
    }

    get isActionablePipelineTab() {
        if (this.activePipelineTabKey === 'myNickleyRealtors') {
            return false;
        }
        return this.isTransactionPipelineTab || this.isAccountPipelineTab || this.isLeadActionTab;
    }

    get isActivePipelineEmpty() {
        if (this.showBenEmptyGroup) {
            return false;
        }
        return !this.activePipelineRows.length;
    }

    get isOpenerWorkflowTab() {
        return ['readyForDisclosures', 'waitingOnSignatures', 'readyToOpen'].includes(this.activePipelineTabKey);
    }

    get isCloserWorkflowTab() {
        return ['closerActivePipeline', 'closerFilesInClosing', 'closerFilesInFunding', 'closerFilesClosingToday'].includes(this.activePipelineTabKey);
    }

    get isConversionMetricsTab() {
        return this.activePipelineTabKey === 'executiveConversionMetrics';
    }

    get isCustomColumnTab() {
        return !!this.rawActiveCustomColumns.length;
    }

    get usesEditableColumnTable() {
        return (
            !this.showBenEmptyGroup &&
            !this.isOpenerWorkflowTab &&
            !this.isCloserWorkflowTab &&
            !this.isConversionMetricsTab &&
            !this.isBrokerChecksOutstandingTab &&
            !this.isAppraisalsOutstandingTab &&
            this.activePipelineObjectApiName !== 'Metric' &&
            !!this.availableColumnsForTab(this.activePipelineTab).length
        );
    }

    get isGenericCustomColumnTab() {
        return this.usesEditableColumnTable;
    }

    get isAppraisalsOutstandingTab() {
        return this.activePipelineTabKey === 'appraisalsOutstanding';
    }

    get isBrokerChecksOutstandingTab() {
        return this.activePipelineTabKey === 'brokerChecksOutstanding';
    }

    get isManagerNoteTab() {
        return this.activePipelineTabKey === 'funderActionRequired';
    }

    get noteEditorLabel() {
        return this.processorNoteMode === 'account'
            ? 'Past Client Note'
            : this.processorNoteMode === 'manager'
              ? 'Manager Note'
              : 'Processor Note';
    }

    get noteEditorSubtitle() {
        return this.processorNoteMode === 'account'
            ? 'This note will be saved to the borrower Person Account.'
            : this.processorNoteMode === 'manager'
              ? 'This will become the latest Manager Note on the Transaction.'
              : 'This will become the latest Processor Note on the Transaction.';
    }

    get showsProcessorColumn() {
        return ['assigned', 'filesInClosing', 'approachingCommitments', 'newFilesNotSubmitted24', 'claFilesNotContacted24'].includes(
            this.activePipelineTabKey
        );
    }

    get showsProcessorContactColumns() {
        return ['assigned', 'myActivePipeline', 'claFilesNotContacted24'].includes(this.activePipelineTabKey);
    }

    get showsOwnerColumn() {
        return !['assigned', 'filesInClosing'].includes(this.activePipelineTabKey);
    }

    get isExecutiveAssignedLeadsTab() {
        if (this.isGenericCustomColumnTab) {
            return false;
        }
        return (
            [
                'executiveAssignedLeads',
                'executiveNewLeadAlerts',
                'newLeadAlerts',
                'stagnant',
                'allLoanOfficerActiveLeads',
                'allLoanOfficerNewLeadAlerts',
                'allLoanOfficerAttentionLeads',
                'allLoanOfficerStagnantLeads'
            ].includes(this.activePipelineTabKey) ||
            (this.activePipelineObjectApiName === 'Lead' && this.activePipelineTabKey === 'assigned')
        );
    }

    get isStandardWorkflowTab() {
        return (
            !this.isOpenerWorkflowTab &&
            !this.isCloserWorkflowTab &&
            !this.isConversionMetricsTab &&
            !this.isGenericCustomColumnTab &&
            !this.isExecutiveAssignedLeadsTab
        );
    }

    get openerDateColumnLabel() {
        if (this.activePipelineTabKey === 'readyForDisclosures') {
            return 'TRID Date';
        }
        if (this.activePipelineTabKey === 'waitingOnSignatures') {
            return 'Disclosures Out Date';
        }
        if (this.activePipelineTabKey === 'readyToOpen') {
            return 'Disclosures Signed Date';
        }
        return 'Date';
    }

    get openerDateSortField() {
        if (this.activePipelineTabKey === 'readyForDisclosures') {
            return 'tridDateTime';
        }
        if (this.activePipelineTabKey === 'waitingOnSignatures') {
            return 'disclosuresOutDate';
        }
        if (this.activePipelineTabKey === 'readyToOpen') {
            return 'disclosuresSignedDate';
        }
        return 'displayDateTime';
    }

    get dateColumnLabel() {
        if (this.activePipelineTabKey === 'disclosuresNeedingSigned') {
            return 'Disclosures Out Date';
        }
        if (
            this.activePipelineObjectApiName === 'Transaction__c' &&
            (
                this.activePipelineTabKey === 'assigned' ||
                this.activePipelineTabKey === 'myActivePipeline' ||
                this.activePipelineTabKey === 'executiveActivePipeline' ||
                this.activePipelineTabKey === 'executiveFilesInClosing' ||
                this.activePipelineTabKey === 'loanOfficerActiveTransactions' ||
                this.activePipelineTabKey === 'openCocRequests' ||
                this.activePipelineTabKey === 'fundingLockDeskActivePipeline' ||
                this.activePipelineTabKey === 'needingWarehouseAssignment' ||
                this.activePipelineTabKey === 'filesInClosing' ||
                this.activePipelineTabKey === 'readyForDisclosures' ||
                this.activePipelineTabKey === 'waitingOnSignatures' ||
                this.activePipelineTabKey === 'readyToOpen'
            )
        ) {
            return 'Closing Date';
        }
        if (
            this.activePipelineObjectApiName === 'Lead' &&
            (
                this.activePipelineTabKey === 'assigned' ||
                this.activePipelineTabKey === 'executiveAssignedLeads'
            )
        ) {
            return 'Created Date';
        }
        if (
            this.activePipelineObjectApiName === 'Transaction__c' &&
            (
                this.activePipelineTabKey === 'approachingCommitments' ||
                this.activePipelineTabKey === 'executiveApproachingCommitments'
            )
        ) {
            return 'Commitment Date';
        }
        if (this.activePipelineTabKey === 'newFilesNotSubmitted24') {
            return 'Processing Since';
        }
        if (this.activePipelineTabKey === 'claFilesNotContacted24') {
            return 'CLA Since';
        }
        if (this.activePipelineTabKey === 'loanOfficerClosedThisMonth') {
            return 'Funding Date';
        }
        if (['fundingQueue', 'funderActionRequired', 'pcReviewPipeline'].includes(this.activePipelineTabKey)) {
            return 'Funding Date';
        }
        if (this.activePipelineTabKey === 'locksExpiring') {
            return 'Rate Lock Exp Date';
        }
        return 'Date';
    }

    get standardDetailColumnLabel() {
        if (
            this.activePipelineObjectApiName === 'Transaction__c' &&
            (
                this.activePipelineTabKey === 'fundingQueue' ||
                this.activePipelineTabKey === 'funderActionRequired' ||
                this.activePipelineTabKey === 'pcReviewPipeline' ||
                this.activePipelineTabKey === 'needingWarehouseAssignment' ||
                this.activePipelineTabKey === 'locksExpiring' ||
                this.activePipelineTabKey === 'openCocRequests'
            )
        ) {
            return 'Review Detail';
        }
        if (
            this.activePipelineObjectApiName === 'Transaction__c' &&
            (
                this.activePipelineTabKey === 'assigned' ||
                this.activePipelineTabKey === 'myActivePipeline' ||
                this.activePipelineTabKey === 'loanOfficerActiveTransactions' ||
                this.activePipelineTabKey === 'loanOfficerClosedThisMonth' ||
                this.activePipelineTabKey === 'fundingLockDeskActivePipeline' ||
                this.activePipelineTabKey === 'approachingCommitments' ||
                this.activePipelineTabKey === 'newFilesNotSubmitted24' ||
                this.activePipelineTabKey === 'claFilesNotContacted24'
            )
        ) {
            return 'Processor Note';
        }
        return 'Detail';
    }

    sortRows(rows) {
        const sortedRows = [...(rows || [])];
        const directionFactor = this.sortDirection === 'desc' ? -1 : 1;
        const activeSortField =
            this.isPastClientTab && this.sortField === 'displayDateTime'
                ? 'custom:lastContacted'
                : this.sortField;
        sortedRows.sort((leftRow, rightRow) => {
            const comparison = this.compareValues(
                this.sortValue(leftRow, activeSortField),
                this.sortValue(rightRow, activeSortField)
            );
            return comparison * directionFactor;
        });
        return sortedRows;
    }

    formattedOpenerDate(row) {
        if (this.activePipelineTabKey === 'readyForDisclosures') {
            return row.formattedTridDateTime;
        }
        if (this.activePipelineTabKey === 'waitingOnSignatures') {
            return row.formattedDisclosuresOutDate;
        }
        if (this.activePipelineTabKey === 'readyToOpen') {
            return row.formattedDisclosuresSignedDate;
        }
        return row.formattedDisplayDate;
    }

    sortValue(row, field) {
        if (field && field.startsWith('custom:')) {
            const cellKey = field.replace('custom:', '');
            const cell = (row.customCells || []).find((candidate) => candidate.key.endsWith(`-${cellKey}`) || candidate.key === cellKey);
            if (cell) {
                return cell.sortValue || cell.value || '';
            }
            return this.standardCellForColumn(row, { key: cellKey }).sortValue || '';
        }
        if (field === 'displayDateTime') {
            return row.displayDateTime || (row.displayDate ? `${row.displayDate}T00:00:00.000Z` : '');
        }
        if (field === 'createdDateTime') {
            return row.createdDateTime || '';
        }
        if (field === 'lastActivityDate') {
            return row.lastActivityDate || '';
        }
        if (field === 'appointmentDateTime') {
            return row.appointmentDateTime || '';
        }
        if (field === 'lastProcessorSms') {
            return row.lastProcessorSms || '';
        }
        if (field === 'lastProcessorCall') {
            return row.lastProcessorCall || '';
        }
        if (field === 'propertyAddress') {
            return row.propertyAddress || '';
        }
        if (field === 'loanAmount') {
            return row.loanAmount === null || row.loanAmount === undefined ? null : Number(row.loanAmount);
        }
        return row[field] || '';
    }

    compareValues(leftValue, rightValue) {
        const leftEmpty = leftValue === null || leftValue === undefined || leftValue === '';
        const rightEmpty = rightValue === null || rightValue === undefined || rightValue === '';
        if (leftEmpty && rightEmpty) {
            return 0;
        }
        if (leftEmpty) {
            return 1;
        }
        if (rightEmpty) {
            return -1;
        }
        if (typeof leftValue === 'number' && typeof rightValue === 'number') {
            return leftValue - rightValue;
        }
        return String(leftValue).localeCompare(String(rightValue), undefined, {
            numeric: true,
            sensitivity: 'base'
        });
    }

    sortClass(field) {
        return this.sortField === field ? 'pcc-sort pcc-sort-active' : 'pcc-sort';
    }

    sortIndicator(field) {
        if (this.sortField !== field) {
            return '';
        }
        return this.sortDirection === 'asc' ? '^' : 'v';
    }

    get nameSortClass() {
        return this.sortClass('name');
    }

    get nameSortIndicator() {
        return this.sortIndicator('name');
    }

    get statusSortClass() {
        return this.sortClass('status');
    }

    get statusSortIndicator() {
        return this.sortIndicator('status');
    }

    get createdDateTimeSortClass() {
        return this.sortClass('createdDateTime');
    }

    get createdDateTimeSortIndicator() {
        return this.sortIndicator('createdDateTime');
    }

    get lastActivityDateSortClass() {
        return this.sortClass('lastActivityDate');
    }

    get lastActivityDateSortIndicator() {
        return this.sortIndicator('lastActivityDate');
    }

    get leadSourceSortClass() {
        return this.sortClass('leadSource');
    }

    get leadSourceSortIndicator() {
        return this.sortIndicator('leadSource');
    }

    get phoneSortClass() {
        return this.sortClass('phone');
    }

    get phoneSortIndicator() {
        return this.sortIndicator('phone');
    }

    get emailSortClass() {
        return this.sortClass('email');
    }

    get emailSortIndicator() {
        return this.sortIndicator('email');
    }

    get realtorBuyingAgentSortClass() {
        return this.sortClass('realtorBuyingAgentName');
    }

    get realtorBuyingAgentSortIndicator() {
        return this.sortIndicator('realtorBuyingAgentName');
    }

    get appointmentDateTimeSortClass() {
        return this.sortClass('appointmentDateTime');
    }

    get appointmentDateTimeSortIndicator() {
        return this.sortIndicator('appointmentDateTime');
    }

    get loanDetailsSortClass() {
        return this.sortClass('loanDetails');
    }

    get loanDetailsSortIndicator() {
        return this.sortIndicator('loanDetails');
    }

    get dateSortClass() {
        return this.sortClass('displayDateTime');
    }

    get dateSortIndicator() {
        return this.sortIndicator('displayDateTime');
    }

    get closingDateSortClass() {
        return this.sortClass('displayDate');
    }

    get closingDateSortIndicator() {
        return this.sortIndicator('displayDate');
    }

    get cdSentDateSortClass() {
        return this.sortClass('cdSentDate');
    }

    get cdSentDateSortIndicator() {
        return this.sortIndicator('cdSentDate');
    }

    get fundingDateSortClass() {
        return this.sortClass('fundingDate');
    }

    get fundingDateSortIndicator() {
        return this.sortIndicator('fundingDate');
    }

    get detailSortClass() {
        return this.sortClass('detail');
    }

    get detailSortIndicator() {
        return this.sortIndicator('detail');
    }

    get purposeSortClass() {
        return this.sortClass('loanPurpose');
    }

    get purposeSortIndicator() {
        return this.sortIndicator('loanPurpose');
    }

    get closerNotesSortClass() {
        return this.sortClass('closerNotes');
    }

    get closerNotesSortIndicator() {
        return this.sortIndicator('closerNotes');
    }

    get tridSortClass() {
        return this.sortClass(this.openerDateSortField);
    }

    get tridSortIndicator() {
        return this.sortIndicator(this.openerDateSortField);
    }

    get lenderSortClass() {
        return this.sortClass('lenderName');
    }

    get lenderSortIndicator() {
        return this.sortIndicator('lenderName');
    }

    get loanOfficerSortClass() {
        return this.sortClass('loanOfficerName');
    }

    get loanOfficerSortIndicator() {
        return this.sortIndicator('loanOfficerName');
    }

    get processorSortClass() {
        return this.sortClass('processorName');
    }

    get processorSortIndicator() {
        return this.sortIndicator('processorName');
    }

    get lastProcessorSmsSortClass() {
        return this.sortClass('lastProcessorSms');
    }

    get lastProcessorSmsSortIndicator() {
        return this.sortIndicator('lastProcessorSms');
    }

    get lastProcessorCallSortClass() {
        return this.sortClass('lastProcessorCall');
    }

    get lastProcessorCallSortIndicator() {
        return this.sortIndicator('lastProcessorCall');
    }

    get ownerSortClass() {
        return this.sortClass('ownerName');
    }

    get ownerSortIndicator() {
        return this.sortIndicator('ownerName');
    }

    get amountSortClass() {
        return this.sortClass('loanAmount');
    }

    get amountSortIndicator() {
        return this.sortIndicator('loanAmount');
    }

    formatDate(value) {
        if (!value) {
            return '';
        }
        return new Intl.DateTimeFormat('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        }).format(new Date(`${value}T00:00:00`));
    }

    formatDateTimeOrDate(dateTimeValue, dateValue) {
        if (dateTimeValue) {
            return new Intl.DateTimeFormat('en-US', {
                month: 'short',
                day: 'numeric',
                hour: 'numeric',
                minute: '2-digit'
            }).format(new Date(dateTimeValue));
        }
        return this.formatDate(dateValue);
    }

    formatCurrency(value) {
        if (value === null || value === undefined) {
            return '';
        }
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(value);
    }

    formatPercent(value) {
        if (value === null || value === undefined) {
            return '0.0%';
        }
        return `${Number(value).toFixed(1)}%`;
    }

    formatNumber(value) {
        if (value === null || value === undefined) {
            return '0.0';
        }
        return Number(value).toFixed(1);
    }

    statusClass(status) {
        const normalizedStatus = (status || '').toLowerCase();
        if (normalizedStatus === 'new') {
            return 'pcc-status pcc-status-new';
        }
        if (normalizedStatus.includes('contact attempt') || normalizedStatus.includes('contacted/call back')) {
            return 'pcc-status pcc-status-contact-attempt';
        }
        if (normalizedStatus === 'working') {
            return 'pcc-status pcc-status-working';
        }
        if (normalizedStatus === 'documents requested') {
            return 'pcc-status pcc-status-docs-requested';
        }
        if (normalizedStatus === 'documents received for review') {
            return 'pcc-status pcc-status-docs-received';
        }
        if (normalizedStatus === 'trid application') {
            return 'pcc-status pcc-status-trid';
        }
        if (normalizedStatus === 'open' || normalizedStatus === 'submission form complete') {
            return 'pcc-status pcc-status-open';
        }
        if (normalizedStatus === 'disclosures out') {
            return 'pcc-status pcc-status-disclosures-out';
        }
        if (normalizedStatus === 'pre-processing') {
            return 'pcc-status pcc-status-pre-processing';
        }
        if (normalizedStatus === 'processing') {
            return 'pcc-status pcc-status-processing';
        }
        if (normalizedStatus === 'conditionally approved' || normalizedStatus === 'approved') {
            return 'pcc-status pcc-status-conditionally-approved';
        }
        if (normalizedStatus.includes('funding')) {
            return 'pcc-status pcc-status-funding';
        }
        if (normalizedStatus.includes('closing')) {
            return 'pcc-status pcc-status-closing';
        }
        if (normalizedStatus === 'pc review' || normalizedStatus === 'post-closed') {
            return 'pcc-status pcc-status-pc-review';
        }
        if (normalizedStatus === 'cancelled' || normalizedStatus === 'canceled') {
            return 'pcc-status pcc-status-cancelled';
        }
        if (normalizedStatus === 'under contract') {
            return 'pcc-status pcc-status-under-contract';
        }
        if (normalizedStatus === 'pre-approval' || normalizedStatus === 'preapproval') {
            return 'pcc-status pcc-status-pre-approval';
        }
        return 'pcc-status pcc-status-review';
    }

    statusLabel(status) {
        return (status || '').toLowerCase() === 'open' ? 'Submission Form Complete' : status;
    }

    defaultEventStartDateTime() {
        const dateValue = new Date();
        dateValue.setHours(dateValue.getHours() + 1, 0, 0, 0);
        const yyyy = dateValue.getFullYear();
        const mm = String(dateValue.getMonth() + 1).padStart(2, '0');
        const dd = String(dateValue.getDate()).padStart(2, '0');
        const hh = String(dateValue.getHours()).padStart(2, '0');
        const min = String(dateValue.getMinutes()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}T${hh}:${min}`;
    }

    extractError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (Array.isArray(error?.body) && error.body.length && error.body[0].message) {
            return error.body[0].message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Unable to load pipeline command center data.';
    }
}
