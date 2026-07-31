@isTest
public class Form1098PDFGeneratorBatchableTest {
    
    // Test Setup Method to create initial test data
    @testSetup
    static void setupTestData() {
        // Create a list to hold Transaction__c records
        List<Transaction__c> transactions = new List<Transaction__c>();
        
        // Populate the list with 5 Transaction__c records
        for(Integer i = 0; i < 5; i++) {
            transactions.add(new Transaction__c(
                Loan_Number__c = 'LN' + String.valueOf(1000 + i),
                Borrower_Last_Name__c = 'Doe' + i,
                Borrower_First_Name__c = 'John' + i,
                Form_recipient__c = true,
                Form_Sent__c = false,
                Borr_Email__c = 'borrower' + i + '@example.com'
            ));
        }
        
        // Insert the Transaction__c records into the database
        insert transactions;
    }
    
    // Test Method for Processing Records with Form_recipient__c = true
    @isTest
    static void testBatchableClass() {
        // Start the test context
        Test.startTest();
        
        // Initialize the batch class
        Form1098PDFGeneratorBatchable batch = new Form1098PDFGeneratorBatchable();
        
        // Retrieve the number of records to process
        Integer recordCount = [SELECT COUNT() FROM Transaction__c WHERE Form_recipient__c = TRUE];
        
        // Execute the batch with a batch size equal to the number of records
        Database.executeBatch(batch, recordCount);

        Test.stopTest();
        
        // Assert that 10 ContentVersion records were created (2 per Transaction__c)
        Integer expectedContentVersions = 10;
        Integer actualContentVersions = [SELECT COUNT() FROM ContentVersion WHERE Title LIKE 'Doe%1098 Form%'];
        System.assertEquals(expectedContentVersions, actualContentVersions, '10 ContentVersion records should be created (2 per Transaction__c).');
        
        // Assert that 10 ContentDocumentLink records were created (2 per Transaction__c)
        Integer expectedContentDocumentLinks = 10;
        Integer actualContentDocumentLinks = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId IN (SELECT Id FROM Transaction__c WHERE Form_recipient__c = FALSE)];
        System.assertEquals(expectedContentDocumentLinks, actualContentDocumentLinks, '10 ContentDocumentLink records should be created (2 per Transaction__c).');
        
        // Assert that 5 ContentDistribution records were created (1 per Transaction__c for Form B)
        Integer expectedContentDistributions = 5;
        Integer actualContentDistributions = [SELECT COUNT() FROM ContentDistribution WHERE Name LIKE 'Doe%1098 Form B'];
        System.assertEquals(expectedContentDistributions, actualContentDistributions, '5 ContentDistribution records should be created (1 per Transaction__c).');

        
        // Assert that all Transaction__c records have Form_recipient__c = false and Form_Sent__c = true
        List<Transaction__c> updatedTransactions = [SELECT Form_recipient__c, Form_Sent__c FROM Transaction__c];
        for(Transaction__c tr : updatedTransactions) {
            System.assertEquals(false, tr.Form_recipient__c, 'Form_recipient__c should be set to false.');
            System.assertEquals(true, tr.Form_Sent__c, 'Form_Sent__c should be set to true.');
        }
    }
    
    // Test Method for Processing When No Records Have Form_recipient__c = true
    @isTest
    static void testNoRecordsToProcess() {
        // Retrieve all Transaction__c records
        List<Transaction__c> transactionsToUpdate = [SELECT Id FROM Transaction__c WHERE Form_recipient__c = TRUE];
        
        // Update all Transaction__c records to set Form_recipient__c = false
        for(Transaction__c tr : transactionsToUpdate) {
            tr.Form_recipient__c = false;
        }
        update transactionsToUpdate;
        
        // Insert additional Transaction__c records with Form_recipient__c = false
        List<Transaction__c> newTransactions = new List<Transaction__c>();
        for(Integer i = 0; i < 3; i++) {
            newTransactions.add(new Transaction__c(
                Loan_Number__c = 'LN' + String.valueOf(2000 + i),
                Borrower_Last_Name__c = 'Smith' + i,
                Borrower_First_Name__c = 'Jane' + i,
                Form_recipient__c = false,
                Form_Sent__c = false,
                Borr_Email__c = 'borrower' + i + '@example.com'
            ));
        }
        insert newTransactions;
        
        // Start the test context
        Test.startTest();
        RunFormSendingInvocable.coveerage();
        RunFormSendingInvocable.runBatch();
        // Initialize the batch class
        //Form1098PDFGeneratorBatchable batch = new Form1098PDFGeneratorBatchable();
        
        // Retrieve the number of records to process (should be 0)
        Integer recordCount = [SELECT COUNT() FROM Transaction__c WHERE Form_recipient__c = TRUE];
        System.assertEquals(0, recordCount, 'There should be no Transaction__c records with Form_recipient__c = true.');
        
        // Execute the batch with a batch size of 1
        //Database.executeBatch(batch, 1);
        
        // End the test context
        Test.stopTest();
        
        // Assert that no ContentVersion records were created for the new records
        List<ContentVersion> newContentVersions = [SELECT Id FROM ContentVersion WHERE Title LIKE 'Smith%1098 Form%'];
        System.assertEquals(0, newContentVersions.size(), 'No ContentVersion records should be created for records with Form_recipient__c = false.');
        
        // Assert that no ContentDocumentLink records were created for the new records
        List<ContentDocumentLink> newContentDocumentLinks = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId IN (SELECT Id FROM Transaction__c WHERE Loan_Number__c LIKE 'LN2000%')];
        System.assertEquals(0, newContentDocumentLinks.size(), 'No ContentDocumentLink records should be created for records with Form_recipient__c = false.');
        
        // Assert that no ContentDistribution records were created for the new records
        List<ContentDistribution> newContentDistributions = [SELECT Id FROM ContentDistribution WHERE Name LIKE 'Smith%1098 Form B'];
        System.assertEquals(0, newContentDistributions.size(), 'No ContentDistribution records should be created for records with Form_recipient__c = false.');
        
        // Assert that no additional emails were sent
        Integer emailInvocations = Limits.getEmailInvocations();
        System.assertEquals(0, emailInvocations, 'No email invocations should have occurred.');
        
        // Assert that the new Transaction__c records remain unchanged
        List<Transaction__c> updatedNewTransactions = [SELECT Form_recipient__c, Form_Sent__c FROM Transaction__c WHERE Loan_Number__c LIKE 'LN2000%'];
        for(Transaction__c tr : updatedNewTransactions) {
            System.assertEquals(false, tr.Form_recipient__c, 'Form_recipient__c should remain false.');
            System.assertEquals(false, tr.Form_Sent__c, 'Form_Sent__c should remain false.');
        }
    }
}