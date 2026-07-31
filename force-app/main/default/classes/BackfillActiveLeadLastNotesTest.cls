@IsTest
private class BackfillActiveLeadLastNotesTest {
    @IsTest
    static void refreshesOnlyActiveLeads() {
        Lead activeLead = new Lead(LastName = 'Batch Active', Company = 'Reach', Status = 'New');
        Lead preApprovalLead = new Lead(
            LastName = 'Batch Pre Approval',
            Company = 'Reach',
            Status = 'Pre-Approval',
            Rating = 'Hot',
            Loan_Amount__c = 250000
        );
        Lead inactiveLead = new Lead(LastName = 'Batch Inactive', Company = 'Reach', Status = 'Closed');
        insert new List<Lead>{ activeLead, preApprovalLead, inactiveLead };
        insert new Enhanced_Note__c(Lead__c = activeLead.Id, Subject__c = 'Batch note', Body__c = '<p>Batch note</p>', Type__c = 'Note');
        insert new Enhanced_Note__c(Lead__c = preApprovalLead.Id, Subject__c = 'Pre Approval note', Body__c = '<p>Pre Approval note</p>', Type__c = 'Note');

        Test.startTest();
        Database.executeBatch(new BackfillActiveLeadLastNotes(), 25);
        Test.stopTest();

        activeLead = [SELECT Last_Note__c FROM Lead WHERE Id = :activeLead.Id];
        preApprovalLead = [SELECT Last_Note__c FROM Lead WHERE Id = :preApprovalLead.Id];
        inactiveLead = [SELECT Last_Note__c FROM Lead WHERE Id = :inactiveLead.Id];
        System.assert(activeLead.Last_Note__c.contains('Batch note'));
        System.assert(preApprovalLead.Last_Note__c.contains('Pre Approval note'));
        System.assertEquals(null, inactiveLead.Last_Note__c);
    }
}
