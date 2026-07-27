/**
 * Created by zeyad on 7/14/2024.
 */

import { LightningElement, api } from 'lwc';
import FORM_FACTOR from '@salesforce/client/formFactor';
import fileUpdateConditionId from '@salesforce/apex/BorrowerDocumentPortalController.updateLoanConditionOnFileUpload';
import markProcessorCommentsViewedByBorrower
    from '@salesforce/apex/BorrowerDocumentPortalController.markProcessorCommentsViewedByBorrower';
import ConditionCommentsModal from 'c/conditionCommentsModal';
import ConditionUploadModal from 'c/conditionUploadModal';

export default class BorrowerPortalDocumentRow extends LightningElement {
    @api condition;
    @api loanId;
    result;

    connectedCallback() {
        if (FORM_FACTOR === 'Small') {
            this.isPhone = true;
        }
    }

    async toggleCommentsVisibility(){
        this.clearActiveCommentIndicator();
        this.result = await ConditionCommentsModal.open({
            label: 'Condition Comments',
            header: 'Condition Comments',
            size: 'full',
            conditionId: this.condition.id,
            portal : true,
            oncommentcreated: () => this.handleCommentCreated()
        });
    }

    async openUploadModal() {
        const updatedCondition = await ConditionUploadModal.open({
            label: 'Upload Files',
            size: 'small',
            loanId: this.loanId,
            conditionId: this.condition.id
        });

        if (updatedCondition) {
            this.condition = updatedCondition;
        }
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        console.log('No. of files uploaded : ' + uploadedFiles.length);
        const versionsIds = [];

        for (const file of uploadedFiles) {
            versionsIds.push(file.contentVersionId);
        }
        fileUpdateConditionId({
            contentVersionIds: versionsIds,
            conditionId: this.condition.id
        }).then(result => {
            this.condition = result;
            console.log(result);
        }).catch(error => {
            console.log(error);
        })
    }

    handleCommentCreated() {
        this.condition = {
            ...this.condition,
            commentCount: (this.condition?.commentCount || 0) + 1,
            activeCommentCount: 0,
            hasActiveComments: false
        };
    }

    clearActiveCommentIndicator() {
        if (!this.condition?.hasActiveComments) {
            return;
        }

        this.condition = {
            ...this.condition,
            activeCommentCount: 0,
            hasActiveComments: false
        };

        markProcessorCommentsViewedByBorrower({ conditionId: this.condition.id })
            .catch(error => {
                console.log(error);
            });
    }

    get commentsButtonClass() {
        return this.condition?.hasActiveComments ? 'comments-button comments-button_active' : 'comments-button';
    }

    get desktopCommentsButtonClass() {
        return this.condition?.hasActiveComments
            ? 'desktop-comments-button desktop-comments-button_active'
            : 'desktop-comments-button';
    }

    get commentIconClass() {
        return this.condition?.hasActiveComments
            ? 'slds-button slds-button_icon slds-button_icon-large comment-icon-button comment-icon-button_active'
            : 'slds-button slds-button_icon slds-button_icon-large comment-icon-button';
    }
}