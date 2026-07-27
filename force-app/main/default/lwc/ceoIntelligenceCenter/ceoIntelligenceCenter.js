import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPageData from '@salesforce/apex/CEOIntelligenceController.getPageData';

export default class CeoIntelligenceCenter extends NavigationMixin(LightningElement) {
    @api pageKey = 'hub';
    data;
    error;
    isLoading = true;

    @wire(getPageData, { pageKey: '$pageKey' })
    wiredData({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.data = {
                ...data,
                cards: this.decorateCards(data.cards || []),
                navItems: this.decorateNavItems(data.navItems || []),
                sections: this.decorateSections(data.sections || [])
            };
            this.error = undefined;
        } else if (error) {
            this.data = undefined;
            this.error = this.extractError(error);
        }
    }

    get title() {
        return this.data?.title || 'CEO Intelligence';
    }

    get subtitle() {
        return this.data?.subtitle || 'Company-level performance intelligence.';
    }

    get kicker() {
        return this.data?.kicker || 'Reach Home Loans';
    }

    get hasData() {
        return !!this.data;
    }

    get formattedGeneratedAt() {
        if (!this.data?.generatedAt) {
            return '';
        }
        return new Intl.DateTimeFormat('en-US', {
            month: 'short',
            day: 'numeric',
            hour: 'numeric',
            minute: '2-digit'
        }).format(new Date(this.data.generatedAt));
    }

    decorateCards(cards) {
        return cards.map((card, index) => ({
            ...card,
            key: `${card.label}-${index}`,
            className: `ceo-card ceo-card-${(index % 4) + 1}${card.urlPath ? ' ceo-card-clickable' : ''}`,
            isReportCard: !!card.urlPath,
            hasBreakdown: (card.breakdown || []).length > 0,
            breakdown: (card.breakdown || []).map((item, itemIndex) => ({
                ...item,
                key: `${card.label}-breakdown-${itemIndex}`
            }))
        }));
    }

    decorateNavItems(navItems) {
        return navItems.map((item) => ({
            ...item,
            className: item.key === this.normalizedPageKey ? 'ceo-nav-pill ceo-nav-pill-active' : 'ceo-nav-pill'
        }));
    }

    decorateSections(sections) {
        return sections.map((section, sectionIndex) => ({
            ...section,
            key: `${section.title}-${sectionIndex}`,
            className: this.sectionClass(section.title),
            isLeadSourcePerformance: section.title === 'Lead Source Performance',
            columns: (section.columns || []).map((column, columnIndex) => ({
                label: column,
                key: `${section.title}-column-${columnIndex}`
            })),
            rows: (section.rows || []).map((row, rowIndex) => ({
                ...row,
                key: `${section.title}-row-${rowIndex}`,
                cells: (row.values || []).map((value, valueIndex) => ({
                    value,
                    key: `${section.title}-row-${rowIndex}-cell-${valueIndex}`,
                    isNavigationCell: !!row.navApiName && valueIndex === (row.values || []).length - 1,
                    isReportCell: this.isReportCell(section.title, row, valueIndex),
                    isRosterPill: this.isRosterPill(section.title, valueIndex),
                    urlPath: this.cellUrlPath(row, valueIndex),
                    reportButtonClass: this.reportButtonClass(section.title, valueIndex, rowIndex, value),
                    rosterPillClass: this.rosterPillClass(valueIndex)
                }))
            }))
        }));
    }

    isReportCell(sectionTitle, row, valueIndex) {
        if (this.cellUrlPath(row, valueIndex)) {
            return true;
        }
        return !!row.urlPath && (
            valueIndex > 0 ||
            sectionTitle === 'Lead Source Performance' ||
            sectionTitle === 'Consumer Webinar Performance by Date' ||
            sectionTitle === 'Open Transaction Pipeline by Status' ||
            sectionTitle === 'Pipeline by Stage' ||
            sectionTitle === 'Active Pipeline by Status'
        );
    }

    cellUrlPath(row, valueIndex) {
        const cellUrlPaths = row.cellUrlPaths || [];
        return cellUrlPaths[valueIndex] || row.urlPath;
    }

    reportButtonClass(sectionTitle, valueIndex, rowIndex, value) {
        if (this.isInsideLoanOfficerSection(sectionTitle)) {
            return `ceo-link-button ceo-inside-lo-pill ${this.insideLoanOfficerPillTone(sectionTitle, valueIndex, rowIndex, value)}`;
        }
        if (sectionTitle === 'Lead Source Performance') {
            return `ceo-link-button ceo-metric-pill ceo-metric-pill-${(valueIndex % 4) + 1}`;
        }
        if (sectionTitle === 'Consumer Webinar Performance by Date') {
            return `ceo-link-button ceo-webinar-pill ceo-webinar-pill-${(valueIndex % 5) + 1}`;
        }
        if (sectionTitle === 'Nickley Group Lead Intelligence') {
            return `ceo-link-button ceo-nickley-pill ceo-nickley-pill-${(valueIndex % 4) + 1}`;
        }
        if (sectionTitle === 'Active Leads Status Funnel') {
            return `ceo-link-button ceo-funnel-pill ceo-funnel-pill-${(valueIndex % 2) + 1}`;
        }
        if (sectionTitle === 'Current Active Leads Assigned by Loan Officer' && valueIndex > 0) {
            return `ceo-link-button ceo-lo-pill ceo-lo-pill-${(valueIndex % 4) + 1}`;
        }
        if (sectionTitle === 'Open Transaction Pipeline by Status' || sectionTitle === 'Pipeline by Stage' || sectionTitle === 'Active Pipeline by Status') {
            if (valueIndex === 0) {
                return `ceo-link-button ceo-transaction-status-pill ceo-transaction-status-${this.statusSlug(value)}`;
            }
            return `ceo-link-button ceo-transaction-soft-pill ceo-transaction-soft-pill-${valueIndex}`;
        }
        return 'ceo-link-button';
    }

    isInsideLoanOfficerSection(sectionTitle) {
        return [
            'This Month',
            'Lead Sources',
            '2025 Baseline',
            'Recent Lead Months',
            'Recent Cohorts',
            'Activity',
            'Data Fixes',
            'Current Month Forecast',
            '2025 Benchmark Validation',
            'Current + Previous 3 Cohorts',
            'Activity and Follow-Up',
            'Data Hygiene Flags',
            'Roster Definition Review'
        ].includes(sectionTitle);
    }

    insideLoanOfficerPillTone(sectionTitle, valueIndex, rowIndex, value) {
        if (sectionTitle === 'Data Fixes' || sectionTitle === 'Data Hygiene Flags') {
            return valueIndex === 2 && this.numericValue(value) > 0 ? 'ceo-inside-lo-pill-warning' : 'ceo-inside-lo-pill-green';
        }
        if (sectionTitle === 'Activity' || sectionTitle === 'Activity and Follow-Up') {
            const followUpColumnIndex = 6;
            const callsColumnIndex = 4;
            if (valueIndex === followUpColumnIndex && this.numericValue(value) > 0) {
                return 'ceo-inside-lo-pill-warning';
            }
            if (valueIndex === callsColumnIndex) {
                return 'ceo-inside-lo-pill-blue';
            }
            return `ceo-inside-lo-pill-${((valueIndex + rowIndex) % 5) + 1}`;
        }
        if (sectionTitle === 'This Month' || sectionTitle === 'Current Month Forecast') {
            if (valueIndex >= 7) {
                return 'ceo-inside-lo-pill-blue';
            }
            if (valueIndex === 3 || valueIndex === 4) {
                return 'ceo-inside-lo-pill-green';
            }
            return `ceo-inside-lo-pill-${((valueIndex + rowIndex) % 5) + 1}`;
        }
        if (sectionTitle === 'Lead Sources') {
            if (valueIndex === 2) {
                return 'ceo-inside-lo-pill-green';
            }
            if (valueIndex === 3) {
                return 'ceo-inside-lo-pill-blue';
            }
            return `ceo-inside-lo-pill-${((valueIndex + rowIndex) % 5) + 1}`;
        }
        if (sectionTitle === 'Roster Definition Review') {
            return valueIndex === 3 ? 'ceo-inside-lo-pill-blue' : 'ceo-inside-lo-pill-slate';
        }
        return `ceo-inside-lo-pill-${((valueIndex + rowIndex) % 5) + 1}`;
    }

    numericValue(value) {
        const parsed = Number.parseFloat((value || '').toString().replace(/[$,%\s,]/g, ''));
        return Number.isNaN(parsed) ? 0 : parsed;
    }

    statusSlug(value) {
        return (value || 'default')
            .toString()
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/^-|-$/g, '') || 'default';
    }

    isRosterPill(sectionTitle, valueIndex) {
        return sectionTitle === 'Reach Home Loans Roster' && valueIndex > 0;
    }

    rosterPillClass(valueIndex) {
        return `ceo-roster-pill ceo-roster-pill-${valueIndex}`;
    }

    sectionClass(sectionTitle) {
        if (this.isInsideLoanOfficerSection(sectionTitle)) {
            return 'ceo-section ceo-inside-lo-section';
        }
        if (sectionTitle === 'Active Pipeline by Status' || sectionTitle === 'Open Transaction Pipeline by Status') {
            return 'ceo-section ceo-transaction-pipeline-section';
        }
        if (sectionTitle === 'Consumer Webinar Performance by Date') {
            return 'ceo-section ceo-webinar-section';
        }
        if (sectionTitle === 'Reach Home Loans Roster') {
            return 'ceo-section ceo-roster-section';
        }
        if (sectionTitle === 'Nickley Group Lead Intelligence') {
            return 'ceo-section ceo-nickley-section';
        }
        return 'ceo-section';
    }

    get normalizedPageKey() {
        return (this.pageKey || 'hub').trim().toLowerCase();
    }

    handleNavClick(event) {
        const tabApiName = event.currentTarget.dataset.tab;
        this.navigateToTab(tabApiName);
    }

    handleCellNavClick(event) {
        const tabApiName = event.currentTarget.dataset.tab;
        this.navigateToTab(tabApiName);
    }

    handleReportClick(event) {
        const urlPath = event.currentTarget.dataset.url;
        this.navigateToUrl(urlPath);
    }

    handleCardClick(event) {
        const urlPath = event.currentTarget.dataset.url;
        this.navigateToUrl(urlPath);
    }

    handleCardBreakdownClick(event) {
        event.stopPropagation();
        const urlPath = event.currentTarget.dataset.url;
        this.navigateToUrl(urlPath);
    }

    navigateToUrl(urlPath) {
        if (!urlPath) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: urlPath
            }
        });
    }

    navigateToTab(tabApiName) {
        if (!tabApiName) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: tabApiName
            }
        });
    }

    extractError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        return 'Unable to load CEO intelligence data.';
    }
}
