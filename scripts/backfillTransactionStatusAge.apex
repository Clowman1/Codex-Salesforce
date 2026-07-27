Set<String> inactiveStatuses = new Set<String>{ 'Cancelled', 'Canceled', 'Post-Closed', 'QC Review', 'PC Review', 'Lost' };

List<Transaction__c> transactions = [
    SELECT Id, Status__c, CreatedDate, Current_Status_Since__c
    FROM Transaction__c
    WHERE CreatedDate >= 2024-01-01T00:00:00Z
    AND Status__c NOT IN :inactiveStatuses
];

Map<Id, Transaction__c> transactionsById = new Map<Id, Transaction__c>(transactions);
Map<Id, Datetime> currentStatusSinceByTransactionId = new Map<Id, Datetime>();

if (!transactionsById.isEmpty()) {
    for (Transaction__History historyRecord : [
        SELECT ParentId, CreatedDate, NewValue
        FROM Transaction__History
        WHERE ParentId IN :transactionsById.keySet()
        AND Field = 'Status__c'
        ORDER BY CreatedDate DESC
    ]) {
        Transaction__c transactionRecord = transactionsById.get(historyRecord.ParentId);
        if (
            transactionRecord != null
            && !currentStatusSinceByTransactionId.containsKey(historyRecord.ParentId)
            && String.valueOf(historyRecord.NewValue) == transactionRecord.Status__c
        ) {
            currentStatusSinceByTransactionId.put(historyRecord.ParentId, historyRecord.CreatedDate);
        }
    }
}

List<Transaction__c> updates = new List<Transaction__c>();
for (Transaction__c transactionRecord : transactions) {
    Datetime statusSinceDateTime = currentStatusSinceByTransactionId.containsKey(transactionRecord.Id)
        ? currentStatusSinceByTransactionId.get(transactionRecord.Id)
        : transactionRecord.CreatedDate;
    Date statusSinceDate = statusSinceDateTime.date();

    if (transactionRecord.Current_Status_Since__c != statusSinceDate) {
        updates.add(new Transaction__c(
            Id = transactionRecord.Id,
            Current_Status_Since__c = statusSinceDate
        ));
    }
}

if (!updates.isEmpty()) {
    update updates;
}

System.debug('Backfilled Current_Status_Since__c on ' + updates.size() + ' active Transaction records.');
