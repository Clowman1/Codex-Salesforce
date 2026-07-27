trigger ClientActivityEmailRouter on EmailMessage (before insert, before update) {
    ClientActivityTransactionRouter.routeEmailMessages(Trigger.new);
}
