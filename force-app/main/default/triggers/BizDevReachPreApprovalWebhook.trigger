trigger BizDevReachPreApprovalWebhook on Lead (after update) {
    BizDevReachPreApprovalWebhookService.enqueueForStatusChanges(
        Trigger.new,
        Trigger.oldMap
    );
}
