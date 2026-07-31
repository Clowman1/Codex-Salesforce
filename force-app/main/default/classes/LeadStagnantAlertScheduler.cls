public with sharing class LeadStagnantAlertScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        LeadStagnantAlertSettings__c settings = LeadStagnantAlertSettings__c.getOrgDefaults();
        String mode = (settings != null && String.isNotBlank(settings.Execution_Mode__c))
            ? settings.Execution_Mode__c
            : 'Batch';

        if (mode == 'Regular') {
            LeadStagnantAlertService.run(Date.today());
        } else {
            Database.executeBatch(new LeadStagnantAlertBatch(Date.today()), 200);
        }
    }

    public static void schedule(String cronExpression) {
        String jobName = 'Stagnant Lead Alerts';

        if (Test.isRunningTest()) {
            // getRandomInteger is safer than a timestamp for concurrent tests
            jobName += ' - ' + Crypto.getRandomInteger();
        }

        System.schedule(jobName, cronExpression, new LeadStagnantAlertScheduler());
    }

}