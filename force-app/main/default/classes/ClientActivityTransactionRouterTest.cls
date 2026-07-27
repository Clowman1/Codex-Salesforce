@IsTest
private class ClientActivityTransactionRouterTest {
    private static Id businessAccountRecordTypeId;

    @IsTest
    static void taskOnBorrowerAccountRoutesToPrimaryActiveTransaction() {
        Account borrower = new Account(LastName = 'Router Borrower');
        insert borrower;

        Transaction__c firstMortgage = createTransaction('Router First', borrower.Id, null);
        Transaction__c secondMortgage = createTransaction('Router Second', borrower.Id, firstMortgage.Id);

        Test.startTest();
        Task communicationTask = new Task(
            Subject = 'Melina Munne texted Router Borrower on 06/09/2026 at 01:00:00 PM',
            WhatId = borrower.Id,
            Status = 'Completed',
            Priority = 'Normal'
        );
        insert communicationTask;
        Test.stopTest();

        Task routedTask = [
            SELECT WhatId
            FROM Task
            WHERE Id = :communicationTask.Id
        ];
        System.assertEquals(firstMortgage.Id, routedTask.WhatId, 'Client activity should route to the primary active transaction.');
        System.assertNotEquals(secondMortgage.Id, routedTask.WhatId, 'Second lien should not receive borrower contact activity when a first lien is linked.');
    }

    @IsTest
    static void callInsightOnSecondLienRoutesToPrimaryActiveTransaction() {
        Account borrower = new Account(LastName = 'Insight Borrower');
        insert borrower;

        Transaction__c firstMortgage = createTransaction('Insight First', borrower.Id, null);
        Transaction__c secondMortgage = createTransaction('Insight Second', borrower.Id, firstMortgage.Id);

        Test.startTest();
        Call_Insight__c insightRecord = new Call_Insight__c(
            Account__c = borrower.Id,
            Transaction__c = secondMortgage.Id,
            Title__c = 'Outbound call with Insight Borrower',
            Recording_Start_DateTime__c = System.now()
        );
        insert insightRecord;
        Test.stopTest();

        Call_Insight__c routedInsight = [
            SELECT Account__c, Transaction__c
            FROM Call_Insight__c
            WHERE Id = :insightRecord.Id
        ];
        System.assertEquals(borrower.Id, routedInsight.Account__c, 'Borrower account should stay attached for account context.');
        System.assertEquals(firstMortgage.Id, routedInsight.Transaction__c, 'RingSense insight should route to primary active transaction.');
        Transaction__c stampedTransaction = [
            SELECT Last_Processor_RC_Call__c
            FROM Transaction__c
            WHERE Id = :firstMortgage.Id
        ];
        System.assertEquals(insightRecord.Recording_Start_DateTime__c, stampedTransaction.Last_Processor_RC_Call__c, 'RingSense insight should stamp the last processor call.');
    }

    @IsTest
    static void emailOnBorrowerAccountRoutesToPrimaryActiveTransaction() {
        Account borrower = new Account(LastName = 'Email Borrower');
        insert borrower;

        Transaction__c firstMortgage = createTransaction('Email First', borrower.Id, null);

        Test.startTest();
        EmailMessage emailMessage = new EmailMessage(
            Incoming = false,
            RelatedToId = borrower.Id,
            Subject = 'Borrower follow up',
            ToAddress = 'email.borrower@example.com',
            FromAddress = 'processor@example.com'
        );
        insert emailMessage;
        Test.stopTest();

        EmailMessage routedEmail = [
            SELECT RelatedToId
            FROM EmailMessage
            WHERE Id = :emailMessage.Id
        ];
        System.assertEquals(firstMortgage.Id, routedEmail.RelatedToId, 'Borrower email should route to active transaction.');
    }

    @IsTest
    static void smsHistoryOnBorrowerAccountRoutesToPrimaryActiveTransaction() {
        Account borrower = new Account(LastName = 'Sms Borrower');
        insert borrower;

        Transaction__c firstMortgage = createTransaction('Sms First', borrower.Id, null);

        Test.startTest();
        smagicinteract__smsMagic__c smsRecord = new smagicinteract__smsMagic__c(
            smagicinteract__Account__c = borrower.Id
        );
        insert smsRecord;
        Test.stopTest();

        smagicinteract__smsMagic__c routedSms = [
            SELECT smagicinteract__Account__c, Transaction__c
            FROM smagicinteract__smsMagic__c
            WHERE Id = :smsRecord.Id
        ];
        System.assertEquals(borrower.Id, routedSms.smagicinteract__Account__c, 'Borrower account should stay attached for SMS context.');
        System.assertEquals(firstMortgage.Id, routedSms.Transaction__c, 'SMS history should route to active transaction.');
        Transaction__c stampedTransaction = [
            SELECT Last_Processor_RC_SMS__c
            FROM Transaction__c
            WHERE Id = :firstMortgage.Id
        ];
        System.assertNotEquals(null, stampedTransaction.Last_Processor_RC_SMS__c, 'SMS history should stamp the last processor SMS.');
    }

    private static Transaction__c createTransaction(String name, Id borrowerId, Id firstMortgageId) {
    if (businessAccountRecordTypeId == null) {
        businessAccountRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName = 'Business_Account'
            LIMIT 1
        ].Id;
    }

    Account lender = new Account(
        Name = name + ' Lender',
        RecordTypeId = businessAccountRecordTypeId,
        Type = 'Investor'
    );
        insert lender;

        Transaction__c transactionRecord = new Transaction__c(
            Name = name,
            Status__c = 'Processing',
            Borrower_Name__c = borrowerId,
            Borrower_First_Name__c = 'Router',
            Borrower_Last_Name__c = 'Borrower',
            First_Mortgage__c = firstMortgageId,
            Lender_lookup__c = lender.Id
        );
        insert transactionRecord;
        return transactionRecord;
    }
}
