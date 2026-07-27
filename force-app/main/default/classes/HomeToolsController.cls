public with sharing class HomeToolsController {
    private static final Set<String> FUNDED_REVIEW_STATUSES = new Set<String>{ 'Funding', 'PC Review', 'Post-Closed' };
    private static final Date TRACKER_PRE_APPROVAL_START = Date.newInstance(2025, 10, 1);
    private static final String DPA_SECOND_LOAN_TYPE = 'DPA 2nd';
    private static final String REPORT_ACTIVE_PRE_APPROVALS = 'LO_Active_Pre_Approvals_2026_Review';
    private static final String REPORT_HOUSE_DEALS_YTD = 'LO_House_Deals_YTD_Review';
    private static final String REPORT_HOUSE_DEALS_MTD = 'LO_House_Deals_MTD_Review';
    private static final String REPORT_PERSONAL_DEALS_YTD = 'LO_Personal_Deals_YTD_Review';
    private static final String REPORT_PERSONAL_DEALS_MTD = 'LO_Personal_Deals_MTD_Review';
    private static final String REPORT_JOSEPH_DEALS_YTD = 'LO_Joseph_Deals_YTD_Review';
    private static final String REPORT_JOSEPH_DEALS_MTD = 'LO_Joseph_Deals_MTD_Review';

    @AuraEnabled(cacheable=true)
    public static HomeToolsData getHomeToolsData() {
        HomeToolsData data = new HomeToolsData();
        data.tasks = getTasks();
        data.events = getEvents();
        data.recentRecords = getRecentRecords();
        data.trackers = getLoanOfficerTrackers();
        return data;
    }

    private static List<HomeTracker> getLoanOfficerTrackers() {
        User currentUser = [
            SELECT Id, Name, FirstName, LastName, Title, Profile.Name, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (!isLoanOfficerUser(currentUser)) {
            return new List<HomeTracker>();
        }

        Map<String, Id> reportIdsByDeveloperName = reportIds(new Set<String>{
            REPORT_ACTIVE_PRE_APPROVALS,
            REPORT_HOUSE_DEALS_YTD,
            REPORT_HOUSE_DEALS_MTD,
            REPORT_PERSONAL_DEALS_YTD,
            REPORT_PERSONAL_DEALS_MTD,
            REPORT_JOSEPH_DEALS_YTD,
            REPORT_JOSEPH_DEALS_MTD
        });

        Date today = Date.today();
        Date yearStart = Date.newInstance(today.year(), 1, 1);
        Date nextYearStart = yearStart.addYears(1);
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);
        Date nextMonthStart = monthStart.addMonths(1);
        String personalBizDev = 'Biz Dev - ' + currentUser.LastName;

        if (currentUser.Name == 'Joseph Carey') {
            return new List<HomeTracker>{
                buildProductionTracker(
                    'Personal Deals Closed This Month',
                    'Your funded month-to-date production.',
                    currentUser.Id,
                    monthStart,
                    nextMonthStart,
                    null,
                    false,
                    reportUrl(reportIdsByDeveloperName.get(REPORT_JOSEPH_DEALS_MTD), new List<String>{ currentUser.Name })
                ),
                buildProductionTracker(
                    'Personal Deals Closed This Year',
                    'Your funded year-to-date production.',
                    currentUser.Id,
                    yearStart,
                    nextYearStart,
                    null,
                    false,
                    reportUrl(reportIdsByDeveloperName.get(REPORT_JOSEPH_DEALS_YTD), new List<String>{ currentUser.Name })
                )
            };
        }

        return new List<HomeTracker>{
            buildPreApprovalTracker(
                currentUser.Id,
                reportUrl(reportIdsByDeveloperName.get(REPORT_ACTIVE_PRE_APPROVALS), new List<String>{ currentUser.Name })
            ),
            buildProductionTracker(
                'Closed House Deals this Year',
                'Company-sourced closings credited to you.',
                currentUser.Id,
                yearStart,
                nextYearStart,
                personalBizDev,
                true,
                reportUrl(reportIdsByDeveloperName.get(REPORT_HOUSE_DEALS_YTD), new List<String>{ currentUser.Name, personalBizDev })
            ),
            buildProductionTracker(
                'Closed House Deals this Month',
                'Company-sourced closings month to date.',
                currentUser.Id,
                monthStart,
                nextMonthStart,
                personalBizDev,
                true,
                reportUrl(reportIdsByDeveloperName.get(REPORT_HOUSE_DEALS_MTD), new List<String>{ currentUser.Name, personalBizDev })
            ),
            buildProductionTracker(
                'Personal Deals Closed This Year',
                'Your personal-sourced funded volume.',
                currentUser.Id,
                yearStart,
                nextYearStart,
                personalBizDev,
                false,
                reportUrl(reportIdsByDeveloperName.get(REPORT_PERSONAL_DEALS_YTD), new List<String>{ currentUser.Name, personalBizDev })
            ),
            buildProductionTracker(
                'Personal Deals Closed This Month',
                'Your personal-sourced funded MTD volume.',
                currentUser.Id,
                monthStart,
                nextMonthStart,
                personalBizDev,
                false,
                reportUrl(reportIdsByDeveloperName.get(REPORT_PERSONAL_DEALS_MTD), new List<String>{ currentUser.Name, personalBizDev })
            )
        };
    }

    private static HomeTracker buildPreApprovalTracker(Id userId, String reportUrl) {
        AggregateResult result = [
            SELECT COUNT(Id) unitCount, SUM(Loan_Amount__c) totalVolume
            FROM Lead
            WHERE OwnerId = :userId
            AND Status = 'Pre-Approval'
            AND Pre_Approval_Date__c >= :TRACKER_PRE_APPROVAL_START
        ];
        return new HomeTracker(
            'Active Pre-Approvals',
            'Work Done, money on the table',
            decimalValue(result.get('totalVolume')),
            integerValue(result.get('unitCount')),
            reportUrl,
            'preapproval'
        );
    }

    private static HomeTracker buildProductionTracker(
        String label,
        String helperText,
        Id userId,
        Date startDate,
        Date endDate,
        String personalBizDev,
        Boolean excludePersonalBizDev,
        String reportUrl
    ) {
        String queryText =
            'SELECT COUNT(Id) unitCount, SUM(Loan_Amount_1st__c) totalVolume ' +
            'FROM Transaction__c ' +
            'WHERE Loan_Officer__c = :userId ' +
            'AND Status__c IN :FUNDED_REVIEW_STATUSES ' +
            'AND Closing_Date__c >= :startDate ' +
            'AND Closing_Date__c < :endDate ' +
            'AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE) ';
        if (!String.isBlank(personalBizDev)) {
            queryText += excludePersonalBizDev
                ? 'AND (Biz_Dev__c = null OR Biz_Dev__c != :personalBizDev) '
                : 'AND Biz_Dev__c = :personalBizDev ';
        }
        AggregateResult result = Database.query(queryText);
        return new HomeTracker(
            label,
            helperText,
            decimalValue(result.get('totalVolume')),
            integerValue(result.get('unitCount')),
            reportUrl,
            excludePersonalBizDev ? 'house' : 'personal'
        );
    }

    private static Boolean isLoanOfficerUser(User userRecord) {
        String descriptor = (
            stringValue(userRecord.Title) + ' ' +
            (userRecord.Profile == null ? '' : stringValue(userRecord.Profile.Name)) + ' ' +
            (userRecord.UserRole == null ? '' : stringValue(userRecord.UserRole.Name))
        ).toLowerCase();
        return descriptor.contains('loan officer') || descriptor.contains('outside lo') || descriptor.contains('inside lo');
    }

    private static Map<String, Id> reportIds(Set<String> developerNames) {
        Map<String, Id> idsByDeveloperName = new Map<String, Id>();
        if (developerNames == null || developerNames.isEmpty()) {
            return idsByDeveloperName;
        }
        for (Report reportRecord : [
            SELECT Id, DeveloperName
            FROM Report
            WHERE DeveloperName IN :developerNames
        ]) {
            idsByDeveloperName.put(reportRecord.DeveloperName, reportRecord.Id);
        }
        return idsByDeveloperName;
    }

    private static String reportUrl(Id reportId, List<String> filterValues) {
        if (reportId == null) {
            return null;
        }
        String url = '/lightning/r/Report/' + reportId + '/view';
        List<String> parameters = new List<String>();
        for (Integer i = 0; filterValues != null && i < filterValues.size(); i++) {
            parameters.add('fv' + String.valueOf(i) + '=' + EncodingUtil.urlEncode(stringValue(filterValues[i]), 'UTF-8'));
        }
        return parameters.isEmpty() ? url : url + '?' + String.join(parameters, '&');
    }

    private static Integer integerValue(Object value) {
        if (value == null) {
            return 0;
        }
        if (value instanceof Integer) {
            return (Integer) value;
        }
        if (value instanceof Long) {
            return Integer.valueOf((Long) value);
        }
        return Integer.valueOf(String.valueOf(value));
    }

    private static Decimal decimalValue(Object value) {
        return value == null ? 0 : (Decimal) value;
    }

    private static String stringValue(String value) {
        return String.isBlank(value) ? '' : value;
    }

    private static List<HomeItem> getTasks() {
        List<HomeItem> items = new List<HomeItem>();
        for (Task taskRecord : [
            SELECT Id, Subject, ActivityDate, Status
            FROM Task
            WHERE OwnerId = :UserInfo.getUserId()
            AND IsClosed = false
            ORDER BY ActivityDate ASC NULLS LAST, LastModifiedDate DESC
            LIMIT 5
        ]) {
            String subtitle = taskRecord.ActivityDate == null ? taskRecord.Status : String.valueOf(taskRecord.ActivityDate);
            items.add(new HomeItem(taskRecord.Id, taskRecord.Subject, subtitle, 'Task'));
        }
        return items;
    }

    private static List<HomeItem> getEvents() {
        List<HomeItem> items = new List<HomeItem>();
        for (Event eventRecord : [
            SELECT Id, Subject, StartDateTime
            FROM Event
            WHERE OwnerId = :UserInfo.getUserId()
            AND StartDateTime >= TODAY
            ORDER BY StartDateTime ASC
            LIMIT 5
        ]) {
            items.add(new HomeItem(eventRecord.Id, eventRecord.Subject, String.valueOf(eventRecord.StartDateTime), 'Event'));
        }
        return items;
    }

    private static List<HomeItem> getRecentRecords() {
        List<HomeItem> items = new List<HomeItem>();
        for (RecentlyViewed viewedRecord : [
            SELECT Id, Name, Type, LastViewedDate
            FROM RecentlyViewed
            ORDER BY LastViewedDate DESC NULLS LAST
            LIMIT 8
        ]) {
            items.add(new HomeItem(viewedRecord.Id, viewedRecord.Name, viewedRecord.Type, viewedRecord.Type));
        }
        return items;
    }

    public class HomeToolsData {
        @AuraEnabled public List<HomeItem> tasks;
        @AuraEnabled public List<HomeItem> events;
        @AuraEnabled public List<HomeItem> recentRecords;
        @AuraEnabled public List<HomeTracker> trackers;
    }

    public class HomeItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String objectApiName;

        public HomeItem(Id id, String title, String subtitle, String objectApiName) {
            this.id = id;
            this.title = title;
            this.subtitle = subtitle;
            this.objectApiName = objectApiName;
        }
    }

    public class HomeTracker {
        @AuraEnabled public String label;
        @AuraEnabled public String helperText;
        @AuraEnabled public Decimal volume;
        @AuraEnabled public Integer units;
        @AuraEnabled public String reportUrl;
        @AuraEnabled public String variant;

        public HomeTracker(String label, String helperText, Decimal volume, Integer units, String reportUrl, String variant) {
            this.label = label;
            this.helperText = helperText;
            this.volume = volume == null ? 0 : volume;
            this.units = units == null ? 0 : units;
            this.reportUrl = reportUrl;
            this.variant = variant;
        }
    }
}
