@IsTest
private class BorrowerPortalHashRefreshBatchTest {
    private static final String ORIGINAL_AES_KEY = '12345678901234567890123456789012';
    private static final String ROTATED_AES_KEY = 'abcdefghijklmnopqrstuvwxyz123456';

    @IsTest
    static void batchRotatesKeyAndRefreshesExistingPortalHashes() {
        BorrowerPortalEncryptionService.testKeyOverride = null;
        BorrowerPortalEncryptionService.testGeneratedKeyOverride = null;

        upsert new AesKey__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Name = 'Org Defaults',
            AesKey__c = ORIGINAL_AES_KEY
        );

        Transaction__c hashedTransaction = new Transaction__c(
            Name = 'Hashed Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-PORTAL-ROTATE-001'
        );
        Transaction__c blankTransaction = new Transaction__c(
            Name = 'Blank Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-PORTAL-ROTATE-002'
        );
        insert new List<Transaction__c>{ hashedTransaction, blankTransaction };

        String originalHash = BorrowerPortalService.encryptTransactionId(hashedTransaction.Id);
        update new Transaction__c(
            Id = hashedTransaction.Id,
            Portal_Hash_Parameter__c = originalHash
        );

        BorrowerPortalEncryptionService.testGeneratedKeyOverride = ROTATED_AES_KEY;

        Test.startTest();
        Database.executeBatch(new BorrowerPortalHashRefreshBatch(), 50);
        Test.stopTest();

        AesKey__c refreshedSettings = AesKey__c.getOrgDefaults();
        Map<Id, Transaction__c> refreshedTransactions = new Map<Id, Transaction__c>([
            SELECT Id, Portal_Hash_Parameter__c
            FROM Transaction__c
            WHERE Id IN :new Set<Id>{ hashedTransaction.Id, blankTransaction.Id }
        ]);

        System.assertEquals(ROTATED_AES_KEY, refreshedSettings.AesKey__c);
        System.assertNotEquals(
            originalHash,
            refreshedTransactions.get(hashedTransaction.Id).Portal_Hash_Parameter__c
        );
        System.assertEquals(
            null,
            refreshedTransactions.get(blankTransaction.Id).Portal_Hash_Parameter__c
        );

        BorrowerPortalEncryptionService.testKeyOverride = ROTATED_AES_KEY;
        System.assertEquals(
            hashedTransaction.Id,
            BorrowerDocumentPortalController.decryptRecordId(
                refreshedTransactions.get(hashedTransaction.Id).Portal_Hash_Parameter__c
            )
        );
    }

    @IsTest
    static void schedulableExecutesBorrowerPortalHashRefreshBatch() {
        BorrowerPortalEncryptionService.testKeyOverride = null;
        BorrowerPortalEncryptionService.testGeneratedKeyOverride = null;

        upsert new AesKey__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Name = 'Org Defaults',
            AesKey__c = ORIGINAL_AES_KEY
        );

        Transaction__c hashedTransaction = new Transaction__c(
            Name = 'Scheduled Hash Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-PORTAL-ROTATE-003'
        );
        insert hashedTransaction;

        String originalHash = BorrowerPortalService.encryptTransactionId(hashedTransaction.Id);
        update new Transaction__c(
            Id = hashedTransaction.Id,
            Portal_Hash_Parameter__c = originalHash
        );

        BorrowerPortalEncryptionService.testGeneratedKeyOverride = ROTATED_AES_KEY;

        Test.startTest();
        new BorrowerPortalHashRefreshBatch().execute((SchedulableContext)null);
        Test.stopTest();

        Transaction__c refreshedTransaction = [
            SELECT Portal_Hash_Parameter__c
            FROM Transaction__c
            WHERE Id = :hashedTransaction.Id
        ];

        BorrowerPortalEncryptionService.testKeyOverride = ROTATED_AES_KEY;
        System.assertNotEquals(originalHash, refreshedTransaction.Portal_Hash_Parameter__c);
        System.assertEquals(
            hashedTransaction.Id,
            BorrowerDocumentPortalController.decryptRecordId(refreshedTransaction.Portal_Hash_Parameter__c)
        );
    }

    @IsTest
    static void serviceCreatesOrgDefaultsAndSkipsEmptyRefreshRecords() {
        BorrowerPortalEncryptionService.testKeyOverride = null;
        BorrowerPortalEncryptionService.testGeneratedKeyOverride = ROTATED_AES_KEY;

        Transaction__c savedTransaction = new Transaction__c(
            Name = 'Refresh Service Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-PORTAL-ROTATE-004'
        );
        insert savedTransaction;

        Test.startTest();
        BorrowerPortalHashRefreshService.rotateConfiguredAesKey();
        BorrowerPortalHashRefreshService.refreshPortalHashes(null);
        BorrowerPortalHashRefreshService.refreshPortalHashes(new List<Transaction__c>());
        BorrowerPortalHashRefreshService.refreshPortalHashes(new List<Transaction__c>{
            new Transaction__c(Name = 'Unsaved Record'),
            new Transaction__c(Id = savedTransaction.Id)
        });
        Test.stopTest();

        AesKey__c refreshedSettings = AesKey__c.getOrgDefaults();
        Transaction__c refreshedTransaction = [
            SELECT Portal_Hash_Parameter__c
            FROM Transaction__c
            WHERE Id = :savedTransaction.Id
        ];

        System.assertEquals(ROTATED_AES_KEY, refreshedSettings.AesKey__c);
        System.assertEquals(false, String.isBlank(refreshedSettings.Name));
        System.assertNotEquals(null, refreshedTransaction.Portal_Hash_Parameter__c);
    }

    @IsTest
    static void hashInvocableEncryptsTransactionIds() {
        BorrowerPortalEncryptionService.testKeyOverride = ORIGINAL_AES_KEY;
        BorrowerPortalEncryptionService.testGeneratedKeyOverride = null;

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Hash Invocable Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-PORTAL-HASH-005'
        );
        insert transactionRecord;

        BorrowerPortalHashInvocable.Request requestItem = new BorrowerPortalHashInvocable.Request();
        requestItem.recordId = transactionRecord.Id;

        Test.startTest();
        List<String> hashes = BorrowerPortalHashInvocable.encryptTransactionIds(
            new List<BorrowerPortalHashInvocable.Request>{ requestItem }
        );
        Test.stopTest();

        System.assertEquals(1, hashes.size());
        System.assertEquals(transactionRecord.Id, BorrowerPortalService.decryptTransactionId(hashes[0]));
    }

    @IsTest
    static void populateHashInvocablePopulatesOnlyMissingHashes() {
        BorrowerPortalEncryptionService.testKeyOverride = ORIGINAL_AES_KEY;
        BorrowerPortalEncryptionService.testGeneratedKeyOverride = null;

        Transaction__c blankHashTransaction = new Transaction__c(
            Name = 'Populate Hash Transaction A',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-PORTAL-HASH-006'
        );
        Transaction__c existingHashTransaction = new Transaction__c(
            Name = 'Populate Hash Transaction B',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-PORTAL-HASH-007',
            Portal_Hash_Parameter__c = 'existing-hash-value'
        );
        insert new List<Transaction__c>{ blankHashTransaction, existingHashTransaction };

        BorrowerPortalPopulateHashInvocable.Request blankHashRequest =
            new BorrowerPortalPopulateHashInvocable.Request();
        blankHashRequest.recordId = blankHashTransaction.Id;

        BorrowerPortalPopulateHashInvocable.Request existingHashRequest =
            new BorrowerPortalPopulateHashInvocable.Request();
        existingHashRequest.recordId = existingHashTransaction.Id;

        BorrowerPortalPopulateHashInvocable.Request nullIdRequest =
            new BorrowerPortalPopulateHashInvocable.Request();

        Test.startTest();
        BorrowerPortalPopulateHashInvocable.populateHashes(
            new List<BorrowerPortalPopulateHashInvocable.Request>{
                null,
                nullIdRequest,
                blankHashRequest,
                existingHashRequest
            }
        );
        Test.stopTest();

        Map<Id, Transaction__c> refreshedTransactions = new Map<Id, Transaction__c>([
            SELECT Portal_Hash_Parameter__c
            FROM Transaction__c
            WHERE Id IN :new Set<Id>{ blankHashTransaction.Id, existingHashTransaction.Id }
        ]);

        System.assertEquals(
            blankHashTransaction.Id,
            BorrowerPortalService.decryptTransactionId(
                refreshedTransactions.get(blankHashTransaction.Id).Portal_Hash_Parameter__c
            )
        );
        System.assertEquals(
            'existing-hash-value',
            refreshedTransactions.get(existingHashTransaction.Id).Portal_Hash_Parameter__c
        );
    }

}