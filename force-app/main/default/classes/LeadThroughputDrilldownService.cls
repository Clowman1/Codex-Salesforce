/**
 * LeadThroughputDrilldownService
 *
 * Use-case service for Throughput Analytics tile drill-down (numerator-only).
 * - No DML
 * - Delegates SOQL to LeadThroughputDrilldownRepo
 */
public with sharing class LeadThroughputDrilldownService {
    private LeadThroughputDrilldownService() {}

    public enum TileKey {
        NEW_TO_PRE_APPROVAL,
        NEW_TO_POST_CLOSED,
        PRE_APPROVAL_TO_POST_CLOSED
    }

    public class DrilldownRow {
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public Id transactionId { get; set; }
        @AuraEnabled public String name { get; set; }

        // Displayed as "Creation Date" per requirement; equals the tile basis date.
        @AuraEnabled public Datetime basisDateTime { get; set; }

        @AuraEnabled public Date preApprovalDate { get; set; }

        // Only meaningful for Post-Closed tiles; UI hides the column otherwise.
        @AuraEnabled public Date postClosedDate { get; set; }
    }

    public class DrilldownResponse {
        @AuraEnabled public Integer totalCount { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }
        @AuraEnabled public List<DrilldownRow> rows { get; set; }
    }

    public static DrilldownResponse getTileDrilldown(
        String timeframeType,
        List<String> quarterYearKeys,
        Id ownerId,
        String leadSource,
        String loanPurpose,
        String tileKey,
        Integer pageSize,
        Integer pageNumber
    ) {
        if (ownerId == null) {
            throw new AuraHandledException('ownerId is required.');
        }
        TileKey parsedTileKey = parseTileKey(tileKey);
        if (parsedTileKey == null) {
            throw new AuraHandledException('A valid tileKey is required.');
        }

        Integer effectivePageSize = normalizePageSize(pageSize);
        Integer effectivePageNumber = normalizePageNumber(pageNumber);
        Integer offsetSize = (effectivePageNumber - 1) * effectivePageSize;

        List<LeadThroughputTimeframe.DateWindow> windows =
            LeadThroughputTimeframe.resolveDateWindows(timeframeType, quarterYearKeys, Date.today());

        String normalizedLeadSource = String.isBlank(leadSource) ? null : leadSource;

        LeadThroughputDrilldownRepo.DrilldownPage page =
            LeadThroughputDrilldownRepo.selectNumeratorLeadsForTile(
                windows,
                ownerId,
                normalizedLeadSource,
                loanPurpose,
                String.valueOf(parsedTileKey),
                effectivePageSize,
                offsetSize
            );

        DrilldownResponse resp = new DrilldownResponse();
        resp.totalCount = page.totalCount;
        resp.pageSize = effectivePageSize;
        resp.pageNumber = effectivePageNumber;
        resp.rows = new List<DrilldownRow>();

        for (Lead l : page.leads) {
            DrilldownRow r = new DrilldownRow();
            r.recordId = l.Id;
            r.transactionId = (Id) l.get('Converted_Transaction_ID__c');
            r.name = l.Name;
            r.preApprovalDate = (Date) l.get('Pre_Approval_Date__c');

            Date postClosed = null;
            if (l.getSObject('Converted_Transaction_ID__r') != null) {
                postClosed = (Date) l.getSObject('Converted_Transaction_ID__r').get('Post_Closed_Date__c');
            }
            r.postClosedDate = postClosed;

            // The modal "Creation Date" column should always reflect the Lead CreatedDate.
            r.basisDateTime = l.CreatedDate;

            resp.rows.add(r);
        }

        return resp;
    }

    private static TileKey parseTileKey(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return TileKey.valueOf(raw.trim().toUpperCase());
        } catch (Exception e) {
            return null;
        }
    }

    private static Integer normalizePageSize(Integer pageSize) {
        Integer s = (pageSize == null) ? 25 : pageSize;
        s = Math.max(1, Math.min(200, s));
        return s;
    }

    private static Integer normalizePageNumber(Integer pageNumber) {
        Integer n = (pageNumber == null) ? 1 : pageNumber;
        return Math.max(1, n);
    }
}