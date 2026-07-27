Id leadId = '00QQi00000mPf7aMAC';

List<Task> tasks = [
    SELECT Id, WhoId, ActivityDate
    FROM Task
    WHERE Id IN (
        '00TQi00001Rh5HJMAZ',
        '00TQi00001RfxqlMAB',
        '00TQi00001Rdq1yMAB',
        '00TQi00001RUybXMAT'
    )
];

for (Task taskRecord : tasks) {
    taskRecord.WhoId = leadId;
    if (taskRecord.ActivityDate == null) {
        taskRecord.ActivityDate = Date.today();
    }
}

if (!tasks.isEmpty()) {
    update tasks;
}

List<Event> events = [
    SELECT Id, WhoId
    FROM Event
    WHERE Id IN (
        '00UQi00000WWtWnMAL',
        '00UQi00000WWpxpMAD'
    )
];

for (Event eventRecord : events) {
    eventRecord.WhoId = leadId;
}

if (!events.isEmpty()) {
    update events;
}
