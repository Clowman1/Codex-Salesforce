@IsTest
private class BPSVerificationServiceTest {
    @IsTest
    static void testBuildVerificationContextWithBpsValue() {
        Account borrower = new Account(Name = 'Borrower Context');
        insert borrower;

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'BPS Context Transaction',
            Loan_Number__c = 'LN-1001',
            Borrower_Name__c = borrower.Id,
            BPS__c = 125.5
        );
        insert transactionRecord;

        Test.startTest();
        BPSVerificationService.VerificationContext context =
            BPSVerificationService.buildVerificationContext(transactionRecord.Id);
        Test.stopTest();

        System.assertEquals(true, context.shouldShowModal, 'Modal should be shown when BPS has a value.');
        System.assertEquals('125.50', context.bpsValue, 'BPS should be formatted to two decimal places.');
        System.assertEquals('LN-1001', context.loanNumber, 'Loan number should be returned for context.');
        System.assertEquals('Borrower Context', context.borrowerName, 'Borrower name should be returned for context.');
    }

    @IsTest
    static void testBuildVerificationContextWithoutBpsValue() {
        Transaction__c transactionRecord = new Transaction__c(Name = 'No BPS Transaction');
        insert transactionRecord;

        Test.startTest();
        BPSVerificationService.VerificationContext context =
            BPSVerificationService.buildVerificationContext(transactionRecord.Id);
        Test.stopTest();

        System.assertEquals(false, context.shouldShowModal, 'Modal should not be shown when BPS is empty.');
        System.assertEquals('', context.bpsValue, 'BPS display should be empty when BPS is blank.');
    }

    @IsTest
    static void testSaveVerificationAndReset() {
        Transaction__c transactionRecord = new Transaction__c(Name = 'Verification Save Transaction');
        insert transactionRecord;

        Test.startTest();
        BPSVerificationService.saveVerification(transactionRecord.Id, true);
        Test.stopTest();

        Transaction__c verifiedRecord = [
            SELECT BPS_Verification_Completed__c, BPS_Verification_Completed_Date_Time__c, BPS_Verified_By__c
            FROM Transaction__c
            WHERE Id = :transactionRecord.Id
        ];

        System.assertEquals(true, verifiedRecord.BPS_Verification_Completed__c, 'Verification flag should be true after confirmation.');
        System.assertNotEquals(null, verifiedRecord.BPS_Verification_Completed_Date_Time__c, 'Verification timestamp should be stamped.');
        System.assertEquals(UserInfo.getUserId(), verifiedRecord.BPS_Verified_By__c, 'Verifier should be the current user.');

        BPSVerificationService.saveVerification(transactionRecord.Id, false);

        Transaction__c resetRecord = [
            SELECT BPS_Verification_Completed__c, BPS_Verification_Completed_Date_Time__c, BPS_Verified_By__c
            FROM Transaction__c
            WHERE Id = :transactionRecord.Id
        ];

        System.assertEquals(false, resetRecord.BPS_Verification_Completed__c, 'Verification flag should be false after reset.');
        System.assertEquals(null, resetRecord.BPS_Verification_Completed_Date_Time__c, 'Verification timestamp should be cleared when reset.');
        System.assertEquals(null, resetRecord.BPS_Verified_By__c, 'Verifier should be cleared when reset.');
    }

    @IsTest
    static void testChecklistControllerVerificationMethods() {
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Controller Delegation Transaction',
            BPS__c = 100
        );
        insert transactionRecord;

        Test.startTest();
        BPSVerificationService.VerificationContext context =
            ChecklistController.getBpsVerificationContext(transactionRecord.Id);
        ChecklistController.saveBpsVerification(transactionRecord.Id, true);
        Test.stopTest();

        System.assertEquals(true, context.shouldShowModal, 'Controller should return modal context when BPS exists.');
    }

    @IsTest
    static void testChecklistControllerGetChecklistPaths() {
        List<ChecklistConfiguration__mdt> checklistConfigs = [
            SELECT Id
            FROM ChecklistConfiguration__mdt
            WHERE DeveloperName = 'Post_Closing_Checklist'
            LIMIT 1
        ];
        System.assertEquals(1, checklistConfigs.size(), 'Post Closing checklist configuration must exist for this test.');

        Transaction__c helperTransaction = new Transaction__c(Name = 'Checklist Helper Transaction');
        insert helperTransaction;

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Checklist Paths Transaction',
            BPS__c = 101,
            Transaction_Helper_Lookup__c = helperTransaction.Id
        );
        insert transactionRecord;

        Test.startTest();
        NCS_Checklist.Checklist checklistWithoutTraversal =
            ChecklistController.getChecklist(transactionRecord.Id, checklistConfigs[0].Id, null);
        NCS_Checklist.Checklist checklistWithTraversal =
            ChecklistController.getChecklist(transactionRecord.Id, checklistConfigs[0].Id, 'Transaction_Helper_Lookup__c');
        Test.stopTest();

        System.assertNotEquals(null, checklistWithoutTraversal, 'Checklist result without traversal should be returned.');
        System.assertNotEquals(null, checklistWithTraversal, 'Checklist result with traversal should be returned.');
    }
}