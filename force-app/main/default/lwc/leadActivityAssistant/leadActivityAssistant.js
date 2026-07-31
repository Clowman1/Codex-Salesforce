import { LightningElement, api } from 'lwc';
import logCall from '@salesforce/apex/LeadActivityAssistantController.logCall';
import createEvent from '@salesforce/apex/LeadActivityAssistantController.createEvent';
import getLeadContext from '@salesforce/apex/LeadActivityAssistantController.getLeadContext';
import { RefreshEvent } from 'lightning/refresh';

export default class LeadActivityAssistant extends LightningElement {
    selectedTab = 'call';
    isSaving = false;
    errorMessage = '';
    successMessage = '';
    buyerAgentMessageLimit = 255;

    callSubject = 'Call - No Contact';
    internalNote = '';
    buyerAgentMessage = '';
    buyerAgentMessageMore = '';
    callEventSubject = '';
    callEventSubjectEdited = false;

    eventSubject = 'Scheduled Appointment';
    eventStartDate = '';
    eventStartTime = '';
    eventDuration = '15';
    eventReminderSet = true;
    eventReminder = '15';
    eventDescription = '';
    eventOwnerId = '';
    defaultEventOwnerId = '';
    assigneeOptions = [];
    hasBuyerAgent = false;
    isConsumerLead = true;
    leadName = '';
    objectApiName = 'Lead';
    leadContextSignature = '';

    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        if (value === this._recordId) {
            return;
        }
        this._recordId = value;
        this.leadContextSignature = '';
        this.hasBuyerAgent = false;
        this.isConsumerLead = true;
        this.leadName = '';
        this.objectApiName = 'Lead';
        this.callSubject = 'Call - No Contact';
        this.callEventSubject = '';
        this.callEventSubjectEdited = false;
        if (value) {
            this.loadLeadContext();
        }
    }

    callSubjectOptions = [
        { label: 'Call - No Contact', value: 'Call - No Contact' },
        { label: 'Call - Contacted/Call Back', value: 'Call - Contacted/Call Back' },
        { label: 'Call - Working', value: 'Call - Working' },
        { label: 'Call - Application', value: 'Call - Application' },
        { label: 'Call - Docs Requested', value: 'Call - Docs Requested' },
        { label: 'Call - Docs Received', value: 'Call - Docs Received' },
        { label: 'Call - Nurturing', value: 'Call - Nurturing' },
        { label: 'Call', value: 'Call' },
        { label: 'Document follow up', value: 'Document follow up' },
        { label: 'Other', value: 'Other' },
        { label: '30 Day Follow Up', value: '30 Day Follow Up' },
        { label: 'Call Preapproved', value: 'Call Preapproved' },
        { label: 'Nurture - Preapproval', value: 'Nurture - Preapproval' },
        { label: 'Under Contract', value: 'Under Contract' }
    ];

    reminderOptions = [
        { label: 'At event time', value: '0' },
        { label: '5 minutes before', value: '5' },
        { label: '10 minutes before', value: '10' },
        { label: '15 minutes before', value: '15' },
        { label: '30 minutes before', value: '30' },
        { label: '1 hour before', value: '60' },
        { label: '1 day before', value: '1440' }
    ];

    get timeOptions() {
        const options = [];
        for (let hour = 7; hour <= 21; hour += 1) {
            for (let minute = 0; minute < 60; minute += 15) {
                if (hour === 21 && minute > 0) {
                    break;
                }
                const value = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
                const suffix = hour >= 12 ? 'PM' : 'AM';
                const displayHour = hour % 12 || 12;
                const label = `${displayHour}:${String(minute).padStart(2, '0')} ${suffix}`;
                options.push({ label, value });
            }
        }
        return options;
    }

    get followUpDateTime() {
        return this.eventStartDateTime;
    }

    get defaultCallEventSubject() {
        return this.leadName ? `Follow Up - ${this.leadName}` : 'Follow Up';
    }

    get isAccountRecord() {
        return this.objectApiName === 'Account';
    }

    get assistantTitle() {
        return this.isAccountRecord ? 'Account Activity Assistant' : 'Lead Activity Assistant';
    }

    get assistantClass() {
        return this.isAccountRecord ? 'assistant assistant-account' : 'assistant';
    }

    get assistantSubcopy() {
        return this.isAccountRecord
            ? 'Log calls, capture account notes, and schedule follow-up events without leaving the account.'
            : 'Log lead calls, capture notes, message buyer agents, and schedule follow-up events in one place.';
    }

    get noteHint() {
        return this.isAccountRecord
            ? 'This saves to the Task and creates an Account note in the Notes tab.'
            : 'This saves to the Task and creates a Lead note in the Notes tab.';
    }

    get callSubjectHint() {
        return this.isAccountRecord
            ? 'Enter the subject that should appear on the completed Account call activity.'
            : 'Choose the activity outcome that best matches the conversation.';
    }

    get assigneeHint() {
        return this.isAccountRecord
            ? 'Defaults to the Account Owner. Select another available account assignee when needed.'
            : 'Defaults to the Lead Owner. Select the Loan Partner when the event should be assigned there.';
    }

    get eventStartDateTime() {
        return this.eventStartDate && this.eventStartTime ? `${this.eventStartDate}T${this.eventStartTime}` : '';
    }

    get eventReminderLabel() {
        const reminder = this.reminderOptions.find((option) => option.value === this.eventReminder);
        return reminder ? reminder.label : '15 minutes before';
    }

    get isReminderDisabled() {
        return !this.eventReminderSet;
    }

    get eventReminderSetValue() {
        return this.eventReminderSet ? 'true' : 'false';
    }

    get callSubjectAllowsNoFutureEvent() {
        const normalizedSubject = this.normalizeSubject(this.callSubject);
        return [
            'CALL NURTURING',
            'NURTURE',
            'NURTURING',
            'PRE APPROVAL',
            'CALL PREAPPROVED',
            'CALL PREAPPROVAL',
            'PREAPPROVED',
            'PREAPPROVAL',
            'NURTURE PREAPPROVAL',
            'NURTURE PRE APPROVAL',
            'UNDER CONTRACT'
        ].includes(normalizedSubject);
    }

    get hasAssigneeOptions() {
        return this.assigneeOptions.length > 0;
    }

    get isCallTab() {
        return this.selectedTab === 'call';
    }

    get callTabClass() {
        return this.isCallTab ? 'tab active' : 'tab';
    }

    get eventTabClass() {
        return !this.isCallTab ? 'tab active' : 'tab';
    }

    selectTab(event) {
        this.selectedTab = event.currentTarget.dataset.tab;
        this.clearMessages();
    }

    handleInput(event) {
        const field = event.currentTarget.dataset.field;
        let value = event.currentTarget.type === 'checkbox' ? event.currentTarget.checked : event.currentTarget.value;
        if (field === 'eventReminderSet') {
            value = value === true || value === 'true';
        }
        if ((field === 'buyerAgentMessage' || field === 'buyerAgentMessageMore') && value) {
            value = value.slice(0, this.buyerAgentMessageLimit);
            event.currentTarget.value = value;
        }
        if (field === 'callEventSubject') {
            this.callEventSubjectEdited = true;
        }
        this[field] = value;
    }

    async loadLeadContext(options = {}) {
        const previousOwnerId = this.eventOwnerId;
        try {
            const context = await getLeadContext({ leadId: this.recordId });
            const assignees = context?.assignees || [];
            const assigneeValues = assignees.map((option) => option.value);
            this.assigneeOptions = assignees;
            this.defaultEventOwnerId = context?.defaultOwnerId || '';
            this.hasBuyerAgent = Boolean(context?.hasBuyerAgent);
            this.isConsumerLead = context?.isConsumerLead !== false;
            this.leadName = context?.leadName || '';
            this.objectApiName = context?.objectApiName || 'Lead';
            if (this.isAccountRecord && this.callSubject === 'Call - No Contact') {
                this.callSubject = '';
                this.syncCallFormInputs();
            }
            if (!this.callEventSubjectEdited) {
                this.callEventSubject = this.defaultCallEventSubject;
            }
            if (options.preserveSelection && previousOwnerId && assigneeValues.includes(previousOwnerId)) {
                this.eventOwnerId = previousOwnerId;
            } else {
                this.eventOwnerId = this.defaultAssigneeId;
            }
        } catch (error) {
            this.assigneeOptions = [];
            this.eventOwnerId = '';
            this.defaultEventOwnerId = '';
            this.hasBuyerAgent = false;
            this.isConsumerLead = true;
        }
    }

    async saveCall() {
        this.clearMessages();
        if (!this.callSubject?.trim()) {
            this.errorMessage = 'Subject is required.';
            return;
        }
        if ((this.eventStartDate || this.eventStartTime) && !this.eventStartDateTime) {
            this.errorMessage = 'Start Date and Start Time are both required to schedule the follow-up event.';
            return;
        }
        if (!this.isAccountRecord && this.isConsumerLead && !this.eventStartDateTime && !this.callSubjectAllowsNoFutureEvent) {
            this.errorMessage = 'This call requires a future event. Please select a Start Date and Start Time, or make sure this Lead already has a future event set.';
            return;
        }

        this.isSaving = true;
        try {
            await logCall({
                leadId: this.recordId,
                subject: this.callSubject,
                taskStatus: 'Completed',
                internalNote: this.internalNote,
                followUpDateTime: this.followUpDateTime,
                buyerAgentMessage: this.buyerAgentMessage,
                buyerAgentMessageMore: this.buyerAgentMessageMore,
                ownerId: this.eventOwnerId,
                durationMinutes: Number(this.eventDuration),
                reminderSet: this.eventReminderSet,
                reminderMinutes: Number(this.eventReminder),
                eventSubject: this.callEventSubject || this.defaultCallEventSubject
            });
            this.resetCallForm();
            this.successMessage = 'Call logged successfully.';
            this.syncCallFormInputs();
            Promise.resolve().then(() => this.syncCallFormInputs());
            this.dispatchEvent(new RefreshEvent());
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isSaving = false;
        }
    }

    async saveEvent() {
        this.clearMessages();
        if (!this.eventSubject?.trim() || !this.eventStartDate || !this.eventStartTime) {
            this.errorMessage = 'Subject and start date/time are required.';
            return;
        }

        this.isSaving = true;
        try {
            await createEvent({
                leadId: this.recordId,
                subject: this.eventSubject,
                ownerId: this.eventOwnerId,
                startDateTime: this.eventStartDateTime,
                durationMinutes: Number(this.eventDuration),
                reminderSet: this.eventReminderSet,
                reminderMinutes: Number(this.eventReminder),
                description: this.eventDescription
            });
            this.successMessage = 'Event scheduled successfully.';
            this.eventDescription = '';
            this.eventStartDate = '';
            this.eventStartTime = '';
            this.dispatchEvent(new RefreshEvent());
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isSaving = false;
        }
    }

    clearMessages() {
        this.errorMessage = '';
        this.successMessage = '';
    }

    get defaultAssigneeId() {
        return this.defaultEventOwnerId || this.assigneeOptions[0]?.value || '';
    }

    resetCallForm() {
        this.callSubject = this.isAccountRecord ? '' : 'Call - No Contact';
        this.internalNote = '';
        this.eventOwnerId = this.defaultAssigneeId;
        this.eventStartDate = '';
        this.eventStartTime = '';
        this.eventDuration = '15';
        this.eventReminderSet = true;
        this.eventReminder = '15';
        this.callEventSubject = this.defaultCallEventSubject;
        this.callEventSubjectEdited = false;
        this.buyerAgentMessage = '';
        this.buyerAgentMessageMore = '';
    }

    syncCallFormInputs() {
        const fieldValues = {
            callSubject: this.callSubject,
            internalNote: this.internalNote,
            eventOwnerId: this.eventOwnerId,
            eventStartDate: this.eventStartDate,
            eventStartTime: this.eventStartTime,
            eventDuration: this.eventDuration,
            eventReminderSet: this.eventReminderSetValue,
            eventReminder: this.eventReminder,
            callEventSubject: this.callEventSubject,
            buyerAgentMessage: this.buyerAgentMessage,
            buyerAgentMessageMore: this.buyerAgentMessageMore
        };

        this.template.querySelectorAll('[data-field]').forEach((field) => {
            const fieldName = field.dataset.field;
            if (Object.prototype.hasOwnProperty.call(fieldValues, fieldName)) {
                field.value = fieldValues[fieldName] ?? '';
            }
        });
    }

    reduceError(error) {
        const messages = [];
        const body = error?.body;
        if (Array.isArray(body)) {
            body.forEach((item) => {
                if (item?.message) {
                    messages.push(item.message);
                }
            });
        } else if (body) {
            if (body.message) {
                messages.push(body.message);
            }
            if (Array.isArray(body.pageErrors)) {
                body.pageErrors.forEach((item) => {
                    if (item?.message) {
                        messages.push(item.message);
                    }
                });
            }
            if (body.fieldErrors) {
                Object.values(body.fieldErrors).forEach((fieldMessages) => {
                    fieldMessages.forEach((item) => {
                        if (item?.message) {
                            messages.push(item.message);
                        }
                    });
                });
            }
            if (body.output?.errors) {
                body.output.errors.forEach((item) => {
                    if (item?.message) {
                        messages.push(item.message);
                    }
                });
            }
            if (body.output?.fieldErrors) {
                Object.values(body.output.fieldErrors).forEach((fieldMessages) => {
                    fieldMessages.forEach((item) => {
                        if (item?.message) {
                            messages.push(item.message);
                        }
                    });
                });
            }
        }
        if (error?.message) {
            messages.push(error.message);
        }
        const message = messages.find((item) => item && item !== 'An internal server error has occurred') || '';
        if (this.isPreApprovalRequirementError(message)) {
            return 'To move this Lead to Pre-Approval, fill in both Lead Rating and Loan Amount on the Lead record, then try again.';
        }
        if (message.includes('Follow Up Date Time field cannot be blank')) {
            return 'This call requires a future event. Please select a Start Date and Start Time, or make sure this Lead already has a future event set.';
        }
        if (message.includes('External Message to Buyer')) {
            return 'This status requires an External Message to Buyer\'s Agent before the call can be logged.';
        }
        if (message.includes('comments cannot be blank')) {
            return 'Internal Note is required for this call action.';
        }
        return message || 'The call could not be logged. Please review the required fields and try again.';
    }

    isPreApprovalRequirementError(message) {
        const normalized = (message || '').toLowerCase();
        return normalized.includes('lead rating')
            && normalized.includes('amount')
            && normalized.includes('pre-approval');
    }

    normalizeSubject(value) {
        return (value || '').trim().toUpperCase().replace(/-/g, ' ').replace(/\s+/g, ' ');
    }
}
