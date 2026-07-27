import {LightningElement, api, track} from 'lwc';
import { plog } from 'c/consoleLogger';
import markProcessorCommentUnreadForBorrower
    from '@salesforce/apex/BorrowerDocumentPortalController.markProcessorCommentUnreadForBorrower';

const FLOW_STATUS = {
    FINISHED: 'FINISHED_SCREEN',
    ERROR: 'ERROR'
};

const USER_TYPES = {
    PORTAL: 'Portal User',
    MANAGER: 'Manager'
};

export default class ConditionComments extends LightningElement {

    @api conditionId;
    @api isPortal = false;
    @api isUnread = false;

    /** @type {import('c/chat').ChatMessageDef[]} */
    @track chatComments = [];

    errorMessage = '';
    showError = false;
    newCommentText = '';
    currentCommentId = '';
    currentCommentIsUnread = false;

    chatActionType = '';
    chatActionValue = '';
    chatActionPreviousValue = '';

    isPublic = true;
    isLoading = true;
    portalVisible = true;

    // Flow state properties
    showConditionCommentFlow = true;
    showCreateConditionCommentFlow = false;
    showUpdateReadCommentFlow = false;
    showProcessChatActionCommentFlow = false;

    /**
     * Handles the condition comment flow status changes
     * @param {CustomEvent} event - The flow status change event
     */
    handleConditionCommentFlow(event) {
        const { status, outputVariables } = event.detail;

        if (status === FLOW_STATUS.FINISHED) {
            this.processCommentsFromFlow(outputVariables);
        } else if (status === FLOW_STATUS.ERROR) {
            this.handleFlowError('Error retrieving comments');
        }
    }

    /**
     * Processes comments received from the flow
     * @param {Array} outputVariables - The flow output variables
     */
    processCommentsFromFlow(outputVariables) {
        /** @type {Condition_Comment__c[]} */
        const commentsData = outputVariables[0]?.value || [];
        console.log('commentsData =>', commentsData);
        this.chatComments = commentsData.map(comment => this.getChatCommentItem(comment));

        this.showConditionCommentFlow = false;
        this.isLoading = false;

        this.initializeChat();
    }

    /**
     * Initializes the chat component with current configuration
     */
    initializeChat() {
        this.refs.chat.setupChat(this.chatConfiguration);
    }

    /**
     * Handles errors from flows
     * @param {string} errorMessage - The error message
     */
    handleFlowError(errorMessage) {
        plog.error('ConditionComments', { message: errorMessage });
        this.errorMessage = errorMessage;
        this.showError = true;
        this.showConditionCommentFlow = false;
        this.showCreateConditionCommentFlow = false;
        this.showUpdateReadCommentFlow = false;
        this.showProcessChatActionCommentFlow = false;
        this.isLoading = false;
    }

    handleCloseError() {
        this.showError = false;
    }

    /**
     * Handles visibility toggle between portal and internal comments
     */
    visibilityChangeHandler() {
        this.portalVisible = !this.portalVisible;
        this.isPublic = this.portalVisible;
    }

    /**
     * Handles double click on comments for marking as read
     * @param {CustomEvent} event - The double click event
     */
    doubleClickHandler(event) {
        const message = event.detail.message;

        if (!message.unRead) return;

        if (!this.isPortal) {
            this.markMessageAsRead(message);
        }
    }

    /**
    * Initiates the process to update a message record according to chat action perameters
    * @param {CustomEvent} event - The flow status change event
    * @typedef {Object} event.detail
    * @property {string} id - message id
    * @property {string} type - action type
    * @property {string} value - action value
    * @property {string} previousValue - action previousValue
    */
    chatActionHandler(event){
        const actionDetails = event.detail;
        console.log('chatActionHandler conditions', actionDetails);

        this.isLoading = true;

        this.currentCommentId = actionDetails.id;
        this.chatActionType = actionDetails.type;
        this.chatActionValue = actionDetails.value;
        this.chatActionPreviousValue = actionDetails.previousValue;

        this.showProcessChatActionCommentFlow = true;
    }

    /**
     * Handles the chat action flow changes
     * @param {CustomEvent} event - The flow status change event
     */
    handleProcessChatActionCommentFlow(event) {
        const { status, outputVariables } = event.detail;
        if (status === FLOW_STATUS.ERROR) {
            this.handleFlowError('Error processing chat action for comment');
            return;
        }
        if (status !== FLOW_STATUS.FINISHED) return;
        this.updateCommentAfterChatAction(outputVariables);
    }

    /**
     * Updates the comment after chat action
     * @param {Array} outputVariables - The flow output variables
     */
    updateCommentAfterChatAction(outputVariables) {
        const updatedChatComment = this.getChatCommentItem(outputVariables[0].value);
        const commentChatIndex = this.chatComments.findIndex(comment => comment.id === updatedChatComment.id);

        this.chatComments[commentChatIndex] = updatedChatComment;
        this.chatComments = [...this.chatComments];

        this.initializeChat();
        this.resetChatActionTracking();
    }

    /**
     * Resets the chat action tracking state
     */
    resetChatActionTracking() {
        this.showProcessChatActionCommentFlow = false;
        this.isLoading = false;
        this.currentCommentId = '';
        this.chatActionType = '';
        this.chatActionValue = '';
        this.chatActionPreviousValue = '';
    }
    /**
     * Initiates the process to mark a message as read
     * @param {import('c/chat').ChatMessageDef} message - The message to mark as read
     */
    markMessageAsRead(message) {
        this.isLoading = true;
        this.currentCommentId = message.id;
        this.currentCommentIsUnread = message.unRead;
        this.showUpdateReadCommentFlow = true;
    }

    /**
     * Handles the send message event
     * @param {CustomEvent} event - The send message event
     */
    sendMessageHandler(event) {
        this.newCommentText = event.detail?.message;

        if (this.newCommentText) {
            this.isLoading = true;
            this.showCreateConditionCommentFlow = true;
        }
    }

    /**
     * Handles the update read comment flow status changes
     * @param {CustomEvent} event - The flow status change event
     */
    handleUpdateReadCommentFlow(event) {
        const { status, outputVariables } = event.detail;

        if (status === FLOW_STATUS.ERROR) {
            this.handleFlowError('Error updating comment read status');
            return;
        }

        if (status !== FLOW_STATUS.FINISHED) return;

        this.updateCommentReadStatus(outputVariables);
    }

    /**
     * Updates the read status of a comment
     * @param {Array} outputVariables - The flow output variables
     */
    updateCommentReadStatus(outputVariables) {
        const updatedChatComment = this.getChatCommentItem(outputVariables[0].value);
        const commentChatIndex = this.chatComments.findIndex(comment => comment.id === updatedChatComment.id);

        this.chatComments[commentChatIndex] = updatedChatComment;
        this.chatComments = [...this.chatComments];

        this.initializeChat();
        this.resetReadStatusTracking();
        this.dispatchToggleReadEvent();
    }

    /**
     * Resets the read status tracking state
     */
    resetReadStatusTracking() {
        this.showUpdateReadCommentFlow = false;
        this.isLoading = false;
        this.currentCommentId = '';
        this.currentCommentIsUnread = false;
    }

    /**
     * Dispatches the toggle read event
     */
    dispatchToggleReadEvent() {
        this.dispatchEvent(new CustomEvent("toggleread"));
    }

    /**
     * Handles the create comment flow status changes
     * @param {CustomEvent} event - The flow status change event
     */
    handleCreateConditionCommentFlow(event) {
        const { status, outputVariables } = event.detail;

        if (status === FLOW_STATUS.FINISHED) {
            this.addNewComment(outputVariables);
        } else if (status === FLOW_STATUS.ERROR) {
            this.handleFlowError('Error creating comment');
        }
    }

    /**
     * Adds a new comment from flow output
     * @param {Array} outputVariables - The flow output variables
     */
    addNewComment(outputVariables) {
        const newChatComment = this.getChatCommentItem(outputVariables[0].value);
        this.chatComments = [...this.chatComments, newChatComment];
        this.markNewProcessorCommentUnreadForBorrower(outputVariables[0].value);

        this.newCommentText = '';
        this.initializeChat();

        this.showCreateConditionCommentFlow = false;
        this.isLoading = false;
        this.dispatchEvent(new CustomEvent('commentcreated', {
            bubbles: true,
            composed: true
        }));
    }

    markNewProcessorCommentUnreadForBorrower(commentRecord) {
        if (this.isPortal || !this.isPublic || !commentRecord?.Id) {
            return;
        }

        markProcessorCommentUnreadForBorrower({ commentId: commentRecord.Id })
            .catch(error => {
                plog.error('ConditionComments', {
                    message: 'Error marking processor comment unread for borrower',
                    error
                });
            });
    }

    /**
     * Transforms a Salesforce comment record into a chat message format
     * @param {Condition_Comment__c} commentRecord - Comment record from Salesforce
     * @returns {import('c/chat').ChatMessageDef} - Formatted message for chat component
     */
    getChatCommentItem(commentRecord) {
        const isSenderComment = ('' + commentRecord.Portal_Comment__c) === ('' + this.isPortal);
        let userTypeName = commentRecord.Portal_Comment__c ? USER_TYPES.PORTAL : USER_TYPES.MANAGER;

        /** @type {boolean} */
        const isUnread = isSenderComment ? false : !commentRecord.Read__c;

        return {
            id: commentRecord.Id,
            message: commentRecord.Comment_Text__c,
            createdBy: commentRecord.Created_By_Name__c,
            createdOn: commentRecord.CreatedDate,
            unRead: isUnread,
            userTypeName: isSenderComment ? undefined : userTypeName,
            isOutbound: isSenderComment,
            badge: '', // Will be calculated by the chat component
            status: 'sent', // Default status for existing messages
            createdOnFormatted: '',
            actions: this.getActions(commentRecord)
        };
    }

    /**
     * @param {Condition_Comment__c} commentRecord
     * @returns {import('c/chatAction').ChatActionTypeDef[]}
     */
    getActions(commentRecord) {
        const actions = [];

        const visibilityChangeAction = this.getVisibilityChangeAction(commentRecord);
        if (visibilityChangeAction) actions.push(visibilityChangeAction);

        return actions;
    }

    /**
     * @param commentRecord
     * @returns {import('c/chatAction').ChatActionTypeDef}
     */
    getVisibilityChangeAction(commentRecord) {
        if (this.isPortal || commentRecord.Portal_Comment__c) return;

        let toggleConfigMessage = this.toggleConfig;
        toggleConfigMessage.options.forEach(option => option.label = undefined);
        toggleConfigMessage.defaultValue = commentRecord.Public__c ? 'portal' : 'internal';
        toggleConfigMessage.id = commentRecord.Id;
        toggleConfigMessage.iconSize = "xx-small";

        /** @type{ToggleConfig} **/
        return {
            type: 'TOGGLE',
            config: toggleConfigMessage
        };

    }

// Getters for flow inputs and configurations
    get chatConfiguration() {
        return {
            messages: this.chatComments,
            allowAttachments: false,
            title: 'Comments',
            maxMessageLength: 255
        };
    }

    get conditionCommentFlowInput() {
        return [
            { name: 'conditionId', type: 'String', value: this.conditionId },
            { name: 'getPrivate', type: 'Boolean', value: !this.isPortal }
        ];
    }

    get createConditionCommentFlowInput() {
        return [
            { name: 'conditionId', type: 'String', value: this.conditionId },
            { name: 'commentText', type: 'String', value: this.newCommentText },
            { name: 'isPublic', type: 'Boolean', value: this.isPublic },
            { name: 'isPortalComment', type: 'Boolean', value: this.isPortal }
        ];
    }

    get updateReadCommentFlowInput() {
        return [
            { name: 'commentId', type: 'String', value: this.currentCommentId },
            { name: 'isUnread', type: 'Boolean', value: this.currentCommentIsUnread }
        ];
    }

    get processChatActionCommentFlowInput() {
        return [
            { name: 'commentId', type: 'String', value: this.currentCommentId },
            { name: 'chatActionType', type: 'String', value: this.chatActionType },
            { name: 'chatActionValue', type: 'String', value: this.chatActionValue },
            { name: 'chatActionPreviousValue', type: 'String', value: this.chatActionPreviousValue }
        ];
    }

    /** @type {import('c/enhancedSwitcher').ToggleConfig} **/
    get toggleConfig() {
        return {
            containerStyle: 'max-width: 300px; --enhancedSwitcherFontSize: 14px;',
            defaultValue: 'portal',
            allowDeselect: false,
            options: [
                {
                    value: 'portal',
                    label: 'Portal',
                    iconName: 'utility:world',
                    customClass: 'portal-option',
                },
                {
                    value: 'internal',
                    label: 'Internal',
                    iconName: 'utility:lock',
                    customClass: 'internal-option',
                }
            ]
        };
    }
}