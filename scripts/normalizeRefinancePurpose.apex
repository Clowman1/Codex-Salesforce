Map<String, String> refinancePurposeMap = new Map<String, String>{
    'Cash Out - Type II' => 'Cash Out Refinance',
    'Cash-Out Refi' => 'Cash Out Refinance',
    'CashOut' => 'Cash Out Refinance',
    'CashOutHomeImprovement' => 'Cash Out Refinance',
    'CashOutOther' => 'Cash Out Refinance',
    'VA Cash Out - Type II' => 'Cash Out Refinance',
    'CashOutDebtConsolidation' => 'Cash-Out Debt Consolidation',
    'ChangeInRateTerm' => 'Rate & Term',
    'NoCashOut' => 'Rate & Term',
    '1 YR Balloon - Fixed Rate Home Equity Loan' => 'Rate & Term'
};

List<Transaction__c> updates = new List<Transaction__c>();
for (Transaction__c transactionRecord : [
    SELECT Id, Refinance_Purpose__c
    FROM Transaction__c
    WHERE Refinance_Purpose__c IN :refinancePurposeMap.keySet()
    LIMIT 10000
]) {
    updates.add(new Transaction__c(
        Id = transactionRecord.Id,
        Refinance_Purpose__c = refinancePurposeMap.get(transactionRecord.Refinance_Purpose__c)
    ));
}
if (!updates.isEmpty()) {
    update updates;
}
System.debug('Normalized Refinance_Purpose__c rows: ' + updates.size());
