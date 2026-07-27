import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import getRealtorPartnerFormOptions from '@salesforce/apex/PipelineCommandCenterController.getRealtorPartnerFormOptions';
import createRealtorPartner from '@salesforce/apex/PipelineCommandCenterController.createRealtorPartner';
import searchRealtorAccounts from '@salesforce/apex/PipelineCommandCenterController.searchRealtorAccounts';

export default class FlowRealtorAccountLookup extends LightningElement {
    @api label = 'Realtor - Buying Agent';
    @api required = false;
    @api selectedRecordId;

    searchTerm = '';
    options = [];
    selectedLabel = '';
    selectedSubtitle = '';
    errorMessage = '';
    isSearching = false;
    isCreateOpen = false;
    isCreating = false;
    hasSearched = false;
    searchTimeout;
    createFirstName = '';
    createLastName = '';
    createPhone = '';
    createEmail = '';
    createBizDevDesignation = '';
    bizDevOptions = [];

    connectedCallback() {
        this.loadFormOptions();
    }

    get hasSelection() {
        return Boolean(this.selectedRecordId);
    }

    get showResults() {
        return !this.hasSelection && this.options.length > 0;
    }

    get showNoResults() {
        return !this.hasSelection && this.hasSearched && !this.isSearching && this.searchTerm.length >= 2 && this.options.length === 0;
    }

    get showLookupSearch() {
        return !this.hasSelection && !this.isCreateOpen;
    }

    get createButtonLabel() {
        return this.isCreating ? 'Creating...' : 'Create Realtor Partner';
    }

    async loadFormOptions() {
        try {
            const data = await getRealtorPartnerFormOptions();
            this.bizDevOptions = data?.bizDevDesignation || [];
        } catch (error) {
            this.bizDevOptions = [];
        }
    }

    handleFocus() {
        if (this.searchTerm.length >= 2 && this.options.length === 0) {
            this.runSearch();
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value || '';
        this.errorMessage = '';
        window.clearTimeout(this.searchTimeout);

        if (this.searchTerm.trim().length < 2) {
            this.options = [];
            this.hasSearched = false;
            this.isSearching = false;
            return;
        }

        this.searchTimeout = window.setTimeout(() => {
            this.runSearch();
        }, 250);
    }

    openCreatePanel() {
        this.errorMessage = '';
        this.isCreateOpen = true;
        this.options = [];
    }

    closeCreatePanel() {
        this.errorMessage = '';
        this.isCreateOpen = false;
        this.isCreating = false;
    }

    handleCreateInput(event) {
        this[event.currentTarget.dataset.field] = event.detail.value;
    }

    async createRealtorAccount() {
        const inputs = [...this.template.querySelectorAll('[data-create-realtor-input="true"]')];
        const valid = inputs.reduce((isValid, input) => {
            input.reportValidity();
            return isValid && input.checkValidity();
        }, true);

        if (!valid) {
            this.errorMessage = 'Complete the required Realtor fields before creating the account.';
            return;
        }

        this.isCreating = true;
        this.errorMessage = '';

        try {
            const recordId = await createRealtorPartner({
                firstName: this.createFirstName,
                lastName: this.createLastName,
                mobilePhone: this.createPhone,
                email: this.createEmail,
                bizDevDesignation: this.createBizDevDesignation,
                brokerage: '',
                realtorGroup: '',
                transactionCoordinatorId: null,
                realtorIndividualLicenseNumber: '',
                companyLicenseNumber: ''
            });

            this.selectedRecordId = recordId;
            this.selectedLabel = `${this.createFirstName || ''} ${this.createLastName || ''}`.trim();
            this.selectedSubtitle = [this.createPhone, this.createEmail].filter(Boolean).join(' | ');
            this.searchTerm = '';
            this.options = [];
            this.hasSearched = false;
            this.isCreateOpen = false;
            this.dispatchEvent(new FlowAttributeChangeEvent('selectedRecordId', this.selectedRecordId));
        } catch (error) {
            this.errorMessage = error?.body?.message || 'Unable to create the Realtor Partner account.';
        } finally {
            this.isCreating = false;
        }
    }

    async runSearch() {
        const term = this.searchTerm.trim();
        if (term.length < 2) {
            return;
        }

        this.isSearching = true;
        this.hasSearched = true;
        try {
            this.options = await searchRealtorAccounts({ searchTerm: term });
        } catch (error) {
            this.options = [];
            this.errorMessage = error?.body?.message || 'Unable to search Realtor accounts.';
        } finally {
            this.isSearching = false;
        }
    }

    selectOption(event) {
        this.selectedRecordId = event.currentTarget.dataset.id;
        this.selectedLabel = event.currentTarget.dataset.label;
        this.selectedSubtitle = event.currentTarget.dataset.subtitle;
        this.errorMessage = '';
        this.options = [];
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedRecordId', this.selectedRecordId));
    }

    clearSelection() {
        this.selectedRecordId = null;
        this.selectedLabel = '';
        this.selectedSubtitle = '';
        this.searchTerm = '';
        this.options = [];
        this.hasSearched = false;
        this.isCreateOpen = false;
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedRecordId', null));
    }

    @api
    validate() {
        if (this.required && !this.selectedRecordId) {
            this.errorMessage = 'Select a Realtor - Buying Agent.';
            return {
                isValid: false,
                errorMessage: this.errorMessage
            };
        }

        this.errorMessage = '';
        return { isValid: true };
    }
}
