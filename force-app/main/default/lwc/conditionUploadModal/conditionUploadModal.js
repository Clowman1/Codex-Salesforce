import LightningModal from 'lightning/modal';
import { api } from 'lwc';
import fileUpdateConditionId from '@salesforce/apex/BorrowerDocumentPortalController.updateLoanConditionOnFileUpload';

export default class ConditionUploadModal extends LightningModal {
    @api loanId;
    @api conditionId;

    handleUploadFinished(event) {
        const contentVersionIds = event.detail.files.map((file) => file.contentVersionId);

        fileUpdateConditionId({
            contentVersionIds,
            conditionId: this.conditionId
        }).then((updatedCondition) => {
            this.close(updatedCondition);
        }).catch((error) => {
            // Keep the modal open so the borrower can retry the upload.
            console.log(error);
        });
    }
}