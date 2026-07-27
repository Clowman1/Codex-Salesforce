import { api, LightningElement } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class TransactionSubmissionFormAction extends LightningElement {
    _recordId;
    hasStartedFlow = false;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        this.startFlowWhenReady();
    }

    get isReady() {
        return Boolean(this.recordId) && this.hasStartedFlow;
    }

    get inputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    renderedCallback() {
        this.startFlowWhenReady();
    }

    startFlowWhenReady() {
        if (!this.recordId || this.hasStartedFlow) {
            return;
        }

        const flow = this.template.querySelector('lightning-flow');
        if (!flow) {
            return;
        }

        this.hasStartedFlow = true;
        flow.startFlow('Loan_Origination_Submission_Form', this.inputVariables);
    }

    handleStatusChange(event) {
        const status = event.detail.status;
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }
}
