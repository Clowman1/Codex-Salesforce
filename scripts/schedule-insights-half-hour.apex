List<CronTrigger> existing = [
    SELECT Id, CronJobDetail.Name
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'Insights Job - Half Hour'
    AND State != 'DELETED'
];

for (CronTrigger job : existing) {
    System.abortJob(job.Id);
}

System.schedule(
    'Insights Job - Half Hour',
    '0 30 9-19 * * ?',
    new ScheduleInsights()
);
