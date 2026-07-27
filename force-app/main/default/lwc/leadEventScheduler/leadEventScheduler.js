import { LightningElement, api } from 'lwc';
import createEvent from '@salesforce/apex/LeadActivityAssistantController.createEvent';
import getLeadContext from '@salesforce/apex/LeadActivityAssistantController.getLeadContext';
import { RefreshEvent } from 'lightning/refresh';

export default class LeadEventScheduler extends LightningElement {
    eventSubject = 'Scheduled Appointment';
    eventStartDate = '';
    eventStartTime = '';
    eventDuration = '15';
    eventReminderSet = true;
    eventReminder = '15';
    eventDescription = '';
    eventOwnerId = '';
    assigneeOptions = [];
    isSaving = false;
    errorMessage = '';
    successMessage = '';

    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadLeadContext();
        }
    }

    reminderOptions = [
        { label: 'At event time', value: '0' },
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
                options.push({ label: `${displayHour}:${String(minute).padStart(2, '0')} ${suffix}`, value });
            }
        }
        return options;
    }

    get eventStartDateTime() {
        return this.eventStartDate && this.eventStartTime ? `${this.eventStartDate}T${this.eventStartTime}` : '';
    }

    get hasAssigneeOptions() {
        return this.assigneeOptions.length > 0;
    }

    get isReminderDisabled() {
        return !this.eventReminderSet;
    }

    handleInput(event) {
        const field = event.currentTarget.dataset.field;
        this[field] = event.currentTarget.type === 'checkbox' ? event.currentTarget.checked : event.currentTarget.value;
    }

    async loadLeadContext() {
        try {
            const context = await getLeadContext({ leadId: this.recordId });
            this.assigneeOptions = context?.assignees || [];
            this.eventOwnerId = context?.defaultOwnerId || '';
        } catch (error) {
            this.assigneeOptions = [];
            this.eventOwnerId = '';
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

    reduceError(error) {
        return error?.body?.message || error?.message || 'Something went wrong.';
    }
}
