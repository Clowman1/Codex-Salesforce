public with sharing class BorrowerPortalPopulateHashInvocable {
    public class Request {
        @InvocableVariable(required=true)
        public Id recordId;
    }

    @InvocableMethod(label='Populate Transaction Portal Hash')
    public static void populateHashes(List<Request> requests) {
        Set<Id> transactionIds = new Set<Id>();
        for (Request requestItem : requests) {
            if (requestItem != null && requestItem.recordId != null) {
                transactionIds.add(requestItem.recordId);
            }
        }

        BorrowerPortalService.populateMissingPortalHashes(transactionIds);
    }
}