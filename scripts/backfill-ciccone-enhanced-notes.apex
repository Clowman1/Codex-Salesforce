Id leadId = '00QQi00000mPf7aMAC';
Set<Id> noteIds = new Set<Id>{
    '069Qi00000vRgKIIA0',
    '069Qi00000vSbjlIAC'
};

List<Enhanced_Note__c> existing = [
    SELECT Id, Subject__c
    FROM Enhanced_Note__c
    WHERE Lead__c = :leadId
    AND Subject__c LIKE 'Lead Call Note - 7/6/2026%'
    LIMIT 50
];

Set<String> existingSubjects = new Set<String>();
for (Enhanced_Note__c noteRecord : existing) {
    existingSubjects.add(noteRecord.Subject__c);
}

List<Enhanced_Note__c> notesToInsert = new List<Enhanced_Note__c>();
for (ContentNote contentNote : [
    SELECT Id, Title, Content, CreatedDate
    FROM ContentNote
    WHERE Id IN :noteIds
    ORDER BY CreatedDate ASC
]) {
    if (existingSubjects.contains(contentNote.Title)) {
        continue;
    }

    String noteBody = contentNote.Content == null ? '' : contentNote.Content.toString();
    if (String.isBlank(noteBody)) {
        continue;
    }

    notesToInsert.add(new Enhanced_Note__c(
        Lead__c = leadId,
        Subject__c = contentNote.Title,
        Body__c = '<p><strong>Adam Stephens call note backfilled from Salesforce ContentNote.</strong></p><p>' +
            noteBody.escapeHtml4().replace('\n', '<br/>') +
            '</p>',
        Type__c = 'Note',
        Direction__c = 'Outbound'
    ));
}

if (!notesToInsert.isEmpty()) {
    insert notesToInsert;
}

System.debug('Inserted visible Enhanced Notes: ' + notesToInsert.size());
