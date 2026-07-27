List<CronTrigger> existingJobs = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'ValueLink Appraisal Status Poller'
        AND State != 'DELETED'
];

if (existingJobs.isEmpty()) {
    String jobId = System.schedule(
        'ValueLink Appraisal Status Poller',
        '0 0 * * * ?',
        new ValueLinkOrderStatusBatchable()
    );
    System.debug('Scheduled ValueLink Appraisal Status Poller: ' + jobId);
} else {
    System.debug('ValueLink Appraisal Status Poller already scheduled: ' + existingJobs[0].Id);
}
