List<Transaction__c> transactionsToTouch = [
    SELECT Id
    FROM Transaction__c
    WHERE Id IN ('a01Qi00001MxtiOIAR', 'a01Qi00001N0MNnIAN')
];

System.debug('Backfilling UTM fields for ' + transactionsToTouch.size() + ' Broze Transaction records.');
update transactionsToTouch;
