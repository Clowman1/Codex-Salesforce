trigger ClientActivitySmsHistoryRouter on smagicinteract__smsMagic__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        ClientActivityTransactionRouter.routeSmsHistory(Trigger.new);
    }
    if (Trigger.isAfter) {
        ClientActivityTransactionRouter.stampProcessorSmsFromHistory(Trigger.new);
    }
}
