@IsTest
private class ManualLeadOwnerNotificationServiceTest {
    private static User createUser(String suffix, String firstName, String lastName) {
        Profile profileRecord = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];
        String uniqueValue = String.valueOf(DateTime.now().getTime()) + suffix;
        User userRecord = new User(
            Alias = ('mlo' + suffix).left(8),
            Email = 'mlo' + uniqueValue + '@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = firstName,
            LastName = lastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileRecord.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'mlo' + uniqueValue + '@example.com'
        );
        insert userRecord;
        return userRecord;
    }

    @IsTest
    static void notifyOwnersSendsForManualUserOwnedLead() {
        User ownerUser = createUser('owner', 'Manual', 'Owner');
        Lead leadRecord = new Lead(
            FirstName = 'Test',
            LastName = 'Manual',
            Company = 'Test Manual',
            Status = 'New',
            OwnerId = ownerUser.Id
        );
        insert leadRecord;

        Test.startTest();
        ManualLeadOwnerNotificationService.notifyOwners(new List<Lead>{ leadRecord });
        Test.stopTest();

        System.assertEquals(1, Limits.getEmailInvocations(), 'Expected one notification email invocation.');
    }

    @IsTest
    static void buildEmailsSkipsReferralFormLeadsAndUsesExpectedContent() {
        User ownerUser = createUser('content', 'Email', 'Recipient');
        Lead eligibleLead = new Lead(
            FirstName = 'Hello',
            LastName = 'World',
            Company = 'Hello World Co',
            Status = 'New',
            OwnerId = ownerUser.Id
        );
        insert eligibleLead;

        Lead excludedLead = new Lead(
            FirstName = 'Referral',
            LastName = 'Lead',
            Company = 'Referral Lead Co',
            Status = 'New',
            OwnerId = ownerUser.Id,
            ReferralFormSourceEmail__c = 'agent@example.com'
        );
        insert excludedLead;

        List<Lead> leadsForEmailBuild = [
            SELECT Id, FirstName, LastName, Name, OwnerId, Owner.Email, ReferralFormSourceEmail__c
            FROM Lead
            WHERE Id IN :new Set<Id>{ eligibleLead.Id, excludedLead.Id }
            ORDER BY CreatedDate ASC
        ];

        List<Messaging.SingleEmailMessage> emails = ManualLeadOwnerNotificationService.buildEmails(
            leadsForEmailBuild
        );

        System.assertEquals(1, emails.size(), 'Expected only the manual lead to generate an email.');
    }
}