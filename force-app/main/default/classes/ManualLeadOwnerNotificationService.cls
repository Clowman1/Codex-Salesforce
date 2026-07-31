public with sharing class ManualLeadOwnerNotificationService {
    private static final String ORG_WIDE_EMAIL_ADDRESS = 'reachus@reachhomeloans.com';
    private static final String SALESFORCE_BASE_URL = 'https://reachhomeloans.lightning.force.com';

    @TestVisible private static Id orgWideEmailAddressIdOverride;

    public static void notifyOwners(List<Lead> newLeads) {
        if (newLeads == null || newLeads.isEmpty()) {
            return;
        }

        Set<Id> leadIds = new Set<Id>();
        for (Lead leadRecord : newLeads) {
            if (isEligible(leadRecord)) {
                leadIds.add(leadRecord.Id);
            }
        }
        if (leadIds.isEmpty()) {
            return;
        }

        sendNotificationsForLeadIds(leadIds);
    }

    public static void sendNotificationsForLeadIds(Set<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        List<Lead> leads = [
            SELECT Id, FirstName, LastName, Name, OwnerId, Owner.Email, ReferralFormSourceEmail__c
            FROM Lead
            WHERE Id IN :leadIds
        ];
        List<Messaging.SingleEmailMessage> emails = buildEmails(leads);
        if (emails.isEmpty()) {
            return;
        }

        Messaging.sendEmail(emails, false);
    }

    @TestVisible
    private static List<Messaging.SingleEmailMessage> buildEmails(List<Lead> leads) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Id orgWideEmailId = resolveOrgWideEmailAddressId();

        for (Lead leadRecord : leads) {
            if (!isEligible(leadRecord) || leadRecord.Owner == null || String.isBlank(leadRecord.Owner.Email)) {
                continue;
            }

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ leadRecord.Owner.Email });
            email.setSubject('New Salesforce Lead - \'' + leadDisplayName(leadRecord) + '\'');
            email.setHtmlBody(
                '<p>A new Salesforce Lead has been created and assigned to you.</p>' +
                '<p><a href="' + leadUrl(leadRecord.Id) + '" target="_blank" rel="noopener noreferrer">' +
                'Open ' + String.escapeSingleQuotes(leadDisplayName(leadRecord)).escapeHtml4() + ' in Salesforce</a></p>'
            );
            email.setUseSignature(false);
            email.setSaveAsActivity(false);
            if (orgWideEmailId != null) {
                email.setOrgWideEmailAddressId(orgWideEmailId);
            }
            emails.add(email);
        }
        return emails;
    }

    private static Boolean isEligible(Lead leadRecord) {
        return leadRecord != null
            && leadRecord.OwnerId != null
            && String.valueOf(leadRecord.OwnerId).startsWith('005')
            && String.isBlank(leadRecord.ReferralFormSourceEmail__c);
    }

    private static String leadDisplayName(Lead leadRecord) {
        if (leadRecord == null) {
            return 'Lead';
        }
        if (String.isNotBlank(leadRecord.FirstName) && String.isNotBlank(leadRecord.LastName)) {
            return leadRecord.FirstName + ' ' + leadRecord.LastName;
        }
        if (String.isNotBlank(leadRecord.LastName)) {
            return leadRecord.LastName;
        }
        if (String.isNotBlank(leadRecord.Name)) {
            return leadRecord.Name;
        }
        return 'Lead';
    }

    private static String leadUrl(Id leadId) {
        return SALESFORCE_BASE_URL + '/lightning/r/Lead/' + String.valueOf(leadId) + '/view';
    }

    private static Id resolveOrgWideEmailAddressId() {
        if (Test.isRunningTest() && orgWideEmailAddressIdOverride != null) {
            return orgWideEmailAddressIdOverride;
        }

        List<OrgWideEmailAddress> addresses = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :ORG_WIDE_EMAIL_ADDRESS
            LIMIT 1
        ];
        return addresses.isEmpty() ? null : addresses[0].Id;
    }
}