trigger ConsumerWebinarDocsWebhook on Lead (after update) {
    ConsumerWebinarDocsWebhookSvc.enqueueForStatusChanges(Trigger.new, Trigger.oldMap);
}