@isTest
private class UserActionControllerTest {
    @TestSetup
    static void setupData() {
        Account accountRecord = new Account(LastName = 'User Action Test');
        insert accountRecord;

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'UA Test Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Borrower_Name__c = accountRecord.Id
        );
        insert transactionRecord;

        Condition__c conditionRecord = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Type__c = 'Loan Officer',
            Description__c = 'User action condition'
        );
        insert conditionRecord;
    }

    @isTest
    static void saveUserInteraction_createsUserActionForCurrentRuntime() {
        Transaction__c transactionRecord = [SELECT Id FROM Transaction__c LIMIT 1];
        Condition__c conditionRecord = [SELECT Id FROM Condition__c LIMIT 1];

        Test.startTest();
        UserActionController.saveUserInteraction(
            new Map<String, Object>{
                'transactionId' => transactionRecord.Id,
                'conditionId' => conditionRecord.Id,
                'type' => 'Loan Conditions Email Sent'
            }
        );
        Test.stopTest();

        User_Action__c insertedAction = [
            SELECT Transaction__c, Condition__c, Type__c, User__c
            FROM User_Action__c
            LIMIT 1
        ];

        System.assertEquals(transactionRecord.Id, insertedAction.Transaction__c);
        System.assertEquals(conditionRecord.Id, insertedAction.Condition__c);
        System.assertEquals('Loan Conditions Email Sent', insertedAction.Type__c);
        System.assertEquals(UserInfo.getUserId(), insertedAction.User__c);
    }
}