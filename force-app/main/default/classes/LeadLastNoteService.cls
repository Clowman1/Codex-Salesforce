public without sharing class LeadLastNoteService {
    private static final Integer MAX_FIELD_LENGTH = 130000;

    public static void refreshForNotes(
        List<Enhanced_Note__c> newRecords,
        Map<Id, Enhanced_Note__c> oldMap
    ) {
        Set<Id> leadIds = new Set<Id>();
        collectLeadIds(leadIds, newRecords);
        if (oldMap != null) {
            collectLeadIds(leadIds, oldMap.values());
        }
        refresh(leadIds);
    }

    public static void refresh(Set<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        Map<Id, Enhanced_Note__c> latestByLeadId = new Map<Id, Enhanced_Note__c>();
        for (Enhanced_Note__c note : [
            SELECT Lead__c, Body__c, CreatedDate
            FROM Enhanced_Note__c
            WHERE Lead__c IN :leadIds
            AND IsDeleted__c = false
            AND Type__c = 'Note'
            ORDER BY Lead__c, CreatedDate DESC, Id DESC
        ]) {
            if (!latestByLeadId.containsKey(note.Lead__c)) {
                latestByLeadId.put(note.Lead__c, note);
            }
        }

        List<Lead> leadsToUpdate = new List<Lead>();
        for (Id leadId : leadIds) {
            Enhanced_Note__c latestNote = latestByLeadId.get(leadId);
            String value = latestNote == null ? null : formatLatestNote(latestNote);
            leadsToUpdate.add(new Lead(Id = leadId, Last_Note__c = value));
        }
        if (!leadsToUpdate.isEmpty()) {
            Database.update(leadsToUpdate, false, AccessLevel.SYSTEM_MODE);
        }
    }

    private static void collectLeadIds(Set<Id> leadIds, Iterable<Enhanced_Note__c> notes) {
        if (notes == null) {
            return;
        }
        for (Enhanced_Note__c note : notes) {
            if (note.Lead__c != null) {
                leadIds.add(note.Lead__c);
            }
        }
    }

    private static String formatLatestNote(Enhanced_Note__c note) {
        String header = '<p><strong>Logged: ' + note.CreatedDate.format('M/d/yyyy h:mm a') + '</strong></p>';
        String body = note.Body__c == null ? '' : note.Body__c;
        String value = header + body;
        return value.length() > MAX_FIELD_LENGTH ? value.substring(0, MAX_FIELD_LENGTH) : value;
    }
}
