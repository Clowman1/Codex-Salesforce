public with sharing class CEOIntelligenceController {
    private static final Date TODAY_DATE = Date.today();
    private static final Date MONTH_START = TODAY_DATE.toStartOfMonth();
    private static final Date LAST_MONTH_START = MONTH_START.addMonths(-1);
    private static final Date NEXT_MONTH_START = MONTH_START.addMonths(1);
    private static final Date QUARTER_START = Date.newInstance(TODAY_DATE.year(), (((TODAY_DATE.month() - 1) / 3) * 3) + 1, 1);
    private static final Date YEAR_START = Date.newInstance(TODAY_DATE.year(), 1, 1);
    private static final Date LEAD_INTELLIGENCE_START = Date.newInstance(2025, 1, 1);
    private static final Date STATUS_AGE_CLOSING_CUTOFF = TODAY_DATE.addDays(30);
    private static final String LEAD_FUNNEL_REPORT_DEVELOPER_NAME = 'CEO_Lead_Intelligence_Funnel_Review';
    private static final String LEAD_SOURCE_REPORT_DEVELOPER_NAME = 'CEO_Lead_Source_Performance_Review';
    private static final String LEAD_MONTHLY_AVERAGE_REPORT_DEVELOPER_NAME = 'CEO_Lead_2026_Monthly_Average_Review';
    private static final String LEAD_WORKING_REPORT_DEVELOPER_NAME = 'CEO_Working_Leads_Review';
    private static final String LEAD_STAGNANT_7_REPORT_DEVELOPER_NAME = 'CEO_Stagnant_Leads_Review';
    private static final String LEAD_STAGNANT_14_REPORT_DEVELOPER_NAME = 'CEO_Stagnant_Leads_14_Days_Review';
    private static final String LEAD_STAGNANT_21_REPORT_DEVELOPER_NAME = 'CEO_Stagnant_Leads_21_Days_Review';
    private static final String LEAD_PRE_APPROVALS_YTD_REPORT_DEVELOPER_NAME = 'CEO_Pre_Approvals_Issued_YTD_Review';
    private static final String LEAD_LO_ACTIVE_REPORT_DEVELOPER_NAME = 'CEO_LO_Active_Leads_Review';
    private static final String LEAD_LO_STAGNANT_7_REPORT_DEVELOPER_NAME = 'CEO_LO_Stagnant_7_Days_Review';
    private static final String LEAD_LO_STAGNANT_14_REPORT_DEVELOPER_NAME = 'CEO_LO_Stagnant_14_Days_Review';
    private static final String LEAD_LO_STAGNANT_21_REPORT_DEVELOPER_NAME = 'CEO_LO_Stagnant_21_Days_Review';
    private static final String LEAD_LO_PRE_APPROVAL_2026_REPORT_DEVELOPER_NAME = 'CEO_LO_Current_Pre_Approvals_2026_Review';
    private static final String LEAD_WEBINAR_BY_DATE_REPORT_DEVELOPER_NAME = 'CEO_Consumer_Webinar_By_Date_Review';
    private static final String NICKLEY_GROUP_LEADS_REPORT_DEVELOPER_NAME = 'CEO_Nickley_Group_Leads_Review';
    private static final String TRANSACTION_ACTIVE_STATUS_REPORT_DEVELOPER_NAME = 'CEO_Active_Pipeline_By_Status_Review';
    private static final String TRANSACTION_FUNDED_MTD_REPORT_DEVELOPER_NAME = 'CEO_Funded_MTD_Review';
    private static final String TRANSACTION_FUNDED_QTD_REPORT_DEVELOPER_NAME = 'CEO_Funded_QTD_Review';
    private static final String TRANSACTION_FUNDED_YTD_REPORT_DEVELOPER_NAME = 'CEO_Funded_YTD_Review';
    private static final String TRANSACTION_ACTIVE_VOLUME_REPORT_DEVELOPER_NAME = 'CEO_Active_Transaction_Volume_Review';
    private static final String LO_LEAD_PIPELINE_REPORT_DEVELOPER_NAME = 'Loan_Officer_Lead_Pipeline_Rwl';
    private static final String LO_ACTIVE_PRE_APPROVALS_REPORT_DEVELOPER_NAME = 'LO_Active_Pre_Approvals_2026_Review';
    private static final String LO_PERSONAL_DEALS_MTD_REPORT_DEVELOPER_NAME = 'LO_Personal_Deals_MTD_Review';
    private static final String LO_OUTBOUND_CALLS_MTD_REPORT_DEVELOPER_NAME = 'Outbound_Calls_by_User_wUS';
    private static final String LO_LEAD_REPORT_RECORD_TYPE_FILTER = 'Lead.Loan_Officer_Lead_Record_Type';
    private static final String LO_OUTBOUND_CALL_TYPE_FILTER = '2';
    private static final Set<String> ACTIVE_TRANSACTION_EXCLUDES = new Set<String>{ 'Cancelled', 'Canceled', 'Post-Closed', 'QC Review', 'PC Review', 'Lost' };
    private static final Set<Id> STATUS_AGE_OUTLIER_TRANSACTION_IDS = new Set<Id>{ 'a01Qi000016jZYlIAM' };
    private static final Set<String> FUNDED_STATUSES = new Set<String>{ 'Funding', 'QC Review', 'PC Review', 'Post-Closed' };
    private static final Set<String> CLOSED_TRANSACTION_STATUSES = new Set<String>{ 'Post-Closed', 'PC Review' };
    private static final Set<String> CANCELLED_TRANSACTION_STATUSES = new Set<String>{ 'Cancelled', 'Canceled' };
    private static final String DPA_SECOND_LOAN_TYPE = 'DPA 2nd';
    private static final Set<String> ACTIVE_LEAD_EXCLUDES = new Set<String>{ 'Nurturing', 'Nurture - Preapproval', 'Pre-Approval', '30 Days Plus Follow Up', 'Credit Repair' };
    private static final Set<String> ADVANCING_LEAD_STATUSES = new Set<String>{
        'Working',
        'Application',
        'Application Link Out',
        'Documents Requested',
        'Documents Received for Review',
        'Under Contract'
    };
    private static final List<String> ACTIVE_LEAD_FUNNEL_STATUSES = new List<String>{
        'New',
        'Contact Attempt 1',
        'Contact Attempt 2',
        'Contact Attempt 3',
        'Working',
        'Application',
        'Application Link Out',
        'Documents Requested',
        'Documents Received for Review',
        'Pre-Approval',
        'Under Contract'
    };
    private static final Set<String> LEAD_INTELLIGENCE_EXCLUDED_OWNERS = new Set<String>{
        'Adam Stephens',
        'Benjamin Bondarevsky',
        'Benjamin Bondarevsky - Outside',
        'John Carbera',
        'John Cabrera',
        'Byron Richie',
        'Alex Saludes',
        'Joseph Carey',
        'Plutarco Castellanos',
        'Ryan Kauffman',
        'Chad Gorman',
        'Dylan Betcher',
        'Daniel Alvaro',
        'Daniel Rubio',
        'Lauren Williams',
        'Nimbus Development',
        'Nimbus Development - Outside'
    };
    private static final Set<String> ROSTER_EXCLUDED_USERS = new Set<String>{
        'Christian MarketingLogin',
        'Insights Integration',
        'Integration User',
        'Nimbus Development',
        'Security User'
    };
    private static final Set<String> ROSTER_SALES_USERS = new Set<String>{
        'Benjamin Bondarevsky',
        'Brandon Brotsky',
        'Zenen Chamizo'
    };
    private static final Set<String> ROSTER_OUTSIDE_LO_USERS = new Set<String>{
        'Harold Ellis',
        'Joseph Carey',
        'Justin Waters'
    };
    private static final Set<String> ROSTER_OPERATIONS_USERS = new Set<String>{
        'Jamie Martinez',
        'Melina Munne'
    };
    private static final Set<String> NICKLEY_REALTOR_GROUPS = new Set<String>{
        'The Nickley Group',
        'Nickley ISA\'s'
    };
    private static Map<String, String> reportIdsByDeveloperName = new Map<String, String>();

    @AuraEnabled(cacheable=true)
    public static PageData getPageData(String pageKey) {
        if (!Test.isRunningTest() && !FeatureManagement.checkPermission('CEO_Intelligence_Access')) {
            throw new AuraHandledException('CEO Hub access is limited to approved executive users.');
        }

        String normalizedKey = String.isBlank(pageKey) ? 'hub' : pageKey.trim().toLowerCase();
        PageData data = basePage(normalizedKey);

        if (normalizedKey == 'leads') {
            populateLeadPage(data);
        } else if (normalizedKey == 'transactions') {
            populateTransactionPage(data);
        } else if (normalizedKey == 'trends') {
            populateTrendPage(data);
        } else if (normalizedKey == 'loanofficers') {
            populateLoanOfficerPage(data);
        } else if (normalizedKey == 'realtors') {
            populateRealtorPage(data);
        } else if (normalizedKey == 'fallout') {
            populateFalloutPage(data);
        } else if (normalizedKey == 'operations') {
            populateOperationsPage(data);
        } else {
            populateHubPage(data);
        }
        return data;
    }

    private static PageData basePage(String pageKey) {
        PageData data = new PageData();
        data.pageKey = pageKey;
        data.generatedAt = System.now();
        data.navItems = new List<NavItem>{
            new NavItem('hub', 'CEO Hub', 'CEO_Intelligence_Hub'),
            new NavItem('leads', 'Lead Intelligence', 'CEO_Lead_Intelligence'),
            new NavItem('transactions', 'Transaction Intelligence', 'CEO_Transaction_Intelligence'),
            new NavItem('trends', 'Trends', 'CEO_Trends'),
            new NavItem('loanofficers', 'Inside Loan Officers', 'CEO_Loan_Officer_Performance'),
            new NavItem('realtors', 'Realtor Partners', 'CEO_Realtor_Partners'),
            new NavItem('fallout', 'Fallout', 'CEO_Fallout_Lost_Business'),
            new NavItem('operations', 'Operational Health', 'CEO_Operational_Health')
        };
        return data;
    }

    private static void populateHubPage(PageData data) {
        data.title = 'CEO Intelligence Hub';
        data.subtitle = 'High-level company intelligence organized by business topic.';
        data.kicker = 'Reach Home Loans';
        data.cards.add(productionBoardCard('Production Board Last Month', LAST_MONTH_START, MONTH_START, true));
        data.cards.add(productionBoardCard('Production Board This Month', MONTH_START, NEXT_MONTH_START, false));
        data.cards.add(productionBoardCard('Production Board Next Month', NEXT_MONTH_START, NEXT_MONTH_START.addMonths(1), false));
        data.cards.add(card('Average Loan Size YTD', formatCurrency(averageLoanSize(YEAR_START, TODAY_DATE.addDays(1))), 'Funded files only'));

        data.sections.add(section('Nickley Group Lead Intelligence', '2026 YTD lead flow from The Nickley Group and Nickley ISA\'s, with monthly trend and top 15 referring Realtors.', nickleyGroupLeadRows()));
        data.sections.add(section('Reach Home Loans Roster', 'Active Salesforce users with current position and contact details.', activeUserRosterRows()));
        data.sections.add(section('Open Transaction Pipeline by Status', 'Current transaction pipeline by Salesforce status.', pipelineStageRows(8)));
    }

    private static void populateLeadPage(PageData data) {
        data.title = 'CEO Lead Intelligence';
        data.subtitle = 'Where leads are coming from, how they are moving, and what needs attention.';
        data.kicker = 'Lead Source and Funnel';
        data.cards.add(card(
            'Average New Leads per Month 2026',
            String.valueOf(averageLeadIntelligenceMonthlyLeadCount2026()),
            leadIntelligenceLastThreeMonthSummary2026(),
            reportUrl(reportIdByDeveloperName(LEAD_MONTHLY_AVERAGE_REPORT_DEVELOPER_NAME), null)
        ));
        data.cards.add(card(
            'Working Leads',
            String.valueOf(workingLeadCount(LEAD_INTELLIGENCE_START)),
            'Excludes Nurturing, Pre-Approval, 30+ Day Follow Up, and Credit Repair',
            reportUrl(reportIdByDeveloperName(LEAD_WORKING_REPORT_DEVELOPER_NAME), null)
        ));
        data.cards.add(stagnantLeadsCard());
        data.cards.add(card(
            'Pre-Approvals Issued Year to Date',
            String.valueOf(preApprovalsIssuedYtdCount()),
            'Pre-Approval Date in current year',
            reportUrl(reportIdByDeveloperName(LEAD_PRE_APPROVALS_YTD_REPORT_DEVELOPER_NAME), null)
        ));
        data.sections.add(section('Lead Source Performance', 'YTD volume by source with active and advanced funnel movement.', leadSourcePerformanceRows()));
        data.sections.add(section('Active Leads Status Funnel', 'Current lead counts and share by key stage.', leadFunnelRows()));
        data.sections.add(section('Current Active Leads Assigned by Loan Officer', 'Active lead ownership with status-stagnant counts and current 2026 pre-approvals.', activeLeadOwnershipRows()));
        data.sections.add(section('Consumer Webinar Performance by Date', 'Consumer Webinar leads grouped by webinar date with movement percentages.', consumerWebinarRows()));
    }

    private static void populateTransactionPage(PageData data) {
        data.title = 'CEO Transaction Intelligence';
        data.subtitle = 'What is in the pipe, where it is stuck, and what is funding.';
        data.kicker = 'Pipeline and Pull-Through';
        data.cards.add(card(
            'Funded MTD',
            formatCurrency(fundedVolume(MONTH_START, TODAY_DATE.addDays(1))),
            String.valueOf(fundedUnits(MONTH_START, TODAY_DATE.addDays(1))) + ' units',
            reportUrl(reportIdByDeveloperName(TRANSACTION_FUNDED_MTD_REPORT_DEVELOPER_NAME), null)
        ));
        data.cards.add(card(
            'Funded QTD',
            formatCurrency(fundedVolume(QUARTER_START, TODAY_DATE.addDays(1))),
            String.valueOf(fundedUnits(QUARTER_START, TODAY_DATE.addDays(1))) + ' units',
            reportUrl(reportIdByDeveloperName(TRANSACTION_FUNDED_QTD_REPORT_DEVELOPER_NAME), null)
        ));
        data.cards.add(card(
            'Funded YTD',
            formatCurrency(fundedVolume(YEAR_START, TODAY_DATE.addDays(1))),
            String.valueOf(fundedUnits(YEAR_START, TODAY_DATE.addDays(1))) + ' units',
            reportUrl(reportIdByDeveloperName(TRANSACTION_FUNDED_YTD_REPORT_DEVELOPER_NAME), null)
        ));
        data.cards.add(card(
            'Active Transaction Volume',
            formatCurrency(activeTransactionVolume()),
            String.valueOf(activeTransactionUnits()) + ' units',
            reportUrl(reportIdByDeveloperName(TRANSACTION_ACTIVE_VOLUME_REPORT_DEVELOPER_NAME), null)
        ));
        data.sections.add(section('Active Pipeline by Status', 'Current transaction counts and volume by status.', pipelineStageRows(20)));
        data.sections.add(section('Loan Type Mix', 'Funded YTD by loan type.', loanTypeRows()));
        data.sections.add(section('Purpose Mix', 'Funded YTD by loan purpose.', loanPurposeRows()));
    }

    private static void populateTrendPage(PageData data) {
        data.title = 'CEO Trends';
        data.subtitle = 'Momentum over time across funded volume, applications, leads, and mix.';
        data.kicker = 'Rolling View';
        data.cards.add(card('This Month', formatCurrency(fundedVolume(MONTH_START, NEXT_MONTH_START)), 'Funded volume'));
        data.cards.add(card('Last Month', formatCurrency(fundedVolume(MONTH_START.addMonths(-1), MONTH_START)), 'Funded volume'));
        data.cards.add(card('Next Month Pipeline', formatCurrency(closingVolume(NEXT_MONTH_START, NEXT_MONTH_START.addMonths(1))), 'Scheduled closing volume'));
        data.cards.add(card('Lead Volume YTD', String.valueOf(leadCount(YEAR_START, TODAY_DATE.addDays(1))), 'Created leads'));
        data.sections.add(section('Rolling 12-Month Funded Volume', 'Funded units and dollars by month.', rollingFundedRows()));
        data.sections.add(section('Lead Volume Trend', 'Lead creation counts by month.', rollingLeadRows()));
    }

    private static void populateLoanOfficerPage(PageData data) {
        data.title = 'Inside Loan Officers';
        data.subtitle = 'Daily LO review: lead funnel, funded production, follow-up effort, forecast, and data hygiene.';
        data.kicker = 'CEO Hub';

        List<LoanOfficerBook> books = loanOfficerDashboardBooks();
        List<LoanOfficerPerformance> monthMetrics = loanOfficerPerformance(books, MONTH_START, NEXT_MONTH_START, true);
        List<LoanOfficerPerformance> benchmarkMetrics = loanOfficerPerformance(books, Date.newInstance(2025, 1, 1), Date.newInstance(2026, 1, 1), false);
        List<LoanOfficerPerformance> yearToDateMetrics = loanOfficerPerformance(books, YEAR_START, TODAY_DATE.addDays(1), false);

        String leadPipelineUrl = reportUrlByDeveloperName(LO_LEAD_PIPELINE_REPORT_DEVELOPER_NAME, null);
        String fundedMtdUrl = reportUrlByDeveloperName(LO_PERSONAL_DEALS_MTD_REPORT_DEVELOPER_NAME, null);
        data.cards.add(card('Inside LOs', String.valueOf(books.size()), 'Named team members in this dashboard', leadPipelineUrl));
        data.cards.add(card('Funded MTD', formatCurrency(sumFundedVolume(monthMetrics)), String.valueOf(sumFundedUnits(monthMetrics)) + ' funded units', fundedMtdUrl));
        data.cards.add(card('Forecast Closes', String.valueOf(sumBlendedForecast(monthMetrics)), 'Where this month is pacing', leadPipelineUrl));
        data.cards.add(card('Data Gaps', String.valueOf(sumPreApprovalGaps(monthMetrics)), 'Transactions missing PA data', leadPipelineUrl));

        data.sections.add(section('Inside LO Realtor Referral Intelligence 2025', '2025 Biz Dev - Reach Realtor Referral lead distribution and conversion by inside loan officer.', loanOfficerReferralIntelligenceRows(benchmarkMetrics, '2025')));
        data.sections.add(section('Inside LO Realtor Referral Intelligence 2026', '2026 YTD Biz Dev - Reach Realtor Referral lead distribution and conversion by inside loan officer.', loanOfficerReferralIntelligenceRows(yearToDateMetrics, '2026 YTD')));
        data.sections.add(section('2025 Baseline', 'Full-year 2025 lead-funnel validation. Reported rates match the known-good checks; adjusted rates also credit recovered cancelled deals.', loanOfficerBenchmarkRows(benchmarkMetrics)));
        data.sections.add(section('Recent Lead Months', 'Leads created in each recent month and what happened after: pre-approval, transaction, close, active pipeline, and forecast.', loanOfficerRollingCohortRows(books, benchmarkMetrics)));
        data.sections.add(section('Activity', 'Funded production, outbound calls, and current pre-approvals that may need follow-up.', loanOfficerActivityRows(monthMetrics)));
        data.sections.add(section('Data Fixes', 'Records that can make the funnel look worse or point credit to the wrong place until fixed.', loanOfficerDataHygieneRows(monthMetrics, benchmarkMetrics)));
    }

    private static void populateRealtorPage(PageData data) {
        data.title = 'CEO Realtor Partner Intelligence';
        data.subtitle = 'Which realtor relationships are producing leads and where referral momentum is building.';
        data.kicker = 'Referral Partners';
        data.cards.add(card('Realtor Referral Leads YTD', String.valueOf(realtorReferralLeadCount()), 'Lead Source = Realtor Referral'));
        data.cards.add(card('Top Partners', String.valueOf(realtorPartnerRows().size()), 'Displayed by current-year lead volume'));
        data.cards.add(card('Active Realtor Leads', String.valueOf(activeRealtorLeadCount()), 'Open non-nurture realtor leads'));
        data.cards.add(card('Under Contract', String.valueOf(realtorLeadStatusCount('Under Contract')), 'Current lead status'));
        data.sections.add(section('Top Referring Agents', 'Referral volume by buying agent and assigned owner.', realtorPartnerRows()));
    }

    private static void populateFalloutPage(PageData data) {
        data.title = 'CEO Fallout & Lost Business';
        data.subtitle = 'Withdrawn, denied, cancelled, and lost business indicators.';
        data.kicker = 'Leakage Intelligence';
        data.cards.add(card('Cancelled YTD', String.valueOf(transactionStatusCount('Cancelled', YEAR_START)), 'Transactions moved to cancelled'));
        data.cards.add(card('Lost YTD', String.valueOf(transactionStatusCount('Lost', YEAR_START)), 'Legacy lost status'));
        data.cards.add(card('Denied Leads YTD', String.valueOf(leadStatusCount('Denied', YEAR_START)), 'Current lead status'));
        data.cards.add(card('Withdrawn Leads YTD', String.valueOf(leadStatusCount('Withdrawn', YEAR_START)), 'Current lead status'));
        data.sections.add(section('Transaction Fallout by Status', 'Current cancelled/lost/review leakage counts.', falloutTransactionRows()));
        data.sections.add(section('Lead Fallout by Status', 'Current lead fallout counts.', falloutLeadRows()));
    }

    private static void populateOperationsPage(PageData data) {
        data.title = 'CEO Operational Health';
        data.subtitle = 'Bottlenecks, aging files, and pipeline work needing leadership visibility.';
        data.kicker = 'Operational Watchlist';
        data.cards.add(card('Past Closing Date', String.valueOf(pastClosingDateCount()), 'Active files with closing dates before today'));
        data.cards.add(card('Conditionally Approved', String.valueOf(transactionStatusCount('Conditionally Approved', null)), 'Current status count'));
        data.cards.add(card('Closing/Funding', String.valueOf(closingFundingCount()), 'Files in closing or funding'));
        data.cards.add(card('Processing', String.valueOf(transactionStatusCount('Processing', null)), 'Current status count'));
        data.sections.add(section('Stage Bottlenecks', 'Current active files by operational stage.', pipelineStageRows(20)));
        data.sections.add(section('Past-Due Closing Dates', 'Active files with closing dates before today.', pastDueClosingRows()));
    }

    private static Section topicSection(String title, String subtitle, List<NavItem> navItems) {
        Section s = new Section(title, subtitle);
        s.columns = new List<String>{ 'Topic', 'Purpose', 'Open' };
        Map<String, String> descriptions = new Map<String, String>{
            'hub' => 'Navigation and executive summary snapshot.',
            'leads' => 'Lead sources, funnel movement, aging, and assignment.',
            'transactions' => 'Pipeline, funded volume, mix, and pull-through indicators.',
            'trends' => 'Monthly volume and momentum over time.',
            'loanofficers' => 'Production and pipeline performance by LO.',
            'realtors' => 'Referral partner production and activity.',
            'fallout' => 'Lost, withdrawn, denied, and cancelled business.',
            'operations' => 'Files stuck in stages and items needing attention.'
        };
        for (NavItem item : navItems) {
            s.rows.add(new DataRow(s.columns, new List<String>{ item.label, descriptions.get(item.key), item.tabApiName }, item.tabApiName));
        }
        return s;
    }

    private static List<DataRow> activeUserRosterRows() {
        List<DataRow> rows = new List<DataRow>();
        List<String> columns = new List<String>{ 'Team Member', 'Position', 'Department', 'Phone', 'Mobile', 'Email' };

        for (User userRecord : [
            SELECT Name, Title, Phone, MobilePhone, Email, Department, UserRole.Name
            FROM User
            WHERE IsActive = true
            AND (UserType = 'Standard' OR Name IN :ROSTER_OUTSIDE_LO_USERS)
            AND Name NOT IN :ROSTER_EXCLUDED_USERS
            ORDER BY Name
            LIMIT 200
        ]) {
            rows.add(row(columns, new List<String>{
                stringValue(userRecord.Name, 'Unassigned'),
                userPosition(userRecord),
                userDepartment(userRecord),
                stringValue(userRecord.Phone, 'Not listed'),
                stringValue(userRecord.MobilePhone, 'Not listed'),
                stringValue(userRecord.Email, 'Not listed')
            }));
        }

        return rows;
    }

    private static String userPosition(User userRecord) {
        if (userRecord.Name == 'Adam Stephens') {
            return 'CEO';
        }
        if (userRecord.Name == 'Angelina Noble') {
            return 'Processing Team Lead';
        }
        if (userRecord.Name == 'Bianca Rodrigues') {
            return 'Administrative Director';
        }
        if (userRecord.Name == 'Joey D\'Alessandro') {
            return 'Loan Officer Assistant';
        }
        if (userRecord.Name == 'Zenen Chamizo') {
            return 'VP InIT';
        }
        if (ROSTER_OUTSIDE_LO_USERS.contains(userRecord.Name)) {
            return 'Outside Loan Officer';
        }
        if (!String.isBlank(userRecord.Title)) {
            return userRecord.Title;
        }
        if (userRecord.UserRole != null && !String.isBlank(userRecord.UserRole.Name)) {
            return userRecord.UserRole.Name;
        }
        return 'Team Member';
    }

    private static String userDepartment(User userRecord) {
        String position = userPosition(userRecord);
        if (position == 'Loan Officer' || position == 'Outside Loan Officer' || ROSTER_SALES_USERS.contains(userRecord.Name)) {
            return 'Sales';
        }
        if (ROSTER_OPERATIONS_USERS.contains(userRecord.Name)) {
            return 'Operations';
        }
        String department = stringValue(userRecord.Department, 'Operations');
        return department == 'Team Member' ? 'Operations' : department;
    }

    private static String transactionStatusDisplayLabel(String statusValue) {
        return statusValue == 'Open' ? 'Submission Form Complete' : statusValue;
    }

    private static Section section(String title, String subtitle, List<DataRow> rows) {
        Section s = new Section(title, subtitle);
        s.rows = rows == null ? new List<DataRow>() : rows;
        if (!s.rows.isEmpty()) {
            s.columns = s.rows[0].columns;
        }
        return s;
    }

    private static MetricCard card(String label, String value, String helper) {
        return card(label, value, helper, null);
    }

    private static MetricCard card(String label, String value, String helper, String urlPath) {
        MetricCard c = new MetricCard();
        c.label = label;
        c.value = value;
        c.helper = helper;
        c.urlPath = urlPath;
        return c;
    }

    private static MetricCard productionBoardCard(String label, Date startDate, Date endDate, Boolean fundedStatusesOnly) {
        Integer units = productionBoardUnits(startDate, endDate, fundedStatusesOnly);
        Decimal volume = productionBoardVolume(startDate, endDate, fundedStatusesOnly);
        return card(label, String.valueOf(units) + ' units', formatCurrency(volume) + ' total loan amount');
    }

    private static MetricCard stagnantLeadsCard() {
        StagnantLeadCounts counts = stagnantLeadCounts();
        MetricCard c = card(
            'Stagnant Leads',
            String.valueOf(counts.sevenDays),
            'Active leads in the same status',
            reportUrl(reportIdByDeveloperName(LEAD_STAGNANT_7_REPORT_DEVELOPER_NAME), null)
        );
        c.breakdown.add(metricBreakdown(
            '7+ Days',
            String.valueOf(counts.sevenDays),
            reportUrl(reportIdByDeveloperName(LEAD_STAGNANT_7_REPORT_DEVELOPER_NAME), null)
        ));
        c.breakdown.add(metricBreakdown(
            '14+ Days',
            String.valueOf(counts.fourteenDays),
            reportUrl(reportIdByDeveloperName(LEAD_STAGNANT_14_REPORT_DEVELOPER_NAME), null)
        ));
        c.breakdown.add(metricBreakdown(
            '21+ Days',
            String.valueOf(counts.twentyOneDays),
            reportUrl(reportIdByDeveloperName(LEAD_STAGNANT_21_REPORT_DEVELOPER_NAME), null)
        ));
        return c;
    }

    private static MetricBreakdown metricBreakdown(String label, String value, String urlPath) {
        MetricBreakdown item = new MetricBreakdown();
        item.label = label;
        item.value = value;
        item.urlPath = urlPath;
        return item;
    }

    private static List<DataRow> leadSourceRows() {
        List<DataRow> rows = new List<DataRow>();
        for (AggregateResult result : [
            SELECT LeadSource sourceName, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :LEAD_INTELLIGENCE_START
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            GROUP BY LeadSource
            ORDER BY COUNT(Id) DESC
            LIMIT 10
        ]) {
            rows.add(row(new List<String>{ 'Lead Source', 'Count' }, new List<String>{ stringValue(result.get('sourceName'), 'Unspecified'), String.valueOf(result.get('recordCount')) }));
        }
        return rows;
    }

    private static List<DataRow> leadSourcePerformanceRows() {
        List<DataRow> rows = new List<DataRow>();
        List<String> topSources = new List<String>();
        Map<String, Integer> totalBySource = new Map<String, Integer>();
        Map<String, Integer> ytdBySource = new Map<String, Integer>();
        Map<String, Integer> lastMonthBySource = new Map<String, Integer>();
        Map<String, Integer> thisMonthBySource = new Map<String, Integer>();
        Map<String, Integer> nurturingBySource = new Map<String, Integer>();
        Map<String, Integer> currentPreApprovalBySource = new Map<String, Integer>();
        Map<String, Integer> convertedTransactionBySource = new Map<String, Integer>();
        Map<String, Integer> closedTransactionBySource = new Map<String, Integer>();
        Integer allLeadCount = leadIntelligenceLeadCount();
        Integer ytdLeadCount = leadIntelligenceLeadCount(YEAR_START);
        String reportId = reportIdByDeveloperName(LEAD_SOURCE_REPORT_DEVELOPER_NAME);

        for (AggregateResult result : [
            SELECT LeadSource sourceName, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :LEAD_INTELLIGENCE_START
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            GROUP BY LeadSource
            ORDER BY COUNT(Id) DESC
            LIMIT 12
        ]) {
            String sourceName = stringValue(result.get('sourceName'), 'Unspecified');
            topSources.add(sourceName);
            totalBySource.put(sourceName, (Integer) result.get('recordCount'));
        }

        if (topSources.isEmpty()) {
            return rows;
        }

        for (AggregateResult result : [
            SELECT LeadSource sourceName, Status statusValue, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :LEAD_INTELLIGENCE_START
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND LeadSource IN :topSources
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            GROUP BY LeadSource, Status
        ]) {
            String sourceName = stringValue(result.get('sourceName'), 'Unspecified');
            String statusValue = stringValue(result.get('statusValue'), 'Unspecified');
            Integer countValue = (Integer) result.get('recordCount');

            if (statusValue == 'Nurturing' || statusValue == 'Nurture - Preapproval') {
                nurturingBySource.put(sourceName, intValue(nurturingBySource.get(sourceName)) + countValue);
            } else if (statusValue == 'Pre-Approval') {
                currentPreApprovalBySource.put(sourceName, intValue(currentPreApprovalBySource.get(sourceName)) + countValue);
            }
        }

        for (AggregateResult result : [
            SELECT LeadSource sourceName, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :YEAR_START
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND LeadSource IN :topSources
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            GROUP BY LeadSource
        ]) {
            ytdBySource.put(stringValue(result.get('sourceName'), 'Unspecified'), (Integer) result.get('recordCount'));
        }

        for (AggregateResult result : [
            SELECT LeadSource sourceName, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :LAST_MONTH_START
            AND CreatedDate < :MONTH_START
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND LeadSource IN :topSources
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            GROUP BY LeadSource
        ]) {
            lastMonthBySource.put(stringValue(result.get('sourceName'), 'Unspecified'), (Integer) result.get('recordCount'));
        }

        for (AggregateResult result : [
            SELECT LeadSource sourceName, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :MONTH_START
            AND CreatedDate < :NEXT_MONTH_START
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND LeadSource IN :topSources
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            GROUP BY LeadSource
        ]) {
            thisMonthBySource.put(stringValue(result.get('sourceName'), 'Unspecified'), (Integer) result.get('recordCount'));
        }

        for (AggregateResult result : [
            SELECT LeadSource sourceName, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :LEAD_INTELLIGENCE_START
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND LeadSource IN :topSources
            AND Converted_Transaction_ID__c != null
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            GROUP BY LeadSource
        ]) {
            convertedTransactionBySource.put(stringValue(result.get('sourceName'), 'Unspecified'), (Integer) result.get('recordCount'));
        }

        for (AggregateResult result : [
            SELECT LeadSource sourceName, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :LEAD_INTELLIGENCE_START
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND LeadSource IN :topSources
            AND Converted_Transaction_ID__c != null
            AND Converted_Transaction_ID__r.Status__c = 'Post-Closed'
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            GROUP BY LeadSource
        ]) {
            closedTransactionBySource.put(stringValue(result.get('sourceName'), 'Unspecified'), (Integer) result.get('recordCount'));
        }

        for (String sourceName : topSources) {
            Integer total = intValue(totalBySource.get(sourceName));
            Integer ytd = intValue(ytdBySource.get(sourceName));
            Integer nurturing = intValue(nurturingBySource.get(sourceName));
            Integer preApprovalOrBeyond = intValue(currentPreApprovalBySource.get(sourceName)) + intValue(convertedTransactionBySource.get(sourceName));
            Integer closedTransactions = intValue(closedTransactionBySource.get(sourceName));
            Integer lastMonth = intValue(lastMonthBySource.get(sourceName));
            Integer thisMonth = intValue(thisMonthBySource.get(sourceName));
            rows.add(row(
                new List<String>{ 'Lead Source', 'Since 2025', '% of Since 2025', 'YTD', '% of YTD', 'Last Month', 'This Month', 'MoM Trend', 'Nurturing %', 'Reached Pre-Approval %', 'Closed Transaction %' },
                new List<String>{
                    sourceName,
                    String.valueOf(total),
                    percentValue(total, allLeadCount),
                    String.valueOf(ytd),
                    percentValue(ytd, ytdLeadCount),
                    String.valueOf(lastMonth),
                    String.valueOf(thisMonth),
                    monthOverMonthTrend(thisMonth, lastMonth),
                    percentValue(nurturing, total),
                    percentValue(preApprovalOrBeyond, total),
                    percentValue(closedTransactions, total)
                },
                null,
                reportUrl(reportId, sourceName)
            ));
        }
        return rows;
    }

    private static List<DataRow> nickleyGroupLeadRows() {
        List<DataRow> rows = new List<DataRow>();
        List<String> columns = new List<String>{ 'Nickley View', 'Leads', 'MoM Trend', '% of Reach Leads', 'Detail' };
        String nickleyReportUrl = reportUrl(reportIdByDeveloperName(NICKLEY_GROUP_LEADS_REPORT_DEVELOPER_NAME), null);
        Integer totalNickleyLeads = nickleyLeadCount(YEAR_START, TODAY_DATE.addDays(1));
        Integer totalLeadsYtd = [
            SELECT COUNT()
            FROM Lead
            WHERE CreatedDate >= :YEAR_START
        ];

        rows.add(row(
            columns,
            new List<String>{
                'Nickley Group YTD',
                String.valueOf(totalNickleyLeads),
                '2026 YTD',
                percentValue(totalNickleyLeads, totalLeadsYtd),
                'The Nickley Group + Nickley ISA\'s'
            },
            null,
            null,
            repeatedUrl(nickleyReportUrl, columns.size())
        ));

        Date trendStart = MONTH_START.addMonths(-5);
        Map<String, Integer> nickleyMonthlyCounts = new Map<String, Integer>();
        for (AggregateResult result : [
            SELECT CALENDAR_YEAR(CreatedDate) yearValue, CALENDAR_MONTH(CreatedDate) monthValue, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :trendStart
            AND CreatedDate < :NEXT_MONTH_START
            AND Realtor_Group_New__c IN :NICKLEY_REALTOR_GROUPS
            GROUP BY CALENDAR_YEAR(CreatedDate), CALENDAR_MONTH(CreatedDate)
        ]) {
            nickleyMonthlyCounts.put(monthKey((Integer) result.get('yearValue'), (Integer) result.get('monthValue')), (Integer) result.get('recordCount'));
        }

        Map<String, Integer> allMonthlyCounts = new Map<String, Integer>();
        for (AggregateResult result : [
            SELECT CALENDAR_YEAR(CreatedDate) yearValue, CALENDAR_MONTH(CreatedDate) monthValue, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :trendStart
            AND CreatedDate < :NEXT_MONTH_START
            GROUP BY CALENDAR_YEAR(CreatedDate), CALENDAR_MONTH(CreatedDate)
        ]) {
            allMonthlyCounts.put(monthKey((Integer) result.get('yearValue'), (Integer) result.get('monthValue')), (Integer) result.get('recordCount'));
        }

        Integer previousNickleyCount;
        for (Integer monthOffset = 0; monthOffset < 6; monthOffset++) {
            Date monthDate = trendStart.addMonths(monthOffset);
            String monthKey = monthKey(monthDate.year(), monthDate.month());
            Integer nickleyMonthCount = intValue(nickleyMonthlyCounts.get(monthKey));
            Integer allMonthCount = intValue(allMonthlyCounts.get(monthKey));
            rows.add(row(
                columns,
                new List<String>{
                    shortMonthLabel(monthDate.month()) + ' ' + String.valueOf(monthDate.year()),
                    String.valueOf(nickleyMonthCount),
                    previousNickleyCount == null ? 'Baseline month' : monthOverMonthTrend(nickleyMonthCount, previousNickleyCount),
                    percentValue(nickleyMonthCount, allMonthCount),
                    monthDate == MONTH_START ? 'Current month to date' : 'Completed month'
                },
                null,
                null,
                repeatedUrl(nickleyReportUrl, columns.size())
            ));
            previousNickleyCount = nickleyMonthCount;
        }

        List<AggregateResult> topAgentResults = [
            SELECT Realtor_Buying_Agent__c agentId, Realtor_Buying_Agent__r.Name agentName, COUNT(Id) recordCount, MAX(CreatedDate) lastReferral
            FROM Lead
            WHERE CreatedDate >= :YEAR_START
            AND Realtor_Group_New__c IN :NICKLEY_REALTOR_GROUPS
            AND Realtor_Buying_Agent__c != null
            GROUP BY Realtor_Buying_Agent__c, Realtor_Buying_Agent__r.Name
            ORDER BY COUNT(Id) DESC
            LIMIT 15
        ];

        Set<Id> topAgentIds = new Set<Id>();
        for (AggregateResult result : topAgentResults) {
            Id agentId = (Id) result.get('agentId');
            if (agentId != null) {
                topAgentIds.add(agentId);
            }
        }

        Map<Id, Lead> latestLeadByAgentId = new Map<Id, Lead>();
        if (!topAgentIds.isEmpty()) {
            for (Lead leadRecord : [
                SELECT Id, CreatedDate, Realtor_Buying_Agent__c, Owner.Name
                FROM Lead
                WHERE CreatedDate >= :YEAR_START
                AND Realtor_Group_New__c IN :NICKLEY_REALTOR_GROUPS
                AND Realtor_Buying_Agent__c IN :topAgentIds
                ORDER BY CreatedDate DESC
            ]) {
                if (!latestLeadByAgentId.containsKey(leadRecord.Realtor_Buying_Agent__c)) {
                    latestLeadByAgentId.put(leadRecord.Realtor_Buying_Agent__c, leadRecord);
                }
            }
        }

        for (AggregateResult result : topAgentResults) {
            Id agentId = (Id) result.get('agentId');
            Integer referralCount = (Integer) result.get('recordCount');
            Datetime lastReferral = (Datetime) result.get('lastReferral');
            Lead latestLead = latestLeadByAgentId.get(agentId);
            String latestOwnerName = latestLead == null || latestLead.Owner == null ? 'Unassigned' : latestLead.Owner.Name;
            rows.add(row(
                columns,
                new List<String>{
                    stringValue(result.get('agentName'), 'Unspecified Realtor'),
                    String.valueOf(referralCount),
                    '',
                    percentValue(referralCount, totalLeadsYtd),
                    'Latest LO: ' + latestOwnerName + ' | Last referral: ' + (lastReferral == null ? 'Not available' : monthDayYearLabel(lastReferral.date()))
                },
                null,
                null,
                repeatedUrl(nickleyReportUrl, columns.size())
            ));
        }

        return rows;
    }

    private static Integer nickleyLeadCount(Date startDate, Date endDate) {
        return [
            SELECT COUNT()
            FROM Lead
            WHERE CreatedDate >= :startDate
            AND CreatedDate < :endDate
            AND Realtor_Group_New__c IN :NICKLEY_REALTOR_GROUPS
        ];
    }

    private static String monthOverMonthTrend(Integer currentCount, Integer previousCount) {
        Integer currentValue = intValue(currentCount);
        Integer previousValue = intValue(previousCount);
        Integer delta = currentValue - previousValue;
        String deltaPrefix = delta > 0 ? '+' : '';
        if (previousValue == 0) {
            return deltaPrefix + String.valueOf(delta);
        }
        Decimal ratio = (Decimal.valueOf(delta) / Decimal.valueOf(previousValue)) * 100;
        return deltaPrefix + String.valueOf(delta) + ' (' + String.valueOf(ratio.setScale(1)) + '%)';
    }

    private static List<DataRow> leadFunnelRows() {
        List<DataRow> rows = new List<DataRow>();
        List<String> statuses = ACTIVE_LEAD_FUNNEL_STATUSES;
        Map<String, Integer> counts = leadCountsByStatus(statuses, LEAD_INTELLIGENCE_START);
        String reportId = reportIdByDeveloperName(LEAD_FUNNEL_REPORT_DEVELOPER_NAME);
        Integer total = 0;
        for (String statusValue : statuses) {
            total += counts.containsKey(statusValue) ? counts.get(statusValue) : 0;
        }
        for (String statusValue : statuses) {
            Integer countValue = counts.containsKey(statusValue) ? counts.get(statusValue) : 0;
            rows.add(row(
                new List<String>{ 'Stage', 'Count', 'Share' },
                new List<String>{ statusValue, String.valueOf(countValue), percentValue(countValue, total) },
                null,
                reportUrl(reportId, statusValue)
            ));
        }
        return rows;
    }

    private static List<DataRow> staleLeadRows() {
        return new List<DataRow>{
            row(new List<String>{ 'Aging Bucket', 'Count' }, new List<String>{ '> 7 days untouched', String.valueOf(staleLeadCount(7, LEAD_INTELLIGENCE_START)) }),
            row(new List<String>{ 'Aging Bucket', 'Count' }, new List<String>{ '> 14 days untouched', String.valueOf(staleLeadCount(14, LEAD_INTELLIGENCE_START)) }),
            row(new List<String>{ 'Aging Bucket', 'Count' }, new List<String>{ '> 30 days untouched', String.valueOf(staleLeadCount(30, LEAD_INTELLIGENCE_START)) })
        };
    }

    private static List<DataRow> consumerWebinarRows() {
        List<DataRow> rows = new List<DataRow>();
        List<Date> webinarDates = new List<Date>();
        Map<Date, Integer> totalByDate = new Map<Date, Integer>();
        Map<Date, Integer> nurtureByDate = new Map<Date, Integer>();
        Map<Date, Integer> preApprovalByDate = new Map<Date, Integer>();
        Map<Date, Integer> activeByDate = new Map<Date, Integer>();
        Map<Date, Integer> transactionByDate = new Map<Date, Integer>();
        String reportId = reportIdByDeveloperName(LEAD_WEBINAR_BY_DATE_REPORT_DEVELOPER_NAME);

        List<String> activeStatuses = new List<String>(ACTIVE_LEAD_FUNNEL_STATUSES);
        Integer preApprovalIndex = activeStatuses.indexOf('Pre-Approval');
        if (preApprovalIndex >= 0) {
            activeStatuses.remove(preApprovalIndex);
        }

        for (AggregateResult result : [
            SELECT Webinar_Date__c webinarDate, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :LEAD_INTELLIGENCE_START
            AND LeadSource = 'Consumer Webinar'
            AND Webinar_Date__c != null
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            GROUP BY Webinar_Date__c
            ORDER BY Webinar_Date__c DESC
            LIMIT 25
        ]) {
            Date webinarDate = (Date) result.get('webinarDate');
            webinarDates.add(webinarDate);
            totalByDate.put(webinarDate, (Integer) result.get('recordCount'));
        }

        if (webinarDates.isEmpty()) {
            return rows;
        }

        for (AggregateResult result : [
            SELECT Webinar_Date__c webinarDate, Status statusValue, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :LEAD_INTELLIGENCE_START
            AND LeadSource = 'Consumer Webinar'
            AND Webinar_Date__c IN :webinarDates
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            GROUP BY Webinar_Date__c, Status
        ]) {
            Date webinarDate = (Date) result.get('webinarDate');
            String statusValue = stringValue(result.get('statusValue'), 'Unspecified');
            Integer countValue = (Integer) result.get('recordCount');

            if (statusValue == 'Nurturing' || statusValue == 'Nurture - Preapproval') {
                nurtureByDate.put(webinarDate, intValue(nurtureByDate.get(webinarDate)) + countValue);
            }
            if (statusValue == 'Pre-Approval') {
                preApprovalByDate.put(webinarDate, intValue(preApprovalByDate.get(webinarDate)) + countValue);
            }
            if (activeStatuses.contains(statusValue)) {
                activeByDate.put(webinarDate, intValue(activeByDate.get(webinarDate)) + countValue);
            }
        }

        for (AggregateResult result : [
            SELECT Webinar_Date__c webinarDate, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :LEAD_INTELLIGENCE_START
            AND LeadSource = 'Consumer Webinar'
            AND Webinar_Date__c IN :webinarDates
            AND Converted_Transaction_ID__c != null
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            GROUP BY Webinar_Date__c
        ]) {
            transactionByDate.put((Date) result.get('webinarDate'), (Integer) result.get('recordCount'));
        }

        for (Date webinarDate : webinarDates) {
            Integer total = intValue(totalByDate.get(webinarDate));
            rows.add(row(
                new List<String>{ 'Webinar Date', 'Leads', 'Nurture %', 'Pre-Approval %', 'Active %', 'Transaction %' },
                new List<String>{
                    monthDayYearLabel(webinarDate),
                    String.valueOf(total),
                    percentValue(intValue(nurtureByDate.get(webinarDate)), total),
                    percentValue(intValue(preApprovalByDate.get(webinarDate)), total),
                    percentValue(intValue(activeByDate.get(webinarDate)), total),
                    percentValue(intValue(transactionByDate.get(webinarDate)), total)
                },
                null,
                reportUrl(reportId, monthDayYearLabel(webinarDate))
            ));
        }
        return rows;
    }

    private static List<DataRow> leadOwnerRows() {
        List<DataRow> rows = new List<DataRow>();
        for (AggregateResult result : [
            SELECT Owner.Name ownerName, COUNT(Id) recordCount
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate >= :LEAD_INTELLIGENCE_START
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            GROUP BY Owner.Name
            ORDER BY COUNT(Id) DESC
            LIMIT 15
        ]) {
            rows.add(row(new List<String>{ 'Owner', 'Open Leads' }, new List<String>{ stringValue(result.get('ownerName'), 'Unassigned'), String.valueOf(result.get('recordCount')) }));
        }
        return rows;
    }

    private static List<DataRow> activeLeadOwnershipRows() {
        List<DataRow> rows = new List<DataRow>();
        List<String> ownerOrder = new List<String>();
        Map<String, Integer> activeByOwner = new Map<String, Integer>();
        Map<String, StagnantLeadCounts> stagnantByOwner = stagnantLeadCountsByOwner();
        Map<String, Integer> currentPreApproval2026ByOwner = new Map<String, Integer>();
        Date tomorrow = TODAY_DATE.addDays(1);
        String activeReportId = reportIdByDeveloperName(LEAD_LO_ACTIVE_REPORT_DEVELOPER_NAME);
        String stagnant7ReportId = reportIdByDeveloperName(LEAD_LO_STAGNANT_7_REPORT_DEVELOPER_NAME);
        String stagnant14ReportId = reportIdByDeveloperName(LEAD_LO_STAGNANT_14_REPORT_DEVELOPER_NAME);
        String stagnant21ReportId = reportIdByDeveloperName(LEAD_LO_STAGNANT_21_REPORT_DEVELOPER_NAME);
        String preApprovalReportId = reportIdByDeveloperName(LEAD_LO_PRE_APPROVAL_2026_REPORT_DEVELOPER_NAME);

        List<String> activeStatuses = new List<String>(ACTIVE_LEAD_FUNNEL_STATUSES);
        Integer preApprovalIndex = activeStatuses.indexOf('Pre-Approval');
        if (preApprovalIndex >= 0) {
            activeStatuses.remove(preApprovalIndex);
        }

        for (AggregateResult result : [
            SELECT Owner.Name ownerName, COUNT(Id) recordCount
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate >= :LEAD_INTELLIGENCE_START
            AND Status IN :activeStatuses
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            GROUP BY Owner.Name
            ORDER BY COUNT(Id) DESC
        ]) {
            String ownerName = stringValue(result.get('ownerName'), 'Unassigned');
            ownerOrder.add(ownerName);
            activeByOwner.put(ownerName, (Integer) result.get('recordCount'));
        }

        for (AggregateResult result : [
            SELECT Owner.Name ownerName, COUNT(Id) recordCount
            FROM Lead
            WHERE IsConverted = false
            AND Status = 'Pre-Approval'
            AND Pre_Approval_Date__c >= :YEAR_START
            AND Pre_Approval_Date__c < :tomorrow
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            GROUP BY Owner.Name
        ]) {
            currentPreApproval2026ByOwner.put(stringValue(result.get('ownerName'), 'Unassigned'), (Integer) result.get('recordCount'));
        }

        for (String ownerName : ownerOrder) {
            StagnantLeadCounts stagnantCounts = stagnantByOwner.containsKey(ownerName) ? stagnantByOwner.get(ownerName) : new StagnantLeadCounts();
            Integer preApprovalCount = intValue(currentPreApproval2026ByOwner.get(ownerName));
            rows.add(row(
                new List<String>{ 'Loan Officer', 'Active Leads', 'Stagnant 7+ Days', 'Stagnant 14+ Days', 'Stagnant 21+ Days', 'Current Pre-Approvals 2026' },
                new List<String>{
                    ownerName,
                    String.valueOf(activeByOwner.get(ownerName)),
                    String.valueOf(stagnantCounts.sevenDays),
                    String.valueOf(stagnantCounts.fourteenDays),
                    String.valueOf(stagnantCounts.twentyOneDays),
                    String.valueOf(preApprovalCount)
                },
                null,
                null,
                new List<String>{
                    reportUrl(activeReportId, ownerName),
                    reportUrl(activeReportId, ownerName),
                    reportUrl(stagnant7ReportId, ownerName),
                    reportUrl(stagnant14ReportId, ownerName),
                    reportUrl(stagnant21ReportId, ownerName),
                    reportUrl(preApprovalReportId, ownerName)
                }
            ));
        }
        return rows;
    }

    private static List<DataRow> pipelineStageRows(Integer rowLimit) {
        List<DataRow> rows = new List<DataRow>();
        String reportId = reportIdByDeveloperName(TRANSACTION_ACTIVE_STATUS_REPORT_DEVELOPER_NAME);

        Map<String, Decimal> averageDaysByStatus = new Map<String, Decimal>();
        for (AggregateResult result : [
            SELECT Status__c statusValue, AVG(Days_In_Current_Status__c) averageDays
            FROM Transaction__c
            WHERE CreatedDate >= 2024-01-01T00:00:00Z
            AND Status__c NOT IN :ACTIVE_TRANSACTION_EXCLUDES
            AND (New_Build_Bank_Owned__c = false OR New_Build_Bank_Owned__c = null)
            AND Id NOT IN :STATUS_AGE_OUTLIER_TRANSACTION_IDS
            AND (Closing_Date__c = null OR Closing_Date__c <= :STATUS_AGE_CLOSING_CUTOFF)
            GROUP BY Status__c
        ]) {
            averageDaysByStatus.put(stringValue(result.get('statusValue'), 'Unspecified'), (Decimal) result.get('averageDays'));
        }

        for (AggregateResult result : [
            SELECT Status__c statusValue, COUNT(Id) recordCount, SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE CreatedDate >= 2024-01-01T00:00:00Z
            AND Status__c NOT IN :ACTIVE_TRANSACTION_EXCLUDES
            GROUP BY Status__c
            ORDER BY COUNT(Id) DESC
            LIMIT :rowLimit
        ]) {
            String statusValue = stringValue(result.get('statusValue'), 'Unspecified');
            rows.add(row(
                new List<String>{ 'Status', 'Files', 'Volume', 'Avg Days in Status' },
                new List<String>{
                    transactionStatusDisplayLabel(statusValue),
                    String.valueOf(result.get('recordCount')),
                    formatCurrency((Decimal) result.get('volume')),
                    formatDecimal(averageDaysByStatus.get(statusValue))
                },
                null,
                reportUrl(reportId, statusValue)
            ));
        }
        return rows;
    }

    private static List<DataRow> loanTypeRows() {
        List<DataRow> rows = new List<DataRow>();
        for (AggregateResult result : [
            SELECT Loan_Type_1st_TD__c typeValue, COUNT(Id) recordCount, SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE Status__c IN :FUNDED_STATUSES
            AND Funding_Date__c >= :YEAR_START
            GROUP BY Loan_Type_1st_TD__c
            ORDER BY SUM(Loan_Amount_1st__c) DESC
        ]) {
            rows.add(row(new List<String>{ 'Loan Type', 'Units', 'Volume' }, new List<String>{ stringValue(result.get('typeValue'), 'Unspecified'), String.valueOf(result.get('recordCount')), formatCurrency((Decimal) result.get('volume')) }));
        }
        return rows;
    }

    private static List<DataRow> loanPurposeRows() {
        List<DataRow> rows = new List<DataRow>();
        for (AggregateResult result : [
            SELECT Loan_Purpose__c purposeValue, COUNT(Id) recordCount, SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE Status__c IN :FUNDED_STATUSES
            AND Funding_Date__c >= :YEAR_START
            GROUP BY Loan_Purpose__c
            ORDER BY SUM(Loan_Amount_1st__c) DESC
        ]) {
            rows.add(row(new List<String>{ 'Purpose', 'Units', 'Volume' }, new List<String>{ stringValue(result.get('purposeValue'), 'Unspecified'), String.valueOf(result.get('recordCount')), formatCurrency((Decimal) result.get('volume')) }));
        }
        return rows;
    }

    private static List<DataRow> rollingFundedRows() {
        List<DataRow> rows = new List<DataRow>();
        for (Integer i = 11; i >= 0; i--) {
            Date startDate = MONTH_START.addMonths(-i);
            Date endDate = startDate.addMonths(1);
            rows.add(row(new List<String>{ 'Month', 'Units', 'Volume' }, new List<String>{ monthLabel(startDate), String.valueOf(fundedUnits(startDate, endDate)), formatCurrency(fundedVolume(startDate, endDate)) }));
        }
        return rows;
    }

    private static List<DataRow> rollingLeadRows() {
        List<DataRow> rows = new List<DataRow>();
        for (Integer i = 11; i >= 0; i--) {
            Date startDate = MONTH_START.addMonths(-i);
            Date endDate = startDate.addMonths(1);
            rows.add(row(new List<String>{ 'Month', 'Created Leads' }, new List<String>{ monthLabel(startDate), String.valueOf(leadCount(startDate, endDate)) }));
        }
        return rows;
    }

    private static List<DataRow> loanOfficerFundedRows() {
        List<DataRow> rows = new List<DataRow>();
        for (AggregateResult result : [
            SELECT Loan_Officer__r.Name loName, COUNT(Id) recordCount, SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE Status__c IN :FUNDED_STATUSES
            AND Funding_Date__c >= :YEAR_START
            GROUP BY Loan_Officer__r.Name
            ORDER BY SUM(Loan_Amount_1st__c) DESC
            LIMIT 25
        ]) {
            rows.add(row(new List<String>{ 'Loan Officer', 'Units', 'Volume' }, new List<String>{ stringValue(result.get('loName'), 'Unassigned'), String.valueOf(result.get('recordCount')), formatCurrency((Decimal) result.get('volume')) }));
        }
        return rows;
    }

    private static List<DataRow> loanOfficerPipelineRows() {
        List<DataRow> rows = new List<DataRow>();
        for (AggregateResult result : [
            SELECT Loan_Officer__r.Name loName, COUNT(Id) recordCount, SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE CreatedDate >= 2024-01-01T00:00:00Z
            AND Status__c NOT IN :ACTIVE_TRANSACTION_EXCLUDES
            GROUP BY Loan_Officer__r.Name
            ORDER BY SUM(Loan_Amount_1st__c) DESC
            LIMIT 25
        ]) {
            rows.add(row(new List<String>{ 'Loan Officer', 'Active Files', 'Pipeline Volume' }, new List<String>{ stringValue(result.get('loName'), 'Unassigned'), String.valueOf(result.get('recordCount')), formatCurrency((Decimal) result.get('volume')) }));
        }
        return rows;
    }

    private static List<LoanOfficerBook> loanOfficerDashboardBooks() {
        return new List<LoanOfficerBook>{
            new LoanOfficerBook('Zachary Fritz', '0055x00000BrW8MAAV', 'BDR_REALTOR', 'Biz Dev - Reach + Realtor Referral'),
            new LoanOfficerBook('Joe Olmsted', '005Qi000006yeTsIAI', 'BDR_REALTOR', 'Biz Dev - Reach + Realtor Referral'),
            new LoanOfficerBook('Brandon Brotsky', '005f2000009NwSsAAK', 'BDR_REALTOR', 'Biz Dev - Reach + Realtor Referral'),
            new LoanOfficerBook('Alaina Pugh', '005Qi00000KuMK6IAN', 'BDR_REALTOR', 'Biz Dev - Reach + Realtor Referral'),
            new LoanOfficerBook('Martin Rebagliati', '005Qi00000H09nuIAB', 'BDR_REALTOR', 'Biz Dev - Reach + Realtor Referral'),
            new LoanOfficerBook('Megan Straight', '0055x00000BWkSBAA1', 'BDR_REALTOR', 'Biz Dev - Reach + Realtor Referral')
        };
    }

    private static List<LoanOfficerPerformance> loanOfficerPerformance(List<LoanOfficerBook> books, Date startDate, Date endDate) {
        return loanOfficerPerformance(books, startDate, endDate, false);
    }

    private static List<LoanOfficerPerformance> loanOfficerPerformance(List<LoanOfficerBook> books, Date startDate, Date endDate, Boolean includeActivity) {
        List<LoanOfficerPerformance> metrics = new List<LoanOfficerPerformance>();
        Map<String, LoanOfficerPerformance> metricsByName = new Map<String, LoanOfficerPerformance>();
        Map<String, List<Lead>> leadsByMetricName = new Map<String, List<Lead>>();
        Map<Id, LoanOfficerBook> ownerAllBooksByUserId = new Map<Id, LoanOfficerBook>();
        Map<Id, LoanOfficerBook> bdrBooksByUserId = new Map<Id, LoanOfficerBook>();
        LoanOfficerBook nickleyBook;

        for (LoanOfficerBook book : books) {
            LoanOfficerPerformance metric = new LoanOfficerPerformance(book, startDate, endDate);
            metrics.add(metric);
            metricsByName.put(book.name, metric);
            leadsByMetricName.put(book.name, new List<Lead>());
            if (book.filterType == 'OWNER_ALL') {
                ownerAllBooksByUserId.put(book.userId, book);
            } else if (book.filterType == 'NICKLEY') {
                nickleyBook = book;
            } else {
                bdrBooksByUserId.put(book.userId, book);
            }
        }

        DateTime startDateTime = DateTime.newInstanceGmt(startDate, Time.newInstance(0, 0, 0, 0));
        DateTime endDateTime = DateTime.newInstanceGmt(endDate, Time.newInstance(0, 0, 0, 0));

        if (!bdrBooksByUserId.isEmpty()) {
            for (Lead leadRecord : [
                SELECT Id, CreatedDate, OwnerId, Pre_Approved__c, Pre_Approval_Date__c,
                    Converted_Transaction_ID__c, ConvertedAccountId
                FROM Lead
                WHERE CreatedDate >= :startDateTime
                AND CreatedDate < :endDateTime
                AND OwnerId IN :bdrBooksByUserId.keySet()
                AND Biz_Dev__c = 'Biz Dev - Reach'
                AND LeadSource = 'Realtor Referral'
                LIMIT 50000
            ]) {
                LoanOfficerBook book = bdrBooksByUserId.get(leadRecord.OwnerId);
                leadsByMetricName.get(book.name).add(leadRecord);
            }
        }

        if (!ownerAllBooksByUserId.isEmpty()) {
            for (Lead leadRecord : [
                SELECT Id, CreatedDate, OwnerId, Pre_Approved__c, Pre_Approval_Date__c,
                    Converted_Transaction_ID__c, ConvertedAccountId
                FROM Lead
                WHERE CreatedDate >= :startDateTime
                AND CreatedDate < :endDateTime
                AND OwnerId IN :ownerAllBooksByUserId.keySet()
                LIMIT 50000
            ]) {
                LoanOfficerBook book = ownerAllBooksByUserId.get(leadRecord.OwnerId);
                leadsByMetricName.get(book.name).add(leadRecord);
            }
        }

        if (nickleyBook != null) {
            for (Lead leadRecord : [
                SELECT Id, CreatedDate, OwnerId, Pre_Approved__c, Pre_Approval_Date__c,
                    Converted_Transaction_ID__c, ConvertedAccountId
                FROM Lead
                WHERE CreatedDate >= :startDateTime
                AND CreatedDate < :endDateTime
                AND Realtor_Group_New__c IN :NICKLEY_REALTOR_GROUPS
                LIMIT 50000
            ]) {
                leadsByMetricName.get(nickleyBook.name).add(leadRecord);
            }
        }

        Set<Id> convertedTransactionIds = new Set<Id>();
        for (List<Lead> metricLeads : leadsByMetricName.values()) {
            for (Lead leadRecord : metricLeads) {
                if (leadRecord.Converted_Transaction_ID__c != null) {
                    convertedTransactionIds.add(leadRecord.Converted_Transaction_ID__c);
                }
            }
        }

        Map<Id, Transaction__c> transactionsById = new Map<Id, Transaction__c>();
        if (!convertedTransactionIds.isEmpty()) {
            transactionsById = new Map<Id, Transaction__c>([
                SELECT Id, Status__c, Loan_Amount_1st__c, Funding_Date__c, BPS__c, Borrower_Name__c
                FROM Transaction__c
                WHERE Id IN :convertedTransactionIds
            ]);
        }

        for (LoanOfficerBook book : books) {
            LoanOfficerPerformance metric = metricsByName.get(book.name);
            List<Lead> leads = leadsByMetricName.get(book.name);
            applyLeadCohortMetrics(metric, leads, transactionsById);
            if (includeActivity) {
                addFundedProduction(metric, book.userId, startDate, endDate);
                addOutboundCallActivity(metric, book.userId, startDate, endDate);
                addActivePreApprovalFollowUp(metric, book);
            }
        }
        return metrics;
    }

    private static LoanOfficerPerformance loanOfficerPerformance(LoanOfficerBook book, Date startDate, Date endDate) {
        return loanOfficerPerformance(book, startDate, endDate, false);
    }

    private static LoanOfficerPerformance loanOfficerPerformance(LoanOfficerBook book, Date startDate, Date endDate, Boolean includeActivity) {
        LoanOfficerPerformance metric = new LoanOfficerPerformance(book, startDate, endDate);
        List<Lead> leads = leadCohortForBook(book, startDate, endDate);
        Set<Id> convertedTransactionIds = new Set<Id>();
        for (Lead leadRecord : leads) {
            if (leadRecord.Converted_Transaction_ID__c != null) {
                convertedTransactionIds.add(leadRecord.Converted_Transaction_ID__c);
            }
        }

        Map<Id, Transaction__c> transactionsById = new Map<Id, Transaction__c>();
        if (!convertedTransactionIds.isEmpty()) {
            transactionsById = new Map<Id, Transaction__c>([
                SELECT Id, Status__c, Loan_Amount_1st__c, Funding_Date__c, BPS__c, Borrower_Name__c
                FROM Transaction__c
                WHERE Id IN :convertedTransactionIds
            ]);
        }

        applyLeadCohortMetrics(metric, leads, transactionsById);
        if (includeActivity) {
            addFundedProduction(metric, book.userId, startDate, endDate);
            addOutboundCallActivity(metric, book.userId, startDate, endDate);
            addActivePreApprovalFollowUp(metric, book);
        }
        return metric;
    }

    private static void applyLeadCohortMetrics(LoanOfficerPerformance metric, List<Lead> leads, Map<Id, Transaction__c> transactionsById) {
        metric.totalLeads = leads.size();

        Set<Id> cancelledBorrowerIds = new Set<Id>();
        Set<Id> cancelledTransactionIds = new Set<Id>();
        for (Lead leadRecord : leads) {
            Boolean hasPreApproval = leadRecord.Pre_Approval_Date__c != null || leadRecord.Pre_Approved__c;
            if (hasPreApproval) {
                metric.preApprovals++;
            }

            Transaction__c transactionRecord = transactionsById.get(leadRecord.Converted_Transaction_ID__c);
            if (transactionRecord == null) {
                if (leadRecord.Converted_Transaction_ID__c == null && leadRecord.ConvertedAccountId != null) {
                    metric.missingConvertedTransactionLinks++;
                }
                continue;
            }

            if (hasPreApproval) {
                metric.preApprovalsWithTransaction++;
            } else {
                metric.transactionWithoutPreApproval++;
            }

            if (CLOSED_TRANSACTION_STATUSES.contains(transactionRecord.Status__c)) {
                metric.closed++;
                if (!hasPreApproval) {
                    metric.closedWithoutPreApproval++;
                }
            } else if (CANCELLED_TRANSACTION_STATUSES.contains(transactionRecord.Status__c)) {
                metric.cancelled++;
                cancelledTransactionIds.add(transactionRecord.Id);
                if (transactionRecord.Borrower_Name__c != null) {
                    cancelledBorrowerIds.add(transactionRecord.Borrower_Name__c);
                }
            } else {
                metric.active++;
            }
        }

        metric.recovered = recoveredCloseCount(cancelledBorrowerIds, cancelledTransactionIds);
    }

    private static List<Lead> leadCohortForBook(LoanOfficerBook book, Date startDate, Date endDate) {
        DateTime startDateTime = DateTime.newInstanceGmt(startDate, Time.newInstance(0, 0, 0, 0));
        DateTime endDateTime = DateTime.newInstanceGmt(endDate, Time.newInstance(0, 0, 0, 0));
        if (book.filterType == 'NICKLEY') {
            return [
                SELECT Id, CreatedDate, OwnerId, Pre_Approved__c, Pre_Approval_Date__c,
                    Converted_Transaction_ID__c, ConvertedAccountId
                FROM Lead
                WHERE CreatedDate >= :startDateTime
                AND CreatedDate < :endDateTime
                AND Realtor_Group_New__c IN :NICKLEY_REALTOR_GROUPS
                LIMIT 50000
            ];
        }
        if (book.filterType == 'OWNER_ALL') {
            return [
                SELECT Id, CreatedDate, OwnerId, Pre_Approved__c, Pre_Approval_Date__c,
                    Converted_Transaction_ID__c, ConvertedAccountId
                FROM Lead
                WHERE CreatedDate >= :startDateTime
                AND CreatedDate < :endDateTime
                AND OwnerId = :book.userId
                LIMIT 50000
            ];
        }
        return [
            SELECT Id, CreatedDate, OwnerId, Pre_Approved__c, Pre_Approval_Date__c,
                Converted_Transaction_ID__c, ConvertedAccountId
            FROM Lead
            WHERE CreatedDate >= :startDateTime
            AND CreatedDate < :endDateTime
            AND OwnerId = :book.userId
            AND Biz_Dev__c = 'Biz Dev - Reach'
            AND LeadSource = 'Realtor Referral'
            LIMIT 50000
        ];
    }

    private static Integer recoveredCloseCount(Set<Id> borrowerIds, Set<Id> excludedTransactionIds) {
        if (borrowerIds.isEmpty()) {
            return 0;
        }
        Set<Id> recoveredBorrowerIds = new Set<Id>();
        for (Transaction__c transactionRecord : [
            SELECT Id, Borrower_Name__c
            FROM Transaction__c
            WHERE Borrower_Name__c IN :borrowerIds
            AND Id NOT IN :excludedTransactionIds
            AND Status__c IN :CLOSED_TRANSACTION_STATUSES
            LIMIT 50000
        ]) {
            recoveredBorrowerIds.add(transactionRecord.Borrower_Name__c);
        }
        return recoveredBorrowerIds.size();
    }

    private static void addFundedProduction(LoanOfficerPerformance metric, Id loanOfficerId, Date startDate, Date endDate) {
        AggregateResult result = [
            SELECT COUNT(Id) recordCount, SUM(Loan_Amount_1st__c) volume, AVG(Loan_Amount_1st__c) averageLoanSize, SUM(BPS__c) totalBps
            FROM Transaction__c
            WHERE Loan_Officer__c = :loanOfficerId
            AND Status__c IN :FUNDED_STATUSES
            AND Funding_Date__c >= :startDate
            AND Funding_Date__c < :endDate
        ];
        metric.fundedUnits = result.get('recordCount') == null ? 0 : (Integer) result.get('recordCount');
        metric.fundedVolume = decimalValue(result.get('volume'));
        metric.averageLoanSize = decimalValue(result.get('averageLoanSize'));
    }

    private static void addOutboundCallActivity(LoanOfficerPerformance metric, Id ownerId, Date startDate, Date endDate) {
        DateTime startDateTime = DateTime.newInstanceGmt(startDate, Time.newInstance(0, 0, 0, 0));
        DateTime endDateTime = DateTime.newInstanceGmt(endDate, Time.newInstance(0, 0, 0, 0));
        metric.outboundCalls = [
            SELECT COUNT()
            FROM Task
            WHERE OwnerId = :ownerId
            AND CreatedDate >= :startDateTime
            AND CreatedDate < :endDateTime
            AND TaskSubtype = 'Call'
            AND Direction__c = 'Outbound'
        ];
    }

    private static void addActivePreApprovalFollowUp(LoanOfficerPerformance metric, LoanOfficerBook book) {
        List<Lead> activePreApprovals;
        if (book.filterType == 'NICKLEY') {
            activePreApprovals = [
                SELECT Id, Pre_Approval_Date__c
                FROM Lead
                WHERE IsConverted = false
                AND Status = 'Pre-Approval'
                AND Pre_Approval_Date__c != null
                AND Realtor_Group_New__c IN :NICKLEY_REALTOR_GROUPS
                LIMIT 5000
            ];
        } else if (book.filterType == 'OWNER_ALL') {
            activePreApprovals = [
                SELECT Id, Pre_Approval_Date__c
                FROM Lead
                WHERE IsConverted = false
                AND Status = 'Pre-Approval'
                AND Pre_Approval_Date__c != null
                AND OwnerId = :book.userId
                LIMIT 5000
            ];
        } else {
            activePreApprovals = [
                SELECT Id, Pre_Approval_Date__c
                FROM Lead
                WHERE IsConverted = false
                AND Status = 'Pre-Approval'
                AND Pre_Approval_Date__c != null
                AND OwnerId = :book.userId
                AND Biz_Dev__c = 'Biz Dev - Reach'
                AND LeadSource = 'Realtor Referral'
                LIMIT 5000
            ];
        }

        metric.activePreApprovals = activePreApprovals.size();
        if (activePreApprovals.isEmpty()) {
            return;
        }

        Set<Id> activePreApprovalIds = new Map<Id, Lead>(activePreApprovals).keySet();
        Set<Id> leadsCalledLastSevenDays = new Set<Id>();
        DateTime sevenDaysAgo = System.now().addDays(-7);
        for (Task taskRecord : [
            SELECT WhoId
            FROM Task
            WHERE WhoId IN :activePreApprovalIds
            AND CreatedDate >= :sevenDaysAgo
            AND TaskSubtype = 'Call'
            AND Direction__c = 'Outbound'
            LIMIT 50000
        ]) {
            leadsCalledLastSevenDays.add(taskRecord.WhoId);
        }
        metric.activePreApprovalsWithoutRecentCall = metric.activePreApprovals - leadsCalledLastSevenDays.size();
    }

    private static List<DataRow> loanOfficerForecastRows(List<LoanOfficerPerformance> monthMetrics, List<LoanOfficerPerformance> benchmarkMetrics) {
        Map<String, LoanOfficerPerformance> benchmarkByName = metricsByName(benchmarkMetrics);
        List<DataRow> rows = new List<DataRow>();
        List<String> columns = new List<String>{ 'LO', 'Book', 'MTD Leads', 'Closed MTD', 'Active', '2025 L-Close', '2025 Pull', 'Top-Down', 'Pipeline', 'Blended' };
        for (LoanOfficerPerformance metric : monthMetrics) {
            LoanOfficerPerformance benchmark = benchmarkByName.get(metric.name);
            Decimal leadToCloseRate = benchmark == null ? 0 : benchmark.leadToCloseRateReported();
            Decimal pullThroughRate = benchmark == null ? 0 : benchmark.pullThroughRateReported();
            Integer topDown = forecastUnits(metric.totalLeads, leadToCloseRate);
            Integer pipeline = metric.closed + forecastUnits(metric.active, pullThroughRate);
            Integer blended = ((topDown + pipeline) / 2);
            metric.blendedForecast = blended;
            String leadPipelineUrl = loLeadPipelineReportUrl(metric.name, metric.startDate, metric.endDate);
            String fundedMtdUrl = loFundedMtdReportUrl(metric.name);
            rows.add(row(columns, new List<String>{
                metric.name,
                metric.bookDefinition,
                String.valueOf(metric.totalLeads),
                String.valueOf(metric.closed),
                String.valueOf(metric.active),
                percentString(leadToCloseRate),
                percentString(pullThroughRate),
                String.valueOf(topDown),
                String.valueOf(pipeline),
                String.valueOf(blended)
            }, null, null, new List<String>{
                leadPipelineUrl,
                leadPipelineUrl,
                leadPipelineUrl,
                fundedMtdUrl,
                leadPipelineUrl,
                leadPipelineUrl,
                leadPipelineUrl,
                leadPipelineUrl,
                leadPipelineUrl,
                leadPipelineUrl
            }));
        }
        return rows;
    }

    private static List<DataRow> loanOfficerReferralIntelligenceRows(List<LoanOfficerPerformance> metrics, String periodLabel) {
        List<DataRow> rows = new List<DataRow>();
        List<String> columns = new List<String>{
            'LO',
            periodLabel + ' Referral Leads',
            '% of Inside Referrals',
            'Reached Pre-Approval',
            'Pre-Approval %',
            'Closed Transactions',
            'Closed Transaction %'
        };
        Integer totalReferralLeads = 0;
        for (LoanOfficerPerformance metric : metrics) {
            totalReferralLeads += metric.totalLeads;
        }

        for (LoanOfficerPerformance metric : metrics) {
            String leadPipelineUrl = loLeadPipelineReportUrl(metric.name, metric.startDate, metric.endDate);
            rows.add(row(columns, new List<String>{
                metric.name,
                String.valueOf(metric.totalLeads),
                percentValue(metric.totalLeads, totalReferralLeads),
                String.valueOf(metric.preApprovals),
                percentString(metric.leadToPreApprovalRate()),
                String.valueOf(metric.closed),
                percentString(metric.leadToCloseRateReported())
            }, null, null, repeatedUrl(leadPipelineUrl, columns.size())));
        }
        return rows;
    }

    private static List<DataRow> loanOfficerLeadSourceRows(List<LoanOfficerBook> books, Date startDate, Date endDate) {
        List<DataRow> rows = new List<DataRow>();
        List<String> columns = new List<String>{ 'Lead Source', 'LO', 'Leads', '% of LO Leads' };
        Map<String, Map<String, Integer>> countsByLo = new Map<String, Map<String, Integer>>();
        Map<String, Integer> totalsByLo = new Map<String, Integer>();
        Map<Id, LoanOfficerBook> ownerAllBooksByUserId = new Map<Id, LoanOfficerBook>();
        Map<Id, LoanOfficerBook> bdrBooksByUserId = new Map<Id, LoanOfficerBook>();
        LoanOfficerBook nickleyBook;

        for (LoanOfficerBook book : books) {
            countsByLo.put(book.name, new Map<String, Integer>());
            totalsByLo.put(book.name, 0);
            if (book.filterType == 'OWNER_ALL') {
                ownerAllBooksByUserId.put(book.userId, book);
            } else if (book.filterType == 'NICKLEY') {
                nickleyBook = book;
            } else {
                bdrBooksByUserId.put(book.userId, book);
            }
        }

        DateTime startDateTime = DateTime.newInstanceGmt(startDate, Time.newInstance(0, 0, 0, 0));
        DateTime endDateTime = DateTime.newInstanceGmt(endDate, Time.newInstance(0, 0, 0, 0));

        if (!bdrBooksByUserId.isEmpty()) {
            for (AggregateResult result : [
                SELECT OwnerId ownerId, LeadSource sourceName, COUNT(Id) recordCount
                FROM Lead
                WHERE CreatedDate >= :startDateTime
                AND CreatedDate < :endDateTime
                AND OwnerId IN :bdrBooksByUserId.keySet()
                AND Biz_Dev__c = 'Biz Dev - Reach'
                AND LeadSource = 'Realtor Referral'
                GROUP BY OwnerId, LeadSource
            ]) {
                LoanOfficerBook book = bdrBooksByUserId.get((Id) result.get('ownerId'));
                addLeadSourceCount(countsByLo, totalsByLo, book.name, stringValue(result.get('sourceName'), 'Unspecified'), (Integer) result.get('recordCount'));
            }
        }

        if (!ownerAllBooksByUserId.isEmpty()) {
            for (AggregateResult result : [
                SELECT OwnerId ownerId, LeadSource sourceName, COUNT(Id) recordCount
                FROM Lead
                WHERE CreatedDate >= :startDateTime
                AND CreatedDate < :endDateTime
                AND OwnerId IN :ownerAllBooksByUserId.keySet()
                GROUP BY OwnerId, LeadSource
            ]) {
                LoanOfficerBook book = ownerAllBooksByUserId.get((Id) result.get('ownerId'));
                addLeadSourceCount(countsByLo, totalsByLo, book.name, stringValue(result.get('sourceName'), 'Unspecified'), (Integer) result.get('recordCount'));
            }
        }

        if (nickleyBook != null) {
            for (AggregateResult result : [
                SELECT LeadSource sourceName, COUNT(Id) recordCount
                FROM Lead
                WHERE CreatedDate >= :startDateTime
                AND CreatedDate < :endDateTime
                AND Realtor_Group_New__c IN :NICKLEY_REALTOR_GROUPS
                GROUP BY LeadSource
            ]) {
                addLeadSourceCount(countsByLo, totalsByLo, nickleyBook.name, stringValue(result.get('sourceName'), 'Unspecified'), (Integer) result.get('recordCount'));
            }
        }

        Set<String> sourceNameSet = new Set<String>();
        for (String loName : countsByLo.keySet()) {
            sourceNameSet.addAll(countsByLo.get(loName).keySet());
        }
        List<String> sourceNames = new List<String>(sourceNameSet);
        sourceNames.sort();

        for (String sourceName : sourceNames) {
            Boolean isFirstSourceRow = true;
            for (LoanOfficerBook book : books) {
                Integer total = totalsByLo.get(book.name);
                Integer countValue = countsByLo.get(book.name).get(sourceName);
                if (countValue == null || countValue == 0 || total == null || total == 0) {
                    continue;
                }
                String leadPipelineUrl = loLeadPipelineReportUrl(book.name, startDate, endDate);
                rows.add(row(columns, new List<String>{
                    isFirstSourceRow ? sourceName : '',
                    book.name,
                    String.valueOf(countValue),
                    percentValue(countValue, total)
                }, null, null, firstCellGroupedUrls(leadPipelineUrl, columns.size(), !isFirstSourceRow)));
                isFirstSourceRow = false;
            }
        }

        Boolean isFirstNoLeadRow = true;
        for (LoanOfficerBook book : books) {
            Integer total = totalsByLo.get(book.name);
            if (total == null || total == 0) {
                String leadPipelineUrl = loLeadPipelineReportUrl(book.name, startDate, endDate);
                rows.add(row(columns, new List<String>{
                    isFirstNoLeadRow ? 'No leads this month' : '',
                    book.name,
                    '0',
                    '0.0%'
                }, null, null, firstCellGroupedUrls(leadPipelineUrl, columns.size(), !isFirstNoLeadRow)));
                isFirstNoLeadRow = false;
            }
        }
        return rows;
    }

    private static void addLeadSourceCount(Map<String, Map<String, Integer>> countsByLo, Map<String, Integer> totalsByLo, String loName, String sourceName, Integer countValue) {
        if (!countsByLo.containsKey(loName)) {
            countsByLo.put(loName, new Map<String, Integer>());
            totalsByLo.put(loName, 0);
        }
        Integer normalizedCount = countValue == null ? 0 : countValue;
        Map<String, Integer> countsBySource = countsByLo.get(loName);
        countsBySource.put(sourceName, (countsBySource.containsKey(sourceName) ? countsBySource.get(sourceName) : 0) + normalizedCount);
        totalsByLo.put(loName, (totalsByLo.containsKey(loName) ? totalsByLo.get(loName) : 0) + normalizedCount);
    }

    private static List<DataRow> loanOfficerBenchmarkRows(List<LoanOfficerPerformance> metrics) {
        List<DataRow> rows = new List<DataRow>();
        List<String> columns = new List<String>{ 'LO', '2025 Leads', 'Lead-PA', 'PA-Trans', 'Pull Reported', 'Pull Adjusted', 'Lead-Close Reported', 'Lead-Close Adjusted', 'Known Good' };
        for (LoanOfficerPerformance metric : metrics) {
            String leadPipelineUrl = loLeadPipelineReportUrl(metric.name, metric.startDate, metric.endDate);
            rows.add(row(columns, new List<String>{
                metric.name,
                String.valueOf(metric.totalLeads),
                percentString(metric.leadToPreApprovalRate()),
                percentString(metric.preApprovalToTransactionRate()),
                percentString(metric.pullThroughRateReported()),
                percentString(metric.pullThroughRateAdjusted()),
                percentString(metric.leadToCloseRateReported()),
                percentString(metric.leadToCloseRateAdjusted()),
                knownGoodBenchmarkNote(metric)
            }, null, null, repeatedUrl(leadPipelineUrl, columns.size())));
        }
        return rows;
    }

    private static List<DataRow> loanOfficerRollingCohortRows(List<LoanOfficerBook> books, List<LoanOfficerPerformance> benchmarkMetrics) {
        Map<String, LoanOfficerPerformance> benchmarkByName = metricsByName(benchmarkMetrics);
        List<DataRow> rows = new List<DataRow>();
        List<String> columns = new List<String>{ 'Lead Month', 'LO', 'Leads', 'Lead-PA', 'PA-Trans', 'Closed Adj', 'Active', 'Lead-Close Adj', 'Forecast' };
        for (Integer i = 3; i >= 0; i--) {
            Date startDate = MONTH_START.addMonths(-i);
            Date endDate = startDate.addMonths(1);
            Boolean isFirstMonthRow = true;
            for (LoanOfficerPerformance metric : loanOfficerPerformance(books, startDate, endDate, false)) {
                LoanOfficerPerformance benchmark = benchmarkByName.get(metric.name);
                Decimal benchmarkLeadToClose = benchmark == null ? 0 : benchmark.leadToCloseRateReported();
                Integer forecast = i == 0 ? forecastUnits(metric.totalLeads, benchmarkLeadToClose) : metric.closedAdjusted();
                String leadPipelineUrl = loLeadPipelineReportUrl(metric.name, startDate, endDate);
                rows.add(row(columns, new List<String>{
                    isFirstMonthRow ? monthLabel(startDate) : '',
                    metric.name,
                    String.valueOf(metric.totalLeads),
                    percentString(metric.leadToPreApprovalRate()),
                    percentString(metric.preApprovalToTransactionRate()),
                    String.valueOf(metric.closedAdjusted()),
                    String.valueOf(metric.active),
                    percentString(metric.leadToCloseRateAdjusted()),
                    String.valueOf(forecast)
                }, null, null, firstCellGroupedUrls(leadPipelineUrl, columns.size(), !isFirstMonthRow)));
                isFirstMonthRow = false;
            }
        }
        return rows;
    }

    private static List<DataRow> loanOfficerActivityRows(List<LoanOfficerPerformance> metrics) {
        List<DataRow> rows = new List<DataRow>();
        List<String> columns = new List<String>{ 'LO', 'Funded Units MTD', 'Funded Volume MTD', 'Avg Loan', 'Outbound Calls MTD', 'Active PAs', 'PAs No Call 7d' };
        for (LoanOfficerPerformance metric : metrics) {
            String fundedMtdUrl = loFundedMtdReportUrl(metric.name);
            String outboundCallsUrl = loOutboundCallsMtdReportUrl(metric.name);
            String activePreApprovalUrl = loActivePreApprovalReportUrl(metric.name);
            rows.add(row(columns, new List<String>{
                metric.name,
                String.valueOf(metric.fundedUnits),
                formatCurrency(metric.fundedVolume),
                formatCurrency(metric.averageLoanSize),
                String.valueOf(metric.outboundCalls),
                String.valueOf(metric.activePreApprovals),
                String.valueOf(metric.activePreApprovalsWithoutRecentCall)
            }, null, null, new List<String>{
                fundedMtdUrl,
                fundedMtdUrl,
                fundedMtdUrl,
                fundedMtdUrl,
                outboundCallsUrl,
                activePreApprovalUrl,
                activePreApprovalUrl
            }));
        }
        return rows;
    }

    private static List<DataRow> loanOfficerDataHygieneRows(List<LoanOfficerPerformance> monthMetrics, List<LoanOfficerPerformance> benchmarkMetrics) {
        List<DataRow> rows = new List<DataRow>();
        List<String> columns = new List<String>{ 'Fix Needed', 'LO', 'Count', 'Why' };
        for (LoanOfficerPerformance metric : monthMetrics) {
            String leadPipelineUrl = loLeadPipelineReportUrl(metric.name, metric.startDate, metric.endDate);
            rows.add(row(columns, new List<String>{ 'Missing PA', metric.name, String.valueOf(metric.transactionWithoutPreApproval), 'Transacted leads without PA flag/date.' }, null, null, repeatedUrl(leadPipelineUrl, columns.size())));
            rows.add(row(columns, new List<String>{ 'Missing link', metric.name, String.valueOf(metric.missingConvertedTransactionLinks), 'Converted lead has an account but no transaction link.' }, null, null, repeatedUrl(leadPipelineUrl, columns.size())));
        }
        for (LoanOfficerPerformance metric : benchmarkMetrics) {
            String leadPipelineUrl = loLeadPipelineReportUrl(metric.name, metric.startDate, metric.endDate);
            rows.add(row(columns, new List<String>{ '2025 PA gap', metric.name, String.valueOf(metric.closedWithoutPreApproval), 'Closed 2025 files missing PA data.' }, null, null, repeatedUrl(leadPipelineUrl, columns.size())));
        }
        return rows;
    }

    private static List<DataRow> loanOfficerRosterReviewRows() {
        List<DataRow> rows = new List<DataRow>();
        List<String> columns = new List<String>{ 'Candidate', 'UserId', 'Current Signal', 'Proposed Question' };
        for (User userRecord : [
            SELECT Id, Name, Title, Department, UserRole.Name
            FROM User
            WHERE IsActive = true
            AND Id IN ('005Qi0000011MxBIAU', '005Qi00000TYQgvIAH')
            ORDER BY Name
        ]) {
            rows.add(row(columns, new List<String>{
                userRecord.Name,
                userRecord.Id,
                stringValue(userRecord.Title, stringValue(userRecord.UserRole == null ? null : userRecord.UserRole.Name, 'Loan Officer candidate')),
                'Confirm include/exclude and exact book filter before adding to production roster.'
            }, null, null, repeatedUrl('/lightning/setup/ManageUsers/page?address=%2F' + userRecord.Id, columns.size())));
        }
        return rows;
    }

    private static Map<String, LoanOfficerPerformance> metricsByName(List<LoanOfficerPerformance> metrics) {
        Map<String, LoanOfficerPerformance> valuesByName = new Map<String, LoanOfficerPerformance>();
        for (LoanOfficerPerformance metric : metrics) {
            valuesByName.put(metric.name, metric);
        }
        return valuesByName;
    }

    private static Integer forecastUnits(Integer baseCount, Decimal rate) {
        if (baseCount == null || rate == null) {
            return 0;
        }
        return Integer.valueOf((Decimal.valueOf(baseCount) * rate).setScale(0));
    }

    private static String percentString(Decimal value) {
        return String.valueOf((value == null ? 0 : value * 100).setScale(1)) + '%';
    }

    private static String knownGoodBenchmarkNote(LoanOfficerPerformance metric) {
        if (metric.name == 'Zachary Fritz') {
            return 'Target check: 573 leads / 14.0% Lead-Close';
        }
        if (metric.name == 'Joe Olmsted') {
            return 'Target check: 311 leads / 14.5% Lead-Close';
        }
        return 'No fixed known-good target supplied';
    }

    private static Decimal sumFundedVolume(List<LoanOfficerPerformance> metrics) {
        Decimal total = 0;
        for (LoanOfficerPerformance metric : metrics) {
            total += metric.fundedVolume == null ? 0 : metric.fundedVolume;
        }
        return total;
    }

    private static Integer sumFundedUnits(List<LoanOfficerPerformance> metrics) {
        Integer total = 0;
        for (LoanOfficerPerformance metric : metrics) {
            total += metric.fundedUnits;
        }
        return total;
    }

    private static Integer sumBlendedForecast(List<LoanOfficerPerformance> metrics) {
        Integer total = 0;
        for (LoanOfficerPerformance metric : metrics) {
            total += metric.blendedForecast;
        }
        return total;
    }

    private static Integer sumPreApprovalGaps(List<LoanOfficerPerformance> metrics) {
        Integer total = 0;
        for (LoanOfficerPerformance metric : metrics) {
            total += metric.transactionWithoutPreApproval;
        }
        return total;
    }

    private static List<DataRow> realtorPartnerRows() {
        return realtorPartnerRows(YEAR_START);
    }

    private static List<DataRow> realtorPartnerRows(Date createdAfter) {
        List<DataRow> rows = new List<DataRow>();
        for (AggregateResult result : [
            SELECT Realtor_Buying_Agent__r.Name agentName, Owner.Name ownerName, COUNT(Id) recordCount
            FROM Lead
            WHERE CreatedDate >= :createdAfter
            AND LeadSource = 'Realtor Referral'
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            GROUP BY Realtor_Buying_Agent__r.Name, Owner.Name
            ORDER BY COUNT(Id) DESC
            LIMIT 25
        ]) {
            rows.add(row(new List<String>{ 'Referral Partner', 'Assigned Owner', 'Leads YTD' }, new List<String>{ stringValue(result.get('agentName'), 'Unspecified'), stringValue(result.get('ownerName'), 'Unassigned'), String.valueOf(result.get('recordCount')) }));
        }
        return rows;
    }

    private static List<DataRow> falloutTransactionRows() {
        List<DataRow> rows = new List<DataRow>();
        for (AggregateResult result : [
            SELECT Status__c statusValue, COUNT(Id) recordCount, SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE Status__c IN ('Cancelled', 'Canceled', 'Lost')
            AND CreatedDate = THIS_YEAR
            GROUP BY Status__c
            ORDER BY COUNT(Id) DESC
        ]) {
            rows.add(row(new List<String>{ 'Status', 'Files', 'Volume' }, new List<String>{ stringValue(result.get('statusValue'), 'Unspecified'), String.valueOf(result.get('recordCount')), formatCurrency((Decimal) result.get('volume')) }));
        }
        return rows;
    }

    private static List<DataRow> falloutLeadRows() {
        List<DataRow> rows = new List<DataRow>();
        for (AggregateResult result : [
            SELECT Status statusValue, COUNT(Id) recordCount
            FROM Lead
            WHERE Status IN ('Denied', 'Withdrawn', 'Credit Repair', 'Nurturing', 'Nurture - Preapproval')
            AND CreatedDate = THIS_YEAR
            GROUP BY Status
            ORDER BY COUNT(Id) DESC
        ]) {
            rows.add(row(new List<String>{ 'Lead Status', 'Leads' }, new List<String>{ stringValue(result.get('statusValue'), 'Unspecified'), String.valueOf(result.get('recordCount')) }));
        }
        return rows;
    }

    private static List<DataRow> pastDueClosingRows() {
        List<DataRow> rows = new List<DataRow>();
        for (AggregateResult result : [
            SELECT Processor__r.Name processorName, COUNT(Id) recordCount, SUM(Loan_Amount_1st__c) volume
            FROM Transaction__c
            WHERE Closing_Date__c < :TODAY_DATE
            AND Status__c NOT IN :ACTIVE_TRANSACTION_EXCLUDES
            GROUP BY Processor__r.Name
            ORDER BY COUNT(Id) DESC
            LIMIT 20
        ]) {
            rows.add(row(new List<String>{ 'Processor', 'Past-Due Files', 'Volume' }, new List<String>{ stringValue(result.get('processorName'), 'Unassigned'), String.valueOf(result.get('recordCount')), formatCurrency((Decimal) result.get('volume')) }));
        }
        return rows;
    }

    private static DataRow row(List<String> columns, List<String> values) {
        return new DataRow(columns, values, null);
    }

    private static DataRow row(List<String> columns, List<String> values, String navApiName) {
        return new DataRow(columns, values, navApiName, null);
    }

    private static DataRow row(List<String> columns, List<String> values, String navApiName, String urlPath) {
        return new DataRow(columns, values, navApiName, urlPath);
    }

    private static DataRow row(List<String> columns, List<String> values, String navApiName, String urlPath, List<String> cellUrlPaths) {
        return new DataRow(columns, values, navApiName, urlPath, cellUrlPaths);
    }

    private static List<String> repeatedUrl(String urlPath, Integer countValue) {
        List<String> urls = new List<String>();
        for (Integer i = 0; i < countValue; i++) {
            urls.add(urlPath);
        }
        return urls;
    }

    private static List<String> firstCellGroupedUrls(String urlPath, Integer countValue, Boolean firstCellIsBlank) {
        List<String> urls = repeatedUrl(urlPath, countValue);
        if (firstCellIsBlank && !urls.isEmpty()) {
            urls[0] = null;
        }
        return urls;
    }

    private static String loLeadPipelineReportUrl(String loanOfficerName, Date startDate, Date endDate) {
        return reportUrlByDeveloperNameWithFilters(
            LO_LEAD_PIPELINE_REPORT_DEVELOPER_NAME,
            new List<String>{ LO_LEAD_REPORT_RECORD_TYPE_FILTER, loanOfficerName },
            startDate,
            endDate
        );
    }

    private static String loFundedMtdReportUrl(String loanOfficerName) {
        return reportUrlByDeveloperNameWithFilters(LO_PERSONAL_DEALS_MTD_REPORT_DEVELOPER_NAME, new List<String>{ loanOfficerName });
    }

    private static String loOutboundCallsMtdReportUrl(String loanOfficerName) {
        return reportUrlByDeveloperNameWithFilters(LO_OUTBOUND_CALLS_MTD_REPORT_DEVELOPER_NAME, new List<String>{ LO_OUTBOUND_CALL_TYPE_FILTER, loanOfficerName });
    }

    private static String loActivePreApprovalReportUrl(String loanOfficerName) {
        return reportUrlByDeveloperNameWithFilters(LO_ACTIVE_PRE_APPROVALS_REPORT_DEVELOPER_NAME, new List<String>{ loanOfficerName });
    }

    private static String reportIdByDeveloperName(String developerName) {
        if (reportIdsByDeveloperName.containsKey(developerName)) {
            return reportIdsByDeveloperName.get(developerName);
        }
        List<Report> reports = [
            SELECT Id
            FROM Report
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
        String reportId = reports.isEmpty() ? null : reports[0].Id;
        reportIdsByDeveloperName.put(developerName, reportId);
        return reportId;
    }

    private static String reportUrl(String reportId, String statusValue) {
        if (String.isBlank(reportId)) {
            return null;
        }
        if (String.isBlank(statusValue)) {
            return '/lightning/r/Report/' + reportId + '/view';
        }
        return '/lightning/r/Report/' + reportId + '/view?fv0=' + EncodingUtil.urlEncode(statusValue, 'UTF-8');
    }

    private static String reportUrlByDeveloperName(String developerName, String filterValue) {
        return reportUrl(reportIdByDeveloperName(developerName), filterValue);
    }

    private static String reportUrlByDeveloperNameWithFilters(String developerName, List<String> filterValues) {
        return reportUrl(reportIdByDeveloperName(developerName), filterValues, null, null);
    }

    private static String reportUrlByDeveloperNameWithFilters(String developerName, List<String> filterValues, Date startDate, Date endDate) {
        return reportUrl(reportIdByDeveloperName(developerName), filterValues, startDate, endDate);
    }

    private static String reportUrl(String reportId, List<String> filterValues, Date startDate, Date endDate) {
        if (String.isBlank(reportId)) {
            return null;
        }
        List<String> parameters = new List<String>();
        for (Integer i = 0; filterValues != null && i < filterValues.size(); i++) {
            if (filterValues[i] != null) {
                parameters.add('fv' + String.valueOf(i) + '=' + EncodingUtil.urlEncode(filterValues[i], 'UTF-8'));
            }
        }
        if (startDate != null) {
            parameters.add('startDate=' + EncodingUtil.urlEncode(String.valueOf(startDate), 'UTF-8'));
        }
        if (endDate != null) {
            parameters.add('endDate=' + EncodingUtil.urlEncode(String.valueOf(endDate.addDays(-1)), 'UTF-8'));
        }
        String baseUrl = '/lightning/r/Report/' + reportId + '/view';
        return parameters.isEmpty() ? baseUrl : baseUrl + '?' + String.join(parameters, '&');
    }

    private static Map<String, Integer> leadCountsByStatus(List<String> statuses) {
        return leadCountsByStatus(statuses, null);
    }

    private static Map<String, Integer> leadCountsByStatus(List<String> statuses, Date createdAfter) {
        Map<String, Integer> counts = new Map<String, Integer>();
        if (createdAfter == null) {
            for (AggregateResult result : [
                SELECT Status statusValue, COUNT(Id) recordCount
                FROM Lead
                WHERE IsConverted = false
                AND Status IN :statuses
                GROUP BY Status
            ]) {
                counts.put((String) result.get('statusValue'), (Integer) result.get('recordCount'));
            }
        } else {
            for (AggregateResult result : [
                SELECT Status statusValue, COUNT(Id) recordCount
                FROM Lead
                WHERE IsConverted = false
                AND CreatedDate >= :createdAfter
                AND Status IN :statuses
                AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
                AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
                GROUP BY Status
            ]) {
                counts.put((String) result.get('statusValue'), (Integer) result.get('recordCount'));
            }
        }
        return counts;
    }

    private static Integer leadCount(Date startDate, Date endDate) {
        return [SELECT COUNT() FROM Lead WHERE CreatedDate >= :startDate AND CreatedDate < :endDate];
    }

    private static Integer leadIntelligenceLeadCount() {
        return leadIntelligenceLeadCount(LEAD_INTELLIGENCE_START);
    }

    private static Integer leadIntelligenceLeadCount(Date createdAfter) {
        return [
            SELECT COUNT()
            FROM Lead
            WHERE CreatedDate >= :createdAfter
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
        ];
    }

    private static Integer averageLeadIntelligenceMonthlyLeadCount2026() {
        Date startDate = Date.newInstance(2026, 1, 1);
        if (TODAY_DATE < startDate) {
            return 0;
        }
        Integer monthCount = TODAY_DATE.month();
        Integer total = leadIntelligenceLeadCountBetween(startDate, TODAY_DATE.addDays(1));
        Decimal average = (Decimal.valueOf(total) / monthCount).setScale(0);
        return average.intValue();
    }

    private static String leadIntelligenceLastThreeMonthSummary2026() {
        Date firstMonth = Date.newInstance(2026, 1, 1);
        if (TODAY_DATE < firstMonth) {
            return '2026 lead pacing begins 01/01/2026';
        }

        List<String> monthSummaries = new List<String>();
        Integer startMonth = TODAY_DATE.month() > 2 ? TODAY_DATE.month() - 2 : 1;
        for (Integer monthNumber = startMonth; monthNumber <= TODAY_DATE.month(); monthNumber++) {
            Date startDate = Date.newInstance(2026, monthNumber, 1);
            Date endDate = monthNumber == TODAY_DATE.month() ? TODAY_DATE.addDays(1) : startDate.addMonths(1);
            monthSummaries.add(shortMonthLabel(monthNumber) + ': ' + String.valueOf(leadIntelligenceLeadCountBetween(startDate, endDate)));
        }
        return String.join(monthSummaries, ' | ');
    }

    private static Integer leadIntelligenceLeadCountBetween(Date startDate, Date endDate) {
        return [
            SELECT COUNT()
            FROM Lead
            WHERE CreatedDate >= :startDate
            AND CreatedDate < :endDate
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
        ];
    }

    private static Integer preApprovalsIssuedYtdCount() {
        Date tomorrow = TODAY_DATE.addDays(1);
        return [
            SELECT COUNT()
            FROM Lead
            WHERE Pre_Approval_Date__c >= :YEAR_START
            AND Pre_Approval_Date__c < :tomorrow
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
        ];
    }

    private static Integer activeLeadCount() {
        return [SELECT COUNT() FROM Lead WHERE IsConverted = false AND Status NOT IN :ACTIVE_LEAD_EXCLUDES];
    }

    private static Integer advancingLeadCount() {
        return [SELECT COUNT() FROM Lead WHERE IsConverted = false AND Status IN :ADVANCING_LEAD_STATUSES];
    }

    private static Integer advancingLeadCount(Date createdAfter) {
        return [
            SELECT COUNT()
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate >= :createdAfter
            AND Status IN :ADVANCING_LEAD_STATUSES
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
        ];
    }

    private static Integer workingLeadCount(Date createdAfter) {
        List<String> statuses = new List<String>(ACTIVE_LEAD_FUNNEL_STATUSES);
        Integer preApprovalIndex = statuses.indexOf('Pre-Approval');
        if (preApprovalIndex >= 0) {
            statuses.remove(preApprovalIndex);
        }
        return [
            SELECT COUNT()
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate >= :createdAfter
            AND Status IN :statuses
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
        ];
    }

    private static Integer staleLeadCount(Integer daysOld) {
        Date cutoff = TODAY_DATE.addDays(-daysOld);
        return [SELECT COUNT() FROM Lead WHERE IsConverted = false AND (LastActivityDate = null OR LastActivityDate <= :cutoff)];
    }

    private static Integer staleLeadCount(Integer daysOld, Date createdAfter) {
        Date cutoff = TODAY_DATE.addDays(-daysOld);
        return [
            SELECT COUNT()
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate >= :createdAfter
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            AND (LastActivityDate = null OR LastActivityDate <= :cutoff)
        ];
    }

    private static Integer stagnantLeadCount(Integer daysOld) {
        DateTime statusCutoff = System.now().addDays(-daysOld);
        List<String> statuses = new List<String>(ACTIVE_LEAD_FUNNEL_STATUSES);
        Integer preApprovalIndex = statuses.indexOf('Pre-Approval');
        if (preApprovalIndex >= 0) {
            statuses.remove(preApprovalIndex);
        }
        return [
            SELECT COUNT()
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate >= :LEAD_INTELLIGENCE_START
            AND CreatedDate <= :statusCutoff
            AND Status IN :statuses
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
            AND Id NOT IN (
                SELECT LeadId
                FROM LeadHistory
                WHERE Field = 'Status'
                AND CreatedDate > :statusCutoff
            )
        ];
    }

    private static StagnantLeadCounts stagnantLeadCounts() {
        DateTime sevenDayCutoff = System.now().addDays(-7);
        DateTime fourteenDayCutoff = System.now().addDays(-14);
        DateTime twentyOneDayCutoff = System.now().addDays(-21);
        List<String> statuses = new List<String>(ACTIVE_LEAD_FUNNEL_STATUSES);
        Integer preApprovalIndex = statuses.indexOf('Pre-Approval');
        if (preApprovalIndex >= 0) {
            statuses.remove(preApprovalIndex);
        }

        List<Lead> leads = [
            SELECT Id, CreatedDate
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate >= :LEAD_INTELLIGENCE_START
            AND CreatedDate <= :sevenDayCutoff
            AND Status IN :statuses
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
        ];

        StagnantLeadCounts counts = new StagnantLeadCounts();
        if (leads.isEmpty()) {
            return counts;
        }

        Set<Id> leadIds = new Set<Id>();
        for (Lead leadRecord : leads) {
            leadIds.add(leadRecord.Id);
        }

        Map<Id, Datetime> lastStatusChangeByLeadId = new Map<Id, Datetime>();
        for (AggregateResult result : [
            SELECT LeadId leadId, MAX(CreatedDate) lastStatusChange
            FROM LeadHistory
            WHERE Field = 'Status'
            AND LeadId IN :leadIds
            GROUP BY LeadId
        ]) {
            lastStatusChangeByLeadId.put((Id) result.get('leadId'), (Datetime) result.get('lastStatusChange'));
        }

        for (Lead leadRecord : leads) {
            Datetime statusSince = lastStatusChangeByLeadId.containsKey(leadRecord.Id)
                ? lastStatusChangeByLeadId.get(leadRecord.Id)
                : leadRecord.CreatedDate;
            if (statusSince <= sevenDayCutoff) {
                counts.sevenDays++;
            }
            if (statusSince <= fourteenDayCutoff) {
                counts.fourteenDays++;
            }
            if (statusSince <= twentyOneDayCutoff) {
                counts.twentyOneDays++;
            }
        }
        return counts;
    }

    private static Map<String, StagnantLeadCounts> stagnantLeadCountsByOwner() {
        DateTime sevenDayCutoff = System.now().addDays(-7);
        DateTime fourteenDayCutoff = System.now().addDays(-14);
        DateTime twentyOneDayCutoff = System.now().addDays(-21);
        List<String> statuses = new List<String>(ACTIVE_LEAD_FUNNEL_STATUSES);
        Integer preApprovalIndex = statuses.indexOf('Pre-Approval');
        if (preApprovalIndex >= 0) {
            statuses.remove(preApprovalIndex);
        }

        List<Lead> leads = [
            SELECT Id, CreatedDate, Owner.Name
            FROM Lead
            WHERE IsConverted = false
            AND CreatedDate >= :LEAD_INTELLIGENCE_START
            AND CreatedDate <= :sevenDayCutoff
            AND Status IN :statuses
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
        ];

        Map<String, StagnantLeadCounts> countsByOwner = new Map<String, StagnantLeadCounts>();
        if (leads.isEmpty()) {
            return countsByOwner;
        }

        Set<Id> leadIds = new Set<Id>();
        for (Lead leadRecord : leads) {
            leadIds.add(leadRecord.Id);
        }

        Map<Id, Datetime> lastStatusChangeByLeadId = new Map<Id, Datetime>();
        for (AggregateResult result : [
            SELECT LeadId leadId, MAX(CreatedDate) lastStatusChange
            FROM LeadHistory
            WHERE Field = 'Status'
            AND LeadId IN :leadIds
            GROUP BY LeadId
        ]) {
            lastStatusChangeByLeadId.put((Id) result.get('leadId'), (Datetime) result.get('lastStatusChange'));
        }

        for (Lead leadRecord : leads) {
            String ownerName = stringValue(leadRecord.Owner.Name, 'Unassigned');
            if (!countsByOwner.containsKey(ownerName)) {
                countsByOwner.put(ownerName, new StagnantLeadCounts());
            }
            StagnantLeadCounts counts = countsByOwner.get(ownerName);
            Datetime statusSince = lastStatusChangeByLeadId.containsKey(leadRecord.Id)
                ? lastStatusChangeByLeadId.get(leadRecord.Id)
                : leadRecord.CreatedDate;
            if (statusSince <= sevenDayCutoff) {
                counts.sevenDays++;
            }
            if (statusSince <= fourteenDayCutoff) {
                counts.fourteenDays++;
            }
            if (statusSince <= twentyOneDayCutoff) {
                counts.twentyOneDays++;
            }
        }
        return countsByOwner;
    }

    private static Integer leadStatusCount(String statusValue, Date createdAfter) {
        if (createdAfter == null) {
            return [SELECT COUNT() FROM Lead WHERE Status = :statusValue];
        }
        return [SELECT COUNT() FROM Lead WHERE Status = :statusValue AND CreatedDate >= :createdAfter];
    }

    private static Integer leadIntelligenceStatusCount(String statusValue) {
        return [
            SELECT COUNT()
            FROM Lead
            WHERE Status = :statusValue
            AND CreatedDate >= :LEAD_INTELLIGENCE_START
            AND Owner.Name NOT IN :LEAD_INTELLIGENCE_EXCLUDED_OWNERS
            AND (Status != 'New' OR Loan_Purpose__c != 'Refinance' OR Loan_Purpose__c = null OR CreatedDate >= :TODAY_DATE)
            AND (LeadSource != 'Past Client' OR Loan_Purpose__c != 'Refinance' OR LeadSource = null OR Loan_Purpose__c = null)
        ];
    }

    private static Integer transactionStatusCount(String statusValue, Date createdAfter) {
        if (createdAfter == null) {
            return [SELECT COUNT() FROM Transaction__c WHERE Status__c = :statusValue];
        }
        return [SELECT COUNT() FROM Transaction__c WHERE Status__c = :statusValue AND CreatedDate >= :createdAfter];
    }

    private static Integer activeTransactionCount() {
        return [SELECT COUNT() FROM Transaction__c WHERE CreatedDate >= 2024-01-01T00:00:00Z AND Status__c NOT IN :ACTIVE_TRANSACTION_EXCLUDES];
    }

    private static Integer closingFundingCount() {
        return [SELECT COUNT() FROM Transaction__c WHERE Status__c IN ('Closing', 'Funding')];
    }

    private static Integer pastClosingDateCount() {
        return [SELECT COUNT() FROM Transaction__c WHERE Closing_Date__c < :TODAY_DATE AND Status__c NOT IN :ACTIVE_TRANSACTION_EXCLUDES];
    }

    private static Integer fundedUnits(Date startDate, Date endDate) {
        return [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Status__c IN :FUNDED_STATUSES
            AND Funding_Date__c >= :startDate
            AND Funding_Date__c < :endDate
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
    }

    private static Decimal fundedVolume(Date startDate, Date endDate) {
        AggregateResult result = [
            SELECT SUM(Loan_Amount_1st__c) totalVolume
            FROM Transaction__c
            WHERE Status__c IN :FUNDED_STATUSES
            AND Funding_Date__c >= :startDate
            AND Funding_Date__c < :endDate
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
        return decimalValue(result.get('totalVolume'));
    }

    private static Decimal closingVolume(Date startDate, Date endDate) {
        AggregateResult result = [
            SELECT SUM(Loan_Amount_1st__c) totalVolume
            FROM Transaction__c
            WHERE Status__c NOT IN :ACTIVE_TRANSACTION_EXCLUDES
            AND Closing_Date__c >= :startDate
            AND Closing_Date__c < :endDate
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
        return decimalValue(result.get('totalVolume'));
    }

    private static Integer productionBoardUnits(Date startDate, Date endDate, Boolean fundedStatusesOnly) {
        if (fundedStatusesOnly) {
            return [
                SELECT COUNT()
                FROM Transaction__c
                WHERE Closing_Date__c >= :startDate
                AND Closing_Date__c < :endDate
                AND Status__c IN :FUNDED_STATUSES
                AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
            ];
        }
        return [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Closing_Date__c >= :startDate
            AND Closing_Date__c < :endDate
            AND Status__c NOT IN ('Cancelled', 'Canceled')
            AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
        ];
    }

    private static Decimal productionBoardVolume(Date startDate, Date endDate, Boolean fundedStatusesOnly) {
        AggregateResult result;
        if (fundedStatusesOnly) {
            result = [
                SELECT SUM(Loan_Amount_1st__c) totalVolume
                FROM Transaction__c
                WHERE Closing_Date__c >= :startDate
                AND Closing_Date__c < :endDate
                AND Status__c IN :FUNDED_STATUSES
                AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
            ];
        } else {
            result = [
                SELECT SUM(Loan_Amount_1st__c) totalVolume
                FROM Transaction__c
                WHERE Closing_Date__c >= :startDate
                AND Closing_Date__c < :endDate
                AND Status__c NOT IN ('Cancelled', 'Canceled')
                AND (Loan_Type_1st_TD__c = null OR Loan_Type_1st_TD__c != :DPA_SECOND_LOAN_TYPE)
            ];
        }
        return decimalValue(result.get('totalVolume'));
    }

    private static Decimal activePipelineVolume() {
        AggregateResult result = [
            SELECT SUM(Loan_Amount_1st__c) totalVolume
            FROM Transaction__c
            WHERE CreatedDate >= 2024-01-01T00:00:00Z
            AND Status__c NOT IN :ACTIVE_TRANSACTION_EXCLUDES
        ];
        return decimalValue(result.get('totalVolume'));
    }

    private static Integer activeTransactionUnits() {
        return [
            SELECT COUNT()
            FROM Transaction__c
            WHERE Status__c NOT IN :ACTIVE_TRANSACTION_EXCLUDES
        ];
    }

    private static Decimal activeTransactionVolume() {
        AggregateResult result = [
            SELECT SUM(Loan_Amount_1st__c) totalVolume
            FROM Transaction__c
            WHERE Status__c NOT IN :ACTIVE_TRANSACTION_EXCLUDES
        ];
        return decimalValue(result.get('totalVolume'));
    }

    private static Decimal averageLoanSize(Date startDate, Date endDate) {
        AggregateResult result = [
            SELECT AVG(Loan_Amount_1st__c) averageValue
            FROM Transaction__c
            WHERE Status__c IN :FUNDED_STATUSES
            AND Funding_Date__c >= :startDate
            AND Funding_Date__c < :endDate
        ];
        return decimalValue(result.get('averageValue'));
    }

    private static Integer fundedLoanOfficerCount() {
        AggregateResult result = [
            SELECT COUNT_DISTINCT(Loan_Officer__c) officerCount
            FROM Transaction__c
            WHERE Status__c IN :FUNDED_STATUSES
            AND Funding_Date__c >= :YEAR_START
            AND Loan_Officer__c != null
        ];
        return result.get('officerCount') == null ? 0 : (Integer) result.get('officerCount');
    }

    private static Integer realtorReferralLeadCount() {
        return [SELECT COUNT() FROM Lead WHERE CreatedDate = THIS_YEAR AND LeadSource = 'Realtor Referral'];
    }

    private static Integer activeRealtorLeadCount() {
        return [SELECT COUNT() FROM Lead WHERE IsConverted = false AND LeadSource = 'Realtor Referral' AND Status NOT IN :ACTIVE_LEAD_EXCLUDES];
    }

    private static Integer realtorLeadStatusCount(String statusValue) {
        return [SELECT COUNT() FROM Lead WHERE LeadSource = 'Realtor Referral' AND Status = :statusValue];
    }

    private static String monthLabel(Date monthDate) {
        return String.valueOf(monthDate.year()) + '-' + String.valueOf(monthDate.month()).leftPad(2, '0');
    }

    private static String monthKey(Integer yearValue, Integer monthValue) {
        return String.valueOf(yearValue) + '-' + String.valueOf(monthValue).leftPad(2, '0');
    }

    private static String monthDayYearLabel(Date value) {
        if (value == null) {
            return '';
        }
        return String.valueOf(value.month()) + '/' + String.valueOf(value.day()) + '/' + String.valueOf(value.year());
    }

    private static String shortMonthLabel(Integer monthNumber) {
        List<String> monthLabels = new List<String>{ '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' };
        return monthLabels[monthNumber];
    }

    private static Decimal decimalValue(Object value) {
        return value == null ? 0 : (Decimal) value;
    }

    private static Integer intValue(Integer value) {
        return value == null ? 0 : value;
    }

    private static String stringValue(Object value, String fallback) {
        String text = value == null ? null : String.valueOf(value);
        return String.isBlank(text) ? fallback : text;
    }

    private static String percentValue(Integer numerator, Integer denominator) {
        if (denominator == null || denominator == 0 || numerator == null) {
            return '0%';
        }
        Decimal ratio = (Decimal.valueOf(numerator) / Decimal.valueOf(denominator)) * 100;
        return String.valueOf(ratio.setScale(1)) + '%';
    }

    private static String formatDecimal(Decimal value) {
        return value == null ? '0.0' : String.valueOf(value.setScale(1));
    }

    private static String formatCurrency(Decimal value) {
        Decimal safeValue = value == null ? 0 : value.setScale(0);
        return '$' + safeValue.format();
    }

    public class PageData {
        @AuraEnabled public String pageKey;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String kicker;
        @AuraEnabled public Datetime generatedAt;
        @AuraEnabled public List<MetricCard> cards = new List<MetricCard>();
        @AuraEnabled public List<Section> sections = new List<Section>();
        @AuraEnabled public List<NavItem> navItems = new List<NavItem>();
    }

    public class MetricCard {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String helper;
        @AuraEnabled public String urlPath;
        @AuraEnabled public List<MetricBreakdown> breakdown = new List<MetricBreakdown>();
    }

    public class MetricBreakdown {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String urlPath;
    }

    private class StagnantLeadCounts {
        Integer sevenDays = 0;
        Integer fourteenDays = 0;
        Integer twentyOneDays = 0;
    }

    private class LoanOfficerBook {
        String name;
        Id userId;
        String filterType;
        String bookDefinition;

        LoanOfficerBook(String name, Id userId, String filterType, String bookDefinition) {
            this.name = name;
            this.userId = userId;
            this.filterType = filterType;
            this.bookDefinition = bookDefinition;
        }
    }

    private class LoanOfficerPerformance {
        String name;
        Id userId;
        String bookDefinition;
        Date startDate;
        Date endDate;
        Integer totalLeads = 0;
        Integer preApprovals = 0;
        Integer preApprovalsWithTransaction = 0;
        Integer closed = 0;
        Integer cancelled = 0;
        Integer active = 0;
        Integer recovered = 0;
        Integer transactionWithoutPreApproval = 0;
        Integer closedWithoutPreApproval = 0;
        Integer missingConvertedTransactionLinks = 0;
        Integer fundedUnits = 0;
        Decimal fundedVolume = 0;
        Decimal averageLoanSize = 0;
        Integer outboundCalls = 0;
        Integer activePreApprovals = 0;
        Integer activePreApprovalsWithoutRecentCall = 0;
        Integer blendedForecast = 0;

        LoanOfficerPerformance(LoanOfficerBook book, Date startDate, Date endDate) {
            this.name = book.name;
            this.userId = book.userId;
            this.bookDefinition = book.bookDefinition;
            this.startDate = startDate;
            this.endDate = endDate;
        }

        Integer closedAdjusted() {
            return closed + recovered;
        }

        Decimal leadToPreApprovalRate() {
            return ratio(preApprovals, totalLeads);
        }

        Decimal preApprovalToTransactionRate() {
            return ratio(preApprovalsWithTransaction, preApprovals);
        }

        Decimal pullThroughRateReported() {
            return ratio(closed, closed + cancelled);
        }

        Decimal pullThroughRateAdjusted() {
            return ratio(closedAdjusted(), closedAdjusted() + Math.max(0, cancelled - recovered));
        }

        Decimal leadToCloseRateReported() {
            return ratio(closed, totalLeads);
        }

        Decimal leadToCloseRateAdjusted() {
            return ratio(closedAdjusted(), totalLeads);
        }

        private Decimal ratio(Integer numerator, Integer denominator) {
            if (numerator == null || denominator == null || denominator == 0) {
                return 0;
            }
            return (Decimal.valueOf(numerator) / Decimal.valueOf(denominator)).setScale(4);
        }
    }

    public class Section {
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public List<String> columns = new List<String>();
        @AuraEnabled public List<DataRow> rows = new List<DataRow>();

        public Section(String title, String subtitle) {
            this.title = title;
            this.subtitle = subtitle;
        }
    }

    public class DataRow {
        @AuraEnabled public List<String> columns;
        @AuraEnabled public List<String> values;
        @AuraEnabled public String navApiName;
        @AuraEnabled public String urlPath;
        @AuraEnabled public List<String> cellUrlPaths;

        public DataRow(List<String> columns, List<String> values, String navApiName) {
            this(columns, values, navApiName, null);
        }

        public DataRow(List<String> columns, List<String> values, String navApiName, String urlPath) {
            this(columns, values, navApiName, urlPath, null);
        }

        public DataRow(List<String> columns, List<String> values, String navApiName, String urlPath, List<String> cellUrlPaths) {
            this.columns = columns;
            this.values = values;
            this.navApiName = navApiName;
            this.urlPath = urlPath;
            this.cellUrlPaths = cellUrlPaths;
        }
    }

    public class NavItem {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String tabApiName;

        public NavItem(String key, String label, String tabApiName) {
            this.key = key;
            this.label = label;
            this.tabApiName = tabApiName;
        }
    }
}