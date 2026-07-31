@IsTest
public class ConvertLeadsInvocableTest {
    
    @TestSetup
    static void setup() {

        RecordType consumerRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead' AND Name LIKE '%Consumer%' LIMIT 1];
        RecordType realtorRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'Lead' AND Name LIKE '%Realtor%' LIMIT 1];
        
        Lead consumerLead = new Lead(
            LastName = 'Test Consumer',
            Company = 'Test Company',
            RecordTypeId = consumerRecordType.Id
        );
        insert consumerLead;
        
        Lead realtorLead = new Lead(
            LastName = 'Test Realtor',
            Company = 'Test Company',
            RecordTypeId = realtorRecordType.Id
        );
        insert realtorLead;
    }

    @IsTest
    static void testConvertLeads() {

        Lead consumerLead = [SELECT Id FROM Lead WHERE LastName = 'Test Consumer' LIMIT 1];
        Lead realtorLead = [SELECT Id FROM Lead WHERE LastName = 'Test Realtor' LIMIT 1];

        List<Id> leadIds = new List<Id>{ consumerLead.Id, realtorLead.Id };

        Test.startTest();
        ConvertLeadsInvocable.convertLeads(leadIds);
        Test.stopTest();
        
        Lead consumerLeadAfter = [SELECT Id, IsConverted FROM Lead WHERE Id = :consumerLead.Id];
        Lead realtorLeadAfter = [SELECT Id, IsConverted FROM Lead WHERE Id = :realtorLead.Id];

        System.assert(consumerLeadAfter.IsConverted, 'Consumer Lead should be converted.');
        System.assert(realtorLeadAfter.IsConverted, 'Realtor Lead should be converted.');
    }
}