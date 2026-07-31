public with sharing class ReachNewLeadWebhookSvc {
    private static final String BIZ_DEV_REACH = 'Biz Dev - Reach';
    private static final String NEW_STATUS = 'New';
    private static final String WEBHOOK_ENDPOINT =
        'https://hooks.zapier.com/hooks/catch/449994/4uj6r8l/';
    private static final String EVENT_TYPE = 'LeadQualified';

    @TestVisible private static String endpointOverride;
    @TestVisible private static Integer enqueuedJobCount = 0;

    public static void enqueueQualifiedLeads(
        List<Lead> newLeads,
        Map<Id, Lead> oldLeadMap
    ) {
        if (newLeads == null) {
            return;
        }

        List<StatusChange> changes = new List<StatusChange>();
        for (Lead newLead : newLeads) {
            Lead oldLead = oldLeadMap == null ? null : oldLeadMap.get(newLead.Id);
            if (!isQualified(newLead) || newLead.BDR_New_Webhook_Sent__c) {
                continue;
            }

            Boolean qualifiedBefore = oldLead != null && isQualified(oldLead);
            if (qualifiedBefore) {
                continue;
            }

            changes.add(new StatusChange(
                newLead.Id,
                oldLead == null ? null : oldLead.Status,
                newLead.Status
            ));
        }

        if (!changes.isEmpty()) {
            enqueuedJobCount++;
            System.enqueueJob(new WebhookJob(changes));
        }
    }

    private static Boolean isQualified(Lead leadRecord) {
        return leadRecord != null
            && leadRecord.Biz_Dev__c == BIZ_DEV_REACH
            && leadRecord.Status == NEW_STATUS;
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
                    LeadSource, Biz_Dev__c, Status, BDR_New_Webhook_Sent__c,
                    OwnerId, Owner.Name, LastModifiedDate
                FROM Lead
                WHERE Id IN :changesByLeadId.keySet()
                    AND Biz_Dev__c = :BIZ_DEV_REACH
                    AND Status = :NEW_STATUS
                    AND BDR_New_Webhook_Sent__c = false
            ];

            Http http = new Http();
            List<Lead> successfulUpdates = new List<Lead>();
            for (Lead leadRecord : leads) {
                HttpRequest request = new HttpRequest();
                request.setEndpoint(getEndpoint());
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setTimeout(10000);
                request.setBody(JSON.serialize(buildPayload(
                    leadRecord,
                    changesByLeadId.get(leadRecord.Id)
                )));

                try {
                    HttpResponse response = http.send(request);
                    if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                        successfulUpdates.add(new Lead(
                            Id = leadRecord.Id,
                            BDR_New_Webhook_Sent__c = true
                        ));
                    } else {
                        System.debug(LoggingLevel.ERROR,
                            'Biz Dev - Reach New Lead webhook failed for Lead ' + leadRecord.Id +
                            ': ' + response.getStatusCode() + ' ' + response.getBody());
                    }
                } catch (Exception caughtException) {
                    System.debug(LoggingLevel.ERROR,
                        'Biz Dev - Reach New Lead webhook exception for Lead ' + leadRecord.Id +
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

    private static Map<String, Object> buildPayload(Lead leadRecord, StatusChange change) {
        return new Map<String, Object>{
            'eventType' => EVENT_TYPE,
            'changedAt' => formatDateTime(System.now()),
            'leadId' => String.valueOf(leadRecord.Id),
            'name' => leadRecord.Name,
            'firstName' => leadRecord.FirstName,
            'lastName' => leadRecord.LastName,
            'company' => leadRecord.Company,
            'email' => leadRecord.Email,
            'phone' => leadRecord.Phone,
            'mobilePhone' => leadRecord.MobilePhone,
            'leadSource' => leadRecord.LeadSource,
            'bizDev' => leadRecord.Biz_Dev__c,
            'oldStatus' => change == null ? null : change.oldStatus,
            'newStatus' => change == null ? leadRecord.Status : change.newStatus,
            'bdrNewWebhookSent' => leadRecord.BDR_New_Webhook_Sent__c,
            'ownerId' => String.valueOf(leadRecord.OwnerId),
            'ownerName' => leadRecord.Owner == null ? null : leadRecord.Owner.Name,
            'salesforceLastModifiedAt' => formatDateTime(leadRecord.LastModifiedDate)
        };
    }

    private static String formatDateTime(Datetime value) {
        return value == null ? null : value.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
}