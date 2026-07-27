trigger ClientActivityCallInsightRouter on Call_Insight__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        ClientActivityTransactionRouter.routeCallInsights(Trigger.new);
    }
    if (Trigger.isAfter) {
        ClientActivityTransactionRouter.stampProcessorCallFromInsights(Trigger.new);
    }
}
