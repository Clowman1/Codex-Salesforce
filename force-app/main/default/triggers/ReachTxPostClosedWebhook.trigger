trigger ReachTxPostClosedWebhook on Transaction__c (after update) {
    ReachTxPostClosedWebhookSvc.enqueueForStatusChanges(
        Trigger.new,
        Trigger.oldMap
    );
}