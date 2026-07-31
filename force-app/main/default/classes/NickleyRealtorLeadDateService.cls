// Narrow, deliberate sharing bypass for the "My Nickley Realtors" Home tab
// (PipelineCommandCenterController). Lead sharing in this org is per-owner, so a
// "with sharing" query would only surface leads the viewing LO personally owns,
// silently under-reporting or misdating "last lead sent" for realtors whose leads
// are spread across multiple LOs. This class exposes nothing but a MAX(CreatedDate)
// per Account Id, for an Account Id set the caller has already vetted - no Lead
// record content is returned.
public without sharing class NickleyRealtorLeadDateService {
    public static Map<Id, Datetime> lastLeadSentDates(Set<Id> accountIds) {
        Map<Id, Datetime> lastLeadDateByAccountId = new Map<Id, Datetime>();
        if (accountIds == null || accountIds.isEmpty()) {
            return lastLeadDateByAccountId;
        }
        for (AggregateResult result : [
            SELECT Realtor_Buying_Agent__c acctId, MAX(CreatedDate) lastDate
            FROM Lead
            WHERE Realtor_Buying_Agent__c IN :accountIds
            GROUP BY Realtor_Buying_Agent__c
        ]) {
            lastLeadDateByAccountId.put((Id) result.get('acctId'), (Datetime) result.get('lastDate'));
        }
        return lastLeadDateByAccountId;
    }
}