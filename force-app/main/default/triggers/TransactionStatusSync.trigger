trigger TransactionStatusSync on Transaction__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        TransactionStatusAgeService.stampCurrentStatusSince(Trigger.new, Trigger.isInsert ? null : Trigger.oldMap);
    }

    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        TransactionUtmCopyService.copyFromConvertedLeads(
            Trigger.new,
            Trigger.isInsert ? null : Trigger.oldMap
        );

        PurchaseDefaultConditionService.ensureForPurchaseTransactions(
            Trigger.new,
            Trigger.isInsert ? null : Trigger.oldMap
        );

        LoanOfficerRecordSharingService.syncTransactionShares(
            Trigger.new,
            Trigger.isInsert ? null : Trigger.oldMap
        );
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        DpaSecondTransactionStatusSync.syncAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}