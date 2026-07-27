List<Lead> leadsToUpdate = [
    SELECT Id, Webinar_Date__c
    FROM Lead
    WHERE LeadSource = 'Consumer Webinar'
    AND Webinar_Date__c = null
    AND CreatedDate > 2026-05-05T00:00:00Z
];

for (Lead leadRecord : leadsToUpdate) {
    leadRecord.Webinar_Date__c = Date.newInstance(2026, 5, 27);
}

if (!leadsToUpdate.isEmpty()) {
    update leadsToUpdate;
}

System.debug('Updated Consumer Webinar leads created after 2026-05-05 with blank Webinar_Date__c: ' + leadsToUpdate.size());
