public with sharing class ConsumerWebinarLeadStatusWebhookService {
    private static final String CONSUMER_WEBINAR_LEAD_SOURCE = 'Consumer Webinar';
    private static final String WEBHOOK_ENDPOINT =
        'https://hooks.zapier.com/hooks/catch/449994/4uc94zc/';
    private static final String EVENT_TYPE = 'LeadStatusChanged';
    private static final Set<String> EARLY_CONTACT_STATUSES = new Set<String>{
        'New',
        'Contact Attempt 1',
        'Contact Attempt 2',
        'Contact Attempt 3',
        'Contact Attempt 4',
        'Contact Attempt 5'
    };

    @TestVisible private static String endpointOverride;
    @TestVisible private static Integer enqueuedJobCount = 0;

    public static void enqueueForStatusChanges(List<Lead> newLeads, Map<Id, Lead> oldLeadMap) {
        if (newLeads == null || oldLeadMap == null) {
            return;
        }

        List<StatusChange> changes = new List<StatusChange>();
        for (Lead newLead : newLeads) {
            Lead oldLead = oldLeadMap.get(newLead.Id);
            if (oldLead == null
                || newLead.LeadSource != CONSUMER_WEBINAR_LEAD_SOURCE
                || newLead.Status == oldLead.Status
                || newLead.Consumer_Webinar_Contacted_Webhook_Sent__c
                || !EARLY_CONTACT_STATUSES.contains(oldLead.Status)
                || EARLY_CONTACT_STATUSES.contains(newLead.Status)) {
                continue;
            }

            changes.add(new StatusChange(newLead.Id, oldLead.Status, newLead.Status));
        }

        if (!changes.isEmpty()) {
            enqueuedJobCount++;
            System.enqueueJob(new WebhookJob(changes));
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
        private List<StatusChange> changes;

        public WebhookJob(List<StatusChange> changes) {
            this.changes = changes;
        }

        public void execute(QueueableContext context) {
            Map<Id, StatusChange> changesByLeadId = new Map<Id, StatusChange>();
            for (StatusChange change : changes) {
                changesByLeadId.put(change.leadId, change);
            }
            if (changesByLeadId.isEmpty()) {
                return;
            }

            Set<Id> leadIds = changesByLeadId.keySet();

            List<Lead> leads = [
                SELECT Id, FirstName, LastName, Name, Company, Email, Phone, MobilePhone,
                    LeadSource, Status, Consumer_Webinar_Contacted_Webhook_Sent__c,
                    OwnerId, Owner.Name, LastModifiedDate
                FROM Lead
                WHERE Id IN :leadIds
                    AND LeadSource = :CONSUMER_WEBINAR_LEAD_SOURCE
                    AND Consumer_Webinar_Contacted_Webhook_Sent__c = false
            ];

            Http http = new Http();
            List<Lead> successfulUpdates = new List<Lead>();
            for (Lead lead : leads) {
                HttpRequest request = new HttpRequest();
                request.setEndpoint(getEndpoint());
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setBody(JSON.serialize(buildPayload(lead, changesByLeadId.get(lead.Id))));

                try {
                    HttpResponse response = http.send(request);
                    if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                        successfulUpdates.add(new Lead(
                            Id = lead.Id,
                            Consumer_Webinar_Contacted_Webhook_Sent__c = true
                        ));
                    } else {
                        System.debug(LoggingLevel.ERROR,
                            'Consumer Webinar Zapier webhook failed for Lead ' + lead.Id +
                            ': ' + response.getStatusCode() + ' ' + response.getBody());
                    }
                } catch (Exception caughtException) {
                    System.debug(LoggingLevel.ERROR,
                        'Consumer Webinar Zapier webhook exception for Lead ' + lead.Id +
                        ': ' + caughtException.getMessage());
                }
            }

            if (!successfulUpdates.isEmpty()) {
                Database.update(successfulUpdates, false);
            }
        }
    }

    private static String getEndpoint() {
        return String.isBlank(endpointOverride) ? WEBHOOK_ENDPOINT : endpointOverride;
    }

    private static Map<String, Object> buildPayload(Lead lead, StatusChange change) {
        return new Map<String, Object>{
            'eventType' => EVENT_TYPE,
            'changedAt' => formatDateTime(System.now()),
            'leadId' => String.valueOf(lead.Id),
            'name' => lead.Name,
            'firstName' => lead.FirstName,
            'lastName' => lead.LastName,
            'company' => lead.Company,
            'email' => lead.Email,
            'phone' => lead.Phone,
            'mobilePhone' => lead.MobilePhone,
            'leadSource' => lead.LeadSource,
            'oldStatus' => change.oldStatus,
            'newStatus' => change.newStatus,
            'consumerWebinarContactedWebhookSent' => lead.Consumer_Webinar_Contacted_Webhook_Sent__c,
            'ownerId' => String.valueOf(lead.OwnerId),
            'ownerName' => lead.Owner.Name,
            'salesforceLastModifiedAt' => formatDateTime(lead.LastModifiedDate)
        };
    }

    private static String formatDateTime(Datetime value) {
        return value == null ? null : value.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
}