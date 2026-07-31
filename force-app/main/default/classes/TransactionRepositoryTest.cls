@IsTest
private class TransactionRepositoryTest {

    @TestSetup
    static void setup() {
        Account borrower = new Account(Name = 'Test Borrower');
        insert borrower;

        Account lender = new Account(Name = 'UWM', Type = 'Investor');
        insert lender;

        Transaction__c t1 = new Transaction__c(
            Borrower_Name__c = borrower.Id,
            Account__c = borrower.Id,
            Lien_Position__c = '1st',
            Lender_lookup__c = lender.Id,
            Loan_Amount_1st__c = 100000,
            Loan_Number__c = '12345',
            Property_Address__c = '123 Main St',
            Property_City__c = 'City',
            Property_State__c = 'CA',
            Property_Postal_Code__c = '90210'
        );
        insert t1;

        Transaction__c t2 = new Transaction__c(
            Borrower_Name__c = borrower.Id,
            Account__c = borrower.Id,
            Lien_Position__c = '2nd',
            Lender_lookup__c = lender.Id,
            First_Mortgage__c = t1.Id,
            Loan_Amount_2nd__c = 20000
        );
        insert t2;
    }

    @IsTest
    static void testGetInstance() {
        Test.startTest();
        TransactionRepository repo1 = TransactionRepository.getInstance();
        TransactionRepository repo2 = TransactionRepository.getInstance();
        Test.stopTest();

        System.assertNotEquals(null, repo1, 'Instance should not be null');
        System.assertEquals(repo1, repo2, 'Singleton should return same instance');
    }

    @IsTest
    static void testGetTransactionById() {
        Transaction__c t = [SELECT Id FROM Transaction__c WHERE Lien_Position__c = '1st' LIMIT 1];
        
        Test.startTest();
        Transaction__c result = TransactionRepository.getInstance().getTransactionById(t.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(t.Id, result.Id, 'Id should match');
    }

    @IsTest
    static void testGetTransactionsMapByIds() {
        Map<Id, Transaction__c> transactions = new Map<Id, Transaction__c>([SELECT Id FROM Transaction__c]);
        
        Test.startTest();
        Map<Id, Loan> result = TransactionRepository.getInstance().getTransactionsMapByIds(transactions.keySet());
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(transactions.size(), result.size(), 'Size should match');
    }

    @IsTest
    static void testSelectForDpaSecondByIds() {
        Transaction__c t = [SELECT Id FROM Transaction__c WHERE Lien_Position__c = '1st' LIMIT 1];
        
        Test.startTest();
        Map<Id, Transaction__c> result = TransactionRepository.getInstance().selectForDpaSecondByIds(new Set<Id>{t.Id});
        Map<Id, Transaction__c> emptyResult = TransactionRepository.getInstance().selectForDpaSecondByIds(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.size(), 'Should return 1 record');
        System.assertEquals(t.Id, result.values()[0].Id, 'Id should match');
        System.assertEquals(0, emptyResult.size(), 'Null input should return empty map');
    }

    @IsTest
    static void testSelectSecondTransactionsByFirstIds() {
        Transaction__c t1 = [SELECT Id FROM Transaction__c WHERE Lien_Position__c = '1st' LIMIT 1];
        Transaction__c t2 = [SELECT Id FROM Transaction__c WHERE Lien_Position__c = '2nd' LIMIT 1];

        Test.startTest();
        Map<Id, Transaction__c> result = TransactionRepository.getInstance().selectSecondTransactionsByFirstIds(new Set<Id>{t1.Id});
        Map<Id, Transaction__c> emptyResult = TransactionRepository.getInstance().selectSecondTransactionsByFirstIds(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.size(), 'Should return 1 record');
        System.assertEquals(t2.Id, result.get(t1.Id).Id, 'Should return second transaction mapped by first transaction Id');
        System.assertEquals(0, emptyResult.size(), 'Null input should return empty map');
    }

    @IsTest
    static void testGetUWMLoans() {
        Test.startTest();
        List<Loan> result = TransactionRepository.getInstance().getUWMLoans();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        // Depending on data visibility and query filters, assert size or content
        // In setup, we created one UWM loan that matches criteria
        System.assertEquals(1, result.size(), 'Should find the UWM loan');
    }
}