public with sharing class ConsumerWebinarDocsWebhookSvc {
    private static final String CONSUMER_WEBINAR_LEAD_SOURCE = 'Consumer Webinar';
    private static final String DOCUMENTS_REQUESTED_STATUS = 'Documents Requested';
    private static final String WEBHOOK_ENDPOINT =
        'https://hooks.zapier.com/hooks/catch/449994/4ujb1k8/';
    private static final String EVENT_TYPE = 'LeadStatusChanged';

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
                || newLead.Status != DOCUMENTS_REQUESTED_STATUS
                || oldLead.Status == DOCUMENTS_REQUESTED_STATUS
                || newLead.CW_Docs_Req_Webhook_Sent__c) {
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
            this.changes = changes == null ? new List<StatusChange>() : changes;
        }

        public void execute(QueueableContext context) {
            Map<Id, StatusChange> changesByLeadId = new Map<Id, StatusChange>();
            for (StatusChange change : changes) {
                if (change != null && change.leadId != null) {
                    changesByLeadId.put(change.leadId, change);
                }
            }
            if (changesByLeadId.isEmpty()) {
                return;
            }

            List<Lead> leads = [
                SELECT Id, FirstName, LastName, Name, Company, Email, Phone, MobilePhone,
                    LeadSource, Status, CW_Docs_Req_Webhook_Sent__c,
                    OwnerId, Owner.Name, LastModifiedDate
                FROM Lead
                WHERE Id IN :changesByLeadId.keySet()
                    AND LeadSource = :CONSUMER_WEBINAR_LEAD_SOURCE
                    AND Status = :DOCUMENTS_REQUESTED_STATUS
                    AND CW_Docs_Req_Webhook_Sent__c = false
            ];

            Http http = new Http();
            List<Lead> successfulUpdates = new List<Lead>();
            for (Lead lead : leads) {
                HttpRequest request = new HttpRequest();
                request.setEndpoint(getEndpoint());
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setTimeout(10000);
                request.setBody(JSON.serialize(buildPayload(lead, changesByLeadId.get(lead.Id))));

                try {
                    HttpResponse response = http.send(request);
                    if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                        successfulUpdates.add(new Lead(
                            Id = lead.Id,
                            CW_Docs_Req_Webhook_Sent__c = true
                        ));
                    } else {
                        System.debug(LoggingLevel.ERROR,
                            'Consumer Webinar Documents Requested webhook failed for Lead ' + lead.Id +
                            ': ' + response.getStatusCode() + ' ' + response.getBody());
                    }
                } catch (Exception caughtException) {
                    System.debug(LoggingLevel.ERROR,
                        'Consumer Webinar Documents Requested webhook exception for Lead ' + lead.Id +
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
            'consumerWebinarDocsRequestedWebhookSent' => lead.CW_Docs_Req_Webhook_Sent__c,
            'ownerId' => String.valueOf(lead.OwnerId),
            'ownerName' => lead.Owner.Name,
            'salesforceLastModifiedAt' => formatDateTime(lead.LastModifiedDate)
        };
    }

    private static String formatDateTime(Datetime value) {
        return value == null ? null : value.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
}
