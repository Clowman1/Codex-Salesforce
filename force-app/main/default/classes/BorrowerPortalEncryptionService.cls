public with sharing class BorrowerPortalEncryptionService {
    @TestVisible
    private static String testKeyOverride;
    @TestVisible
    private static String testGeneratedKeyOverride;

    public static String encryptString(String valueToEncrypt) {
        Blob encrypted = Crypto.encryptWithManagedIV(
            'AES256',
            getAesKey(),
            Blob.valueOf(valueToEncrypt)
        );
        return EncodingUtil.convertToHex(encrypted);
    }

    public static String decryptString(String encryptedValue) {
        Blob decrypted = Crypto.decryptWithManagedIV(
            'AES256',
            getAesKey(),
            EncodingUtil.convertFromHex(encryptedValue)
        );
        return decrypted.toString();
    }

    private static Blob getAesKey() {
        String configuredKey = Test.isRunningTest() && String.isNotBlank(testKeyOverride)
            ? testKeyOverride
            : getConfiguredKey();

        Integer keyLength = Blob.valueOf(configuredKey).size();
        if (keyLength != 16 && keyLength != 24 && keyLength != 32) {
            throw new BorrowerPortalEncryptionServiceException(
                'Borrower portal AES key must be 16, 24, or 32 bytes.'
            );
        }

        return Blob.valueOf(configuredKey);
    }

    private static String getConfiguredKey() {
        AesKey__c defaults = AesKey__c.getOrgDefaults();
        if (defaults == null || String.isBlank(defaults.AesKey__c)) {
            throw new BorrowerPortalEncryptionServiceException(
                'Borrower portal AES key is not configured.'
            );
        }

        return defaults.AesKey__c;
    }

    public static String generateAesKeyString() {
        if (Test.isRunningTest() && String.isNotBlank(testGeneratedKeyOverride)) {
            return testGeneratedKeyOverride;
        }

        Blob randomKey = Crypto.generateAesKey(256);
        return EncodingUtil.base64Encode(randomKey).substring(0, 32);
    }

    public class BorrowerPortalEncryptionServiceException extends Exception {}
}