@isTest 
private class TransactionControllerTest {

	@TestSetup
	static void testSetup(){
		Account a = new Account(PersonLeadSource='Website - Refi',LastName='test');
		insert a;
		Transaction__c t = new Transaction__c(Status__c='TRID Application',Borrower_Name__c=a.Id);
		insert t;
		
	}

	@isTest
	private static void testCloneTransaction() {
		Transaction__c t = [SELECT Id FROM Transaction__c LIMIT 1];
		String clonedId = TransactionController.clone('Transaction',t.Id);
		List<Transaction__c> transactions = [SELECT Id FROM Transaction__c];
		System.assertEquals(2,transactions.size());
	}
}