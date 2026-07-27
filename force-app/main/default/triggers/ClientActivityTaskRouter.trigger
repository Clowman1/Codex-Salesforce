trigger ClientActivityTaskRouter on Task (before insert, before update) {
    ClientActivityTransactionRouter.routeTasks(Trigger.new);
}
