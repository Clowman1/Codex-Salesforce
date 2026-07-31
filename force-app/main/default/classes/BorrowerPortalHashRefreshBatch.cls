public with sharing class BorrowerPortalHashRefreshBatch implements Database.Batchable<SObject>, Schedulable {
    private static final Integer DEFAULT_BATCH_SIZE = 200;

    public Database.QueryLocator start(Database.BatchableContext context) {
        BorrowerPortalHashRefreshService.rotateConfiguredAesKey();
        return LoanRepository.getInstance().getBorrowerPortalHashRefreshScope();
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        List<Transaction__c> transactionScope = new List<Transaction__c>();
        for (SObject scopeRecord : scope) {
            transactionScope.add((Transaction__c)scopeRecord);
        }
        BorrowerPortalHashRefreshService.refreshPortalHashes(transactionScope);
    }

    public void finish(Database.BatchableContext context) {
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new BorrowerPortalHashRefreshBatch(), DEFAULT_BATCH_SIZE);
    }
}