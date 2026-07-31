public with sharing class BizDevReachPreApprovalWebhookService {
    private static final String BIZ_DEV_REACH = 'Biz Dev - Reach';
    private static final String PRE_APPROVAL_STATUS = 'Pre-Approval';
    private static final String WEBHOOK_ENDPOINT =
        'https://hooks.zapier.com/hooks/catch/449994/4unbo3i/';

    public static void enqueueForStatusChanges(
        List<Lead> newLeads,
        Map<Id, Lead> oldLeadMap
    ) {
        List<StatusChange> changes = new List<StatusChange>();

        for (Lead newLead : newLeads) {
            Lead oldLead = oldLeadMap.get(newLead.Id);
            if (oldLead == null
                || newLead.Biz_Dev__c != BIZ_DEV_REACH
                || newLead.Status != PRE_APPROVAL_STATUS
                || oldLead.Status == PRE_APPROVAL_STATUS) {
                continue;
            }

            changes.add(new StatusChange(newLead.Id, oldLead.Status));
        }

        if (!changes.isEmpty()) {
            System.enqueueJob(new WebhookJob(changes));
        }
    }

    public class StatusChange {
        public Id leadId;
        public String oldStatus;

        public StatusChange(Id leadId, String oldStatus) {
            this.leadId = leadId;
            this.oldStatus = oldStatus;
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

            for (Lead lead : [
                SELECT Id, FirstName, LastName, Name, Company, Email, Phone, MobilePhone,
                    LeadSource, Biz_Dev__c, Status, OwnerId, Owner.Name, LastModifiedDate
                FROM Lead
                WHERE Id IN :changesByLeadId.keySet()
                    AND Biz_Dev__c = :BIZ_DEV_REACH
                    AND Status = :PRE_APPROVAL_STATUS
            ]) {
                StatusChange change = changesByLeadId.get(lead.Id);
                HttpRequest request = new HttpRequest();
                request.setEndpoint(WEBHOOK_ENDPOINT);
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setBody(JSON.serialize(buildPayload(lead, change)));

                try {
                    HttpResponse response = new Http().send(request);
                    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                        System.debug(LoggingLevel.WARN,
                            'Biz Dev - Reach Pre-Approval Zapier webhook failed for Lead '
                            + lead.Id + ': ' + response.getStatusCode()
                        );
                    }
                } catch (Exception caughtException) {
                    System.debug(LoggingLevel.ERROR,
                        'Biz Dev - Reach Pre-Approval Zapier webhook callout failed for Lead '
                        + lead.Id + ': ' + caughtException.getMessage()
                    );
                }
            }
        }
    }

    private static Map<String, Object> buildPayload(Lead lead, StatusChange change) {
        return new Map<String, Object>{
            'eventType' => 'LeadStatusChanged',
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
            'bizDev' => lead.Biz_Dev__c,
            'oldStatus' => change.oldStatus,
            'newStatus' => lead.Status,
            'ownerId' => String.valueOf(lead.OwnerId),
            'ownerName' => lead.Owner.Name,
            'salesforceLastModifiedAt' => formatDateTime(lead.LastModifiedDate)
        };
    }

    private static String formatDateTime(Datetime value) {
        return value == null ? null : value.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
}