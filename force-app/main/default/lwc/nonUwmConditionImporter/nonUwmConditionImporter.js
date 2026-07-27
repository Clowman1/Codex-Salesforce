import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import uploadPdfFiles from '@salesforce/apex/NonUwmConditionImportController.uploadPdfFiles';
import extractConditions from '@salesforce/apex/NonUwmConditionImportController.extractConditions';
import createConditions from '@salesforce/apex/NonUwmConditionImportController.createConditions';

const TYPE_OPTIONS = [
    { label: 'Processor', value: 'Processor' },
    { label: 'Loan Officer', value: 'Loan Officer' },
    { label: 'Borrower', value: 'Borrower' },
    { label: 'Vendor', value: 'Vendor' },
    { label: 'Post Closing', value: 'Post Closing' }
];

const STATUS_OPTIONS = [
    { label: 'New', value: 'New' },
    { label: 'Requested', value: 'Requested' },
    { label: 'Review', value: 'Review' },
    { label: 'Approved', value: 'Approved' },
    { label: 'Cleared', value: 'Cleared' },
    { label: 'Submitted', value: 'Submitted' }
];

const MANUAL_SOURCE_LABEL = 'Manual Entry';

export default class NonUwmConditionImporter extends LightningElement {
    @api recordId;

    @track uploadedFiles = [];
    @track conditions = [];
    @track extractionErrors = [];
    @track expandedConditionKeys = {};

    isDragging = false;
    isWorking = false;
    showReview = false;
    showCancelConfirm = false;
    importCompleted = false;
    createdCount = 0;
    globalMessage = '';
    progressText = '';

    get typeOptions() {
        return TYPE_OPTIONS;
    }

    get statusOptions() {
        return STATUS_OPTIONS;
    }

    get hasConditions() {
        return this.conditions.length > 0;
    }

    get hasUploadedFiles() {
        return this.uploadedFiles.length > 0;
    }

    get hasExtractionErrors() {
        return this.extractionErrors.length > 0;
    }

    get hasGlobalMessage() {
        return Boolean(this.globalMessage);
    }

    get totalCount() {
        return this.conditions.length;
    }

    get selectedCount() {
        return this.conditions.filter((condition) => condition.selected).length;
    }

    get duplicateCount() {
        return this.conditions.filter((condition) => condition.isDuplicate).length;
    }

    get manualCount() {
        return this.conditions.filter((condition) => this.isManualCondition(condition)).length;
    }

    get successfulUploadCount() {
        return this.uploadedFiles.filter((file) => file.success).length;
    }

    get failedUploadCount() {
        return this.uploadedFiles.filter((file) => !file.success).length;
    }

    get importDisabled() {
        return this.selectedCount === 0 || this.isWorking;
    }

    get uploaderDisabled() {
        return this.isWorking;
    }

    get showUploader() {
        return !this.showReview && !this.importCompleted;
    }

    get showStartOver() {
        return this.hasUploadedFiles || this.hasConditions || this.importCompleted || this.hasExtractionErrors;
    }

    get importButtonLabel() {
        return this.selectedCount > 0 ? `Create ${this.selectedCount} Condition(s)` : 'Create Conditions';
    }

    get uploadSummaryText() {
        if (!this.hasUploadedFiles) {
            return 'No files uploaded yet.';
        }

        if (this.failedUploadCount > 0) {
            return `${this.successfulUploadCount} uploaded successfully, ${this.failedUploadCount} need attention`;
        }

        return `${this.successfulUploadCount} file(s) uploaded and ready for review`;
    }

    get dropZoneClass() {
        return this.isDragging ? 'drop-zone drop-zone--active' : 'drop-zone';
    }

    get decoratedConditions() {
        return [...this.conditions]
            .sort((leftCondition, rightCondition) => this.compareConditionsForDisplay(leftCondition, rightCondition))
            .map((condition, index) => this.decorateCondition(condition, index));
    }

    handleDragOver(event) {
        event.preventDefault();
        this.isDragging = true;
    }

    handleDragLeave(event) {
        event.preventDefault();
        this.isDragging = false;
    }

    handleDrop(event) {
        event.preventDefault();
        this.isDragging = false;
        const files = event.dataTransfer && event.dataTransfer.files ? Array.from(event.dataTransfer.files) : [];
        this.processFiles(files);
    }

    handleBrowseClick() {
        if (this.uploaderDisabled) {
            return;
        }

        const input = this.template.querySelector('[data-id="pdfInput"]');
        if (input) {
            input.click();
        }
    }

    handleDropZoneKeydown(event) {
        if (event.key !== 'Enter' && event.key !== ' ') {
            return;
        }

        event.preventDefault();
        this.handleBrowseClick();
    }

    handleInputChange(event) {
        const files = event.target.files ? Array.from(event.target.files) : [];
        this.processFiles(files);
        event.target.value = null;
    }

    async processFiles(files) {
        if (!this.recordId) {
            this.showToast('Error', 'This component must be used on an Opportunity record.', 'error');
            return;
        }

        const pdfFiles = files.filter((file) => this.isPdf(file));
        if (pdfFiles.length === 0) {
            this.showToast('Error', 'Please select at least one PDF file.', 'error');
            return;
        }

        this.isWorking = true;
        this.progressText = 'Uploading files...';
        this.importCompleted = false;
        this.createdCount = 0;

        try {
            const payload = await Promise.all(
                pdfFiles.map(async (file) => ({
                    fileName: file.name,
                    base64Data: await this.readAsBase64(file)
                }))
            );

            const uploadResponse = await uploadPdfFiles({
                opportunityId: this.recordId,
                files: payload
            });

            const nextUploadedFiles = [];
            const uploadedDocumentIds = [];

            (uploadResponse.files || []).forEach((item, index) => {
                nextUploadedFiles.push({
                    clientKey: `${Date.now()}-${index}-${item.fileName}`,
                    fileName: item.fileName,
                    contentDocumentId: item.contentDocumentId,
                    success: item.success,
                    statusClass: item.success ? 'badge badge--success' : 'badge badge--error',
                    statusLabel: item.success ? 'Uploaded' : 'Upload issue',
                    message: item.message
                });

                if (item.success && item.contentDocumentId) {
                    uploadedDocumentIds.push(item.contentDocumentId);
                }
            });

            this.uploadedFiles = [...this.uploadedFiles, ...nextUploadedFiles];
            this.extractionErrors = [...this.extractionErrors, ...(uploadResponse.errors || [])];

            this.progressText = 'Extracting conditions with AI...';
            const extractionResponse = await extractConditions({
                opportunityId: this.recordId,
                contentDocumentIds: uploadedDocumentIds
            });

            this.globalMessage = extractionResponse.globalMessage || '';
            this.extractionErrors = [...this.extractionErrors, ...(extractionResponse.errors || [])];
            const incomingConditions = (extractionResponse.conditions || []).map((condition) => ({
                ...condition,
                selected: condition.isDuplicate ? false : condition.selected !== false
            }));

            this.initializeExpandedStates(incomingConditions, this.conditions.length);
            this.conditions = [...this.conditions, ...incomingConditions];
            this.showReview = true;
            this.showToast('Success', 'Files processed. Review conditions before import.', 'success');
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isWorking = false;
            this.progressText = '';
        }
    }

    handleConditionToggle(event) {
        const key = event.currentTarget.dataset.key;
        const checked = event.target.checked;
        this.conditions = this.conditions.map((condition) => {
            if (condition.clientKey !== key) {
                return condition;
            }

            return { ...condition, selected: checked };
        });
    }

    handleFieldChange(event) {
        const key = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const value =
            event.detail && Object.prototype.hasOwnProperty.call(event.detail, 'recordId')
                ? event.detail.recordId
                : event.target.type === 'checkbox'
                ? event.target.checked
                : event.detail && Object.prototype.hasOwnProperty.call(event.detail, 'value')
                  ? event.detail.value
                  : event.target.value;

        this.conditions = this.conditions.map((condition) => {
            if (condition.clientKey !== key) {
                return condition;
            }

            return { ...condition, [field]: value };
        });
    }

    handleToggleDetails(event) {
        const key = event.currentTarget.dataset.key;
        const conditionIndex = this.conditions.findIndex((condition) => condition.clientKey === key);
        const currentState =
            conditionIndex >= 0
                ? this.isConditionExpanded(this.conditions[conditionIndex], conditionIndex)
                : Boolean(this.expandedConditionKeys[key]);

        this.expandedConditionKeys = {
            ...this.expandedConditionKeys,
            [key]: !currentState
        };
    }

    handleSelectAllReady() {
        this.conditions = this.conditions.map((condition) => ({
            ...condition,
            selected: condition.isDuplicate ? false : true
        }));
    }

    handleClearSelection() {
        this.conditions = this.conditions.map((condition) => ({
            ...condition,
            selected: false
        }));
    }

    handleAddManualCondition() {
        const unique = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
        const manualCondition = {
            clientKey: unique,
            sourceFileName: MANUAL_SOURCE_LABEL,
            selected: true,
            isDuplicate: false,
            duplicateReason: null,
            confidence: 100,
            name: 'Manual Condition',
            description: '',
            type: 'Processor',
            status: 'New',
            category: 'Generic',
            canBorrowerSee: true,
            includeInEmail: true,
            assignedToId: null
        };

        this.conditions = [...this.conditions, manualCondition];
        this.expandedConditionKeys = {
            ...this.expandedConditionKeys,
            [unique]: true
        };
    }

    handleCancelPreview() {
        this.showCancelConfirm = true;
    }

    handleKeepFilesWithoutCreate() {
        this.showCancelConfirm = false;
        this.conditions = [];
        this.expandedConditionKeys = {};
        this.showReview = false;
        this.globalMessage = '';
        this.importCompleted = false;
        this.createdCount = 0;
        this.showToast('Info', 'PDF files were kept on the loan. No conditions were created.', 'info');
    }

    handleCloseCancelModal() {
        this.showCancelConfirm = false;
    }

    async handleCreateConditions() {
        if (this.importDisabled) {
            return;
        }

        this.isWorking = true;
        this.progressText = 'Creating loan conditions...';
        try {
            const selectedConditions = this.conditions.filter((condition) => condition.selected);
            const createResponse = await createConditions({
                opportunityId: this.recordId,
                conditions: selectedConditions
            });

            if (!createResponse.success) {
                throw new Error(createResponse.userMessage || 'Condition import failed.');
            }

            this.createdCount = createResponse.createdCount || 0;
            this.importCompleted = true;
            this.showReview = false;
            this.conditions = [];
            this.expandedConditionKeys = {};

            if ((createResponse.skippedDuplicateCount || 0) > 0) {
                this.showToast(
                    'Warning',
                    `Created ${this.createdCount} conditions. Skipped ${createResponse.skippedDuplicateCount} duplicate(s).`,
                    'warning'
                );
            } else {
                this.showToast('Success', `Created ${this.createdCount} condition(s).`, 'success');
            }
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isWorking = false;
            this.progressText = '';
        }
    }

    handleStartOver() {
        this.conditions = [];
        this.uploadedFiles = [];
        this.extractionErrors = [];
        this.expandedConditionKeys = {};
        this.showReview = false;
        this.showCancelConfirm = false;
        this.importCompleted = false;
        this.createdCount = 0;
        this.globalMessage = '';
        this.isDragging = false;
    }

    compareConditionsForDisplay(leftCondition, rightCondition) {
        const leftWeight = this.getConditionSortWeight(leftCondition);
        const rightWeight = this.getConditionSortWeight(rightCondition);

        if (leftWeight !== rightWeight) {
            return leftWeight - rightWeight;
        }

        return (leftCondition.name || '').localeCompare(rightCondition.name || '');
    }

    getConditionSortWeight(condition) {
        const duplicateWeight = condition.isDuplicate ? 100 : 0;
        const selectionWeight = condition.selected ? 0 : 10;
        const manualWeight = this.isManualCondition(condition) ? 0 : 1;

        return duplicateWeight + selectionWeight + manualWeight;
    }

    decorateCondition(condition, index) {
        const isManual = this.isManualCondition(condition);
        const isExpanded = this.isConditionExpanded(condition, index);
        const descriptionPreview = condition.description || 'No description added yet. Expand the row to add details.';
        const confidenceValue = Number.isFinite(Number(condition.confidence)) ? Math.round(Number(condition.confidence)) : null;
        const selectionStateClass = condition.isDuplicate
            ? 'state-pill state-pill--warning'
            : condition.selected
              ? 'state-pill state-pill--success'
              : 'state-pill state-pill--neutral';

        let rowClass = 'conditions-table__row';
        if (condition.isDuplicate) {
            rowClass += ' conditions-table__row--duplicate';
        } else if (condition.selected) {
            rowClass += ' conditions-table__row--selected';
        }

        return {
            ...condition,
            rowClass,
            isExpanded,
            displayName: condition.name || 'Untitled Condition',
            descriptionPreview,
            detailsButtonLabel: isExpanded ? 'Hide Details' : 'Edit Details',
            detailsSectionId: `details-${condition.clientKey}`,
            sourceBadgeClass: isManual ? 'badge badge--manual' : 'badge',
            sourceLabel: condition.sourceFileName || 'Imported PDF',
            confidenceBadgeClass: this.getConfidenceBadgeClass(confidenceValue),
            confidenceLabel: confidenceValue === null ? 'Confidence unavailable' : `${confidenceValue}% confidence`,
            selectionStateClass,
            selectionStateLabel: condition.isDuplicate ? 'Duplicate' : condition.selected ? 'Included' : 'Not selected',
            statusLabel: condition.status || 'New',
            typeLabel: condition.type || 'Processor',
            assignedToInputValue: condition.assignedToId || '',
            borrowerVisibilityLabel: condition.canBorrowerSee ? 'Borrower visible' : 'Internal only',
            emailVisibilityLabel: condition.includeInEmail ? 'Included in email' : 'Not emailed'
        };
    }

    getConfidenceBadgeClass(confidenceValue) {
        if (confidenceValue === null) {
            return 'badge';
        }

        if (confidenceValue >= 90) {
            return 'badge badge--success';
        }

        if (confidenceValue < 70) {
            return 'badge badge--warning';
        }

        return 'badge';
    }

    isConditionExpanded(condition, index) {
        if (Object.prototype.hasOwnProperty.call(this.expandedConditionKeys, condition.clientKey)) {
            return this.expandedConditionKeys[condition.clientKey];
        }

        return condition.isDuplicate || this.isManualCondition(condition) || index === 0;
    }

    initializeExpandedStates(conditions, startingIndex) {
        const nextExpandedKeys = { ...this.expandedConditionKeys };

        conditions.forEach((condition, index) => {
            if (!Object.prototype.hasOwnProperty.call(nextExpandedKeys, condition.clientKey)) {
                nextExpandedKeys[condition.clientKey] =
                    condition.isDuplicate || this.isManualCondition(condition) || startingIndex + index === 0;
            }
        });

        this.expandedConditionKeys = nextExpandedKeys;
    }

    isManualCondition(condition) {
        return condition.sourceFileName === MANUAL_SOURCE_LABEL;
    }

    isPdf(file) {
        if (!file || !file.name) {
            return false;
        }

        return file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf');
    }

    readAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = typeof reader.result === 'string' ? reader.result : '';
                const payload = result.includes(',') ? result.substring(result.indexOf(',') + 1) : result;
                resolve(payload);
            };
            reader.onerror = () => reject(new Error('Unable to read file.'));
            reader.readAsDataURL(file);
        });
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'An unexpected error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}