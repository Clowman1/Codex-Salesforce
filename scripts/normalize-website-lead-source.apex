List<Lead> leadsToUpdate = [
    SELECT Id, LeadSource
    FROM Lead
    WHERE IsConverted = false
    AND LeadSource IN ('Website - Refi', 'Website - Purchase')
];
for (Lead leadRecord : leadsToUpdate) {
    leadRecord.LeadSource = 'Website';
}
if (!leadsToUpdate.isEmpty()) {
    update leadsToUpdate;
}

List<Transaction__c> transactionsToUpdate = [
    SELECT Id, Lead_Source__c
    FROM Transaction__c
    WHERE Lead_Source__c IN ('Website - Refi', 'Website - Purchase')
];
for (Transaction__c transactionRecord : transactionsToUpdate) {
    transactionRecord.Lead_Source__c = 'Website';
}
if (!transactionsToUpdate.isEmpty()) {
    update transactionsToUpdate;
}

System.debug('Updated Leads: ' + leadsToUpdate.size());
System.debug('Updated Transactions: ' + transactionsToUpdate.size());
