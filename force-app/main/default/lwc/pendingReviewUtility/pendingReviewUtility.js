import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getQueue from '@salesforce/apex/ConditionReviewQueueController.getQueue';
import getConditionDocuments from '@salesforce/apex/ConditionReviewQueueController.getConditionDocuments';
import approveDocument from '@salesforce/apex/ConditionReviewQueueController.approveDocument';
import rejectDocument from '@salesforce/apex/ConditionReviewQueueController.rejectDocument';
import moveDocumentToCondition from '@salesforce/apex/ConditionReviewQueueController.moveDocumentToCondition';
import unassociateDocuments from '@salesforce/apex/ConditionReviewQueueController.unassociateDocuments';
import approveCondition from '@salesforce/apex/LoanConditionController.approveCondition';
import reviewCondition from '@salesforce/apex/LoanConditionController.reviewCondition';
import getComments from '@salesforce/apex/ConditionCommentController.getComments';
import getCommentsFresh from '@salesforce/apex/ConditionReviewQueueController.getCommentsFresh';
import createComment from '@salesforce/apex/ConditionCommentController.createComment';
import markCommentAsRead from '@salesforce/apex/ConditionCommentController.markCommentAsRead';

const STATUS_REVIEW = 'Review';
const STATUS_APPROVED = 'Approved';
const STATUS_REQUESTED = 'Requested';
const STATUS_NEEDS_INFO = 'Needs Info';
const AUTO_REFRESH_MS = 60000;

export default class PendingReviewUtility extends NavigationMixin(LightningElement) {
    @track loans = [];
    @track expandedLoanIds = new Set();
    isLoading = true;
    hasLoadedQueue = false;
    isAutoRefreshing = false;
    error;
    refreshTimer;

    wiredQueueResult;

    // Modal / review state
    @track activeLoan;
    @track activeCondition;
    @track activeDocuments = [];
    @track activeDocId;
    @track activeComments = [];
    @track isModalOpen = false;
    @track decisionMode = 'idle'; // idle | rejecting
    @track selectedDocsToRemove = new Set();
    @track rejectionReason = '';
    @track updatedConditionDescription = '';
    @track sendRejectEmail = true;
    @track replyText = '';
    @track replyVisibility = 'Public'; // 'Public' | 'Private'
    @track linkPopoverDocId;
    @track toastMessage;
    @track resolvedStatus; // local override after approve/reject
    @track lastRejectEmailSent;
    @track hasRejectedDocumentInSession = false;

    @wire(getQueue)
    wiredGetQueue(result) {
        this.wiredQueueResult = result;
        this.isLoading = !this.hasLoadedQueue && !this.isAutoRefreshing;
        if (result.data) {
            this.loans = this.normalizeLoans(result.data);
            this.hasLoadedQueue = true;
            this.isLoading = false;
            this.error = undefined;
        } else if (result.error) {
            this.error = this.extractErrorMessage(result.error);
            this.loans = [];
            this.hasLoadedQueue = true;
            this.isLoading = false;
        }
        this.notifyActivityChange();
    }

    connectedCallback() {
        this.startAutoRefresh();
    }

    disconnectedCallback() {
        this.stopAutoRefresh();
        this.lockBodyScroll(false);
    }

    startAutoRefresh() {
        this.stopAutoRefresh();
        this.refreshTimer = window.setInterval(() => {
            this.refreshQueueSilently();
        }, AUTO_REFRESH_MS);
    }

    stopAutoRefresh() {
        if (this.refreshTimer) {
            window.clearInterval(this.refreshTimer);
            this.refreshTimer = undefined;
        }
    }

    async refreshQueueSilently() {
        if (!this.wiredQueueResult || this.isAutoRefreshing) {
            return;
        }
        if (typeof document !== 'undefined' && document.hidden) {
            return;
        }
        this.isAutoRefreshing = true;
        try {
            await refreshApex(this.wiredQueueResult);
        } catch (e) {
            // Keep background polling quiet. A manual open/refresh will still
            // surface any queue load error through the normal component state.
        } finally {
            this.isAutoRefreshing = false;
        }
    }

    // Lets an Aura wrapper (PendingReviewUtilityHost) drive the visible
    // utility bar via lightning:utilityBarAPI (setUtilityHighlighted +
    // setUtilityLabel). The LWC equivalents (lightning/platformUtilityBarApi)
    // do not visually update the bar in standard navigation apps, which is
    // why the dynamic indicator lives in the Aura wrapper instead.
    notifyActivityChange() {
        const loans = Array.isArray(this.loans) ? this.loans : [];
        const pendingCount = loans.reduce((sum, loan) => {
            return sum + (Number(loan.pendingConditionsCount) || 0);
        }, 0);
        const hasActivity = pendingCount > 0;
        this.dispatchEvent(
            new CustomEvent('activitychange', {
                detail: { hasActivity, pendingCount },
                bubbles: true,
                composed: true
            })
        );
    }

    refreshQueue() {
        if (this.wiredQueueResult) {
            return refreshApex(this.wiredQueueResult);
        }
        return Promise.resolve();
    }

    normalizeLoans(rawLoans) {
        return (rawLoans || []).map((loan) => {
            const conditions = (loan.conditions || []).map((c) => ({
                ...c,
                hasDocs: (c.documentCount || 0) > 0,
                hasUnreadComments: (c.unreadCommentCount || 0) > 0,
                docsLabel: this.pluralize(c.documentCount || 0, 'Document', 'Documents'),
                commentsLabel: this.pluralize(c.commentCount || 0, 'Comment', 'Comments'),
                statusBadgeClass: this.statusBadgeClass(c.status),
                statusBadgeIcon: this.statusBadgeIcon(c.status),
                isReviewIcon: c.status === STATUS_REVIEW
            }));
            const formattedAmount = loan.loanAmount
                ? '$' + Number(loan.loanAmount).toLocaleString('en-US', { maximumFractionDigits: 0 })
                : '';
            return {
                ...loan,
                conditions,
                formattedAmount,
                pendingLabel: this.pluralize(loan.pendingConditionsCount || 0, 'Action Item', 'Action Items'),
                isExpanded: !this.expandedLoanIds.has(loan.loanId + ':collapsed'),
                expandedClass: this.expandedLoanIds.has(loan.loanId + ':collapsed')
                    ? 'pru-loan-body collapsed'
                    : 'pru-loan-body',
                chevronIcon: this.expandedLoanIds.has(loan.loanId + ':collapsed')
                    ? 'utility:chevrondown'
                    : 'utility:chevronup'
            };
        });
    }

    pluralize(n, singular, plural) {
        return `${n} ${n === 1 ? singular : plural}`;
    }

    statusBadgeClass(status) {
        switch (status) {
            case STATUS_APPROVED:
                return 'pru-badge pru-badge-approved';
            case STATUS_NEEDS_INFO:
                return 'pru-badge pru-badge-needsinfo';
            case STATUS_REQUESTED:
                return 'pru-badge pru-badge-requested';
            case STATUS_REVIEW:
            default:
                return 'pru-badge pru-badge-review';
        }
    }

    statusBadgeIcon(status) {
        switch (status) {
            case STATUS_APPROVED:
                return 'utility:check';
            case STATUS_NEEDS_INFO:
                return 'utility:warning';
            case STATUS_REQUESTED:
                return 'utility:send';
            case STATUS_REVIEW:
            default:
                return 'utility:preview';
        }
    }

    get hasLoans() {
        return !this.isLoading && this.loans && this.loans.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && (!this.loans || this.loans.length === 0) && !this.error;
    }

    get totalConditions() {
        return this.loans.reduce((s, l) => s + (l.pendingConditionsCount || 0), 0);
    }

    get totalDocs() {
        return this.loans.reduce((s, l) =>
            s + (l.conditions || []).reduce((d, c) => d + (c.documentCount || 0), 0), 0);
    }

    get totalComments() {
        return this.loans.reduce((s, l) => s + (l.unreadCommentsCount || 0), 0);
    }

    handleToggleLoan(event) {
        const loanId = event.currentTarget.dataset.loanId;
        const key = loanId + ':collapsed';
        const next = new Set(this.expandedLoanIds);
        if (next.has(key)) {
            next.delete(key);
        } else {
            next.add(key);
        }
        this.expandedLoanIds = next;
        this.loans = this.normalizeLoans(this.rawLoans);
    }

    get rawLoans() {
        return this.wiredQueueResult && this.wiredQueueResult.data
            ? this.wiredQueueResult.data
            : [];
    }

    handleOpenLoan(event) {
        event.preventDefault();
        event.stopPropagation();
        const loanId = event.currentTarget.dataset.loanId;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: loanId,
                objectApiName: 'Transaction__c',
                actionName: 'view'
            }
        });
    }

    async handleOpenCondition(event) {
        const conditionId = event.currentTarget.dataset.conditionId;
        const loanId = event.currentTarget.dataset.loanId;
        this.activeLoan = this.loans.find((l) => l.loanId === loanId);
        const conditionSummary = this.activeLoan
            ? this.activeLoan.conditions.find((c) => c.id === conditionId)
            : null;
        this.activeCondition = conditionSummary
            ? { ...conditionSummary }
            : {
                  id: conditionId,
                  title: 'Condition',
                  category: '',
                  status: STATUS_REVIEW,
                  statusBadgeClass: this.statusBadgeClass(STATUS_REVIEW),
                  statusBadgeIcon: this.statusBadgeIcon(STATUS_REVIEW),
                  isReviewIcon: true
              };
        this.activeDocuments = [];
        this.activeDocId = undefined;
        this.activeComments = [];
        this.decisionMode = 'idle';
        this.selectedDocsToRemove = new Set();
        this.rejectionReason = '';
        this.updatedConditionDescription = this.activeCondition.title || '';
        this.sendRejectEmail = true;
        this.linkPopoverDocId = undefined;
        this.replyText = '';
        this.replyVisibility = 'Public';
        this.resolvedStatus = undefined;
        this.lastRejectEmailSent = null;
        this.hasRejectedDocumentInSession = false;
        this.isModalOpen = true;
        this.lockBodyScroll(true);

        try {
            const [docs, comments] = await Promise.all([
                getConditionDocuments({ conditionId }),
                getComments({ conditionId, isPortalView: false })
            ]);
            this.activeDocuments = this.buildDocumentRows(docs);
            if (this.activeDocuments.length > 0) {
                this.activeDocId = this.activeDocuments[0].id;
                this.activeDocuments = this.activeDocuments.map((d) => ({
                    ...d,
                    isActive: d.id === this.activeDocId,
                    rowClass: this.docRowClass(d.id, this.activeDocId, false)
                }));
            }
            this.activeComments = this.formatComments(comments || []);
        } catch (e) {
            this.fireToast('Error loading condition: ' + this.extractErrorMessage(e), 'error');
        }
    }

    buildDocumentRows(docs) {
        if (!docs) {
            return [];
        }
        return docs.map((d) => ({
            id: d.id,
            contentVersionId: d.contentVersionId,
            filename: d.filename,
            extension: d.extension || '',
            sizeLabel: d.sizeLabel || '',
            uploadedBy: d.uploadedBy || '',
            uploadedDateLabel: this.formatShortDate(d.uploadedDate),
            iconName: this.fileIconName(d.extension),
            iconClass: this.fileIconClass(d.extension),
            isMarked: false,
            isActive: false,
            rowClass: 'pru-doc-row'
        }));
    }

    formatShortDate(ts) {
        if (!ts) return '';
        try {
            return new Date(ts).toLocaleDateString();
        } catch (e) {
            return '';
        }
    }

    fileIconName(ext) {
        if (!ext) return 'doctype:unknown';
        const e = ext.toLowerCase();
        if (e === 'pdf') return 'doctype:pdf';
        if (['png', 'jpg', 'jpeg', 'gif'].includes(e)) return 'doctype:image';
        if (['doc', 'docx'].includes(e)) return 'doctype:gdoc';
        return 'doctype:attachment';
    }

    fileIconClass(ext) {
        if (!ext) return 'pru-doc-icon';
        const e = ext.toLowerCase();
        if (e === 'pdf') return 'pru-doc-icon pru-doc-icon-pdf';
        if (['png', 'jpg', 'jpeg', 'gif'].includes(e)) return 'pru-doc-icon pru-doc-icon-img';
        return 'pru-doc-icon';
    }

    docRowClass(docId, activeDocId, isMarked) {
        let cls = 'pru-doc-row';
        if (isMarked) cls += ' pru-doc-row-marked';
        else if (docId === activeDocId) cls += ' pru-doc-row-active';
        return cls;
    }

    formatComments(comments) {
        return (comments || []).map((c) => {
            const isPrivate = c.publicComment === false;
            const unread = c.read === false;
            return {
                id: c.id,
                authorName: c.createdByName || 'User',
                role: c.portalComment ? 'Borrower' : 'Internal',
                message: c.commentText,
                isPrivate,
                unread,
                bubbleClass: isPrivate
                    ? 'pru-comment-bubble pru-comment-bubble-private'
                    : unread
                    ? 'pru-comment-bubble pru-comment-bubble-unread'
                    : 'pru-comment-bubble',
                timestampLabel: this.formatTimestamp(c.createdDate)
            };
        });
    }

    formatTimestamp(ts) {
        if (!ts) return '';
        try {
            return new Date(ts).toLocaleString([], {
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        } catch (e) {
            return ts;
        }
    }

    handleSelectDoc(event) {
        const docId = event.currentTarget.dataset.docId;
        if (this.decisionMode === 'rejecting') {
            return;
        }
        this.setActiveDocument(docId);
    }

    setActiveDocument(docId) {
        if (!docId) {
            return;
        }
        this.activeDocId = docId;
        this.activeDocuments = this.activeDocuments.map((d) => ({
            ...d,
            isActive: d.id === docId,
            rowClass: this.docRowClass(d.id, docId, this.selectedDocsToRemove.has(d.id))
        }));
    }

    handleToggleDocSelected(event) {
        event.stopPropagation();
        const docId = event.currentTarget.dataset.docId;
        const next = new Set(this.selectedDocsToRemove);
        if (next.has(docId)) next.delete(docId);
        else next.add(docId);
        this.selectedDocsToRemove = next;
        this.activeDocuments = this.activeDocuments.map((d) => ({
            ...d,
            isMarked: next.has(d.id),
            rowClass: this.docRowClass(d.id, this.activeDocId, next.has(d.id))
        }));
    }

    async handleCloseModal() {
        if (this.decisionMode === 'rejecting') {
            this.decisionMode = 'idle';
        }
        // Closing the modal WITHOUT taking action must NOT auto-mark comments
        // as read. Otherwise a condition that was only surfaced in the queue
        // because of an unread borrower comment would silently fall off the
        // moment the processor peeked at it. Mark-as-read now happens only on
        // explicit Approve / Reject / Mark Reviewed (see those handlers).
        this.isModalOpen = false;
        this.lockBodyScroll(false);
        this.linkPopoverDocId = undefined;
        this.refreshQueue();
    }

    // Marks every unread comment on the currently-open condition as read.
    // Called from the explicit action handlers (Approve / Reject / Mark
    // Reviewed) so that conditions surfaced via unread comments leave the
    // queue once the processor takes a real action on them.
    async markActiveConditionCommentsRead() {
        const unreadIds = (this.activeComments || [])
            .filter((c) => c.unread)
            .map((c) => c.id);
        if (!unreadIds.length) return 0;
        try {
            await Promise.all(unreadIds.map((id) => markCommentAsRead({ commentId: id })));
            this.activeComments = (this.activeComments || []).map((comment) => ({
                ...comment,
                unread: false,
                bubbleClass: comment.isPrivate
                    ? 'pru-comment-bubble pru-comment-bubble-private'
                    : 'pru-comment-bubble'
            }));
            return unreadIds.length;
        } catch (e) {
            // non-fatal - the action already succeeded, the lingering unread
            // state is a minor inconsistency that will self-heal next time the
            // processor reopens the condition.
            return 0;
        }
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    setActiveStatus(status) {
        this.activeCondition = {
            ...this.activeCondition,
            status,
            statusBadgeClass: this.statusBadgeClass(status),
            statusBadgeIcon: this.statusBadgeIcon(status),
            isReviewIcon: status === STATUS_REVIEW
        };
    }

    async handleApprove() {
        try {
            const activeDocId = this.activeDocId;
            if (!activeDocId) {
                this.fireToast('Select a document to accept.', 'warning');
                return;
            }
            await approveDocument({
                conditionId: this.activeCondition.id,
                contentDocumentId: activeDocId,
                approveConditionWhenNoPending: !this.hasRejectedDocumentInSession
            });
            await this.markActiveConditionCommentsRead();
            this.removeActiveDocumentFromList(activeDocId);
            if (!this.hasActiveDocuments) {
                const finalStatus = this.hasRejectedDocumentInSession ? STATUS_REQUESTED : STATUS_APPROVED;
                this.resolvedStatus = finalStatus;
                this.setActiveStatus(finalStatus);
            } else {
                this.resolvedStatus = undefined;
                this.setActiveStatus(STATUS_REVIEW);
            }
            this.fireToast('Document accepted', 'success');
        } catch (e) {
            this.fireToast('Error accepting document: ' + this.extractErrorMessage(e), 'error');
        }
    }

    handleApproveDocumentClick(event) {
        event.stopPropagation();
        this.setActiveDocument(event.currentTarget.dataset.docId);
        this.handleApprove();
    }

    async handleMarkReviewed() {
        // No documents to evaluate. Treat this as an explicit "I've handled
        // this" - flip the condition to Approved so it leaves the queue.
        // Also marks any unread comments as read so non-Review conditions
        // surfaced by a borrower comment drop off the queue too.
        try {
            await approveCondition({ recordId: this.activeCondition.id });
            await this.markActiveConditionCommentsRead();
            this.resolvedStatus = STATUS_APPROVED;
            this.setActiveStatus(STATUS_APPROVED);
            this.fireToast('Condition marked as reviewed', 'success');
        } catch (e) {
            this.fireToast('Error marking condition as reviewed: ' + this.extractErrorMessage(e), 'error');
        }
    }

    async handleCloseCommentOnlyItem() {
        return this.handleClearCommentAlert();
    }

    async handleClearCommentAlert() {
        try {
            const clearedCount = await this.markActiveConditionCommentsRead();
            await this.refreshQueue();
            this.fireToast(
                clearedCount > 0 ? 'Comment alert cleared' : 'No unread comment alert to clear',
                clearedCount > 0 ? 'success' : 'info'
            );
        } catch (e) {
            this.fireToast('Error clearing comment alert: ' + this.extractErrorMessage(e), 'error');
        }
    }

    async handleReopen() {
        try {
            await reviewCondition({ recordId: this.activeCondition.id });
            this.resolvedStatus = STATUS_REVIEW;
            this.setActiveStatus(STATUS_REVIEW);
            this.fireToast('Condition reopened', 'success');
        } catch (e) {
            this.fireToast('Error reopening condition: ' + this.extractErrorMessage(e), 'error');
        }
    }

    handleStartReject(event) {
        if (event && event.currentTarget && event.currentTarget.dataset.docId) {
            event.stopPropagation();
            this.setActiveDocument(event.currentTarget.dataset.docId);
        }
        if (!this.activeDocId) {
            this.fireToast('Select a document to reject.', 'warning');
            return;
        }
        this.decisionMode = 'rejecting';
        this.selectedDocsToRemove = this.activeDocId ? new Set([this.activeDocId]) : new Set();
        this.rejectionReason = '';
        this.updatedConditionDescription = this.activeCondition.title || '';
        this.sendRejectEmail = true;
        this.linkPopoverDocId = undefined;
        this.activeDocuments = this.activeDocuments.map((d) => ({
            ...d,
            isMarked: d.id === this.activeDocId,
            rowClass: this.docRowClass(d.id, this.activeDocId, d.id === this.activeDocId)
        }));
    }

    handleCancelReject() {
        this.decisionMode = 'idle';
        this.selectedDocsToRemove = new Set();
        this.rejectionReason = '';
        this.updatedConditionDescription = this.activeCondition.title || '';
        this.activeDocuments = this.activeDocuments.map((d) => ({
            ...d,
            isMarked: false,
            rowClass: this.docRowClass(d.id, this.activeDocId, false)
        }));
    }

    handleRejectReasonChange(event) {
        this.rejectionReason = event.target.value;
    }

    handleConditionDescriptionChange(event) {
        this.updatedConditionDescription = event.target.value;
    }

    handleSendEmailToggle(event) {
        this.sendRejectEmail = event.target.checked;
    }

    async handleConfirmReject() {
        if (this.sendRejectEmail && !(this.rejectionReason && this.rejectionReason.trim())) {
            this.fireToast('A reason is required when emailing the borrower.', 'warning');
            return;
        }
        if (!this.activeDocId) {
            this.fireToast('Select a document to reject.', 'warning');
            return;
        }
        try {
            await rejectDocument({
                conditionId: this.activeCondition.id,
                contentDocumentId: this.activeDocId,
                rejectionReason: this.rejectionReason,
                emailBorrower: this.sendRejectEmail,
                updatedConditionDescription: this.updatedConditionDescription
            });
            await this.markActiveConditionCommentsRead();
            this.lastRejectEmailSent = this.sendRejectEmail;
            this.hasRejectedDocumentInSession = true;
            const rejectedDocId = this.activeDocId;
            this.removeActiveDocumentFromList(rejectedDocId);
            if (this.updatedConditionDescription && this.updatedConditionDescription.trim()) {
                this.activeCondition = {
                    ...this.activeCondition,
                    title: this.updatedConditionDescription.trim()
                };
            }
            const finalStatus = this.hasActiveDocuments ? STATUS_REVIEW : STATUS_REQUESTED;
            this.resolvedStatus = finalStatus;
            this.setActiveStatus(finalStatus);
            this.decisionMode = 'idle';
            this.selectedDocsToRemove = new Set();
            this.fireToast(
                this.sendRejectEmail
                    ? 'Document rejected \u2014 borrower has been notified'
                    : 'Document rejected \u2014 borrower was not emailed',
                'success'
            );
        } catch (e) {
            this.fireToast('Error rejecting document: ' + this.extractErrorMessage(e), 'error');
        }
    }

    removeActiveDocumentFromList(documentId) {
        if (!documentId) {
            return;
        }
        this.activeDocuments = this.activeDocuments.filter((d) => d.id !== documentId);
        this.activeDocId = this.activeDocuments[0] ? this.activeDocuments[0].id : undefined;
        this.activeDocuments = this.activeDocuments.map((d) => ({
            ...d,
            isActive: d.id === this.activeDocId,
            isMarked: false,
            rowClass: this.docRowClass(d.id, this.activeDocId, false)
        }));
    }

    handleOpenLinkPopover(event) {
        event.stopPropagation();
        const docId = event.currentTarget.dataset.docId;
        this.linkPopoverDocId = this.linkPopoverDocId === docId ? undefined : docId;
    }

    async handleAssociate(event) {
        const targetConditionId = event.currentTarget.dataset.targetId;
        const docId = this.linkPopoverDocId;
        if (!docId || !targetConditionId) return;
        const doc = this.activeDocuments.find((d) => d.id === docId);
        const target = this.siblingConditions.find((s) => s.id === targetConditionId);
        try {
            await moveDocumentToCondition({
                contentDocumentId: docId,
                fromConditionId: this.activeCondition.id,
                toConditionId: targetConditionId
            });
            this.activeDocuments = this.activeDocuments.filter((d) => d.id !== docId);
            if (this.activeDocId === docId) {
                this.activeDocId = this.activeDocuments[0] ? this.activeDocuments[0].id : undefined;
                this.activeDocuments = this.activeDocuments.map((d) => ({
                    ...d,
                    isActive: d.id === this.activeDocId,
                    rowClass: this.docRowClass(d.id, this.activeDocId, false)
                }));
            }
            this.linkPopoverDocId = undefined;
            this.fireToast(
                doc && target ? `Moved "${doc.filename}" to "${target.title}"` : 'Document moved',
                'success'
            );
        } catch (e) {
            this.fireToast('Error moving document: ' + this.extractErrorMessage(e), 'error');
        }
    }

    get siblingConditions() {
        if (!this.activeLoan || !this.activeCondition) return [];
        return this.activeLoan.conditions
            .filter((c) => c.id !== this.activeCondition.id)
            .map((c) => ({
                id: c.id,
                title: c.title,
                category: c.category,
                status: c.status,
                statusDotClass: this.statusDotClass(c.status)
            }));
    }

    statusDotClass(status) {
        switch (status) {
            case STATUS_APPROVED:
                return 'pru-status-dot pru-dot-green';
            case STATUS_NEEDS_INFO:
                return 'pru-status-dot pru-dot-red';
            case STATUS_REQUESTED:
                return 'pru-status-dot pru-dot-slate';
            default:
                return 'pru-status-dot pru-dot-amber';
        }
    }

    handleReplyChange(event) {
        this.replyText = event.target.value;
    }

    handleVisibilityPublic() {
        this.replyVisibility = 'Public';
    }

    handleVisibilityPrivate() {
        this.replyVisibility = 'Private';
    }

    async handleSendReply() {
        const text = (this.replyText || '').trim();
        if (!text) return;
        const isPublic = this.replyVisibility === 'Public';
        try {
            const conditionId = this.activeCondition.id;
            await createComment({
                conditionId: conditionId,
                commentText: text,
                isPortalComment: false,
                isPublic: isPublic
            });
            await this.markActiveConditionCommentsRead();
            // Clear the textarea both via state and via DOM (so the
            // current input element drops its uncontrolled value).
            this.replyText = '';
            const textarea = this.template.querySelector('.pru-reply-input-wrap textarea');
            if (textarea) textarea.value = '';
            // Use a non-cacheable refresh so the new comment shows up
            // immediately (getComments is @AuraEnabled(cacheable=true)).
            const refreshed = await getCommentsFresh({ conditionId: conditionId });
            this.activeComments = this.formatComments(refreshed || []);
            await this.refreshQueue();
            this.fireToast(isPublic ? 'Public reply posted' : 'Internal note posted', 'success');
        } catch (e) {
            this.fireToast('Error posting comment: ' + this.extractErrorMessage(e), 'error');
        }
    }

    lockBodyScroll(lock) {
        try {
            if (typeof document === 'undefined') return;
            const targets = [document.body, document.documentElement].filter(Boolean);
            if (lock) {
                if (!this._priorOverflows) {
                    this._priorOverflows = targets.map((t) => t.style.overflow || '');
                }
                targets.forEach((t) => { t.style.overflow = 'hidden'; });
            } else {
                if (this._priorOverflows) {
                    targets.forEach((t, i) => {
                        t.style.overflow = this._priorOverflows[i] || '';
                    });
                    this._priorOverflows = null;
                } else {
                    targets.forEach((t) => { t.style.overflow = ''; });
                }
            }
        } catch (e) {
            // non-fatal
        }
    }

    handleDownloadActiveDoc() {
        const doc = this.activeDocuments.find((d) => d.id === this.activeDocId);
        if (!doc) return;
        const url = '/sfc/servlet.shepherd/document/download/' + doc.id;
        window.open(url, '_blank');
    }

    fireToast(message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title: message, message: '', variant: variant || 'info' })
        );
    }

    extractErrorMessage(err) {
        if (!err) return 'Unknown error';
        if (typeof err === 'string') return err;
        if (err.body) {
            if (err.body.message) return err.body.message;
            if (Array.isArray(err.body)) return err.body.map((e) => e.message).join(', ');
        }
        return err.message || 'Unknown error';
    }

    // Derived getters used by HTML
    get isRejecting() {
        return this.decisionMode === 'rejecting';
    }
    get isResolved() {
        return this.activeCondition && (
            this.activeCondition.status === STATUS_APPROVED ||
            this.activeCondition.status === STATUS_NEEDS_INFO
        );
    }
    get isResolvedApproved() {
        return this.activeCondition && this.activeCondition.status === STATUS_APPROVED;
    }
    get isResolvedRejected() {
        return this.activeCondition && this.activeCondition.status === STATUS_NEEDS_INFO;
    }
    get rejectedBannerText() {
        return this.lastRejectEmailSent === false
            ? 'Document rejected \u2014 borrower was not emailed'
            : 'Document rejected \u2014 borrower has been notified';
    }
    get hasActiveDocuments() {
        return this.activeDocuments && this.activeDocuments.length > 0;
    }
    get hasUnreadActiveComments() {
        return (this.activeComments || []).some((comment) => comment.unread);
    }
    get activeDocumentsWithFlags() {
        const isRejecting = this.decisionMode === 'rejecting';
        const hasSiblings = this.siblingConditions.length > 0;
        return this.activeDocuments.map((d) => ({
            ...d,
            subLabel: this.buildDocSubLabel(d),
            showCheckbox: false,
            showLinkButton: !isRejecting && hasSiblings,
            showReviewButtons: !isRejecting,
            showPopover: this.linkPopoverDocId === d.id
        }));
    }
    get activeDocumentLabel() {
        const d = this.activeDocuments.find((x) => x.id === this.activeDocId);
        return d ? d.filename : '';
    }
    get activeDocumentActionLabel() {
        return this.activeDocumentLabel || 'selected document';
    }
    get activeDocumentMetaLabel() {
        const d = this.activeDocuments.find((x) => x.id === this.activeDocId);
        if (!d) return '';
        const parts = [];
        if (d.sizeLabel) parts.push(d.sizeLabel);
        if (d.extension) parts.push(d.extension);
        if (d.uploadedDateLabel) parts.push('Uploaded ' + d.uploadedDateLabel);
        return parts.join(' \u2022 ');
    }
    get activeDocumentPreviewUrl() {
        const d = this.activeDocuments.find((x) => x.id === this.activeDocId);
        if (!d || !d.contentVersionId) return '';
        return '/sfc/servlet.shepherd/version/download/' + d.contentVersionId;
    }
    get activeDocumentIsImage() {
        const d = this.activeDocuments.find((x) => x.id === this.activeDocId);
        if (!d || !d.extension) return false;
        return ['PNG', 'JPG', 'JPEG', 'GIF', 'BMP', 'WEBP', 'TIF', 'TIFF'].includes(d.extension.toUpperCase());
    }
    get activeDocumentPreviewTitle() {
        return this.activeDocumentLabel
            ? 'Preview of ' + this.activeDocumentLabel
            : 'Document preview';
    }
    buildDocSubLabel(d) {
        const parts = [];
        if (d.sizeLabel) parts.push(d.sizeLabel);
        if (d.uploadedBy) parts.push(d.uploadedBy);
        else if (d.extension) parts.push(d.extension);
        return parts.join(' \u2022 ');
    }
    get hasActiveDocSelected() {
        return !!this.activeDocId;
    }
    get rejectingHelpText() {
        return `This will reject ${this.activeDocumentActionLabel} and remove only that document from this condition.`;
    }
    get rejectConfirmDisabled() {
        return this.sendRejectEmail && !(this.rejectionReason && this.rejectionReason.trim());
    }
    get reasonRequiredLabel() {
        return this.sendRejectEmail ? 'Reason for rejection *' : 'Reason for rejection (optional)';
    }
    get reasonPlaceholder() {
        return this.sendRejectEmail
            ? 'Required \u2014 this message will be emailed to the borrower.'
            : "Let the borrower know what's needed to resolve this condition...";
    }
    get visibilityHelpHtml() {
        return this.replyVisibility === 'Private'
            ? 'Internal only. The borrower will not see this comment.'
            : 'Public. The borrower will see this comment.';
    }
    get publicTabClass() {
        return this.replyVisibility === 'Public'
            ? 'pru-vis-btn pru-vis-public-on'
            : 'pru-vis-btn pru-vis-off';
    }
    get privateTabClass() {
        return this.replyVisibility === 'Private'
            ? 'pru-vis-btn pru-vis-private-on'
            : 'pru-vis-btn pru-vis-off';
    }
    get textareaClass() {
        return this.replyVisibility === 'Private'
            ? 'pru-reply-textarea pru-reply-private'
            : 'pru-reply-textarea';
    }
    get sendBtnClass() {
        return this.replyVisibility === 'Private'
            ? 'pru-reply-send pru-reply-send-private'
            : 'pru-reply-send';
    }
    get sendDisabled() {
        return !(this.replyText && this.replyText.trim());
    }
    get conditionDocCountLabel() {
        return this.pluralize(this.activeDocuments.length, 'Document', 'Documents');
    }
    get conditionCommentCountLabel() {
        return this.pluralize(this.activeComments.length, 'Comment', 'Comments');
    }
    get sendEmailHelpText() {
        return this.sendRejectEmail
            ? 'They will receive an email with the rejection reason.'
            : 'No email will be sent. You can notify them another way.';
    }
}
