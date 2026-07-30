@IsTest
private class DpaSecondTransactionInvocableTest {
    private static Id getPersonAccountRecordTypeId() {
        List<RecordType> personAccountRecordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName = 'PersonAccount'
            LIMIT 1
        ];
        return personAccountRecordTypes.isEmpty() ? null : personAccountRecordTypes[0].Id;
    }

    @TestSetup
    static void setup() {
        Account borrower = new Account(LastName = 'Borrower');
        Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
        if (personAccountRecordTypeId != null) {
            borrower.RecordTypeId = personAccountRecordTypeId;
        }
        insert borrower;

        Account lender = new Account(Name = 'Test Lender', Type = 'Investor');
        insert lender;

        Transaction__c t1 = new Transaction__c(
            Borrower_Name__c = borrower.Id,
            Account__c = borrower.Id,
            Lien_Position__c = '1st',
            Lender_lookup__c = lender.Id,
            Loan_Amount_1st__c = 100000,
            Loan_Type_1st_TD__c = 'Conventional',
            Loan_Program_1st__c = '30 yr Fixed',
            Rate_1st_TD__c = 5.0,
            Property_Address__c = '123 Main St',
            Property_City__c = 'City',
            Property_State__c = 'CA',
            Property_Postal_Code__c = '90210'
        );
        insert t1;
    }

    @IsTest
    static void testCreateSecondTransactions() {
        Transaction__c t1 = [SELECT Id FROM Transaction__c WHERE Lien_Position__c = '1st' LIMIT 1];
        
        DpaSecondTransactionInvocable.Request request = new DpaSecondTransactionInvocable.Request();
        request.parentTransactionId = String.valueOf(t1.Id);
        request.mode = 'AUTO';
        
        Test.startTest();
        List<DpaSecondTransactionInvocable.Result> results = DpaSecondTransactionInvocable.createSecondTransactions(new List<DpaSecondTransactionInvocable.Request>{request});
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return 1 result');
        System.assertEquals(true, results[0].success, 'Should be successful');
        System.assertNotEquals(null, results[0].secondTransactionId, 'Should have created a second transaction');
        System.assertEquals('Borrower - ', results[0].secondTransactionName, 'Should return the formatted second transaction name');
        
        Transaction__c t2 = [SELECT Id, First_Mortgage__c FROM Transaction__c WHERE Id = :results[0].secondTransactionId];
        System.assertEquals(t1.Id, t2.First_Mortgage__c, 'Second transaction should be linked to first');
    }

    @IsTest
    static void testCreateSecondTransactionsManual() {
        Transaction__c t1 = [SELECT Id FROM Transaction__c WHERE Lien_Position__c = '1st' LIMIT 1];
        
        DpaSecondTransactionInvocable.Request request = new DpaSecondTransactionInvocable.Request();
        request.parentTransactionId = String.valueOf(t1.Id);
        request.mode = 'MANUAL';
        request.loanAmount2nd = 20000;
        request.rate2nd = 5.0;
        request.loanType2nd = 'Conventional';
        request.loanProgram2nd = 'DPA';
        
        Test.startTest();
        List<DpaSecondTransactionInvocable.Result> results = DpaSecondTransactionInvocable.createSecondTransactions(new List<DpaSecondTransactionInvocable.Request>{request});
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return 1 result');
        System.assertEquals(true, results[0].success, 'Should be successful');
        System.assertNotEquals(null, results[0].secondTransactionId, 'Should have created a second transaction');
        System.assertEquals('Borrower - ', results[0].secondTransactionName, 'Should return the formatted second transaction name');
        
        Transaction__c t2 = [SELECT Id, First_Mortgage__c, Loan_Amount_2nd__c FROM Transaction__c WHERE Id = :results[0].secondTransactionId];
        System.assertEquals(t1.Id, t2.First_Mortgage__c, 'Second transaction should be linked to first');
        System.assertEquals(20000, t2.Loan_Amount_2nd__c, 'Loan amount should match manual input');
    }

    @IsTest
    static void testCreateSecondTransactionsFail() {
        // Create a request with missing required fields for manual creation which defaults to null for auto fallback if fields are missing on parent
        // But here we'll use an invalid ID to force failure
        
        DpaSecondTransactionInvocable.Request request = new DpaSecondTransactionInvocable.Request();
        request.parentTransactionId = null; // Invalid ID
        
        Test.startTest();
        List<DpaSecondTransactionInvocable.Result> results = DpaSecondTransactionInvocable.createSecondTransactions(new List<DpaSecondTransactionInvocable.Request>{request});
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return 1 result');
        System.assertEquals(false, results[0].success, 'Should fail');
        System.assertNotEquals(null, results[0].errorCode, 'Should have error code');
    }

    @IsTest
    static void testCreateSecondTransactionsInvalidParentIdString() {
        DpaSecondTransactionInvocable.Request request = new DpaSecondTransactionInvocable.Request();
        request.parentTransactionId = 'not-an-id';

        Test.startTest();
        List<DpaSecondTransactionInvocable.Result> results =
            DpaSecondTransactionInvocable.createSecondTransactions(
                new List<DpaSecondTransactionInvocable.Request>{ request }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return 1 result');
        System.assertEquals(false, results[0].success, 'Should fail gracefully for invalid string IDs');
        System.assertEquals('INVALID_INPUT', results[0].errorCode, 'Invalid string IDs should be treated as invalid input');
    }
}