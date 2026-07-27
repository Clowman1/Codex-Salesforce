import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

export default class LeadConditionChoiceCards extends LightningElement {
    @api selectedChoice;
    errorMessage = '';

    get initialClass() {
        return this.cardClass('Create Initial Bundle');
    }

    get additionalClass() {
        return this.cardClass('Additional Conditions');
    }

    cardClass(value) {
        return this.selectedChoice === value ? 'choice-card choice-card-selected' : 'choice-card';
    }

    handleSelect(event) {
        this.selectedChoice = event.currentTarget.dataset.value;
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedChoice', this.selectedChoice));
        this.errorMessage = '';
    }

    @api
    validate() {
        if (this.selectedChoice) {
            return { isValid: true };
        }
        this.errorMessage = 'Please choose a condition workflow before continuing.';
        return {
            isValid: false,
            errorMessage: this.errorMessage
        };
    }
}
