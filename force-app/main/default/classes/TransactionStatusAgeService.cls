public with sharing class TransactionStatusAgeService {
    public static void stampCurrentStatusSince(List<Transaction__c> newRecords, Map<Id, Transaction__c> oldRecordsById) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        Date today = Date.today();
        for (Transaction__c transactionRecord : newRecords) {
            Transaction__c oldRecord = oldRecordsById == null ? null : oldRecordsById.get(transactionRecord.Id);
            Boolean isInsert = oldRecord == null;
            Boolean statusChanged = !isInsert && transactionRecord.Status__c != oldRecord.Status__c;

            if ((isInsert || statusChanged) && transactionRecord.Current_Status_Since__c == null) {
                transactionRecord.Current_Status_Since__c = today;
            }

            if (statusChanged) {
                transactionRecord.Current_Status_Since__c = today;
            }
        }
    }
}