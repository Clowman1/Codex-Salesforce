@IsTest
public class ClosingPortalControllerTests {
    
    @IsTest public static void test() {
        // Set up test data
        Account acc = new Account(Name = 'Test Borrower');
        insert acc;
        
        Transaction__c txn = new Transaction__c(
            Name = 'Test Transaction',
            Borrower_Name__c = acc.Id
        );
        insert txn;
        
        Test.startTest();
        ClosingPortalController.getTransactionStatus(txn.Id);
        ClosingPortalController.updateTransactionStatus(txn.Id, 'Rejected', 'Test Rejection Note');
        ClosingPortalController.sendEmail(txn.Id, new List<String> { 'Test File Name #1' });
        Test.stopTest();
    }
    
}