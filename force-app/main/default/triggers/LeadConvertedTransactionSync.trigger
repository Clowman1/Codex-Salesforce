trigger LeadConvertedTransactionSync on Lead (after update) {
    LeadConvertedTransactionSyncService.syncLoanPartnerToConvertedTransactions(Trigger.new, Trigger.oldMap);
}
