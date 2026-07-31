/**
 * Created by toma on 10/6/2022.
 */

public with sharing class LeadRepository {
    private static List<String> LEAD_FIELDS;
    private static LeadRepository self;
    static{
        List<String> fields = new List<String>();
        Set<String> ownerFields = new Set<String>();
        Set<String> userFields = new Set<String>{'NMLS_ID__c','Banking_Bridge_ID__c'};
        fields.addAll(Schema.getGlobalDescribe().get('Lead').getDescribe().fields.getMap().keySet());
//        Map<String, SObjectField> userFieldMap = Schema.getGlobalDescribe().get('User').getDescribe().fields.getMap();
//        for(String s: userFields){
//            ownerFields.add('Owner.'+s);
//        }
//        String ownerFieldSubQuery = String.join((Iterable<String>)userFields, ',');
//        ownerFieldSubQuery = 'TYPEOF Owner WHEN USER THEN ' + ownerFieldSubQuery + ' END';
//        fields.add(ownerFieldSubQuery);
        LEAD_FIELDS = fields;
    }
    public static LeadRepository getInstance(){
        if(self==null){

            self = new LeadRepository();
        }
        return self;
    }
    public Lead getLeadById(String recordId){
        String query = 'SELECT ' + String.join(LEAD_FIELDS, ',')
                + ' FROM Lead WHERE Id=:recordId';
        System.debug(query);
        Lead lead = (Lead)Database.query(query);
        return lead;
    }

    /**
     * Selector used by Realtor Lead Convert quick action.
     * Keep this focused to avoid dynamic SELECT * usage in conversion logic.
     */
    public Lead selectForRealtorConvert(Id leadId) {
        if (leadId == null) {
            return null;
        }

        List<Lead> leads = [
            SELECT Id, FirstName, LastName, Email, Phone, MobilePhone, Title, Company,
                   Street, City, State, PostalCode, Country, Description, Website, LeadSource,
                   OwnerId, Status, IsConverted, ConvertedAccountId, Follow_Up_Account__c,
                   Realtor_Group__c, RecordType.DeveloperName
            FROM Lead
            WHERE Id = :leadId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        return leads.isEmpty() ? null : leads[0];
    }

    /**
     * Selects Leads by IDs with SMS Opt Out field for trigger handler use.
     * Used by SchMsgLeadOptOutBlockTrigHandler to check opt-out status when creating new Scheduled Messages.
     */
    public Map<Id, Lead> selectSmsOptOutByIds(Set<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return new Map<Id, Lead>();
        }
        return new Map<Id, Lead>([
            SELECT Id, Opt_Out_from_SMS_Automation__c
            FROM Lead
            WHERE Id IN :leadIds
            WITH SECURITY_ENFORCED
        ]);
    }

    /**
     * Selects Leads by email for borrower portal opt-out processing.
     */
    public List<Lead> selectByEmailsForEmailOptOut(Set<String> emails) {
        if (emails == null || emails.isEmpty()) {
            return new List<Lead>();
        }

        return [
            SELECT Id, Email, HasOptedOutOfEmail
            FROM Lead
            WHERE Email IN :emails
            WITH SYSTEM_MODE
        ];
    }

    /**
     * Converted Leads for Twilio / comms relinking (ConvertedAccountId / ConvertedContactId).
     */
    public Map<Id, Lead> selectConvertedByIds(Set<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return new Map<Id, Lead>();
        }
        return new Map<Id, Lead>([
            SELECT Id, IsConverted, ConvertedAccountId, ConvertedContactId
            FROM Lead
            WHERE Id IN :leadIds
            AND IsConverted = true
            WITH SECURITY_ENFORCED
        ]);
    }
}