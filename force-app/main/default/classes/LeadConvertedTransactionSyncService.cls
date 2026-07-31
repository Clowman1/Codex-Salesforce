public without sharing class LeadConvertedTransactionSyncService {
    private static Boolean isRunning = false;

    public static void syncLoanPartnerToConvertedTransactions(List<Lead> newRecords, Map<Id, Lead> oldMap) {
        if (isRunning || newRecords == null || newRecords.isEmpty()) {
            return;
        }

        List<Lead> candidates = new List<Lead>();
        Set<Id> transactionIds = new Set<Id>();
        Set<Id> convertedAccountIds = new Set<Id>();

        for (Lead leadRecord : newRecords) {
            if (!shouldSync(leadRecord, oldMap == null ? null : oldMap.get(leadRecord.Id))) {
                continue;
            }

            candidates.add(leadRecord);
            if (leadRecord.Converted_Transaction_ID__c != null) {
                transactionIds.add(leadRecord.Converted_Transaction_ID__c);
            }
            if (leadRecord.ConvertedAccountId != null) {
                convertedAccountIds.add(leadRecord.ConvertedAccountId);
            }
        }

        if (candidates.isEmpty() || (transactionIds.isEmpty() && convertedAccountIds.isEmpty())) {
            return;
        }

        Map<Id, Transaction__c> transactionsById = new Map<Id, Transaction__c>();
        if (!transactionIds.isEmpty()) {
            transactionsById.putAll([
                SELECT Id, Loan_Partner__c
                FROM Transaction__c
                WHERE Id IN :transactionIds
            ]);
        }

        Map<Id, Transaction__c> transactionByAccountId = new Map<Id, Transaction__c>();
        if (!convertedAccountIds.isEmpty()) {
            for (Transaction__c transactionRecord : [
                SELECT Id, Borrower_Name__c, Account__c, Loan_Partner__c, CreatedDate
                FROM Transaction__c
                WHERE Borrower_Name__c IN :convertedAccountIds
                OR Account__c IN :convertedAccountIds
                ORDER BY CreatedDate DESC
            ]) {
                if (
                    transactionRecord.Borrower_Name__c != null &&
                    !transactionByAccountId.containsKey(transactionRecord.Borrower_Name__c)
                ) {
                    transactionByAccountId.put(transactionRecord.Borrower_Name__c, transactionRecord);
                }
                if (
                    transactionRecord.Account__c != null &&
                    !transactionByAccountId.containsKey(transactionRecord.Account__c)
                ) {
                    transactionByAccountId.put(transactionRecord.Account__c, transactionRecord);
                }
            }
        }

        Map<Id, Transaction__c> updatesById = new Map<Id, Transaction__c>();
        for (Lead leadRecord : candidates) {
            Transaction__c transactionRecord = leadRecord.Converted_Transaction_ID__c == null
                ? null
                : transactionsById.get(leadRecord.Converted_Transaction_ID__c);
            if (transactionRecord == null && leadRecord.ConvertedAccountId != null) {
                transactionRecord = transactionByAccountId.get(leadRecord.ConvertedAccountId);
            }
            if (
                transactionRecord == null ||
                transactionRecord.Loan_Partner__c == leadRecord.Loan_Partner__c
            ) {
                continue;
            }

            updatesById.put(
                transactionRecord.Id,
                new Transaction__c(
                    Id = transactionRecord.Id,
                    Loan_Partner__c = leadRecord.Loan_Partner__c
                )
            );
        }

        if (updatesById.isEmpty()) {
            return;
        }

        isRunning = true;
        try {
            update updatesById.values();
        } finally {
            isRunning = false;
        }
    }

    @TestVisible
    private static Boolean shouldSync(Lead leadRecord, Lead oldRecord) {
        if (leadRecord == null || !leadRecord.IsConverted || leadRecord.Loan_Partner__c == null) {
            return false;
        }

        if (leadRecord.Converted_Transaction_ID__c == null && leadRecord.ConvertedAccountId == null) {
            return false;
        }

        if (oldRecord == null) {
            return true;
        }

        return oldRecord.IsConverted != leadRecord.IsConverted ||
            oldRecord.Converted_Transaction_ID__c != leadRecord.Converted_Transaction_ID__c ||
            oldRecord.ConvertedAccountId != leadRecord.ConvertedAccountId ||
            oldRecord.Loan_Partner__c != leadRecord.Loan_Partner__c;
    }
}