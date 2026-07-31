@IsTest
private class BackfillActiveLeadLastNotesTest {
    @IsTest
    static void refreshesOnlyActiveLeads() {
        Lead activeLead = new Lead(LastName = 'Batch Active', Company = 'Reach', Status = 'New');
        Lead inactiveLead = new Lead(LastName = 'Batch Inactive', Company = 'Reach', Status = 'Closed');
        insert new List<Lead>{ activeLead, inactiveLead };
        insert new Enhanced_Note__c(Lead__c = activeLead.Id, Subject__c = 'Batch note', Body__c = '<p>Batch note</p>', Type__c = 'Note');

        Test.startTest();
        Database.executeBatch(new BackfillActiveLeadLastNotes(), 25);
        Test.stopTest();

        activeLead = [SELECT Last_Note__c FROM Lead WHERE Id = :activeLead.Id];
        inactiveLead = [SELECT Last_Note__c FROM Lead WHERE Id = :inactiveLead.Id];
        System.assert(activeLead.Last_Note__c.contains('Batch note'));
        System.assertEquals(null, inactiveLead.Last_Note__c);
    }
}
