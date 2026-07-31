@IsTest
private class LeadLastNoteServiceTest {
    @IsTest
    static void usesNewestActiveNoteAndRefreshesWhenItIsDeleted() {
        Lead lead = new Lead(LastName = 'Last Note Test', Company = 'Reach', Status = 'New');
        insert lead;

        Enhanced_Note__c firstNote = new Enhanced_Note__c(
            Lead__c = lead.Id,
            Subject__c = 'First note',
            Body__c = '<p>First enhanced note</p>',
            Type__c = 'Note'
        );
        insert firstNote;

        lead = [SELECT Last_Note__c FROM Lead WHERE Id = :lead.Id];
        System.assert(lead.Last_Note__c.contains('First enhanced note'));
        System.assert(lead.Last_Note__c.contains('Logged:'));

        Enhanced_Note__c newestNote = new Enhanced_Note__c(
            Lead__c = lead.Id,
            Subject__c = 'Newest note',
            Body__c = '<p>Newest enhanced note</p>',
            Type__c = 'Note'
        );
        insert newestNote;

        lead = [SELECT Last_Note__c FROM Lead WHERE Id = :lead.Id];
        System.assert(lead.Last_Note__c.contains('Newest enhanced note'));

        Enhanced_Note__c newestCall = new Enhanced_Note__c(
            Lead__c = lead.Id,
            Subject__c = 'Newest call',
            Body__c = '<p>Newest call should stay off Last Note</p>',
            Type__c = 'Call'
        );
        insert newestCall;

        lead = [SELECT Last_Note__c FROM Lead WHERE Id = :lead.Id];
        System.assert(lead.Last_Note__c.contains('Newest enhanced note'));
        System.assert(!lead.Last_Note__c.contains('Newest call should stay off Last Note'));

        newestNote.IsDeleted__c = true;
        update newestNote;

        lead = [SELECT Last_Note__c FROM Lead WHERE Id = :lead.Id];
        System.assert(lead.Last_Note__c.contains('First enhanced note'));
        System.assert(!lead.Last_Note__c.contains('Newest enhanced note'));

        Lead secondLead = new Lead(LastName = 'Clear Last Note Test', Company = 'Reach', Status = 'New');
        insert secondLead;
        Enhanced_Note__c onlyNote = new Enhanced_Note__c(
            Lead__c = secondLead.Id,
            Subject__c = 'Only note',
            Body__c = '<p>Only enhanced note</p>',
            Type__c = 'Note'
        );
        insert onlyNote;
        delete onlyNote;

        secondLead = [SELECT Last_Note__c FROM Lead WHERE Id = :secondLead.Id];
        System.assertEquals(null, secondLead.Last_Note__c);
    }
}
