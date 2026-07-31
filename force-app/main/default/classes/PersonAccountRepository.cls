public with sharing class PersonAccountRepository {
    /**
     * Resolve the Person Account record type by developer name.
     */
    public Id selectPersonAccountRecordTypeId() {
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName = 'PersonAccount'
            LIMIT 1
        ];
        return recordTypes.isEmpty() ? null : recordTypes[0].Id;
    }

    /**
     * Finds an existing Person Account by normalized email.
     */
    public Account selectPersonAccountByEmail(String email) {
        if (String.isBlank(email)) {
            return null;
        }

        String normalizedEmail = email.trim();
        List<Account> accounts = [
            SELECT Id, Name, PersonEmail
            FROM Account
            WHERE IsPersonAccount = true
            AND PersonEmail != null
            AND PersonEmail = :normalizedEmail
            WITH SECURITY_ENFORCED
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return accounts.isEmpty() ? null : accounts[0];
    }

    public Account selectPersonAccountById(Id accountId) {
        if (accountId == null) {
            return null;
        }

        List<Account> accounts = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :accountId
            AND IsPersonAccount = true
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return accounts.isEmpty() ? null : accounts[0];
    }
}