trigger EnhancedNoteLeadLastNote on Enhanced_Note__c (after insert, after update, after delete, after undelete) {
    LeadLastNoteService.refreshForNotes(
        Trigger.isDelete ? Trigger.old : Trigger.new,
        Trigger.isInsert || Trigger.isUndelete ? null : Trigger.oldMap
    );
}
