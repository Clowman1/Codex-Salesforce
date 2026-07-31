/**
 * Recurring 7-day stagnant Lead email alerts (days in current status)
 *
 * Repo/Selector layer (SOQL only).
 */
public without sharing class LeadStagnantAlertRepo {
    private LeadStagnantAlertRepo() {}

    public static List<Lead> selectEligibleLeads(
        Set<String> excludedStatuses,
        Date cutoffDate
    ) {
        if (excludedStatuses == null || excludedStatuses.isEmpty()) {
            return new List<Lead>();
        }
        DateTime cutoffDateTime = DateTime.newInstance(cutoffDate, Time.newInstance(0, 0, 0, 0));
        String q = 'SELECT Id, Name, OwnerId, Status, Loan_Details__c FROM Lead' +
            ' WHERE Status NOT IN :excludedStatuses' +
            ' AND IsConverted = false' +
            ' AND CreatedDate >= :cutoffDateTime' +
            ' AND OwnerId IN (SELECT Id FROM User WHERE IsActive = true AND Include_in_Lead_Stagnant_Alerts__c = true)' +
            ' AND Id IN (SELECT Lead__c FROM Lead_Event__c' +
            '            WHERE Event_Type__c = \'Status Changed\'' +
            '            AND Status_Exit_Date_Time__c = null)';
        q += ' WITH SYSTEM_MODE';
        return Database.query(q);
    }

    public static Database.QueryLocator getEligibleLeadsLocator(
        Set<String> excludedStatuses,
        Date cutoffDate
    ) {
        if (excludedStatuses == null || excludedStatuses.isEmpty()) {
            // Return a QueryLocator that yields no rows.
            return Database.getQueryLocator([SELECT Id FROM Lead WHERE Id = null]);
        }
        DateTime cutoffDateTime = DateTime.newInstance(cutoffDate, Time.newInstance(0, 0, 0, 0));
        String q = 'SELECT Id, Name, OwnerId, Status, Loan_Details__c FROM Lead' +
            ' WHERE Status NOT IN :excludedStatuses' +
            ' AND IsConverted = false' +
            ' AND CreatedDate >= :cutoffDateTime' +
            ' AND OwnerId IN (SELECT Id FROM User WHERE IsActive = true AND Include_in_Lead_Stagnant_Alerts__c = true)' +
            ' AND Id IN (SELECT Lead__c FROM Lead_Event__c' +
            '            WHERE Event_Type__c = \'Status Changed\'' +
            '            AND Status_Exit_Date_Time__c = null)';
        q += ' WITH SYSTEM_MODE';
        return Database.getQueryLocator(q);
    }

    public static Map<Id, Lead_Event__c> selectCurrentStatusEvents(Set<Id> leadIds) {
        Map<Id, Lead_Event__c> byLeadId = new Map<Id, Lead_Event__c>();
        if (leadIds == null || leadIds.isEmpty()) {
            return byLeadId;
        }

        for (Lead_Event__c e : [
            SELECT
                Id,
                Lead__c,
                Event_Type__c,
                Status__c,
                Status_Entered_Date_Time__c,
                Status_Exit_Date_Time__c
            FROM Lead_Event__c
            WHERE Lead__c IN :leadIds
            AND Event_Type__c = 'Status Changed'
            AND Status_Exit_Date_Time__c = null
            WITH SECURITY_ENFORCED
        ]) {
            byLeadId.put(e.Lead__c, e);
        }
        return byLeadId;
    }

    public static Map<Id, User> selectActiveUsersByIds(Set<Id> userIds) {
        Map<Id, User> byId = new Map<Id, User>();
        if (userIds == null || userIds.isEmpty()) {
            return byId;
        }
        for (User u : [
            SELECT Id, Name, Email, IsActive
            FROM User
            WHERE Id IN :userIds
            AND IsActive = true
            AND Include_in_Lead_Stagnant_Alerts__c = true
            WITH SYSTEM_MODE
        ]) {
            byId.put(u.Id, u);
        }
        return byId;
    }

    public static Id selectOrgWideEmailAddressId(String address) {
        if (String.isBlank(address)) {
            return null;
        }
        try {
            return [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE Address = :address
                LIMIT 1
            ].Id;
        } catch (Exception e) {
            return null;
        }
    }
}