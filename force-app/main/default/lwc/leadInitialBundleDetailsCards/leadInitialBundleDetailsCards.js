import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

export default class LeadInitialBundleDetailsCards extends LightningElement {
    @api loanPurpose;
    @api employmentType;
    @api selfEmploymentType;
    errorMessage = '';

    get purchaseClass() {
        return this.cardClass(this.loanPurpose, 'Purchase');
    }

    get refinanceClass() {
        return this.cardClass(this.loanPurpose, 'Refinance');
    }

    cardClass(currentValue, value) {
        return currentValue === value ? 'option-card option-card-selected' : 'option-card';
    }

    handleSelect(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.currentTarget.dataset.value;
        this[field] = value;
        this.dispatchEvent(new FlowAttributeChangeEvent(field, value));
        this.employmentType = null;
        this.selfEmploymentType = null;
        this.dispatchEvent(new FlowAttributeChangeEvent('employmentType', null));
        this.dispatchEvent(new FlowAttributeChangeEvent('selfEmploymentType', null));
        this.errorMessage = '';
    }

    @api
    validate() {
        if (!this.loanPurpose) {
            this.errorMessage = 'Please choose Purchase or Refinance before continuing.';
            return { isValid: false, errorMessage: this.errorMessage };
        }
        return { isValid: true };
    }
}
