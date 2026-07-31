public with sharing class LeadThroughputController {
    @AuraEnabled
    public static LeadThroughputService.LeadThroughputResponse getThroughput(String dateRangeKey, Id ownerId, String leadSource) {
        return LeadThroughputService.getThroughput(dateRangeKey, ownerId, leadSource);
    }

    @AuraEnabled
    public static List<LeadThroughputService.LookupOption> getActiveLoanOfficers(Integer limitSize) {
        return LeadThroughputService.getActiveLoanOfficers(limitSize);
    }

    @AuraEnabled
    public static List<LeadThroughputService.OwnerThroughput> getThroughputByOwners(
        String dateRangeKey,
        Date startDate,
        Date endDate,
        List<Id> ownerIds,
        String leadSource
    ) {
        return LeadThroughputService.getThroughputByOwners(dateRangeKey, startDate, endDate, ownerIds, leadSource);
    }

    /**
     * RHL2-276: Throughput Analytics timeframe filters (Quarter+Year union, YTD, Last Year, Two Years Ago).
     * This is a new endpoint to avoid breaking existing callers of getThroughputByOwners(...).
     */
    @AuraEnabled
    public static List<LeadThroughputService.OwnerThroughput> getThroughputByOwnersV2(
        String timeframeType,
        List<String> quarterYearKeys,
        List<Id> ownerIds,
        String leadSource,
        String loanPurpose
    ) {
        return LeadThroughputService.getThroughputByOwnersV2(timeframeType, quarterYearKeys, ownerIds, leadSource, loanPurpose);
    }

    @AuraEnabled
    public static LeadThroughputDrilldownService.DrilldownResponse getTileDrilldown(
        String timeframeType,
        List<String> quarterYearKeys,
        Id ownerId,
        String leadSource,
        String loanPurpose,
        String tileKey,
        Integer pageSize,
        Integer pageNumber
    ) {
        return LeadThroughputDrilldownService.getTileDrilldown(
            timeframeType,
            quarterYearKeys,
            ownerId,
            leadSource,
            loanPurpose,
            tileKey,
            pageSize,
            pageNumber
        );
    }
}