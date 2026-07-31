public without sharing class RingCentralSmsScheduler implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {
    
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new RingCentralSmsScheduler(), 1); // adjust batch size if needed
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Execution_Flow__c
            FROM Scheduled_Message__c
            WHERE Status__c = 'Overdue' AND Type__c = 'RingCentral SMS'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Scheduled_Message__c> scope) {
        for (Scheduled_Message__c msg : scope) {
            if (String.isNotBlank(msg.Execution_Flow__c)) {
                try {
                    // Call the autolaunched flow dynamically
                    Flow.Interview flowInstance = Flow.Interview.createInterview(
                        msg.Execution_Flow__c, 
                        new Map<String, Object>{ 'recordId' => msg.Id }
                    );
                    flowInstance.start();
                } catch (Exception e) {
                    msg.Info_Message__c = e.getMessage();
                }
            } else {
                msg.Info_Message__c = 'No Execution Flow Defined';
            }
        }

        if (!scope.isEmpty()) {
            update scope;
        }
    }

    public void finish(Database.BatchableContext bc) {}
}