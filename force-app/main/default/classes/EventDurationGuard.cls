public without sharing class EventDurationGuard {
    private static final Integer DEFAULT_LEAD_EVENT_MINUTES = 15;
    private static final Integer MINUTES_PER_DAY = 1440;

    public static void normalizeLeadEvents(List<Event> records) {
        for (Event eventRecord : records) {
            if (!shouldNormalize(eventRecord)) {
                continue;
            }

            eventRecord.EndDateTime = normalizedEndTime(eventRecord);
            eventRecord.DurationInMinutes = minutesBetween(eventRecord.StartDateTime, eventRecord.EndDateTime);
        }
    }

    private static Boolean shouldNormalize(Event eventRecord) {
        if (eventRecord == null || eventRecord.StartDateTime == null || eventRecord.EndDateTime == null) {
            return false;
        }

        if (eventRecord.IsAllDayEvent == true || !isLeadId(eventRecord.WhoId)) {
            return false;
        }

        return eventRecord.StartDateTime.dateGmt() != eventRecord.EndDateTime.dateGmt()
            || minutesBetween(eventRecord.StartDateTime, eventRecord.EndDateTime) <= 0
            || Math.mod(minutesAfterMidnight(eventRecord.EndDateTime), DEFAULT_LEAD_EVENT_MINUTES) != 0;
    }

    private static DateTime normalizedEndTime(Event eventRecord) {
        if (eventRecord.StartDateTime.dateGmt() != eventRecord.EndDateTime.dateGmt()
            || eventRecord.EndDateTime <= eventRecord.StartDateTime) {
            return eventRecord.StartDateTime.addMinutes(DEFAULT_LEAD_EVENT_MINUTES);
        }

        Integer endMinutes = minutesAfterMidnight(eventRecord.EndDateTime);
        Integer roundedMinutes = roundUpToInterval(endMinutes, DEFAULT_LEAD_EVENT_MINUTES);

        if (roundedMinutes >= MINUTES_PER_DAY) {
            return eventRecord.StartDateTime.addMinutes(DEFAULT_LEAD_EVENT_MINUTES);
        }

        Date endDate = eventRecord.EndDateTime.dateGmt();
        return DateTime.newInstanceGmt(
            endDate.year(),
            endDate.month(),
            endDate.day(),
            roundedMinutes / 60,
            Math.mod(roundedMinutes, 60),
            0
        );
    }

    private static Integer roundUpToInterval(Integer value, Integer interval) {
        Integer remainder = Math.mod(value, interval);
        return remainder == 0 ? value : value + interval - remainder;
    }

    private static Integer minutesBetween(DateTime startsAt, DateTime endsAt) {
        return Integer.valueOf((endsAt.getTime() - startsAt.getTime()) / (1000 * 60));
    }

    private static Integer minutesAfterMidnight(DateTime value) {
        Time timeValue = value.timeGmt();
        return (timeValue.hour() * 60) + timeValue.minute();
    }

    private static Boolean isLeadId(Id recordId) {
        return recordId != null && String.valueOf(recordId).startsWith('00Q');
    }
}
