/**
 * LeadThroughputRepo
 *
 * Repo/Selector layer for Lead throughput metrics.
 * - SOQL only (no DML)
 * - Uses aggregate COUNT() queries for performance
 */
public with sharing class LeadThroughputRepo {
    private LeadThroughputRepo() {}

    public static Integer countNewLeads(DateTime startInclusive, DateTime endExclusive, Id ownerId, String leadSource) {
        AggCounts a = selectCreatedAgg(startInclusive, endExclusive, ownerId, leadSource);
        return a.denom;
    }

    public static Integer countNewLeadsWithPreApproval(DateTime startInclusive, DateTime endExclusive, Id ownerId, String leadSource) {
        AggCounts a = selectCreatedAgg(startInclusive, endExclusive, ownerId, leadSource);
        return a.preAppNum;
    }

    public static Integer countNewLeadsWithPostClosed(DateTime startInclusive, DateTime endExclusive, Id ownerId, String leadSource) {
        AggCounts a = selectCreatedAgg(startInclusive, endExclusive, ownerId, leadSource);
        return a.postClosedNum;
    }

    public static Integer countPreApprovedLeads(Date startDate, Date endDate, Id ownerId, String leadSource) {
        AggCounts a = selectPreApprovalAgg(startDate, endDate, ownerId, leadSource);
        return a.denom;
    }

    public static Integer countPreApprovedLeadsWithPostClosed(Date startDate, Date endDate, Id ownerId, String leadSource) {
        AggCounts a = selectPreApprovalAgg(startDate, endDate, ownerId, leadSource);
        return a.postClosedNum;
    }

    public class AggCounts {
        public Integer denom { get; private set; }
        public Integer preAppNum { get; private set; }
        public Integer postClosedNum { get; private set; }
        public AggCounts(Integer denom, Integer preAppNum, Integer postClosedNum) {
            this.denom = denom == null ? 0 : denom;
            this.preAppNum = preAppNum == null ? 0 : preAppNum;
            this.postClosedNum = postClosedNum == null ? 0 : postClosedNum;
        }
    }

    public static AggCounts selectCreatedAgg(DateTime startInclusive, DateTime endExclusive, Id ownerId, String leadSource) {
        List<String> clauses = buildCreatedDateClauses(startInclusive, endExclusive, ownerId, leadSource);
        String soql =
            'SELECT COUNT(Id) denom, ' +
            'COUNT(Pre_Approval_Date__c) preAppNum, ' +
            'COUNT(Converted_Transaction_ID__r.Post_Closed_Date__c) postClosedNum ' +
            'FROM Lead WHERE ' + String.join(clauses, ' AND ');

        AggregateResult ar = (AggregateResult) Database.query(soql);
        return new AggCounts(
            (Integer) ar.get('denom'),
            (Integer) ar.get('preAppNum'),
            (Integer) ar.get('postClosedNum')
        );
    }

    public static List<User> selectActiveUsers(Integer limitSize) {
        return [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
            ORDER BY Name
            LIMIT :limitSize
        ];
    }

    public static List<User> selectActiveLoanOfficerUsers(Integer limitSize) {
        Id loanOfficerProfileId = selectLoanOfficerProfileId();
        if (loanOfficerProfileId == null) {
            return new List<User>();
        }

        return [
            SELECT Id, Name, Headshot_URL__c
            FROM User
            WHERE IsActive = true
            AND ProfileId = :loanOfficerProfileId
            ORDER BY Name
            LIMIT :limitSize
        ];
    }

    public static Map<Id, User> selectActiveLoanOfficerUsersByIds(Set<Id> userIds) {
        Map<Id, User> byId = new Map<Id, User>();
        if (userIds == null || userIds.isEmpty()) {
            return byId;
        }
        Id loanOfficerProfileId = selectLoanOfficerProfileId();
        if (loanOfficerProfileId == null) {
            return byId;
        }
        for (User u : [
            SELECT Id, Name, Headshot_URL__c
            FROM User
            WHERE Id IN :userIds
            AND IsActive = true
            AND ProfileId = :loanOfficerProfileId
        ]) {
            byId.put(u.Id, u);
        }
        return byId;
    }

    private static Id selectLoanOfficerProfileId() {
        try {
            return [SELECT Id FROM Profile WHERE Name = 'Loan Officer Profile' LIMIT 1].Id;
        } catch (Exception e) {
            return null;
        }
    }

    public static Map<Id, User> selectUsersByIds(Set<Id> userIds) {
        Map<Id, User> byId = new Map<Id, User>();
        if (userIds == null || userIds.isEmpty()) {
            return byId;
        }
        for (User u : [
            SELECT Id, Name
            FROM User
            WHERE Id IN :userIds
        ]) {
            byId.put(u.Id, u);
        }
        return byId;
    }

    public static Map<Id, AggCounts> selectCreatedAggByOwner(
        DateTime startInclusive,
        DateTime endExclusive,
        Set<Id> ownerIds,
        String leadSource,
        String loanPurpose
    ) {
        List<String> clauses = new List<String>{
            'CreatedDate >= :startInclusive',
            'CreatedDate < :endExclusive'
        };
        if (ownerIds != null && !ownerIds.isEmpty()) {
            clauses.add('OwnerId IN :ownerIds');
        }
        if (!String.isBlank(leadSource)) {
            clauses.add('LeadSource = :leadSource');
        }
        String loanPurposeClause = buildLoanPurposeClause(loanPurpose);
        if (!String.isBlank(loanPurposeClause)) {
            clauses.add(loanPurposeClause);
        }

        String soql =
            'SELECT OwnerId ownerId, ' +
            'COUNT(Id) denom, ' +
            'COUNT(Pre_Approval_Date__c) preAppNum, ' +
            'COUNT(Converted_Transaction_ID__r.Post_Closed_Date__c) postClosedNum ' +
            'FROM Lead WHERE ' + String.join(clauses, ' AND ') +
            ' GROUP BY OwnerId';

        List<AggregateResult> ars = (List<AggregateResult>) Database.query(soql);
        Map<Id, AggCounts> byOwner = new Map<Id, AggCounts>();
        for (AggregateResult ar : ars) {
            Id ownerId = (Id) ar.get('ownerId');
            byOwner.put(
                ownerId,
                new AggCounts(
                    (Integer) ar.get('denom'),
                    (Integer) ar.get('preAppNum'),
                    (Integer) ar.get('postClosedNum')
                )
            );
        }
        return byOwner;
    }

    /**
     * RHL2-276: CreatedDate-based aggregates supporting a union of multiple date windows (Quarter+Year multi-select).
     * Uses Database.queryWithBinds so we can bind a dynamic number of window start/end values safely.
     */
    public static Map<Id, AggCounts> selectCreatedAggByOwnerForWindows(
        List<LeadThroughputTimeframe.CreatedDateWindow> windows,
        Set<Id> ownerIds,
        String leadSource,
        String loanPurpose
    ) {
        if (windows == null || windows.isEmpty()) {
            return new Map<Id, AggCounts>();
        }

        Map<String, Object> binds = new Map<String, Object>();
        String dateClause = buildCreatedDateUnionClause(windows, binds);

        List<String> clauses = new List<String>{ dateClause };
        if (ownerIds != null && !ownerIds.isEmpty()) {
            clauses.add('OwnerId IN :ownerIds');
            binds.put('ownerIds', ownerIds);
        }
        if (!String.isBlank(leadSource)) {
            clauses.add('LeadSource = :leadSource');
            binds.put('leadSource', leadSource);
        }
        String loanPurposeClause = buildLoanPurposeClause(loanPurpose);
        if (!String.isBlank(loanPurposeClause)) {
            clauses.add(loanPurposeClause);
        }

        String soql =
            'SELECT OwnerId ownerId, ' +
            'COUNT(Id) denom, ' +
            'COUNT(Pre_Approval_Date__c) preAppNum, ' +
            'COUNT(Converted_Transaction_ID__r.Post_Closed_Date__c) postClosedNum ' +
            'FROM Lead WHERE ' + String.join(clauses, ' AND ') +
            ' GROUP BY OwnerId';

        List<AggregateResult> ars = (List<AggregateResult>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
        Map<Id, AggCounts> byOwner = new Map<Id, AggCounts>();
        for (AggregateResult ar : ars) {
            Id ownerId = (Id) ar.get('ownerId');
            byOwner.put(
                ownerId,
                new AggCounts(
                    (Integer) ar.get('denom'),
                    (Integer) ar.get('preAppNum'),
                    (Integer) ar.get('postClosedNum')
                )
            );
        }
        return byOwner;
    }

    public static Map<Id, AggCounts> selectPreApprovalAggByOwner(
        Date startDate,
        Date endDate,
        Set<Id> ownerIds,
        String leadSource,
        String loanPurpose
    ) {
        List<String> clauses = new List<String>{
            'Pre_Approval_Date__c >= :startDate',
            'Pre_Approval_Date__c <= :endDate'
        };
        if (ownerIds != null && !ownerIds.isEmpty()) {
            clauses.add('OwnerId IN :ownerIds');
        }
        if (!String.isBlank(leadSource)) {
            clauses.add('LeadSource = :leadSource');
        }
        String loanPurposeClause = buildLoanPurposeClause(loanPurpose);
        if (!String.isBlank(loanPurposeClause)) {
            clauses.add(loanPurposeClause);
        }

        String soql =
            'SELECT OwnerId ownerId, ' +
            'COUNT(Id) denom, ' +
            'COUNT(Converted_Transaction_ID__r.Post_Closed_Date__c) postClosedNum ' +
            'FROM Lead WHERE ' + String.join(clauses, ' AND ') +
            ' GROUP BY OwnerId';

        List<AggregateResult> ars = (List<AggregateResult>) Database.query(soql);
        Map<Id, AggCounts> byOwner = new Map<Id, AggCounts>();
        for (AggregateResult ar : ars) {
            Id ownerId = (Id) ar.get('ownerId');
            byOwner.put(
                ownerId,
                new AggCounts(
                    (Integer) ar.get('denom'),
                    null,
                    (Integer) ar.get('postClosedNum')
                )
            );
        }
        return byOwner;
    }

    /**
     * RHL2-276: Pre-Approval date-based aggregates supporting a union of multiple date windows (Quarter+Year multi-select).
     */
    public static Map<Id, AggCounts> selectPreApprovalAggByOwnerForWindows(
        List<LeadThroughputTimeframe.DateWindow> windows,
        Set<Id> ownerIds,
        String leadSource,
        String loanPurpose
    ) {
        if (windows == null || windows.isEmpty()) {
            return new Map<Id, AggCounts>();
        }

        Map<String, Object> binds = new Map<String, Object>();
        String dateClause = buildPreApprovalDateUnionClause(windows, binds);

        List<String> clauses = new List<String>{ dateClause };
        if (ownerIds != null && !ownerIds.isEmpty()) {
            clauses.add('OwnerId IN :ownerIds');
            binds.put('ownerIds', ownerIds);
        }
        if (!String.isBlank(leadSource)) {
            clauses.add('LeadSource = :leadSource');
            binds.put('leadSource', leadSource);
        }
        String loanPurposeClause = buildLoanPurposeClause(loanPurpose);
        if (!String.isBlank(loanPurposeClause)) {
            clauses.add(loanPurposeClause);
        }

        String soql =
            'SELECT OwnerId ownerId, ' +
            'COUNT(Id) denom, ' +
            'COUNT(Converted_Transaction_ID__r.Post_Closed_Date__c) postClosedNum ' +
            'FROM Lead WHERE ' + String.join(clauses, ' AND ') +
            ' GROUP BY OwnerId';

        List<AggregateResult> ars = (List<AggregateResult>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
        Map<Id, AggCounts> byOwner = new Map<Id, AggCounts>();
        for (AggregateResult ar : ars) {
            Id ownerId = (Id) ar.get('ownerId');
            byOwner.put(
                ownerId,
                new AggCounts(
                    (Integer) ar.get('denom'),
                    null,
                    (Integer) ar.get('postClosedNum')
                )
            );
        }
        return byOwner;
    }

    public static AggCounts selectPreApprovalAgg(Date startDate, Date endDate, Id ownerId, String leadSource) {
        List<String> clauses = buildPreApprovalDateClauses(startDate, endDate, ownerId, leadSource);
        String soql =
            'SELECT COUNT(Id) denom, ' +
            'COUNT(Converted_Transaction_ID__r.Post_Closed_Date__c) postClosedNum ' +
            'FROM Lead WHERE ' + String.join(clauses, ' AND ');

        AggregateResult ar = (AggregateResult) Database.query(soql);
        return new AggCounts(
            (Integer) ar.get('denom'),
            null,
            (Integer) ar.get('postClosedNum')
        );
    }

    public class TimelineAgg {
        public Date day;
        public Integer newDenom;
        public Integer newPreAppNum;
        public Integer newPostClosedNum;

        public Integer preAppDenom;
        public Integer preAppPostClosedNum;
        public TimelineAgg(Date day) {
            this.day = day;
            newDenom = 0;
            newPreAppNum = 0;
            newPostClosedNum = 0;
            preAppDenom = 0;
            preAppPostClosedNum = 0;
        }
    }

    public static List<LeadThroughputService.TimelinePoint> selectTimeline(Date startDate, Date endDate, Id ownerId, String leadSource) {
        // Build an ordered list of dates in range.
        List<Date> days = new List<Date>();
        for (Date d = startDate; d <= endDate; d = d.addDays(1)) {
            days.add(d);
        }

        Map<Date, TimelineAgg> byDay = new Map<Date, TimelineAgg>();
        for (Date d : days) {
            byDay.put(d, new TimelineAgg(d));
        }

        // Created-date bucket aggregates
        for (AggregateResult ar : queryCreatedDateDailyAgg(startDate, endDate, ownerId, leadSource)) {
            Date day = (Date) ar.get('day');
            if (!byDay.containsKey(day)) {
                continue;
            }
            TimelineAgg agg = byDay.get(day);
            agg.newDenom = ((Integer) ar.get('denom'));
            agg.newPreAppNum = ((Integer) ar.get('preAppNum'));
            agg.newPostClosedNum = ((Integer) ar.get('postClosedNum'));
        }

        // Pre-approval bucket aggregates
        for (AggregateResult ar : queryPreApprovalDailyAgg(startDate, endDate, ownerId, leadSource)) {
            Date day = (Date) ar.get('day');
            if (!byDay.containsKey(day)) {
                continue;
            }
            TimelineAgg agg = byDay.get(day);
            agg.preAppDenom = ((Integer) ar.get('preAppDenom'));
            agg.preAppPostClosedNum = ((Integer) ar.get('postClosedFromPreAppNum'));
        }

        // Build timeline DTO
        List<LeadThroughputService.TimelinePoint> points = new List<LeadThroughputService.TimelinePoint>();
        for (Date d : days) {
            TimelineAgg a = byDay.get(d);
            LeadThroughputService.TimelinePoint p = new LeadThroughputService.TimelinePoint();
            p.day = d;

            p.newToPreApprovalPercent = safePercent(a.newPreAppNum, a.newDenom);
            p.newToPostClosedPercent = safePercent(a.newPostClosedNum, a.newDenom);
            p.preApprovalToPostClosedPercent = safePercent(a.preAppPostClosedNum, a.preAppDenom);

            p.newDenominator = a.newDenom;
            p.newToPreApprovalNumerator = a.newPreAppNum;
            p.newToPostClosedNumerator = a.newPostClosedNum;
            p.preApprovalDenominator = a.preAppDenom;
            p.preApprovalToPostClosedNumerator = a.preAppPostClosedNum;

            points.add(p);
        }
        return points;
    }

    private static Decimal safePercent(Integer numerator, Integer denominator) {
        if (denominator == null || denominator == 0) {
            return 0;
        }
        Decimal pct = (Decimal.valueOf(numerator) * 100) / Decimal.valueOf(denominator);
        return pct.setScale(1);
    }

    private static List<AggregateResult> queryCreatedDateDailyAgg(Date startDate, Date endDate, Id ownerId, String leadSource) {
        DateTime startInclusiveDt = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        DateTime endExclusiveDt = DateTime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0));

        List<String> clauses = buildCreatedDateClauses(startInclusiveDt, endExclusiveDt, ownerId, leadSource);
        String soql =
            'SELECT DAY_ONLY(CreatedDate) day, ' +
            'COUNT(Id) denom, ' +
            'COUNT(Pre_Approval_Date__c) preAppNum, ' +
            'COUNT(Converted_Transaction_ID__r.Post_Closed_Date__c) postClosedNum ' +
            'FROM Lead WHERE ' + String.join(clauses, ' AND ') +
            ' GROUP BY DAY_ONLY(CreatedDate) ' +
            ' ORDER BY DAY_ONLY(CreatedDate)';

        // Bind vars must exist in this scope with names referenced in the SOQL.
        DateTime startInclusive = startInclusiveDt;
        DateTime endExclusive = endExclusiveDt;

        return (List<AggregateResult>) Database.query(soql);
    }

    private static List<AggregateResult> queryPreApprovalDailyAgg(Date startDate, Date endDate, Id ownerId, String leadSource) {
        List<String> clauses = buildPreApprovalDateClauses(startDate, endDate, ownerId, leadSource);
        String soql =
            'SELECT Pre_Approval_Date__c day, ' +
            'COUNT(Id) preAppDenom, ' +
            'COUNT(Converted_Transaction_ID__r.Post_Closed_Date__c) postClosedFromPreAppNum ' +
            'FROM Lead WHERE ' + String.join(clauses, ' AND ') +
            ' GROUP BY Pre_Approval_Date__c ' +
            ' ORDER BY Pre_Approval_Date__c';

        return (List<AggregateResult>) Database.query(soql);
    }

    private static List<String> buildCreatedDateClauses(DateTime startInclusive, DateTime endExclusive, Id ownerId, String leadSource) {
        List<String> clauses = new List<String>{
            'CreatedDate >= :startInclusive',
            'CreatedDate < :endExclusive'
        };
        if (ownerId != null) {
            clauses.add('OwnerId = :ownerId');
        }
        if (!String.isBlank(leadSource)) {
            clauses.add('LeadSource = :leadSource');
        }
        return clauses;
    }

    private static String buildCreatedDateUnionClause(
        List<LeadThroughputTimeframe.CreatedDateWindow> windows,
        Map<String, Object> binds
    ) {
        List<String> orClauses = new List<String>();
        Integer idx = 0;
        for (LeadThroughputTimeframe.CreatedDateWindow w : windows) {
            String startKey = 'start' + String.valueOf(idx);
            String endKey = 'end' + String.valueOf(idx);
            binds.put(startKey, w.startInclusive);
            binds.put(endKey, w.endExclusive);
            orClauses.add('(CreatedDate >= :' + startKey + ' AND CreatedDate < :' + endKey + ')');
            idx++;
        }
        return '(' + String.join(orClauses, ' OR ') + ')';
    }

    // NOTE: buildBindsForCreatedDate removed as we no longer use the legacy bind-map pattern.

    private static List<String> buildPreApprovalDateClauses(Date startDate, Date endDate, Id ownerId, String leadSource) {
        List<String> clauses = new List<String>{
            'Pre_Approval_Date__c >= :startDate',
            'Pre_Approval_Date__c <= :endDate'
        };
        if (ownerId != null) {
            clauses.add('OwnerId = :ownerId');
        }
        if (!String.isBlank(leadSource)) {
            clauses.add('LeadSource = :leadSource');
        }
        return clauses;
    }

    private static String buildPreApprovalDateUnionClause(
        List<LeadThroughputTimeframe.DateWindow> windows,
        Map<String, Object> binds
    ) {
        List<String> orClauses = new List<String>();
        Integer idx = 0;
        for (LeadThroughputTimeframe.DateWindow w : windows) {
            String startKey = 'startDate' + String.valueOf(idx);
            String endKey = 'endDate' + String.valueOf(idx);
            binds.put(startKey, w.startDate);
            binds.put(endKey, w.endDate);
            orClauses.add('(Pre_Approval_Date__c >= :' + startKey + ' AND Pre_Approval_Date__c <= :' + endKey + ')');
            idx++;
        }
        return '(' + String.join(orClauses, ' OR ') + ')';
    }

    private static String buildLoanPurposeClause(String loanPurpose) {
        if (String.isBlank(loanPurpose)) {
            return null;
        }
        String key = loanPurpose.trim().toUpperCase();
        String purchaseClause = 'Loan_Purpose__c includes (\'Purchase\')';
        String refinanceClause =
            '(Loan_Purpose__c includes (\'Refinance\') ' +
            'OR Loan_Purpose__c includes (\'Refinance Cash-Out\') ' +
            'OR Loan_Purpose__c includes (\'Refinance Rate & Term\') ' +
            'OR Loan_Purpose__c includes (\'Cash-Out Refinance\') ' +
            'OR Loan_Purpose__c includes (\'NoCash-Out Refinance\') ' +
            'OR Loan_Purpose__c includes (\'Refinance No Cash-Out\') ' +
            'OR Loan_Purpose__c includes (\'Refinance Debt Consolidation\'))';

        if (key == 'PURCHASE') {
            return purchaseClause;
        }
        if (key == 'REFINANCE') {
            return refinanceClause;
        }
        if (key == 'BOTH_PURCHASE_REFINANCE') {
            return '(' + purchaseClause + ' OR ' + refinanceClause + ')';
        }
        return null;
    }

    // NOTE: buildBindsForPreApprovalDate removed as we no longer use the legacy bind-map pattern.

    // NOTE: queryLeadCount removed in favor of richer aggregate queries to support trends + timeline.
}