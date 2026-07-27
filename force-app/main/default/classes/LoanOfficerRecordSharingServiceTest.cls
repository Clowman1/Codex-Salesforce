@IsTest
private class LoanOfficerRecordSharingServiceTest {
    @IsTest
    static void createsTransactionSharesForLoanOfficerAndLoanPartner() {
        User loanOfficer = getAlternateActiveUser();
        User partnerUser = createUser('txpartner');

        Account lender = new Account(
            Name = 'Sharing Test Lender',
            Type = 'Investor'
        );
        insert lender;

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Sharing Transaction',
            OwnerId = UserInfo.getUserId(),
            Loan_Officer__c = loanOfficer.Id,
            Loan_Partner__c = partnerUser.Id,
            Status__c = 'Processing',
            Loan_Purpose__c = 'Purchase',
            Lender_lookup__c = lender.Id,
            Processor__c = UserInfo.getUserId(),
            Loan_Commitment_Date__c = Date.today().addDays(14)
        );

        Test.startTest();
        insert transactionRecord;
        Test.stopTest();

        Set<Id> sharedUserIds = new Set<Id>();
        for (Transaction__Share shareRecord : [
            SELECT UserOrGroupId
            FROM Transaction__Share
            WHERE ParentId = :transactionRecord.Id
            AND RowCause = 'Manual'
        ]) {
            sharedUserIds.add(shareRecord.UserOrGroupId);
        }

        System.assert(sharedUserIds.contains(loanOfficer.Id), 'Expected the transaction loan officer to receive a share.');
        System.assert(sharedUserIds.contains(partnerUser.Id), 'Expected the transaction loan partner to receive a share.');
    }

    private static User getAlternateActiveUser() {
        List<User> users = [
            SELECT Id
            FROM User
            WHERE Id != :UserInfo.getUserId()
            AND IsActive = true
            AND UserType = 'Standard'
            LIMIT 1
        ];
        System.assert(!users.isEmpty(), 'Expected at least one alternate active user for sharing coverage.');
        return users[0];
    }

    private static User createUser(String prefix) {
        Profile profileRecord = [
            SELECT Id
            FROM Profile
            WHERE UserType = 'Standard'
            LIMIT 1
        ];
        String uniqueValue = prefix + String.valueOf(System.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User testUser = new User(
            Alias = uniqueValue.left(8),
            Email = uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = prefix,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileRecord.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = uniqueValue + '@example.com'
        );
        insert testUser;
        return testUser;
    }

}
