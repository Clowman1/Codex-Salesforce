/**
 * LeadThroughputDrilldownRepo
 *
 * Repo/Selector layer for Throughput Analytics drill-down.
 * - SOQL only (no DML)
 * - Numerator-only record sets, exactly matching tile definitions.
 */
public with sharing class LeadThroughputDrilldownRepo {
    private LeadThroughputDrilldownRepo() {}

    public class DrilldownPage {
        public Integer totalCount { get; private set; }
        public List<Lead> leads { get; private set; }
        public DrilldownPage(Integer totalCount, List<Lead> leads) {
            this.totalCount = (totalCount == null) ? 0 : totalCount;
            this.leads = (leads == null) ? new List<Lead>() : leads;
        }
    }

    public static DrilldownPage selectNumeratorLeadsForTile(
        List<LeadThroughputTimeframe.DateWindow> windows,
        Id ownerId,
        String leadSource,
        String loanPurpose,
        String tileKey,
        Integer limitSize,
        Integer offsetSize
    ) {
        if (ownerId == null) {
            return new DrilldownPage(0, new List<Lead>());
        }
        LeadThroughputDrilldownService.TileKey key = parseTileKey(tileKey);
        if (key == null) {
            throw new AuraHandledException('Invalid tileKey.');
        }
        if (windows == null || windows.isEmpty()) {
            return new DrilldownPage(0, new List<Lead>());
        }

        Map<String, Object> binds = new Map<String, Object>();
        binds.put('ownerId', ownerId);
        binds.put('limitSize', limitSize);
        binds.put('offsetSize', offsetSize);

        List<String> clauses = new List<String>();
        clauses.add('OwnerId = :ownerId');

        if (!String.isBlank(leadSource)) {
            clauses.add('LeadSource = :leadSource');
            binds.put('leadSource', leadSource);
        }
        String loanPurposeClause = buildLoanPurposeClause(loanPurpose);
        if (!String.isBlank(loanPurposeClause)) {
            clauses.add(loanPurposeClause);
        }

        String orderBy;
        String dateClause;

        switch on key {
            when NEW_TO_PRE_APPROVAL {
                dateClause = buildCreatedDateUnionClause(LeadThroughputTimeframe.toCreatedDateWindows(windows), binds);
                clauses.add(dateClause);
                clauses.add('Pre_Approval_Date__c != null');
                orderBy = 'CreatedDate DESC, Id DESC';
            }
            when NEW_TO_POST_CLOSED {
                dateClause = buildCreatedDateUnionClause(LeadThroughputTimeframe.toCreatedDateWindows(windows), binds);
                clauses.add(dateClause);
                clauses.add('Converted_Transaction_ID__r.Post_Closed_Date__c != null');
                orderBy = 'CreatedDate DESC, Id DESC';
            }
            when PRE_APPROVAL_TO_POST_CLOSED {
                dateClause = buildPreApprovalDateUnionClause(windows, binds);
                clauses.add(dateClause);
                clauses.add('Converted_Transaction_ID__r.Post_Closed_Date__c != null');
                orderBy = 'Pre_Approval_Date__c DESC, CreatedDate DESC, Id DESC';
            }
        }

        String whereClause = String.join(clauses, ' AND ');

        // Total count (queryWithBinds does not support countQuery directly; use AggregateResult).
        String countSoql =
            'SELECT COUNT(Id) totalCount ' +
            'FROM Lead WHERE ' + whereClause;

        List<AggregateResult> countArs =
            (List<AggregateResult>) Database.queryWithBinds(countSoql, binds, AccessLevel.USER_MODE);
        Integer totalCount = countArs.isEmpty() ? 0 : (Integer) countArs[0].get('totalCount');

        // Page query
        String pageSoql =
            'SELECT Id, Name, CreatedDate, Pre_Approval_Date__c, Converted_Transaction_ID__c, ' +
            'Converted_Transaction_ID__r.Post_Closed_Date__c ' +
            'FROM Lead WHERE ' + whereClause +
            ' ORDER BY ' + orderBy +
            ' LIMIT :limitSize OFFSET :offsetSize';

        List<Lead> leads = (List<Lead>) Database.queryWithBinds(pageSoql, binds, AccessLevel.USER_MODE);
        return new DrilldownPage(totalCount, leads);
    }

    private static LeadThroughputDrilldownService.TileKey parseTileKey(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return LeadThroughputDrilldownService.TileKey.valueOf(raw.trim().toUpperCase());
        } catch (Exception e) {
            return null;
        }
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
}