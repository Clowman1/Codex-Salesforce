public without sharing class LoanOfficerRecordSharingService {
    private static Boolean handlingTransactions = false;

    public static void syncTransactionShares(List<Transaction__c> newRecords, Map<Id, Transaction__c> oldRecordsById) {
        if (handlingTransactions || newRecords == null || newRecords.isEmpty()) {
            return;
        }

        handlingTransactions = true;
        try {
            Set<Id> transactionIds = new Set<Id>();
            Set<Id> userIds = new Set<Id>();
            Set<String> desiredKeys = new Set<String>();
            Set<String> staleKeys = new Set<String>();

            for (Transaction__c transactionRecord : newRecords) {
                if (transactionRecord.Id == null) {
                    continue;
                }

                transactionIds.add(transactionRecord.Id);
                addDesiredShare(transactionRecord.Id, transactionRecord.OwnerId, transactionRecord.Loan_Officer__c, desiredKeys, userIds);
                addDesiredShare(transactionRecord.Id, transactionRecord.OwnerId, transactionRecord.Loan_Partner__c, desiredKeys, userIds);

                Transaction__c oldRecord = oldRecordsById == null ? null : oldRecordsById.get(transactionRecord.Id);
                if (oldRecord != null) {
                    if (oldRecord.Loan_Officer__c != transactionRecord.Loan_Officer__c) {
                        addStaleShare(transactionRecord.Id, oldRecord.Loan_Officer__c, desiredKeys, staleKeys, userIds);
                    }
                    if (oldRecord.Loan_Partner__c != transactionRecord.Loan_Partner__c) {
                        addStaleShare(transactionRecord.Id, oldRecord.Loan_Partner__c, desiredKeys, staleKeys, userIds);
                    }
                }
            }

            Map<String, Transaction__Share> existingByKey = new Map<String, Transaction__Share>();
            if (!transactionIds.isEmpty() && !userIds.isEmpty()) {
                for (Transaction__Share shareRecord : [
                    SELECT Id, ParentId, UserOrGroupId, RowCause
                    FROM Transaction__Share
                    WHERE ParentId IN :transactionIds
                    AND UserOrGroupId IN :userIds
                    AND RowCause = 'Manual'
                ]) {
                    existingByKey.put(key(shareRecord.ParentId, shareRecord.UserOrGroupId), shareRecord);
                }
            }

            List<Transaction__Share> sharesToInsert = new List<Transaction__Share>();
            for (String shareKey : desiredKeys) {
                if (existingByKey.containsKey(shareKey)) {
                    continue;
                }

                List<String> parts = shareKey.split(':');
                sharesToInsert.add(new Transaction__Share(
                    ParentId = (Id) parts[0],
                    UserOrGroupId = (Id) parts[1],
                    AccessLevel = 'Read',
                    RowCause = Schema.Transaction__Share.RowCause.Manual
                ));
            }

            List<Transaction__Share> sharesToDelete = new List<Transaction__Share>();
            for (String shareKey : staleKeys) {
                if (existingByKey.containsKey(shareKey)) {
                    sharesToDelete.add(existingByKey.get(shareKey));
                }
            }

            insertShares(sharesToInsert);
            deleteShares(sharesToDelete);
        } finally {
            handlingTransactions = false;
        }
    }

    private static void addDesiredShare(Id recordId, Id ownerId, Id userId, Set<String> desiredKeys, Set<Id> userIds) {
        if (recordId == null || userId == null || userId == ownerId) {
            return;
        }

        desiredKeys.add(key(recordId, userId));
        userIds.add(userId);
    }

    private static void addStaleShare(Id recordId, Id userId, Set<String> desiredKeys, Set<String> staleKeys, Set<Id> userIds) {
        if (recordId == null || userId == null) {
            return;
        }

        String shareKey = key(recordId, userId);
        if (!desiredKeys.contains(shareKey)) {
            staleKeys.add(shareKey);
            userIds.add(userId);
        }
    }

    private static String key(Id recordId, Id userId) {
        return String.valueOf(recordId) + ':' + String.valueOf(userId);
    }

    private static void insertShares(List<SObject> sharesToInsert) {
        if (sharesToInsert == null || sharesToInsert.isEmpty()) {
            return;
        }

        Database.insert(sharesToInsert, false);
    }

    private static void deleteShares(List<SObject> sharesToDelete) {
        if (sharesToDelete == null || sharesToDelete.isEmpty()) {
            return;
        }

        Database.delete(sharesToDelete, false);
    }
}
