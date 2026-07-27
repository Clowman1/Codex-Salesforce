@IsTest
private class TransactionStatusAgeServiceTest {
    @IsTest
    static void stampsDateOnInsertAndStatusChangeInMemory() {
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Status Age Test',
            Status__c = 'Processing'
        );

        TransactionStatusAgeService.stampCurrentStatusSince(new List<Transaction__c>{ transactionRecord }, null);
        System.assertEquals(Date.today(), transactionRecord.Current_Status_Since__c);

        Transaction__c oldRecord = new Transaction__c(Status__c = 'Processing');
        oldRecord.Id = 'a01000000000001AAA';
        transactionRecord.Id = oldRecord.Id;
        transactionRecord.Current_Status_Since__c = Date.today().addDays(-5);
        transactionRecord.Status__c = 'Submitted';

        TransactionStatusAgeService.stampCurrentStatusSince(
            new List<Transaction__c>{ transactionRecord },
            new Map<Id, Transaction__c>{ oldRecord.Id => oldRecord }
        );
        System.assertEquals(Date.today(), transactionRecord.Current_Status_Since__c);
    }
}
