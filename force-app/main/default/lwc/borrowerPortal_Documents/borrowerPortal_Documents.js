/**
 * Created by zeyad on 7/14/2024.
 */

import { LightningElement, wire, track,api } from 'lwc';
import getData from '@salesforce/apex/BorrowerDocumentPortalController.initializeData';
import FORM_FACTOR from '@salesforce/client/formFactor';
import { CurrentPageReference } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import pulseResources from '@salesforce/resourceUrl/PULSEResources';

export default class BorrowerPortalDocuments extends LightningElement {
    isPhone = false;
    @api tableHeaderColor;
    @api tableHeaderTextColor;
    @track hashRecordId;
    conditions = [];
    recordId;
    @track borrowerName;
    documentStatus = {
        approved : 0,
        requested : 0,
        pending : 0
    }

    connectedCallback() {
        loadStyle(this, pulseResources + '/css/dropZoneStyle.css')
            .then(() => {
                console.log('CSS file loaded successfully');
            })
            .catch(error => {
                console.error('Error loading CSS file', error);
            });
        let root = this.template.host;
        root.style.setProperty('--portal-table-row-header-color',this.tableHeaderColor);
        root.style.setProperty('--portal-table-row-header-text-color',this.tableHeaderTextColor);

        if (FORM_FACTOR === 'Small') {
            this.isPhone = true;
        }
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.hashRecordId = currentPageReference.state?.id;
        }
    }
    @wire(getData, { hashFromURL: '$hashRecordId', isInSitePreview: false})
    wiredData({ error, data }) {
        if (data) {
            this.recordId = data.recordId;
            const statusOrder = {
                'New': 1,
                'Requested': 2,
                'Review': 3,
                'Approved': 4,
                'Cleared': 5,
                'Submitted': 6
            };
            this.conditions = [...data.conditions];
            this.conditions = this.conditions.toSorted((a, b) => {
                return (statusOrder[a.status] || 7) - (statusOrder[b.status] || 7);
            });
            this.documentStatus.approved = data.approvedDocuments;
            this.documentStatus.requested = data.requestedDocuments + data.outstandingDocuments;
            this.documentStatus.pending = data.pendingReviewDocuments;
            this.borrowerName = data.borrowerName;
        } else if (error) {
            this.error = error;
            this.record = undefined;
        }
    }
}
