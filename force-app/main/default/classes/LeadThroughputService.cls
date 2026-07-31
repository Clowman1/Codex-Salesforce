/**
 * LeadThroughputService
 *
 * Use-case service that:
 * - resolves fixed date ranges
 * - orchestrates repo counts
 * - computes throughput percentages
 *
 * Throughput definitions (per requirement):
 * - New -> Pre-Approval: created in range; numerator = has Pre_Approval_Date__c
 * - New -> Post-Closed: created in range; numerator = has Transaction(Post_Closed_Date__c)
 * - Pre-Approval -> Post-Closed: pre-approved in range; numerator = has Transaction(Post_Closed_Date__c)
 *
 * Note: Post-Closed date itself is NOT constrained to the selected date range; only the
 * starting stage date (CreatedDate or Pre_Approval_Date__c) is constrained.
 */
public with sharing class LeadThroughputService {
    private LeadThroughputService() {}

    public enum DateRangeKey {
        TODAY,
        YESTERDAY,
        THIS_WEEK,
        LAST_WEEK,
        THIS_MONTH,
        LAST_MONTH,
        YTD
    }

    public class ThroughputMetric {
        @AuraEnabled public Integer numerator { get; set; }
        @AuraEnabled public Integer denominator { get; set; }
        @AuraEnabled public Decimal percent { get; set; }
    }

    public class TrendDelta {
        @AuraEnabled public Decimal deltaPercentPoints { get; set; } // current.percent - previous.percent
    }

    public class ThroughputMetricWithTrend {
        @AuraEnabled public ThroughputMetric current { get; set; }
        @AuraEnabled public ThroughputMetric previous { get; set; }
        @AuraEnabled public TrendDelta trend { get; set; }
    }

    public class TimelinePoint {
        @AuraEnabled public Date day { get; set; }
        @AuraEnabled public Decimal newToPreApprovalPercent { get; set; }
        @AuraEnabled public Decimal newToPostClosedPercent { get; set; }
        @AuraEnabled public Decimal preApprovalToPostClosedPercent { get; set; }

        // Raw counts (for chart annotations / debugging)
        @AuraEnabled public Integer newDenominator { get; set; }
        @AuraEnabled public Integer newToPreApprovalNumerator { get; set; }
        @AuraEnabled public Integer newToPostClosedNumerator { get; set; }
        @AuraEnabled public Integer preApprovalDenominator { get; set; }
        @AuraEnabled public Integer preApprovalToPostClosedNumerator { get; set; }
    }

    public class LeadThroughputResponse {
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }

        // Existing metrics (backwards compatibility)
        @AuraEnabled public ThroughputMetric newToPreApproval { get; set; }
        @AuraEnabled public ThroughputMetric newToPostClosed { get; set; }
        @AuraEnabled public ThroughputMetric preApprovalToPostClosed { get; set; }

        // Expanded for Magic Patterns UI
        @AuraEnabled public ThroughputMetricWithTrend newToPreApprovalWithTrend { get; set; }
        @AuraEnabled public ThroughputMetricWithTrend newToPostClosedWithTrend { get; set; }
        @AuraEnabled public ThroughputMetricWithTrend preApprovalToPostClosedWithTrend { get; set; }

        @AuraEnabled public List<TimelinePoint> timeline { get; set; }
    }

    public class LookupOption {
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String avatarUrl { get; set; }
    }

    public class OwnerThroughput {
        @AuraEnabled public Id ownerId { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String ownerAvatarUrl { get; set; }

        @AuraEnabled public ThroughputMetric newToPreApproval { get; set; }
        @AuraEnabled public ThroughputMetric newToPostClosed { get; set; }
        @AuraEnabled public ThroughputMetric preApprovalToPostClosed { get; set; }
    }

    public static LeadThroughputResponse getThroughput(String dateRangeKey, Id ownerId, String leadSource) {
        DateRangeKey key = parseDateRangeKey(dateRangeKey);

        DateRange range = resolveDateRange(key, Date.today());
        DateRange prevRange = resolvePreviousPeriod(range);

        // Normalize optional filters.
        String normalizedLeadSource = String.isBlank(leadSource) ? null : leadSource;

        // Current period
        DateTime createdStart = DateTime.newInstance(range.startDate, Time.newInstance(0, 0, 0, 0));
        DateTime createdEndExclusive = DateTime.newInstance(range.endDate.addDays(1), Time.newInstance(0, 0, 0, 0));

        LeadThroughputRepo.AggCounts newAgg =
            LeadThroughputRepo.selectCreatedAgg(createdStart, createdEndExclusive, ownerId, normalizedLeadSource);
        LeadThroughputRepo.AggCounts preAgg =
            LeadThroughputRepo.selectPreApprovalAgg(range.startDate, range.endDate, ownerId, normalizedLeadSource);

        // Previous period (same length)
        DateTime prevCreatedStart = DateTime.newInstance(prevRange.startDate, Time.newInstance(0, 0, 0, 0));
        DateTime prevCreatedEndExclusive = DateTime.newInstance(prevRange.endDate.addDays(1), Time.newInstance(0, 0, 0, 0));

        LeadThroughputRepo.AggCounts prevNewAgg =
            LeadThroughputRepo.selectCreatedAgg(prevCreatedStart, prevCreatedEndExclusive, ownerId, normalizedLeadSource);
        LeadThroughputRepo.AggCounts prevPreAgg =
            LeadThroughputRepo.selectPreApprovalAgg(prevRange.startDate, prevRange.endDate, ownerId, normalizedLeadSource);

        LeadThroughputResponse resp = new LeadThroughputResponse();
        resp.startDate = range.startDate;
        resp.endDate = range.endDate;

        resp.newToPreApproval = buildMetric(newAgg.preAppNum, newAgg.denom);
        resp.newToPostClosed = buildMetric(newAgg.postClosedNum, newAgg.denom);
        resp.preApprovalToPostClosed = buildMetric(preAgg.postClosedNum, preAgg.denom);

        ThroughputMetric prevNewToPre = buildMetric(prevNewAgg.preAppNum, prevNewAgg.denom);
        ThroughputMetric prevNewToPost = buildMetric(prevNewAgg.postClosedNum, prevNewAgg.denom);
        ThroughputMetric prevPreToPost = buildMetric(prevPreAgg.postClosedNum, prevPreAgg.denom);

        resp.newToPreApprovalWithTrend = buildMetricWithTrend(resp.newToPreApproval, prevNewToPre);
        resp.newToPostClosedWithTrend = buildMetricWithTrend(resp.newToPostClosed, prevNewToPost);
        resp.preApprovalToPostClosedWithTrend = buildMetricWithTrend(resp.preApprovalToPostClosed, prevPreToPost);

        // Timeline window: last <=7 days within selected range.
        Date timelineEnd = range.endDate;
        Date timelineStart = range.startDate;
        Date candidateStart = timelineEnd.addDays(-6);
        if (candidateStart > timelineStart) {
            timelineStart = candidateStart;
        }
        resp.timeline = LeadThroughputRepo.selectTimeline(timelineStart, timelineEnd, ownerId, normalizedLeadSource);

        return resp;
    }

    public static List<LookupOption> getActiveLoanOfficers(Integer limitSize) {
        Integer effectiveLimit = (limitSize == null) ? 500 : limitSize;
        effectiveLimit = Math.max(1, Math.min(2000, effectiveLimit));

        List<User> users = LeadThroughputRepo.selectActiveLoanOfficerUsers(effectiveLimit);
        List<LookupOption> options = new List<LookupOption>();
        for (User u : users) {
            LookupOption o = new LookupOption();
            o.value = (String) u.Id;
            o.label = u.Name;
            o.avatarUrl = u.Headshot_URL__c;
            options.add(o);
        }
        return options;
    }

    public static List<OwnerThroughput> getThroughputByOwners(String dateRangeKey, List<Id> ownerIds, String leadSource) {
        return getThroughputByOwners(dateRangeKey, null, null, ownerIds, leadSource);
    }

    /**
     * RHL2-276: New timeframe-based API (mutually exclusive by type), including Quarter+Year multi-select union.
     * - timeframeType: QUARTER_YEAR | YTD | LAST_YEAR | TWO_YEARS_AGO
     * - quarterYearKeys: e.g., ["2024-Q2", "2025-Q1"] (required for QUARTER_YEAR)
     */
    public static List<OwnerThroughput> getThroughputByOwnersV2(
        String timeframeType,
        List<String> quarterYearKeys,
        List<Id> ownerIds,
        String leadSource,
        String loanPurpose
    ) {
        List<LeadThroughputTimeframe.DateWindow> windows =
            LeadThroughputTimeframe.resolveDateWindows(timeframeType, quarterYearKeys, Date.today());
        return getThroughputByOwnersForWindows(windows, ownerIds, leadSource, loanPurpose);
    }

    public static List<OwnerThroughput> getThroughputByOwners(
        String dateRangeKey,
        Date startDate,
        Date endDate,
        List<Id> ownerIds,
        String leadSource
    ) {
        DateRange range = resolveDateRangeFromInputs(dateRangeKey, startDate, endDate, Date.today());
        List<LeadThroughputTimeframe.DateWindow> windows = new List<LeadThroughputTimeframe.DateWindow>{
            new LeadThroughputTimeframe.DateWindow(range.startDate, range.endDate)
        };
        return getThroughputByOwnersForWindows(windows, ownerIds, leadSource, null);
    }

    private static List<OwnerThroughput> getThroughputByOwnersForWindows(
        List<LeadThroughputTimeframe.DateWindow> windows,
        List<Id> ownerIds,
        String leadSource,
        String loanPurpose
    ) {
        if (windows == null || windows.isEmpty()) {
            return new List<OwnerThroughput>();
        }

        String normalizedLeadSource = String.isBlank(leadSource) ? null : leadSource;
        String normalizedLoanPurpose = normalizeLoanPurposeFilter(loanPurpose);

        // Determine which owners to include.
        Set<Id> ownerIdSet = new Set<Id>();
        if (ownerIds != null) {
            ownerIdSet.addAll(ownerIds);
        }

        Map<Id, User> usersById;
        if (ownerIdSet.isEmpty()) {
            usersById = new Map<Id, User>();
            for (User u : LeadThroughputRepo.selectActiveLoanOfficerUsers(2000)) {
                usersById.put(u.Id, u);
            }
            ownerIdSet.addAll(usersById.keySet());
        } else {
            // Enforce that only active Loan Officer-profile users are included.
            usersById = LeadThroughputRepo.selectActiveLoanOfficerUsersByIds(ownerIdSet);
            ownerIdSet = new Set<Id>(usersById.keySet());
        }

        if (ownerIdSet.isEmpty()) {
            return new List<OwnerThroughput>();
        }

        Map<Id, LeadThroughputRepo.AggCounts> createdAggByOwner;
        Map<Id, LeadThroughputRepo.AggCounts> preAggByOwner;

        if (windows.size() == 1) {
            LeadThroughputTimeframe.DateWindow w = windows[0];
            DateTime createdStart = DateTime.newInstance(w.startDate, Time.newInstance(0, 0, 0, 0));
            DateTime createdEndExclusive = DateTime.newInstance(w.endDate.addDays(1), Time.newInstance(0, 0, 0, 0));

            createdAggByOwner =
                LeadThroughputRepo.selectCreatedAggByOwner(
                    createdStart,
                    createdEndExclusive,
                    ownerIdSet,
                    normalizedLeadSource,
                    normalizedLoanPurpose
                );
            preAggByOwner =
                LeadThroughputRepo.selectPreApprovalAggByOwner(
                    w.startDate,
                    w.endDate,
                    ownerIdSet,
                    normalizedLeadSource,
                    normalizedLoanPurpose
                );
        } else {
            List<LeadThroughputTimeframe.CreatedDateWindow> createdWindows = LeadThroughputTimeframe.toCreatedDateWindows(windows);
            createdAggByOwner =
                LeadThroughputRepo.selectCreatedAggByOwnerForWindows(
                    createdWindows,
                    ownerIdSet,
                    normalizedLeadSource,
                    normalizedLoanPurpose
                );
            preAggByOwner =
                LeadThroughputRepo.selectPreApprovalAggByOwnerForWindows(
                    windows,
                    ownerIdSet,
                    normalizedLeadSource,
                    normalizedLoanPurpose
                );
        }

        List<OwnerThroughput> results = new List<OwnerThroughput>();
        for (Id ownerId : ownerIdSet) {
            User u = usersById.get(ownerId);
            OwnerThroughput row = new OwnerThroughput();
            row.ownerId = ownerId;
            row.ownerName = (u == null) ? 'Unknown' : u.Name;
            row.ownerAvatarUrl = (u == null) ? null : u.Headshot_URL__c;

            LeadThroughputRepo.AggCounts createdAgg = createdAggByOwner.get(ownerId);
            if (createdAgg == null) {
                createdAgg = new LeadThroughputRepo.AggCounts(0, 0, 0);
            }
            LeadThroughputRepo.AggCounts preAgg = preAggByOwner.get(ownerId);
            if (preAgg == null) {
                preAgg = new LeadThroughputRepo.AggCounts(0, null, 0);
            }

            row.newToPreApproval = buildMetric(createdAgg.preAppNum, createdAgg.denom);
            row.newToPostClosed = buildMetric(createdAgg.postClosedNum, createdAgg.denom);
            row.preApprovalToPostClosed = buildMetric(preAgg.postClosedNum, preAgg.denom);

            results.add(row);
        }

        // Stable ordering for UI.
        results.sort(new OwnerThroughputSorter());
        return results;
    }

    private class OwnerThroughputSorter implements Comparator<OwnerThroughput> {
        public Integer compare(OwnerThroughput x, OwnerThroughput y) {
            String xn = (x == null || x.ownerName == null) ? '' : x.ownerName;
            String yn = (y == null || y.ownerName == null) ? '' : y.ownerName;
            return xn.toLowerCase().compareTo(yn.toLowerCase());
        }
    }

    private static ThroughputMetricWithTrend buildMetricWithTrend(ThroughputMetric current, ThroughputMetric previous) {
        ThroughputMetricWithTrend m = new ThroughputMetricWithTrend();
        m.current = current;
        m.previous = previous;
        TrendDelta t = new TrendDelta();
        Decimal curPct = (current == null || current.percent == null) ? 0 : current.percent;
        Decimal prevPct = (previous == null || previous.percent == null) ? 0 : previous.percent;
        t.deltaPercentPoints = (curPct - prevPct).setScale(1);
        m.trend = t;
        return m;
    }

    private static ThroughputMetric buildMetric(Integer numerator, Integer denominator) {
        ThroughputMetric m = new ThroughputMetric();
        m.numerator = (numerator == null) ? 0 : numerator;
        m.denominator = (denominator == null) ? 0 : denominator;
        m.percent = calculatePercent(m.numerator, m.denominator);
        return m;
    }

    private static Decimal calculatePercent(Integer numerator, Integer denominator) {
        if (denominator == null || denominator == 0) {
            return 0;
        }
        Decimal pct = (Decimal.valueOf(numerator) * 100) / Decimal.valueOf(denominator);
        return pct.setScale(1);
    }

    private static DateRangeKey parseDateRangeKey(String rawKey) {
        if (String.isBlank(rawKey)) {
            return DateRangeKey.TODAY;
        }
        try {
            return DateRangeKey.valueOf(rawKey.trim().toUpperCase());
        } catch (Exception e) {
            return DateRangeKey.TODAY;
        }
    }

    private class DateRange {
        public Date startDate { get; private set; }
        public Date endDate { get; private set; }
        public DateRange(Date startDate, Date endDate) {
            this.startDate = startDate;
            this.endDate = endDate;
        }
    }

    private static DateRange resolvePreviousPeriod(DateRange current) {
        Integer days = current.startDate.daysBetween(current.endDate) + 1;
        Date prevEnd = current.startDate.addDays(-1);
        Date prevStart = prevEnd.addDays(-(days - 1));
        return new DateRange(prevStart, prevEnd);
    }

    private static DateRange resolveDateRange(DateRangeKey key, Date today) {
        Date startDate;
        Date endDate;

        switch on key {
            when TODAY {
                startDate = today;
                endDate = today;
            }
            when YESTERDAY {
                startDate = today.addDays(-1);
                endDate = today.addDays(-1);
            }
            when THIS_WEEK {
                Date monday = today.toStartOfWeek().addDays(1); // Monday, US-based org convention (see existing code)
                if (monday > today) {
                    monday = monday.addDays(-7); // handle Sunday so week-to-date remains sensible
                }
                startDate = monday;
                endDate = today;
            }
            when LAST_WEEK {
                Date monday = today.toStartOfWeek().addDays(1);
                if (monday > today) {
                    monday = monday.addDays(-7);
                }
                startDate = monday.addDays(-7);
                endDate = monday.addDays(-1);
            }
            when THIS_MONTH {
                startDate = Date.newInstance(today.year(), today.month(), 1);
                endDate = today;
            }
            when LAST_MONTH {
                Date firstOfThisMonth = Date.newInstance(today.year(), today.month(), 1);
                Date firstOfLastMonth = firstOfThisMonth.addMonths(-1);
                startDate = firstOfLastMonth;
                endDate = firstOfThisMonth.addDays(-1);
            }
            when YTD {
                startDate = Date.newInstance(today.year(), 1, 1);
                endDate = today;
            }
        }

        return new DateRange(startDate, endDate);
    }

    private static DateRange resolveDateRangeFromInputs(String dateRangeKey, Date startDate, Date endDate, Date today) {
        // If caller provides an explicit date window, use it.
        if (startDate != null || endDate != null) {
            if (startDate == null || endDate == null) {
                throw new AuraHandledException('Both startDate and endDate are required when filtering by a custom timeframe.');
            }
            if (startDate > endDate) {
                throw new AuraHandledException('startDate must be on or before endDate.');
            }
            return new DateRange(startDate, endDate);
        }

        // Otherwise, fall back to the predefined date buckets.
        DateRangeKey key = parseDateRangeKey(dateRangeKey);
        return resolveDateRange(key, today);
    }

    private static String normalizeLoanPurposeFilter(String loanPurpose) {
        if (String.isBlank(loanPurpose)) {
            return null;
        }
        String key = loanPurpose.trim().toUpperCase();
        if (key == 'ALL') {
            return null;
        }
        if (key == 'PURCHASE' || key == 'REFINANCE' || key == 'BOTH_PURCHASE_REFINANCE') {
            return key;
        }
        return null;
    }
}