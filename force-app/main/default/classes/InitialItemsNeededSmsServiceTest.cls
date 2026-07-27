@IsTest
private class InitialItemsNeededSmsServiceTest {
    @IsTest
    static void createsScheduledMessageForInitialItemsSms() {
        Account borrower = createBorrower('SMS', 'Borrower', '3038591055', 'sms.borrower@example.com', false);

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Initial Items SMS Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'SMS-001',
            Account__c = borrower.Id,
            Borrower_Name__c = borrower.Id,
            Processor__c = UserInfo.getUserId()
        );
        insert transactionRecord;

        Test.startTest();
        InitialItemsNeededSmsService.createAndSend(transactionRecord.Id);
        Test.stopTest();

        Scheduled_Message__c message = [
            SELECT Account__c,
                Blocked__c,
                Campaign_Type__c,
                Execution_Flow__c,
                Recipient_Phone_Number__c,
                Sender__c,
                Type__c
            FROM Scheduled_Message__c
            WHERE Account__c = :borrower.Id
            LIMIT 1
        ];

        System.assertEquals(borrower.Id, message.Account__c);
        System.assertEquals('3038591055', message.Recipient_Phone_Number__c);
        System.assertEquals(UserInfo.getUserId(), message.Sender__c);
        System.assertEquals('RingCentral SMS', message.Type__c);
        System.assertEquals('Initial Conditions Message', message.Campaign_Type__c);
        System.assertEquals('Conditions_Initial_Items_Needed_SMS', message.Execution_Flow__c);
    }

    @IsTest
    static void enqueuesOnlyWhenBorrowerReceivedInitialItemsEmail() {
        Account borrower = createBorrower('Email', 'Borrower', '3038591056', 'email.borrower@example.com', false);
        Transaction__c transactionRecord = createTransaction(borrower.Id, UserInfo.getUserId());

        Test.startTest();
        InitialItemsNeededSmsService.enqueueIfApplicable(
            transactionRecord.Id,
            'Initial_Items_Needed',
            new List<Object>{ 'EMAIL.BORROWER@example.com' }
        );
        InitialItemsNeededSmsService.enqueueIfApplicable(
            transactionRecord.Id,
            'Conditions_Updated',
            new List<Object>{ 'email.borrower@example.com' }
        );
        InitialItemsNeededSmsService.enqueueIfApplicable(
            transactionRecord.Id,
            'Initial_Items_Needed',
            new List<Object>{ 'other@example.com' }
        );
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT()
            FROM Scheduled_Message__c
            WHERE Account__c = :borrower.Id
        ]);
    }

    @IsTest
    static void enqueuesFromOutgoingInitialItemsEmailMessage() {
        Account borrower = createBorrower('EmailMessage', 'Borrower', '3038591059', 'message.borrower@example.com', false);
        Transaction__c transactionRecord = createTransaction(borrower.Id, UserInfo.getUserId());

        EmailMessage emailMessage = new EmailMessage(
            Incoming = false,
            RelatedToId = transactionRecord.Id,
            Subject = 'Conditional Approval for Your Mortgage - Next Steps',
            ToAddress = 'EmailMessage Borrower <MESSAGE.BORROWER@example.com>',
            FromAddress = 'processor@example.com'
        );

        Test.startTest();
        insert emailMessage;
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT()
            FROM Scheduled_Message__c
            WHERE Account__c = :borrower.Id
        ]);
    }

    @IsTest
    static void doesNotDoubleEnqueueWhenEmailTriggerAndControllerPathBothRun() {
        Account borrower = createBorrower('No', 'Duplicate', '3038591061', 'duplicate.borrower@example.com', false);
        Transaction__c transactionRecord = createTransaction(borrower.Id, UserInfo.getUserId());

        EmailMessage emailMessage = new EmailMessage(
            Incoming = false,
            RelatedToId = transactionRecord.Id,
            Subject = 'Conditional Approval for Your Mortgage - Next Steps',
            ToAddress = 'duplicate.borrower@example.com',
            FromAddress = 'processor@example.com'
        );

        Test.startTest();
        insert emailMessage;
        InitialItemsNeededSmsService.enqueueIfApplicable(
            transactionRecord.Id,
            'Initial_Items_Needed',
            new List<Object>{ 'duplicate.borrower@example.com' }
        );
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT()
            FROM Scheduled_Message__c
            WHERE Account__c = :borrower.Id
        ]);
    }

    @IsTest
    static void ignoresNonInitialItemsEmailMessages() {
        Account borrower = createBorrower('Conditions', 'Updated', '3038591060', 'updated.borrower@example.com', false);
        Transaction__c transactionRecord = createTransaction(borrower.Id, UserInfo.getUserId());

        InitialItemsNeededSmsService.enqueueFromEmailMessages(
            new List<EmailMessage>{
                new EmailMessage(
                    Incoming = false,
                    RelatedToId = transactionRecord.Id,
                    Subject = 'You are One Step Closer! Updated Items Needed',
                    ToAddress = 'updated.borrower@example.com',
                    FromAddress = 'processor@example.com'
                )
            }
        );

        System.assertEquals(0, [
            SELECT COUNT()
            FROM Scheduled_Message__c
            WHERE Account__c = :borrower.Id
        ]);
    }

    @IsTest
    static void blocksWhenProcessorIsMissing() {
        Account borrower = createBorrower('No', 'Processor', '3038591057', 'no.processor@example.com', false);
        Transaction__c transactionRecord = createTransaction(borrower.Id, null);

        InitialItemsNeededSmsService.createAndSend(transactionRecord.Id);

        Scheduled_Message__c message = getMessage(borrower.Id);
        System.assertEquals(true, message.Blocked__c);
        System.assert(message.Info_Message__c.contains('No Processor'));
    }

    @IsTest
    static void blocksWhenBorrowerOptedOut() {
        Account borrower = createBorrower('Opted', 'Out', '3038591058', 'opted.out@example.com', true);
        Transaction__c transactionRecord = createTransaction(borrower.Id, UserInfo.getUserId());

        InitialItemsNeededSmsService.createAndSend(transactionRecord.Id);

        Scheduled_Message__c message = getMessage(borrower.Id);
        System.assertEquals(true, message.Blocked__c);
        System.assert(message.Info_Message__c.contains('opted out'));
    }

    @IsTest
    static void blocksWhenBorrowerPhoneIsMissing() {
        Account borrower = createBorrower('No', 'Phone', null, 'no.phone@example.com', false);
        Transaction__c transactionRecord = createTransaction(borrower.Id, UserInfo.getUserId());

        InitialItemsNeededSmsService.createAndSend(transactionRecord.Id);

        Scheduled_Message__c message = getMessage(borrower.Id);
        System.assertEquals(true, message.Blocked__c);
        System.assert(message.Info_Message__c.contains('No borrower phone'));
    }

    @IsTest
    static void doesNotEnqueueForNonInitialTemplate() {
        Test.startTest();
        InitialItemsNeededSmsService.enqueueIfApplicable(
            null,
            'Conditions_Updated',
            new List<Object>{ 'borrower@example.com' }
        );
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Scheduled_Message__c]);
    }

    private static Account createBorrower(
        String firstName,
        String lastName,
        String phone,
        String email,
        Boolean smsOptOut
    ) {
        RecordType personAccountRecordType = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
                AND IsPersonType = true
            LIMIT 1
        ];
        Account borrower = new Account(
            RecordTypeId = personAccountRecordType.Id,
            FirstName = firstName,
            LastName = lastName,
            PersonMobilePhone = phone,
            PersonEmail = email,
            SMS_Opt_Out__c = smsOptOut
        );
        insert borrower;
        return borrower;
    }

    private static Transaction__c createTransaction(Id borrowerId, Id processorId) {
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Initial Items SMS Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = String.valueOf(Math.abs(Crypto.getRandomInteger())),
            Account__c = borrowerId,
            Borrower_Name__c = borrowerId,
            Processor__c = processorId
        );
        insert transactionRecord;
        return transactionRecord;
    }

    private static Scheduled_Message__c getMessage(Id borrowerId) {
        return [
            SELECT Account__c, Blocked__c, Info_Message__c
            FROM Scheduled_Message__c
            WHERE Account__c = :borrowerId
            LIMIT 1
        ];
    }
}
