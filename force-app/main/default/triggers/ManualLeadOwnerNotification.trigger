trigger ManualLeadOwnerNotification on Lead (after insert) {
    ManualLeadOwnerNotificationService.notifyOwners(Trigger.new);
}
