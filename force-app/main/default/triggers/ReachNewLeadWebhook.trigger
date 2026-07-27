trigger ReachNewLeadWebhook on Lead (after insert, after update) {
    ReachNewLeadWebhookSvc.enqueueQualifiedLeads(
        Trigger.new,
        Trigger.isInsert ? null : Trigger.oldMap
    );
}
