import { LightningElement, api, track } from 'lwc';
import { FlowNavigationNextEvent, FlowNavigationFinishEvent } from 'lightning/flowSupport';
import getPresetConditions from '@salesforce/apex/LeadPresetConditionSelectorController.getPresetConditions';
import createSelectedConditionKeys from '@salesforce/apex/LeadPresetConditionSelectorController.createSelectedConditionKeys';

const SECTION_ORDER = [
    'Identification',
    'Identification - Others',
    'W2 Income',
    'Self-Employed Income',
    'Retired Income',
    'Special Income Types',
    'Required Assets',
    'Additional Asset Documentation',
    'Other Items'
];

const SECTION_LABELS = {
    'Identification': {
        category: 'Identification',
        title: 'Identification - Required',
        note: 'Common, pre-checked'
    },
    'Identification - Others': {
        category: 'Identification',
        title: 'Identification - Additional Documents',
        note: 'May be required'
    },
    'W2 Income': {
        category: 'Income',
        title: 'W2 Income',
        note: 'Common documents are listed first; select only what applies.'
    },
    'Self-Employed Income': {
        category: 'Income',
        title: 'Self-Employed Income',
        note: 'Common documents are listed first; select only what applies.'
    },
    'Retired Income': {
        category: 'Income',
        title: 'Retired Income',
        note: 'Common documents are listed first; select only what applies.'
    },
    'Special Income Types': {
        category: 'Income',
        title: 'Income - Special Income Types',
        note: 'Additional income, as applicable'
    },
    'Required Assets': {
        category: 'Assets',
        title: 'Assets - Required for Purchase',
        note: 'Common, pre-checked'
    },
    'Additional Asset Documentation': {
        category: 'Assets',
        title: 'Assets - Additional Documentation',
        note: 'May be required'
    },
    'Other Items': {
        category: 'Other Items',
        title: 'Other Items - Real Estate Owned',
        note: 'Optional'
    }
};

const INCOME_SECTION_MAP = {
    'W-2 Borrowers - Commonly Requested': 'W2 Income',
    'W-2 Borrowers - May Be Required': 'W2 Income',
    'Self-Employed Borrowers - Commonly Requested': 'Self-Employed Income',
    'Self-Employed Borrowers - Business Returns': 'Self-Employed Income',
    'Self-Employed Borrowers - Business Financials': 'Self-Employed Income',
    'Self-Employed Borrowers - Business Verification': 'Self-Employed Income',
    'Self-Employed Borrowers - Additional Self-Employment Items': 'Self-Employed Income',
    'Retired Borrowers - Commonly Requested': 'Retired Income',
    'Retired Borrowers - May Be Required': 'Retired Income'
};

export default class LeadPresetConditionSelector extends LightningElement {
    @api recordId;
    @api loanPurpose;
    @api employmentType;
    @api selfEmploymentType;
    @api availableActions = [];

    @track conditions = [];
    @track expandedSectionNames = [];
    isLoading = false;
    errorMessage = '';

    connectedCallback() {
        this.loadConditions();
    }

    @api
    async loadConditions() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const data = await getPresetConditions({
                loanPurpose: this.loanPurpose,
                employmentType: this.employmentType,
                selfEmploymentType: this.selfEmploymentType
            });
            this.conditions = (data || []).map(item => ({
                ...item,
                key: item.key || item.id,
                selected: item.defaultSelected === true
            }));
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleToggle(event) {
        const key = event.target.dataset.key;
        const selected = event.target.checked;
        this.conditions = this.conditions.map(item => item.key === key ? { ...item, selected } : item);
    }

    handleToggleSection(event) {
        const sectionName = event.currentTarget.dataset.section;
        if (this.expandedSectionNames.includes(sectionName)) {
            this.expandedSectionNames = this.expandedSectionNames.filter(name => name !== sectionName);
            return;
        }
        this.expandedSectionNames = [...this.expandedSectionNames, sectionName];
    }

    async handleCreate() {
        if (this.disableCreate) {
            return;
        }
        this.isLoading = true;
        this.errorMessage = '';
        try {
            await createSelectedConditionKeys({
                leadId: this.recordId,
                selectedKeys: this.conditions.filter(item => item.selected).map(item => item.key)
            });
            this.navigateForward();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    navigateForward() {
        if (this.availableActions.includes('FINISH')) {
            this.dispatchEvent(new FlowNavigationFinishEvent());
            return;
        }
        if (this.availableActions.includes('NEXT')) {
            this.dispatchEvent(new FlowNavigationNextEvent());
        }
    }

    get sections() {
        const sectionsByName = new Map();
        this.conditions.forEach(item => {
            const name = this.displaySectionName(item.section || 'Other Conditions');
            if (!sectionsByName.has(name)) {
                sectionsByName.set(name, []);
            }
            sectionsByName.get(name).push({
                    ...item,
                    key: item.key || item.id,
                    className: item.selected ? 'condition-card condition-card-selected' : 'condition-card'
                });
        });

        return Array.from(sectionsByName.keys())
            .sort((left, right) => this.sectionIndex(left) - this.sectionIndex(right))
            .map(name => {
                const items = sectionsByName.get(name).sort((left, right) => (left.sortOrder || 0) - (right.sortOrder || 0));
                const selectedCount = items.filter(item => item.selected).length;
                const isIncome = this.sectionCategory(name) === 'Income';
                const isExpanded = !isIncome || this.expandedSectionNames.includes(name);
                return {
                    name,
                    title: this.sectionTitle(name),
                    items,
                    selectedCount,
                    category: this.sectionCategory(name),
                    note: this.sectionNote(name),
                    className: [
                        'condition-section',
                        selectedCount > 0 ? 'condition-section-active' : '',
                        isIncome ? 'condition-section-collapsible' : '',
                        isExpanded ? 'condition-section-expanded' : 'condition-section-collapsed'
                    ].filter(Boolean).join(' '),
                    isIncome,
                    isExpanded,
                    toggleLabel: isExpanded ? 'Minimize' : 'Expand',
                    toggleSymbol: isExpanded ? '-' : '+'
                };
            });
    }

    get hasSections() {
        return this.sections.length > 0 && !this.isLoading;
    }

    get selectedCount() {
        return this.conditions.filter(item => item.selected).length;
    }

    get disableCreate() {
        return this.isLoading || this.selectedCount === 0;
    }

    sectionIndex(name) {
        const index = SECTION_ORDER.indexOf(name);
        return index === -1 ? 999 : index;
    }

    displaySectionName(name) {
        return INCOME_SECTION_MAP[name] || name;
    }

    sectionCategory(name) {
        return SECTION_LABELS[name]?.category || 'Conditions';
    }

    sectionTitle(name) {
        return SECTION_LABELS[name]?.title || name;
    }

    sectionNote(name) {
        return SECTION_LABELS[name]?.note || 'May be required';
    }

    reduceError(error) {
        return error?.body?.message || error?.message || 'Unable to load preset conditions.';
    }
}
