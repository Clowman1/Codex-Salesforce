Set<String> allowedValues = new Set<String>{
    'Cash Out Refinance',
    'Cash-Out Debt Consolidation',
    'Rate & Term',
    'Rate And Term Reduction-FHA',
    'Streamline Refinance',
    'VA Interest Rate Reduction'
};

List<Transaction__c> updates = new List<Transaction__c>();
for (Transaction__c transactionRecord : [
    SELECT Id, Refinance_Purpose__c, Refinance_Purpose_Picklist__c
    FROM Transaction__c
    WHERE Refinance_Purpose__c IN :allowedValues
    LIMIT 10000
]) {
    if (transactionRecord.Refinance_Purpose_Picklist__c != transactionRecord.Refinance_Purpose__c) {
        updates.add(new Transaction__c(
            Id = transactionRecord.Id,
            Refinance_Purpose_Picklist__c = transactionRecord.Refinance_Purpose__c
        ));
    }
}
if (!updates.isEmpty()) {
    update updates;
}
System.debug('Backfilled Refinance_Purpose_Picklist__c rows: ' + updates.size());
