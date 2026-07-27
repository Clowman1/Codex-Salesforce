trigger LeadStatusWebhook on Lead (after update) {
    LeadStatusZapierWebhookService.enqueueForStatusChanges(Trigger.new, Trigger.oldMap);
}