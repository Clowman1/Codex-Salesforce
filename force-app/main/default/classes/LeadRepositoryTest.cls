@IsTest
private class LeadRepositoryTest {
    private static Lead createLeadForRepoTest() {
        Id realtorLeadRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Lead'
            AND DeveloperName = 'Realtor_Lead_record_type'
            LIMIT 1
        ].Id;

        Lead leadRecord = new Lead(
            RecordTypeId = realtorLeadRecordTypeId,
            FirstName = 'Repo',
            LastName = 'Test',
            Company = 'Repo Co',
            Email = 'repo-test@example.com'
        );
        insert leadRecord;
        return leadRecord;
    }

    @IsTest
    static void testGetLeadById() {
        Lead leadRecord = createLeadForRepoTest();

        Test.startTest();
        Lead loadedLead = LeadRepository.getInstance().getLeadById(leadRecord.Id);
        Test.stopTest();

        System.assertNotEquals(null, loadedLead);
        System.assertEquals(leadRecord.Id, loadedLead.Id);
    }

    @IsTest
    static void testSelectForRealtorConvert() {
        Lead leadRecord = createLeadForRepoTest();

        Test.startTest();
        Lead loadedLead = LeadRepository.getInstance().selectForRealtorConvert(leadRecord.Id);
        Test.stopTest();

        System.assertNotEquals(null, loadedLead);
        System.assertEquals(leadRecord.Id, loadedLead.Id);
        System.assertEquals('Realtor_Lead_record_type', loadedLead.RecordType.DeveloperName);
    }

    @IsTest
    static void testSelectSmsOptOutByIds() {
        Lead leadRecord = createLeadForRepoTest();

        Test.startTest();
        Map<Id, Lead> loadedLeads = LeadRepository.getInstance().selectSmsOptOutByIds(new Set<Id>{ leadRecord.Id });
        Map<Id, Lead> emptyResult = LeadRepository.getInstance().selectSmsOptOutByIds(new Set<Id>());
        Test.stopTest();

        System.assertEquals(true, loadedLeads.containsKey(leadRecord.Id));
        System.assertEquals(0, emptyResult.size());
    }

    @IsTest
    static void testSelectConvertedByIds_returns_converted_lead() {
        Lead l = new Lead(
            FirstName = 'Conv',
            LastName = 'Lead',
            Company = 'Test Co',
            Email = 'conv.lead.repo.test+' + String.valueOf(Crypto.getRandomInteger()) + '@example.com',
            Status = 'Open - Not Contacted'
        );
        insert l;

        LeadStatus convertedStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(l.Id);
        lc.setConvertedStatus(convertedStatus.MasterLabel);
        Database.LeadConvertResult conv = Database.convertLead(lc);
        System.assertEquals(true, conv.isSuccess());

        Test.startTest();
        Map<Id, Lead> rows = LeadRepository.getInstance().selectConvertedByIds(new Set<Id>{ l.Id });
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals(true, rows.get(l.Id).IsConverted);
        System.assertNotEquals(null, rows.get(l.Id).ConvertedAccountId);
    }
}