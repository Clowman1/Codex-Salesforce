public without sharing class BackfillActiveLeadLastNotes implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id FROM Lead
            WHERE IsConverted = false
            AND Status IN (
                'New', 'Contacted/Call Back', 'Contact Attempt 1', 'Contact Attempt 2',
                'Contact Attempt 3', 'Contact Attempt 4', 'Contact Attempt 5', 'Contact Attempt 6',
                'Contact_Attempt_6', 'Working', 'Application', 'Application Link Out',
                'Documents Requested', 'Documents Received for Review', 'Under Contract'
            )
        ]);
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        LeadLastNoteService.refresh(new Map<Id, SObject>(scope).keySet());
    }

    public void finish(Database.BatchableContext context) {
    }
}
