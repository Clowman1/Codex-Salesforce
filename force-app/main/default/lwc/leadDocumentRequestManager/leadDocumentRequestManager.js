import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { getFieldValue, getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import initializeData from '@salesforce/apex/LeadDocumentRequestController.initializeData';
import saveRequests from '@salesforce/apex/LeadDocumentRequestController.saveRequests';
import deleteRequest from '@salesforce/apex/LeadDocumentRequestController.deleteRequest';
import saveNotes from '@salesforce/apex/LeadDocumentRequestController.saveNotes';
import addComment from '@salesforce/apex/LeadDocumentRequestController.addComment';
import handleInternalFileUpload from '@salesforce/apex/LeadDocumentRequestController.handleInternalFileUpload';
import getRequestDocuments from '@salesforce/apex/LeadDocumentRequestController.getRequestDocuments';
import approveRequestDocument from '@salesforce/apex/LeadDocumentRequestController.approveRequestDocument';
import rejectRequestDocument from '@salesforce/apex/LeadDocumentRequestController.rejectRequestDocument';
import getEmailTemplateOptions from '@salesforce/apex/LeadDocumentRequestController.getEmailTemplateOptions';
import getEmailTemplatePreview from '@salesforce/apex/LeadDocumentRequestController.getEmailTemplatePreview';
import sendEditedRequestEmail from '@salesforce/apex/LeadDocumentRequestController.sendEditedRequestEmail';
import IS_CONVERTED_FIELD from '@salesforce/schema/Lead.IsConverted';
import CONVERTED_TRANSACTION_FIELD from '@salesforce/schema/Lead.Converted_Transaction_ID__c';

const DEFAULT_ROW_TYPE = 'Processor';
const DEFAULT_ROW_STATUS = 'New';
const CREATE_REQUESTS_FLOW_API_NAME = 'Lead_Document_Requests_Creator';
const EMPTY_ROW = {
    name: '',
    subject: '',
    description: '',
    category: '',
    type: DEFAULT_ROW_TYPE,
    status: DEFAULT_ROW_STATUS,
    includeInEmail: true,
    canBorrowerSee: true,
    fileCount: 0
};
const REQUIRED_REQUEST_MESSAGE = 'Enter request details before saving.';
const NO_SAVED_REQUESTS_MESSAGE = 'Add a request before saving.';
const REQUEST_TABLES = [
    {
        key: 'outstanding',
        label: 'Outstanding Requests',
        statuses: ['New', 'Submitted', 'Requested', 'Review']
    },
    {
        key: 'ready',
        label: 'Ready for Lender Requests',
        statuses: ['Approved']
    },
    {
        key: 'cleared',
        label: 'Cleared Requests',
        statuses: ['Cleared']
    }
];
const LEAD_CONVERSION_FIELDS = [IS_CONVERTED_FIELD, CONVERTED_TRANSACTION_FIELD];

export default class LeadDocumentRequestManager extends LightningElement {
    _recordId;
    loadedRecordId;
    loadingRecordId;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        this.loadDataIfReady();
    }

    @track rows = [];
    @track draftRows = [];
    leadName;
    borrowerEmail;
    portalLink;
    isConverted = false;
    convertedTransactionId;
    isLoading = false;
    showCreateModal = false;
    showEmailModal = false;
    emailTemplateOptions = [];
    selectedEmailTemplate;
    emailSectionOneHtml = '';
    emailBody = '';
    emailLastSectionHtml = '';
    emailSubjectLine = '';
    emailEditorFormats = ['bold', 'italic', 'underline', 'strike', 'list', 'indent', 'link', 'color'];
    showUploadModal = false;
    uploadRequestKey;
    uploadRequestName;
    showDocumentPreviewModal = false;
    documentPreviewTitle = 'Uploaded Documents';
    previewDocuments = [];
    selectedPreviewDocumentId;
    previewRequestId;
    previewRequestKey;
    previewRequestDescription;
    showRejectPrompt = false;
    selectedRejectDocumentId;
    selectedRejectDocumentTitle;
    rejectionReason = '';
    updatedRequestDescription = '';
    expandedNotesKey;
    expandedCommentsKey;
    notesDescriptionDraft = '';
    internalNotesDraft = '';
    commentDraft = '';
    inlineEditKey;
    inlineEditField;

    categoryOptions = [
        'Income', 'Assets', 'REO', 'Appraisal', 'Escrow', 'Payoff Demand', 'HOI',
        'Approval', 'Title', 'WVOE', 'EMD', 'LOE', 'Disclosures', 'VOM', 'VOR',
        'Condo', 'Gift Letter', 'HOA', 'VA', 'Survey', 'ID', 'Generic'
    ].map(value => ({ label: value, value }));

    statusOptions = [
        'New', 'Requested', 'Review', 'Approved', 'Cleared', 'Submitted'
    ].map(value => ({ label: value, value }));

    typeOptions = [
        { label: 'Processor', value: 'Processor' },
        { label: 'Borrower', value: 'Borrower' },
        { label: 'Generic', value: 'Generic' }
    ];

    connectedCallback() {
        this.setRecordIdIfMissing(this.getRecordIdFromUrl());
    }

    renderedCallback() {
        this.setRecordIdIfMissing(this.getRecordIdFromUrl());
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(pageReference) {
        this.setRecordIdIfMissing(this.getRecordIdFromPageReference(pageReference));
    }

    @wire(getRecord, { recordId: '$recordId', fields: LEAD_CONVERSION_FIELDS })
    setLeadRecord({ data }) {
        if (!data) {
            return;
        }
        const isConverted = getFieldValue(data, IS_CONVERTED_FIELD) === true;
        const convertedTransactionId = getFieldValue(data, CONVERTED_TRANSACTION_FIELD);
        if (isConverted || convertedTransactionId) {
            this.applyConvertedState(convertedTransactionId);
        }
    }

    loadDataIfReady() {
        if (!this.recordId || this.loadedRecordId === this.recordId || this.loadingRecordId === this.recordId) {
            return;
        }
        this.loadData(this.recordId);
    }

    setRecordIdIfMissing(value) {
        if (value && !this._recordId) {
            this._recordId = value;
        }
        this.loadDataIfReady();
    }

    getRecordIdFromPageReference(pageReference) {
        const directRecordId = pageReference?.state?.recordId || pageReference?.attributes?.recordId;
        if (directRecordId) {
            return directRecordId;
        }

        const encodedContext = pageReference?.state?.inContextOfRef;
        if (!encodedContext) {
            return null;
        }

        try {
            const normalizedContext = encodedContext.startsWith('1.')
                ? encodedContext.substring(2)
                : encodedContext;
            const decodedContext = JSON.parse(window.atob(decodeURIComponent(normalizedContext)));
            return decodedContext?.attributes?.recordId || decodedContext?.state?.recordId || null;
        } catch (error) {
            return null;
        }
    }

    getRecordIdFromUrl() {
        const match = window.location.href.match(/\/lightning\/r\/Lead\/([a-zA-Z0-9]{15,18})\/view/);
        return match ? match[1] : null;
    }

    async loadData(leadId = this.recordId) {
        if (!leadId) {
            return;
        }
        this.loadingRecordId = leadId;
        this.isLoading = true;
        try {
            const data = await initializeData({ leadId });
            this.leadName = data.leadName;
            this.borrowerEmail = data.borrowerEmail;
            this.portalLink = data.portalLink;
            this.isConverted = data.isConverted;
            this.convertedTransactionId = data.convertedTransactionId;
            this.rows = this.decorateRequests(data.requests);
            if (this.isConverted || this.convertedTransactionId) {
                this.applyConvertedState(this.convertedTransactionId);
            }
            this.loadedRecordId = leadId;
        } catch (error) {
            this.showError(error);
        } finally {
            if (this.loadingRecordId === leadId) {
                this.loadingRecordId = null;
            }
            this.isLoading = false;
        }
    }

    openCreateModal() {
        if (this.isConverted) {
            return;
        }
        this.showCreateModal = true;
    }

    closeCreateModal() {
        this.showCreateModal = false;
        this.draftRows = [];
    }

    async handleCreateFlowStatusChange(event) {
        if (event.detail?.status !== 'FINISHED' && event.detail?.status !== 'FINISHED_SCREEN') {
            return;
        }
        this.closeCreateModal();
        this.loadedRecordId = null;
        await this.loadData(this.recordId);
        this.showToast('Document requests saved.');
    }

    addDraftRow() {
        this.draftRows = [
            ...this.draftRows,
            this.createDraftRow()
        ];
    }

    createDraftRow() {
        return { ...EMPTY_ROW, clientKey: `draft-${Date.now()}-${Math.random()}` };
    }

    handleDraftInputChange(event) {
        const source = event.target || event.currentTarget;
        const key = source?.dataset?.key || event.currentTarget?.dataset?.key;
        const field = source?.dataset?.field || event.currentTarget?.dataset?.field;
        if (!key || !field) {
            return;
        }
        const value = this.getInputValue(source, event);
        this.draftRows = this.draftRows.map(row => row.clientKey === key ? { ...row, [field]: value } : row);
    }

    removeDraftRow(event) {
        const key = event.currentTarget.dataset.key;
        const remainingRows = this.draftRows.filter(row => row.clientKey !== key);
        this.draftRows = remainingRows.length > 0 ? remainingRows : [this.createDraftRow()];
    }

    async handleCreateRequests() {
        if (this.isConverted) {
            return;
        }
        if (!this.recordId) {
            this.showError(new Error('Lead record could not be determined. Refresh the page and try again.'));
            return;
        }
        const draftRowsForSave = this.getDraftRowsFromModal();
        this.draftRows = draftRowsForSave;
        const requestsToSave = draftRowsForSave.filter(row => this.hasDocumentRequestIdentity(row));
        if (requestsToSave.length === 0) {
            this.showError(new Error(this.buildMissingRequestDetailsMessage(draftRowsForSave)));
            return;
        }
        this.isLoading = true;
        try {
            const saved = await saveRequests({ leadId: this.recordId, requests: this.toRequestInputs(requestsToSave) });
            this.rows = this.decorateRequests(saved);
            this.closeCreateModal();
            this.showToast('Document requests saved.');
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    getDraftRowsFromModal() {
        const renderedRows = [];
        this.template.querySelectorAll('[data-draft-row-key]').forEach(rowElement => {
            const row = { ...EMPTY_ROW, clientKey: rowElement.dataset.draftRowKey || this.createDraftRow().clientKey };
            rowElement.querySelectorAll('[data-field]').forEach(input => {
                const field = input.dataset.field;
                row[field] = this.getInputValue(input, null);
            });
            renderedRows.push(row);
        });
        return renderedRows.length > 0 ? renderedRows.map(renderedRow => {
            const draftRow = this.draftRows.find(row => row.clientKey === renderedRow.clientKey) || {};
            return {
                ...draftRow,
                ...renderedRow,
                name: renderedRow.name || draftRow.name || '',
                subject: renderedRow.subject || draftRow.subject || '',
                description: renderedRow.description || draftRow.description || '',
                category: renderedRow.category || draftRow.category || '',
                status: renderedRow.status || draftRow.status || DEFAULT_ROW_STATUS,
                type: renderedRow.type || draftRow.type || DEFAULT_ROW_TYPE,
                includeInEmail: renderedRow.includeInEmail,
                canBorrowerSee: renderedRow.canBorrowerSee
            };
        }) : this.draftRows;
    }

    async handleInputChange(event) {
        if (this.isConverted) {
            return;
        }
        const { key, field } = event.currentTarget.dataset;
        const value = this.getInputValue(event.currentTarget, event);
        let updatedRow;
        this.rows = this.rows.map(row => {
            if (row.clientKey !== key) {
                return row;
            }
            updatedRow = this.decorateRequest(this.applyTransactionToggleRules({ ...row, [field]: value }, field));
            return updatedRow;
        });
        if (field === 'includeInEmail' || field === 'canBorrowerSee') {
            await this.persistRequestRows([updatedRow]);
        }
    }

    beginInlineEdit(event) {
        if (this.isConverted) {
            return;
        }
        const key = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const row = this.rows.find(item => item.clientKey === key);
        if (!row?.id || !field) {
            return;
        }
        this.inlineEditKey = key;
        this.inlineEditField = field;
        this.rows = this.decorateRequests(this.rows);
    }

    saveInlineEdit(event) {
        const key = event.currentTarget.dataset.key;
        const form = Array.from(this.template.querySelectorAll('lightning-record-edit-form[data-inline-edit-form="true"]'))
            .find(formElement =>
                formElement.dataset.editFormKey === key &&
                formElement.dataset.editFormField === this.inlineEditField
            );
        if (!form) {
            return;
        }
        form.submit();
    }

    async handleInlineEditSuccess() {
        this.inlineEditKey = null;
        this.inlineEditField = null;
        await this.loadData(this.recordId);
    }

    handleInlineEditError(event) {
        this.isLoading = false;
        const message = event.detail?.message || 'Please update the record.';
        this.showError(new Error(message));
    }

    cancelInlineEdit() {
        this.inlineEditKey = null;
        this.inlineEditField = null;
        this.rows = this.decorateRequests(this.rows);
    }

    async handleToggleTableEmail(event) {
        if (this.isConverted) {
            return;
        }
        const includeInEmail = this.getInputValue(event.currentTarget, event);
        const tableKey = event.currentTarget.dataset.tableKey;
        const tableConfig = REQUEST_TABLES.find(table => table.key === tableKey);
        if (!tableConfig) {
            return;
        }

        const updatedRows = [];
        this.rows = this.rows.map(row => {
            if (!tableConfig.statuses.includes(row.status)) {
                return row;
            }
            const updatedRow = this.decorateRequest(this.applyTransactionToggleRules({ ...row, includeInEmail }, 'includeInEmail'));
            updatedRows.push(updatedRow);
            return updatedRow;
        });
        await this.persistRequestRows(updatedRows);
    }

    handleToggleEmailAction(event) {
        this.toggleRowBooleanField(event, 'includeInEmail');
    }

    handleTogglePortalAction(event) {
        this.toggleRowBooleanField(event, 'canBorrowerSee');
    }

    async toggleRowBooleanField(event, field) {
        if (this.isConverted) {
            return;
        }
        const key = event.currentTarget.dataset.key;
        let updatedRow;
        this.rows = this.rows.map(row => {
            if (row.clientKey !== key) {
                return row;
            }
            updatedRow = this.decorateRequest(this.applyTransactionToggleRules({ ...row, [field]: !row[field] }, field));
            return updatedRow;
        });
        await this.persistRequestRows([updatedRow]);
    }

    async removeRow(event) {
        if (this.isConverted) {
            return;
        }
        const key = event.currentTarget.dataset.key;
        const row = this.rows.find(item => item.clientKey === key);
        if (row?.id) {
            this.isLoading = true;
            try {
                await deleteRequest({ requestId: row.id });
            } catch (error) {
                this.showError(error);
                this.isLoading = false;
                return;
            }
            this.isLoading = false;
        }
        this.rows = this.rows.filter(item => item.clientKey !== key);
    }

    openUploadModal(event) {
        if (this.isConvertedForDisplay) {
            return;
        }
        const key = event.currentTarget.dataset.key;
        const row = this.rows.find(item => item.clientKey === key);
        if (!row?.id) {
            return;
        }
        this.uploadRequestKey = key;
        this.uploadRequestName = row.name;
        this.showUploadModal = true;
    }

    closeUploadModal() {
        this.showUploadModal = false;
        this.uploadRequestKey = null;
        this.uploadRequestName = null;
    }

    async handleUploadFinished(event) {
        if (this.isConvertedForDisplay) {
            return;
        }
        const key = event.currentTarget.dataset.key || this.uploadRequestKey;
        const row = this.rows.find(item => item.clientKey === key);
        const contentVersionIds = (event.detail?.files || [])
            .map(file => file.contentVersionId)
            .filter(Boolean);
        if (!row?.id || contentVersionIds.length === 0) {
            return;
        }

        this.isLoading = true;
        try {
            const updatedRow = await handleInternalFileUpload({
                requestId: row.id,
                contentVersionIds
            });
            this.rows = this.rows.map(item => item.clientKey === key
                ? this.decorateRequest({ ...updatedRow, clientKey: updatedRow.id })
                : item
            );
            this.closeUploadModal();
            this.showToast('File uploaded to Lead document request.');
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handlePreviewDocuments(event) {
        const key = event.currentTarget.dataset.key;
        const row = this.rows.find(item => item.clientKey === key);
        if (!row?.id) {
            return;
        }

        this.isLoading = true;
        try {
            const documents = await getRequestDocuments({ requestId: row.id });
            this.documentPreviewTitle = `Uploaded Documents for ${row.name}`;
            this.previewRequestId = row.id;
            this.previewRequestKey = key;
            this.previewRequestDescription = row.description || '';
            this.previewDocuments = (documents || []).map(documentItem => ({
                ...documentItem,
                downloadUrl: `/sfc/servlet.shepherd/document/download/${documentItem.id}`,
                previewUrl: `/sfc/servlet.shepherd/document/download/${documentItem.id}`,
                viewUrl: `/lightning/r/ContentDocument/${documentItem.id}/view`,
                sizeLabel: this.formatFileSize(documentItem.contentSize),
                reviewStatusLabel: documentItem.reviewStatus || 'Pending Review',
                isSelected: false
            }));
            this.selectedPreviewDocumentId = this.previewDocuments[0]?.id || null;
            this.previewDocuments = this.decoratePreviewDocumentSelection(this.previewDocuments);
            this.showDocumentPreviewModal = true;
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    closeDocumentPreviewModal() {
        this.showDocumentPreviewModal = false;
        this.previewDocuments = [];
        this.selectedPreviewDocumentId = null;
        this.previewRequestId = null;
        this.previewRequestKey = null;
        this.previewRequestDescription = null;
        this.cancelRejectDocument();
    }

    async handleApproveDocument(event) {
        const contentDocumentId = event?.currentTarget?.dataset?.documentId || this.selectedPreviewDocumentId;
        if (!this.previewRequestId || !contentDocumentId) {
            return;
        }

        this.isLoading = true;
        try {
            const updatedRow = await approveRequestDocument({
                requestId: this.previewRequestId,
                contentDocumentId
            });
            this.applyReviewedDocumentResult(updatedRow, contentDocumentId);
            this.showToast('Document accepted.');
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    openRejectDocumentPrompt(event) {
        const contentDocumentId = event?.currentTarget?.dataset?.documentId || this.selectedPreviewDocumentId;
        const documentTitle = event?.currentTarget?.dataset?.documentTitle || this.selectedPreviewDocument?.filename;
        if (!contentDocumentId) {
            return;
        }
        this.selectedRejectDocumentId = contentDocumentId;
        this.selectedRejectDocumentTitle = documentTitle;
        this.rejectionReason = '';
        this.updatedRequestDescription = this.previewRequestDescription || '';
        this.showRejectPrompt = true;
    }

    selectPreviewDocument(event) {
        const contentDocumentId = event.currentTarget.dataset.documentId;
        if (!contentDocumentId) {
            return;
        }
        this.selectedPreviewDocumentId = contentDocumentId;
        this.previewDocuments = this.decoratePreviewDocumentSelection(this.previewDocuments);
    }

    cancelRejectDocument() {
        this.showRejectPrompt = false;
        this.selectedRejectDocumentId = null;
        this.selectedRejectDocumentTitle = null;
        this.rejectionReason = '';
        this.updatedRequestDescription = '';
    }

    handleRejectionInput(event) {
        this.rejectionReason = event.target.value;
    }

    handleUpdatedDescriptionInput(event) {
        this.updatedRequestDescription = event.target.value;
    }

    async handleRejectDocument() {
        if (!this.previewRequestId || !this.selectedRejectDocumentId) {
            return;
        }
        if (!this.rejectionReason || !this.rejectionReason.trim()) {
            this.showError(new Error('Please enter a rejection comment.'));
            return;
        }

        this.isLoading = true;
        try {
            const updatedRow = await rejectRequestDocument({
                requestId: this.previewRequestId,
                contentDocumentId: this.selectedRejectDocumentId,
                rejectionReason: this.rejectionReason,
                updatedRequestDescription: this.updatedRequestDescription
            });
            this.applyReviewedDocumentResult(updatedRow, this.selectedRejectDocumentId);
            this.cancelRejectDocument();
            this.showToast('Document rejected.');
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    applyReviewedDocumentResult(updatedRow, contentDocumentId) {
        if (updatedRow) {
            this.rows = this.rows.map(item => item.clientKey === this.previewRequestKey
                ? this.decorateRequest({ ...updatedRow, clientKey: updatedRow.id })
                : item
            );
            this.previewRequestDescription = updatedRow.description || this.previewRequestDescription;
        }
        this.previewDocuments = this.previewDocuments.filter(documentItem => documentItem.id !== contentDocumentId);
        this.selectedPreviewDocumentId = this.previewDocuments[0]?.id || null;
        this.previewDocuments = this.decoratePreviewDocumentSelection(this.previewDocuments);
        if (this.previewDocuments.length === 0) {
            this.closeDocumentPreviewModal();
        }
    }

    handleNotesAction(event) {
        const key = event.currentTarget.dataset.key;
        const row = this.rows.find(item => item.clientKey === key);
        if (!row) {
            return;
        }
        const shouldExpand = this.expandedNotesKey !== key;
        this.expandedNotesKey = shouldExpand ? key : null;
        this.expandedCommentsKey = null;
        this.notesDescriptionDraft = shouldExpand ? (row.description || '') : '';
        this.internalNotesDraft = shouldExpand ? (row.internalNotes || '') : '';
        this.rows = this.decorateRequests(this.rows);
    }

    handleCommentsAction(event) {
        const key = event.currentTarget.dataset.key;
        const shouldExpand = this.expandedCommentsKey !== key;
        this.expandedCommentsKey = shouldExpand ? key : null;
        this.expandedNotesKey = null;
        this.commentDraft = '';
        this.rows = this.decorateRequests(this.rows);
    }

    handleNotesDescriptionChange(event) {
        this.notesDescriptionDraft = event.target.value;
    }

    handleInternalNotesChange(event) {
        this.internalNotesDraft = event.target.value;
    }

    handleCommentDraftChange(event) {
        this.commentDraft = event.target.value;
    }

    cancelNotesPanel() {
        this.expandedNotesKey = null;
        this.notesDescriptionDraft = '';
        this.internalNotesDraft = '';
        this.rows = this.decorateRequests(this.rows);
    }

    cancelCommentsPanel() {
        this.expandedCommentsKey = null;
        this.commentDraft = '';
        this.rows = this.decorateRequests(this.rows);
    }

    async handleSaveNotes(event) {
        const key = event.currentTarget.dataset.key;
        const row = this.rows.find(item => item.clientKey === key);
        if (!row?.id) {
            return;
        }

        this.isLoading = true;
        try {
            const updatedRow = await saveNotes({
                requestId: row.id,
                description: this.notesDescriptionDraft,
                internalNotes: this.internalNotesDraft
            });
            this.rows = this.rows.map(item => item.clientKey === key
                ? this.decorateRequest({ ...updatedRow, clientKey: updatedRow.id })
                : item
            );
            this.showToast('Notes saved.');
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async sendComment(event) {
        const key = event.currentTarget.dataset.key;
        const publicComment = event.currentTarget.dataset.public === 'true';
        const row = this.rows.find(item => item.clientKey === key);
        if (!row?.id) {
            return;
        }

        this.isLoading = true;
        try {
            const updatedRow = await addComment({
                requestId: row.id,
                commentText: this.commentDraft,
                publicComment
            });
            this.rows = this.rows.map(item => item.clientKey === key
                ? this.decorateRequest({ ...updatedRow, clientKey: updatedRow.id })
                : item
            );
            this.commentDraft = '';
            this.showToast('Comment sent.');
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSave() {
        if (this.isConverted) {
            return;
        }
        const rowsForSave = this.getRowsFromRenderedTable();
        this.rows = rowsForSave.map(row => this.decorateRequest(row));
        if (rowsForSave.length === 0) {
            this.showError(new Error(NO_SAVED_REQUESTS_MESSAGE));
            return;
        }
        const requestsToSave = rowsForSave.filter(row => this.hasDocumentRequestIdentity(row));
        if (requestsToSave.length === 0) {
            this.showError(new Error(REQUIRED_REQUEST_MESSAGE));
            return;
        }
        this.isLoading = true;
        try {
            const saved = await saveRequests({
                leadId: this.recordId,
                requests: this.toRequestInputs(requestsToSave)
            });
            this.rows = this.decorateRequests(saved);
            this.showToast('Document requests saved.');
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    getRowsFromRenderedTable() {
        const rowsByClientKey = new Map(this.rows.map(row => [String(row.clientKey), { ...row }]));
        this.template.querySelectorAll('[data-row-key]').forEach(rowElement => {
            const clientKey = rowElement.dataset.rowKey;
            const row = rowsByClientKey.get(clientKey);
            if (!row) {
                return;
            }
            rowElement.querySelectorAll('[data-field]').forEach(input => {
                const field = input.dataset.field;
                if (field === 'includeInEmail' || field === 'canBorrowerSee') {
                    return;
                }
                const value = this.getInputValue(input, null);
                row[field] = value === '' && row[field] != null ? row[field] : value;
            });
        });
        return Array.from(rowsByClientKey.values());
    }

    getInputValue(input, event) {
        if (event?.detail?.checked !== undefined) {
            return event.detail.checked;
        }
        if (event?.detail?.value !== undefined && event.detail.value !== null) {
            return event.detail.value;
        }
        if (event?.target?.type === 'checkbox') {
            return event.target.checked;
        }
        if (event?.target?.value !== undefined && event.target.value !== null) {
            return event.target.value;
        }

        const tagName = input?.tagName?.toUpperCase();
        if (tagName === 'LIGHTNING-INPUT') {
            if (input.type === 'checkbox') {
                return input.checked;
            }
            return this.getLightningFieldValue(input, 'input');
        }
        if (tagName === 'LIGHTNING-TEXTAREA') {
            return this.getLightningFieldValue(input, 'textarea');
        }
        if (tagName === 'LIGHTNING-COMBOBOX') {
            return input.value ?? '';
        }
        if (tagName === 'SELECT') {
            return input.value ?? '';
        }
        if (input?.type === 'checkbox') {
            return input.checked;
        }
        return input?.value ?? '';
    }

    getLightningFieldValue(component, selector) {
        const hostValue = component?.value;
        if (hostValue != null && hostValue !== '') {
            return hostValue;
        }
        const internalField = component?.shadowRoot?.querySelector(selector);
        return internalField?.value ?? hostValue ?? '';
    }

    hasDocumentRequestIdentity(row) {
        return Boolean(
            row?.id ||
            row?.name?.trim() ||
            row?.subject?.trim() ||
            row?.description?.trim() ||
            row?.category?.trim()
        );
    }

    buildMissingRequestDetailsMessage(rows) {
        const firstRow = rows?.[0] || {};
        const capturedFields = ['name', 'subject', 'description', 'category']
            .filter(field => firstRow[field])
            .join(', ');
        return capturedFields
            ? `${REQUIRED_REQUEST_MESSAGE} Captured fields: ${capturedFields}.`
            : `${REQUIRED_REQUEST_MESSAGE} No request values were captured from the modal.`;
    }

    async handleSendEmail() {
        if (this.isConverted) {
            return;
        }
        this.isLoading = true;
        try {
            await this.saveRenderedRequests();
            await this.loadEmailTemplateOptions();
            this.selectedEmailTemplate = this.emailTemplateOptions[0]?.value;
            if (!this.selectedEmailTemplate) {
                throw new Error('No Lead document email templates are configured.');
            }
            await this.loadSelectedEmailTemplate();
            this.showEmailModal = true;
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadEmailTemplateOptions() {
        const options = await getEmailTemplateOptions();
        this.emailTemplateOptions = (options || []).map(option => ({
            label: option.label,
            value: option.developerName
        }));
    }

    async handleEmailTemplateChange(event) {
        this.selectedEmailTemplate = event.detail.value;
        this.isLoading = true;
        try {
            await this.loadSelectedEmailTemplate();
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadSelectedEmailTemplate() {
        const renderedEmail = await getEmailTemplatePreview({
            leadId: this.recordId,
            templateDeveloperName: this.selectedEmailTemplate
        });
        this.emailSubjectLine = renderedEmail?.subject || '';
        this.applyEditableEmailBody(renderedEmail?.htmlBody || '');
    }

    applyEditableEmailBody(htmlBody) {
        const startMarker = '<span class="container"></span>';
        const endMarker = '<span class="end-container"></span>';
        const startIndex = htmlBody.indexOf(startMarker);
        const endIndex = htmlBody.lastIndexOf(endMarker);
        const hasEditableMarkers = startIndex >= 0 && endIndex > startIndex;

        this.emailSectionOneHtml = hasEditableMarkers ? htmlBody.substring(0, startIndex) : '';
        this.emailBody = hasEditableMarkers ? htmlBody.substring(startIndex, endIndex) : htmlBody;
        this.emailLastSectionHtml = hasEditableMarkers ? htmlBody.substring(endIndex) : '';
    }

    handleEmailSubjectChange(event) {
        this.emailSubjectLine = event.target.value;
    }

    handleEmailBodyChange(event) {
        this.emailBody = event.detail.value;
    }

    closeEmailModal() {
        this.showEmailModal = false;
        this.emailSubjectLine = '';
        this.emailBody = '';
        this.emailSectionOneHtml = '';
        this.emailLastSectionHtml = '';
    }

    async sendComposedEmail() {
        if (!this.emailSubjectLine || !this.emailSubjectLine.trim()) {
            this.showError(new Error('Email subject is required before sending.'));
            return;
        }
        if (!this.emailBody || !this.emailBody.trim()) {
            this.showError(new Error('Email body is required before sending.'));
            return;
        }

        this.isLoading = true;
        try {
            await sendEditedRequestEmail({
                leadId: this.recordId,
                subject: this.emailSubjectLine,
                htmlBody: this.emailSectionOneHtml + this.emailBody + this.emailLastSectionHtml
            });
            this.showToast(`Document request email sent to ${this.borrowerEmail}.`);
            this.closeEmailModal();
            await this.loadData();
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async saveRenderedRequests() {
        const rowsForSave = this.getRowsFromRenderedTable();
        const requestsToSave = rowsForSave.filter(row => this.hasDocumentRequestIdentity(row));
        if (requestsToSave.length === 0) {
            throw new Error(REQUIRED_REQUEST_MESSAGE);
        }
        await this.persistRequestRows(requestsToSave);
    }

    copyPortalLink() {
        if (!this.portalLink || this.isConverted) {
            return;
        }
        navigator.clipboard?.writeText(this.portalLink);
        this.showToast('Portal link copied.');
    }

    get convertedTransactionUrl() {
        return this.convertedTransactionId ? `/${this.convertedTransactionId}` : '';
    }

    get hasConvertedTransaction() {
        return Boolean(this.convertedTransactionId);
    }

    get isConvertedForDisplay() {
        return this.isConverted || this.hasConvertedTransaction;
    }

    get displayLeadName() {
        const name = this.leadName || '';
        return name.length > 30 ? `${name.substring(0, 30)}...` : name;
    }

    get showCreateFlowForOpenLead() {
        return this.showCreateModal && !this.isConvertedForDisplay;
    }

    get createRequestsFlowApiName() {
        return CREATE_REQUESTS_FLOW_API_NAME;
    }

    get createRequestsFlowInputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    get hasPreviewDocuments() {
        return this.previewDocuments.length > 0;
    }

    get selectedPreviewDocument() {
        return this.previewDocuments.find(documentItem => documentItem.id === this.selectedPreviewDocumentId);
    }

    get selectedPreviewUrl() {
        return this.selectedPreviewDocument?.previewUrl;
    }

    get selectedPreviewTitle() {
        return this.selectedPreviewDocument?.filename || 'Document Preview';
    }

    get selectedPreviewIsImage() {
        const filename = (this.selectedPreviewDocument?.filename || '').toLowerCase();
        return filename.endsWith('.jpg') || filename.endsWith('.jpeg') || filename.endsWith('.png');
    }

    get hasSelectedPreviewDocument() {
        return Boolean(this.selectedPreviewDocument);
    }

    get downloadAllUrl() {
        if (!this.previewDocuments.length) {
            return '';
        }
        return `/sfc/servlet.shepherd/document/download/${this.previewDocuments.map(documentItem => documentItem.id).join('/')}`;
    }

    get newCount() {
        return this.countRowsByStatus('New');
    }

    get requestedCount() {
        return this.countRowsByStatus('Requested');
    }

    get reviewCount() {
        return this.countRowsByStatus('Review');
    }

    get outstandingCount() {
        return this.rows.filter(row =>
            this.hasDocumentRequestIdentity(row) &&
            ['New', 'Submitted', 'Requested', 'Review'].includes(row.status)
        ).length;
    }

    get requestTables() {
        return REQUEST_TABLES.map(table => {
            const rows = this.rows.filter(row =>
                this.hasDocumentRequestIdentity(row) && table.statuses.includes(row.status)
            );
            const hasInlineEditingRow = rows.some(row => row.isInlineEditing);
            return {
                ...table,
                rows,
                size: rows.length,
                hasRows: rows.length > 0,
                isEmpty: rows.length === 0,
                wrapperClass: hasInlineEditingRow
                    ? 'request-table-wrapper request-table-wrapper--editing'
                    : 'request-table-wrapper',
                allSelected: rows.length > 0 && rows.every(row => row.includeInEmail),
                isEmailToggleDisabled: this.isConverted || rows.length === 0,
                emptyMessage: `No ${table.label.toLowerCase()} to display.`
            };
        });
    }

    get hasNoRows() {
        return this.rows.length === 0;
    }

    get areAllRowsIncludedInEmail() {
        return this.rows.length > 0 && this.rows.every(row => row.includeInEmail);
    }

    countRowsByStatus(status) {
        return this.rows.filter(row => this.hasDocumentRequestIdentity(row) && row.status === status).length;
    }

    formatFileSize(sizeInBytes) {
        const size = Number(sizeInBytes || 0);
        if (size >= 1048576) {
            return `${(size / 1048576).toFixed(1)} MB`;
        }
        if (size >= 1024) {
            return `${(size / 1024).toFixed(1)} KB`;
        }
        return `${size} B`;
    }

    decoratePreviewDocumentSelection(documents) {
        return (documents || []).map(documentItem => ({
            ...documentItem,
            rowClass: documentItem.id === this.selectedPreviewDocumentId
                ? 'review-document-row review-document-row-selected'
                : 'review-document-row'
        }));
    }

    applyConvertedState(convertedTransactionId) {
        this.isConverted = true;
        this.convertedTransactionId = convertedTransactionId || this.convertedTransactionId;
        this.showCreateModal = false;
        this.closeEmailModal();
        this.closeUploadModal();
        this.draftRows = [];
    }

    toRequestInputs(rows) {
        return (rows || []).map(row => ({
            id: row.id,
            name: row.name,
            status: row.status,
            description: row.description,
            internalNotes: row.internalNotes,
            comments: row.comments,
            subject: row.subject,
            category: row.category,
            type: row.type,
            includeInEmail: row.includeInEmail,
            canBorrowerSee: row.canBorrowerSee,
            referenceId: row.referenceId
        }));
    }

    applyTransactionToggleRules(row, changedField) {
        if (changedField === 'includeInEmail' && row.includeInEmail === true) {
            return { ...row, canBorrowerSee: true };
        }
        return row;
    }

    async persistRequestRows(rowsToPersist) {
        const requestsToSave = (rowsToPersist || []).filter(row => this.hasDocumentRequestIdentity(row));
        if (requestsToSave.length === 0) {
            return;
        }

        this.isLoading = true;
        try {
            const saved = await saveRequests({
                leadId: this.recordId,
                requests: this.toRequestInputs(requestsToSave)
            });
            this.rows = this.decorateRequests(saved);
        } catch (error) {
            await this.loadData(this.recordId);
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    decorateRequests(requests) {
        return (requests || []).map(request => this.decorateRequest({
            ...request,
            clientKey: request.clientKey || request.id
        }));
    }

    decorateRequest(request) {
        const includeInEmail = request.includeInEmail === true;
        const canBorrowerSee = request.canBorrowerSee === true;
        const isInlineEditing = request.clientKey === this.inlineEditKey;
        const isNameEditing = isInlineEditing && this.inlineEditField === 'Name';
        const isDescriptionEditing = isInlineEditing && this.inlineEditField === 'Description__c';
        const isStatusEditing = isInlineEditing && this.inlineEditField === 'Status__c';
        const editingClass = ' request-table-cell--editing';
        return {
            ...request,
            includeInEmail,
            canBorrowerSee,
            emailActionClass: includeInEmail
                ? 'round-action action-email action-active'
                : 'round-action action-email',
            portalActionClass: canBorrowerSee
                ? 'round-action action-view action-active'
                : 'round-action action-view',
            emailActionIcon: includeInEmail ? 'utility:email' : 'utility:turn_off_notifications',
            portalActionIcon: canBorrowerSee ? 'utility:preview' : 'utility:ban',
            emailActionTitle: includeInEmail ? 'Included in email' : 'Excluded from email',
            portalActionTitle: canBorrowerSee ? 'Visible in borrower portal' : 'Hidden from borrower portal',
            hasFiles: Number(request.fileCount || 0) > 0,
            isInlineEditing,
            isNameEditing,
            isDescriptionEditing,
            isStatusEditing,
            nameCellClass: `request-table-cell condition-name-cell${isNameEditing ? editingClass : ''}`,
            descriptionCellClass: `request-table-cell condition-description-cell${isDescriptionEditing ? editingClass : ''}`,
            statusCellClass: `request-table-cell status-cell${isStatusEditing ? editingClass : ''}`,
            inlineEditDisplayClass: this.isConverted ? '' : 'request-field--editable',
            isNotesExpanded: request.clientKey === this.expandedNotesKey,
            isCommentsExpanded: request.clientKey === this.expandedCommentsKey,
            hasComments: Boolean(request.comments)
        };
    }

    showToast(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Lead Documents',
            message,
            variant: 'success'
        }));
    }

    showError(error) {
        const message = error?.body?.message || error?.message || 'An unexpected error occurred.';
        this.dispatchEvent(new ShowToastEvent({
            title: 'Lead Documents',
            message,
            variant: 'error',
            mode: 'sticky'
        }));
    }
}