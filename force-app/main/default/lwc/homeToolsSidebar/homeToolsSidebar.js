import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getHomeToolsData from '@salesforce/apex/HomeToolsController.getHomeToolsData';

export default class HomeToolsSidebar extends NavigationMixin(LightningElement) {
    tasks = [];
    events = [];
    recentRecords = [];
    trackers = [];

    get hasTrackers() {
        return this.trackers.length > 0;
    }

    get hasTasks() {
        return this.tasks.length > 0;
    }

    get hasEvents() {
        return this.events.length > 0;
    }

    get hasRecentRecords() {
        return this.recentRecords.length > 0;
    }

    get eventsCardClass() {
        return this.hasTrackers ? 'tools-card tools-card-hidden' : 'tools-card';
    }

    @wire(getHomeToolsData)
    wiredHomeTools({ data }) {
        if (data) {
            this.tasks = data.tasks || [];
            this.events = data.events || [];
            this.recentRecords = data.recentRecords || [];
            this.trackers = this.decorateTrackers(data.trackers || []);
        }
    }

    decorateTrackers(trackers) {
        return trackers.map((tracker, index) => ({
            ...tracker,
            key: `${tracker.label}-${index}`,
            className: ['tracker-card', tracker.variant ? `tracker-card-${tracker.variant}` : ''].filter(Boolean).join(' '),
            formattedVolume: this.formatCurrency(tracker.volume),
            unitsText: `${tracker.units || 0} ${(tracker.units || 0) === 1 ? 'unit' : 'units'}`
        }));
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(value || 0);
    }

    openRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        const objectApiName = event.currentTarget.dataset.object;
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName,
                actionName: 'view'
            }
        });
    }

    openReport(event) {
        const reportUrl = event.currentTarget.dataset.reportUrl;
        if (!reportUrl) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: reportUrl
            }
        });
    }

    openTasks() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Task',
                actionName: 'list'
            }
        });
    }

    openCalendar() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Event',
                actionName: 'home'
            }
        });
    }
}
