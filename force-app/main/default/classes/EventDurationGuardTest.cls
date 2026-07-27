@IsTest
private class EventDurationGuardTest {
    @IsTest
    static void normalizesMultiDayLeadEvent() {
        Lead leadRecord = new Lead(
            FirstName = 'Guard',
            LastName = 'Lead',
            Company = 'Guard Lead',
            Status = 'New'
        );
        insert leadRecord;

        DateTime startsAt = DateTime.newInstanceGmt(2026, 6, 26, 12, 0, 0);

        Event eventRecord = new Event(
            Subject = 'Guard Test',
            WhoId = leadRecord.Id,
            StartDateTime = startsAt,
            EndDateTime = startsAt.addDays(4).addHours(-2)
        );
        insert eventRecord;

        Event savedEvent = [
            SELECT StartDateTime, EndDateTime, DurationInMinutes
            FROM Event
            WHERE Id = :eventRecord.Id
        ];

        System.assertEquals(startsAt, savedEvent.StartDateTime);
        System.assertEquals(startsAt.addMinutes(15), savedEvent.EndDateTime);
        System.assertEquals(15, savedEvent.DurationInMinutes);
    }

    @IsTest
    static void keepsSameDayLeadEventDuration() {
        Lead leadRecord = new Lead(
            FirstName = 'Same',
            LastName = 'Day',
            Company = 'Same Day',
            Status = 'New'
        );
        insert leadRecord;

        DateTime startsAt = DateTime.newInstanceGmt(2026, 6, 26, 12, 0, 0);

        Event eventRecord = new Event(
            Subject = 'Same Day Test',
            WhoId = leadRecord.Id,
            StartDateTime = startsAt,
            EndDateTime = startsAt.addMinutes(45)
        );
        insert eventRecord;

        Event savedEvent = [
            SELECT EndDateTime, DurationInMinutes
            FROM Event
            WHERE Id = :eventRecord.Id
        ];

        System.assertEquals(startsAt.addMinutes(45), savedEvent.EndDateTime);
        System.assertEquals(45, savedEvent.DurationInMinutes);
    }

    @IsTest
    static void roundsEndTimeToNextFifteenMinuteIncrement() {
        Lead leadRecord = new Lead(
            FirstName = 'Odd',
            LastName = 'Minute',
            Company = 'Odd Minute',
            Status = 'New'
        );
        insert leadRecord;

        DateTime startsAt = DateTime.newInstanceGmt(2026, 6, 26, 12, 0, 0);

        Event eventRecord = new Event(
            Subject = 'Odd Minute Test',
            WhoId = leadRecord.Id,
            StartDateTime = startsAt,
            EndDateTime = DateTime.newInstanceGmt(2026, 6, 26, 12, 7, 0)
        );
        insert eventRecord;

        Event savedEvent = [
            SELECT EndDateTime, DurationInMinutes
            FROM Event
            WHERE Id = :eventRecord.Id
        ];

        System.assertEquals(DateTime.newInstanceGmt(2026, 6, 26, 12, 15, 0), savedEvent.EndDateTime);
        System.assertEquals(15, savedEvent.DurationInMinutes);
    }
}
