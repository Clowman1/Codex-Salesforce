@isTest
private class NickleyRealtorLeadDateServiceTest {
    @isTest
    static void returnsEmptyMapForNullOrEmptyIds() {
        System.assert(NickleyRealtorLeadDateService.lastLeadSentDates(null).isEmpty());
        System.assert(NickleyRealtorLeadDateService.lastLeadSentDates(new Set<Id>()).isEmpty());
    }

    @isTest
    static void returnsMaxCreatedDatePerAccountAcrossOwners() {
        Id personAccountRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();
        Account realtorAccount = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Test',
            LastName = 'Realtor',
            Type__c = 'Realtor Account',
            Group__pc = 'Realtor',
            Is_Realtor__c = true,
            Realtor_Group__c = 'The Nickley Group'
        );
        insert realtorAccount;

        List<User> owners = [SELECT Id FROM User WHERE IsActive = true LIMIT 2];
        System.assert(owners.size() >= 1, 'Test org must have at least one active user.');

        Lead olderLead = new Lead(
            LastName = 'Older Lead',
            Company = 'N/A',
            Realtor_Buying_Agent__c = realtorAccount.Id,
            OwnerId = owners[0].Id
        );
        insert olderLead;
        Test.setCreatedDate(olderLead.Id, DateTime.now().addDays(-10));

        Id newerOwnerId = owners.size() > 1 ? owners[1].Id : owners[0].Id;
        Lead newerLead = new Lead(
            LastName = 'Newer Lead',
            Company = 'N/A',
            Realtor_Buying_Agent__c = realtorAccount.Id,
            OwnerId = newerOwnerId
        );
        insert newerLead;
        Datetime newerLeadCreatedDate = [SELECT CreatedDate FROM Lead WHERE Id = :newerLead.Id].CreatedDate;

        Test.startTest();
        Map<Id, Datetime> result = NickleyRealtorLeadDateService.lastLeadSentDates(new Set<Id>{ realtorAccount.Id });
        Test.stopTest();

        System.assert(result.containsKey(realtorAccount.Id));
        System.assertEquals(
            newerLeadCreatedDate,
            result.get(realtorAccount.Id),
            'Should return the most recent CreatedDate across leads regardless of owner.'
        );
    }
}