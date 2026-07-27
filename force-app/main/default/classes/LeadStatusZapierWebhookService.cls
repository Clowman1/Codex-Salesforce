public with sharing class LeadStatusZapierWebhookService {
    private static final String WEBSITE_LEAD_SOURCE = 'Website';
    private static final Set<String> LINKTREE_LEAD_SOURCES = new Set<String>{
        'Instagram-Linktree',
        'Facebook-Linktree',
        'Youtube-Linktree',
        'Tiktok-Linktree'
    };
    private static final String EVENT_TYPE = 'LeadStatusChanged';
    private static final Set<String> EARLY_CONTACT_STATUSES = new Set<String>{
        'New',
        'Contact Attempt 1',
        'Contact Attempt 2',
        'Contact Attempt 3',
        'Contact Attempt 4',
        'Contact Attempt 5'
    };

    @TestVisible
    private static String endpointOverride;

    @TestVisible
    private static Integer enqueuedJobCount = 0;

    public static void enqueueForStatusChanges(List<Lead> newLeads, Map<Id, Lead> oldLeadMap) {
        if (newLeads == null || oldLeadMap == null) {
            return;
        }

        List<StatusChange> statusChanges = new List<StatusChange>();
        for (Lead leadRecord : newLeads) {
            Lead oldLead = oldLeadMap.get(leadRecord.Id);
            if (oldLead == null) {
                continue;
            }
            if (!isEligibleLeadSource(leadRecord.LeadSource)) {
                continue;
            }
            if (leadRecord.Status == oldLead.Status) {
                continue;
            }
            if (hasAlreadySentForLeadSource(leadRecord)) {
                continue;
            }
            if (!EARLY_CONTACT_STATUSES.contains(oldLead.Status) || EARLY_CONTACT_STATUSES.contains(leadRecord.Status)) {
                continue;
            }
            statusChanges.add(new StatusChange(leadRecord.Id, oldLead.Status, leadRecord.Status));
        }

        if (!statusChanges.isEmpty()) {
            enqueuedJobCount++;
            System.enqueueJob(new WebhookJob(statusChanges));
        }
    }

    public class StatusChange {
        public Id leadId;
        public String oldStatus;
        public String newStatus;

        public StatusChange(Id leadId, String oldStatus, String newStatus) {
            this.leadId = leadId;
            this.oldStatus = oldStatus;
            this.newStatus = newStatus;
        }
    }

    public class WebhookJob implements Queueable, Database.AllowsCallouts {
        private List<StatusChange> statusChanges;

        public WebhookJob(List<StatusChange> statusChanges) {
            this.statusChanges = statusChanges == null ? new List<StatusChange>() : statusChanges;
        }

        public void execute(QueueableContext context) {
            Set<Id> leadIds = new Set<Id>();
            for (StatusChange statusChange : statusChanges) {
                if (statusChange != null && statusChange.leadId != null) {
                    leadIds.add(statusChange.leadId);
                }
            }
            if (leadIds.isEmpty()) {
                return;
            }

            Map<Id, Lead> leadsById = new Map<Id, Lead>([
                SELECT Id, FirstName, LastName, Name, Company, Email, Phone, MobilePhone,
                    LeadSource, Status, Website_Status_Webhook_Sent__c, Linktree_Status_Webhook_Sent__c,
                    OwnerId, Owner.Name, LastModifiedDate
                FROM Lead
                WHERE Id IN :leadIds
            ]);

            Http http = new Http();
            List<Lead> successfulLeads = new List<Lead>();
            for (StatusChange statusChange : statusChanges) {
                Lead leadRecord = leadsById.get(statusChange.leadId);
                if (leadRecord == null) {
                    continue;
                }

                HttpRequest request = new HttpRequest();
                String endpoint = endpointForLeadSource(leadRecord.LeadSource);
                if (String.isBlank(endpoint)) {
                    System.debug(LoggingLevel.WARN, 'Zapier Lead Status webhook skipped because no endpoint is configured for Lead Source ' + leadRecord.LeadSource + '.');
                    continue;
                }

                request.setEndpoint(endpoint);
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setTimeout(10000);
                request.setBody(JSON.serialize(buildPayload(leadRecord, statusChange)));

                try {
                    HttpResponse response = http.send(request);
                    if (response.getStatusCode() >= 300) {
                        System.debug(LoggingLevel.WARN, 'Zapier Lead Status webhook returned status ' + response.getStatusCode() + ': ' + response.getBody());
                    } else {
                        successfulLeads.add(sentFlagUpdateForLeadSource(leadRecord));
                    }
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR, 'Zapier Lead Status webhook failed: ' + ex.getMessage());
                }
            }

            if (!successfulLeads.isEmpty()) {
                Database.update(successfulLeads, false);
            }
        }
    }

    private static Boolean isEligibleLeadSource(String leadSource) {
        return leadSource == WEBSITE_LEAD_SOURCE || LINKTREE_LEAD_SOURCES.contains(leadSource);
    }

    private static Boolean hasAlreadySentForLeadSource(Lead leadRecord) {
        if (leadRecord == null) {
            return false;
        }
        if (LINKTREE_LEAD_SOURCES.contains(leadRecord.LeadSource)) {
            return leadRecord.Linktree_Status_Webhook_Sent__c;
        }
        return leadRecord.Website_Status_Webhook_Sent__c;
    }

    private static Lead sentFlagUpdateForLeadSource(Lead leadRecord) {
        Lead updateRecord = new Lead(Id = leadRecord.Id);
        if (LINKTREE_LEAD_SOURCES.contains(leadRecord.LeadSource)) {
            updateRecord.Linktree_Status_Webhook_Sent__c = true;
        } else {
            updateRecord.Website_Status_Webhook_Sent__c = true;
        }
        return updateRecord;
    }

    private static String endpointForLeadSource(String leadSource) {
        if (!String.isBlank(endpointOverride)) {
            return endpointOverride;
        }
        if (LINKTREE_LEAD_SOURCES.contains(leadSource)) {
            return System.Label.Zapier_Linktree_Lead_Status_Webhook_URL;
        }
        return System.Label.Zapier_Lead_Status_Webhook_URL;
    }

    private static Map<String, Object> buildPayload(Lead leadRecord, StatusChange statusChange) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('eventType', EVENT_TYPE);
        payload.put('changedAt', System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
        payload.put('leadId', leadRecord.Id);
        payload.put('leadName', leadRecord.Name);
        payload.put('firstName', leadRecord.FirstName);
        payload.put('lastName', leadRecord.LastName);
        payload.put('company', leadRecord.Company);
        payload.put('email', leadRecord.Email);
        payload.put('phone', leadRecord.Phone);
        payload.put('mobilePhone', leadRecord.MobilePhone);
        payload.put('leadSource', leadRecord.LeadSource);
        payload.put('oldStatus', statusChange.oldStatus);
        payload.put('newStatus', statusChange.newStatus);
        payload.put('websiteStatusWebhookSent', leadRecord.Website_Status_Webhook_Sent__c);
        payload.put('linktreeStatusWebhookSent', leadRecord.Linktree_Status_Webhook_Sent__c);
        payload.put('ownerId', leadRecord.OwnerId);
        payload.put('ownerName', leadRecord.Owner == null ? null : leadRecord.Owner.Name);
        payload.put('salesforceLastModifiedDate', leadRecord.LastModifiedDate);
        return payload;
    }
}