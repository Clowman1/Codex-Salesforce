trigger ConsumerWebinarLeadStatusWebhook on Lead (after update) {
    ConsumerWebinarLeadStatusWebhookService.enqueueForStatusChanges(Trigger.new, Trigger.oldMap);
}