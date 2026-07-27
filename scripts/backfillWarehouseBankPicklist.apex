List<Transaction__c> updates = new List<Transaction__c>();
for (Transaction__c transactionRecord : [
    SELECT Id, Warehouse_Bank_Picklist__c, Warehouse_Bank__r.Name
    FROM Transaction__c
    WHERE Warehouse_Bank_Picklist__c = null
    AND Warehouse_Bank__c != null
    AND Warehouse_Bank__r.Name IN ('Primis Bank', 'Simmons Bank')
    LIMIT 10000
]) {
    updates.add(new Transaction__c(
        Id = transactionRecord.Id,
        Warehouse_Bank_Picklist__c = transactionRecord.Warehouse_Bank__r.Name
    ));
}
if (!updates.isEmpty()) {
    update updates;
}
System.debug('Backfilled Warehouse_Bank_Picklist__c rows: ' + updates.size());
