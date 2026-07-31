@IsTest
private class LeadLoanPartnerShareTriggerHandlerTest {
    private static final String STANDARD_USER_PROFILE = 'Standard User';

    @IsTest
    static void testCreatesAndReplacesLeadLoanPartnerEditShares() {
        User ownerUser = createUser('ownerlp');
        User firstLoanPartner = createUser('lpfirst');
        User secondLoanPartner = createUser('lpsecond');
        insert new List<User>{ ownerUser, firstLoanPartner, secondLoanPartner };

        Lead leadRecord = new Lead(
            LastName = 'Lead Share Test',
            Company = 'Reach',
            OwnerId = ownerUser.Id
        );
        insert leadRecord;

        leadRecord.Loan_Partner__c = firstLoanPartner.Id;
        update leadRecord;

        List<LeadShare> firstShares = [
            SELECT Id, UserOrGroupId, LeadAccessLevel, RowCause
            FROM LeadShare
            WHERE LeadId = :leadRecord.Id
            AND UserOrGroupId = :firstLoanPartner.Id
            AND RowCause = 'Manual'
        ];
        System.assertEquals(1, firstShares.size(), 'Lead should be shared to the assigned Loan Partner.');
        System.assertEquals('Edit', firstShares[0].LeadAccessLevel, 'Loan Partner share should allow Edit access.');

        leadRecord.Loan_Partner__c = secondLoanPartner.Id;
        update leadRecord;

        Integer oldShareCount = [
            SELECT COUNT()
            FROM LeadShare
            WHERE LeadId = :leadRecord.Id
            AND UserOrGroupId = :firstLoanPartner.Id
            AND RowCause = 'Manual'
        ];
        Integer newShareCount = [
            SELECT COUNT()
            FROM LeadShare
            WHERE LeadId = :leadRecord.Id
            AND UserOrGroupId = :secondLoanPartner.Id
            AND RowCause = 'Manual'
            AND LeadAccessLevel = 'Edit'
        ];
        System.assertEquals(0, oldShareCount, 'Old Loan Partner share should be removed when the field changes.');
        System.assertEquals(1, newShareCount, 'New Loan Partner should receive Edit access.');
    }

    private static User createUser(String key) {
        Profile profile = [
            SELECT Id
            FROM Profile
            WHERE Name = :STANDARD_USER_PROFILE
            LIMIT 1
        ];

        String uniqueKey = key + String.valueOf(DateTime.now().getTime());
        return new User(
            Alias = key.substring(0, Math.min(8, key.length())),
            Email = uniqueKey + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = key,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = uniqueKey + '@example.com'
        );
    }
}