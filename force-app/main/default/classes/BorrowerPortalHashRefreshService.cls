public with sharing class BorrowerPortalHashRefreshService {
    private static final String ORG_DEFAULT_AES_KEY_NAME = 'Org security key';

    public static void rotateConfiguredAesKey() {
        String nextAesKey = BorrowerPortalEncryptionService.generateAesKeyString();
        AesKey__c orgDefaults = AesKey__c.getOrgDefaults();

        if (orgDefaults == null || orgDefaults.Id == null) {
            insert new AesKey__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                Name = ORG_DEFAULT_AES_KEY_NAME,
                AesKey__c = nextAesKey
            );
            return;
        }

        update new AesKey__c(
            Id = orgDefaults.Id,
            Name = String.isBlank(orgDefaults.Name) ? ORG_DEFAULT_AES_KEY_NAME : orgDefaults.Name,
            AesKey__c = nextAesKey
        );
    }

    public static void refreshPortalHashes(List<Transaction__c> transactionScope) {
        if (transactionScope == null || transactionScope.isEmpty()) {
            return;
        }

        List<Transaction__c> transactionsToUpdate = new List<Transaction__c>();
        for (Transaction__c transactionRecord : transactionScope) {
            if (transactionRecord.Id == null) {
                continue;
            }

            transactionsToUpdate.add(new Transaction__c(
                Id = transactionRecord.Id,
                Portal_Hash_Parameter__c = BorrowerPortalService.encryptTransactionId(transactionRecord.Id)
            ));
        }

        if (!transactionsToUpdate.isEmpty()) {
            update transactionsToUpdate;
        }
    }
}