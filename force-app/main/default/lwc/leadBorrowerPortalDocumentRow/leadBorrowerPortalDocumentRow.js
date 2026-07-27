import { LightningElement, api } from 'lwc';
import FORM_FACTOR from '@salesforce/client/formFactor';
import updateRequestOnFileUpload from '@salesforce/apex/LeadDocumentPortalController.updateRequestOnFileUpload';

export default class LeadBorrowerPortalDocumentRow extends LightningElement {
    @api request;
    @api leadId;
    @api portalHash;
    isPhone = false;

    connectedCallback() {
        if (FORM_FACTOR === 'Small') {
            this.isPhone = true;
        }
    }

    handleUploadFinished(event) {
        const contentVersionIds = this.getUploadedContentVersionIds(event);
        if (contentVersionIds.length === 0) {
            this.dispatchUploadError(new Error('No uploaded files were returned by Salesforce. Please try again.'));
            return;
        }

        updateRequestOnFileUpload({
            contentVersionIds,
            requestId: this.request.id,
            hashFromURL: this.portalHash
        }).then(result => {
            this.request = result;
            this.dispatchEvent(new CustomEvent('requestupdated', {
                detail: { request: result },
                bubbles: true,
                composed: true
            }));
        }).catch(error => {
            this.dispatchUploadError(error);
        });
    }

    getUploadedContentVersionIds(event) {
        return (event?.detail?.files || [])
            .map(file => file?.contentVersionId)
            .filter(contentVersionId => Boolean(contentVersionId));
    }

    dispatchUploadError(error) {
        this.dispatchEvent(new CustomEvent('uploaderror', {
            detail: { error },
            bubbles: true,
            composed: true
        }));
    }
}