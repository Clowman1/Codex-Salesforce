public without sharing class ScheduledMessageEmailScheduler implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {

    @AuraEnabled
    public static String scheduleEmailJobs() {
      // Current user
        User u = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId()];// Job name (user-specific)
        String jobName = 'Scheduled Messages Processing (Email): ' + u.Name.replace(' ', '_'); String cron = '0 0 8-19 * * ?'; System.schedule(jobName, cron, new ScheduledMessageEmailScheduler()); return 'Scheduled: ' + jobName + ' (hours 08–19)';
    }
    
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new ScheduledMessageEmailScheduler(), 1); // adjust batch size if needed
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Execution_Flow__c
            FROM Scheduled_Message__c
            WHERE Status__c = 'Overdue' AND Type__c = 'Email' AND Sender__c = :UserInfo.getUserId()
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