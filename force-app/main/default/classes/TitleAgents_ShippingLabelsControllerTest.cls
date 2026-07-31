@isTest
private class TitleAgents_ShippingLabelsControllerTest {
    @isTest
    static void testControllerMethods() {
        // Set up test data
        Account acc = new Account(Name = 'Test Borrower');
        insert acc;
        
        Transaction__c txn = new Transaction__c(
            Name = 'Test Transaction',
            Borrower_Name__c = acc.Id
        );
        insert txn;
        
        // Set page parameters
        Test.setCurrentPageReference(new PageReference('/apex/TitleConfirmation'));
        ApexPages.currentPage().getParameters().put('rid', txn.Id);
        
        // Instantiate controller
        TitleAgents_ShippingLabelsController controller = new TitleAgents_ShippingLabelsController();
        
        // Verify initial state
        System.assertEquals('Test Borrower', controller.fileName);
        System.assertEquals(false, controller.isConfirmed);
        System.assertEquals(false, controller.isError);
        
        // Test updateConfirmation
        controller.updateConfirmation();
        Transaction__c updatedTxn = [SELECT FedEx_Labels_Received__c FROM Transaction__c WHERE Id = :txn.Id];
        System.assertNotEquals(null, updatedTxn.FedEx_Labels_Received__c);
        System.assertEquals(true, controller.isConfirmed);
        
        // Test rejectClosingPackage
        controller.notes = 'Package incomplete';
        controller.rejectClosingPackage();
        updatedTxn = [SELECT Closing_Package_Status__c, Closing_Package_Rejection_Notes__c FROM Transaction__c WHERE Id = :txn.Id];
        System.assertEquals('Rejected', updatedTxn.Closing_Package_Status__c);
        System.assertEquals('Package incomplete', updatedTxn.Closing_Package_Rejection_Notes__c);
        System.assertEquals(false, controller.isConfirmed);
        
        // Test acceptClosingPackage
        controller.acceptClosingPackage();
        updatedTxn = [SELECT Closing_Package_Status__c FROM Transaction__c WHERE Id = :txn.Id];
        System.assertEquals('Accepted', updatedTxn.Closing_Package_Status__c);
        System.assertEquals(true, controller.isConfirmed);
    }
}