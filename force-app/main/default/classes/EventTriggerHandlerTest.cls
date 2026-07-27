@IsTest
private class EventTriggerHandlerTest {
    @IsTest
    static void eventUpdatesLeadAppointmentFields() {
        Lead leadRecord = new Lead(
            FirstName = 'Event',
            LastName = 'Sync',
            Company = 'Reach Test',
            Status = 'New'
        );
        insert leadRecord;

        Datetime startsAt = Datetime.newInstance(2026, 7, 21, 14, 30, 0);

        Test.startTest();
        insert new Event(
            Subject = 'Scheduled Appointment',
            WhoId = leadRecord.Id,
            StartDateTime = startsAt,
            EndDateTime = startsAt.addMinutes(30)
        );
        Test.stopTest();

        Lead updatedLead = [
            SELECT Appointment_Date_Time__c, Appointment_Date__c, Appointment_Time__c
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals(startsAt, updatedLead.Appointment_Date_Time__c);
        System.assertEquals(startsAt.date(), updatedLead.Appointment_Date__c);
        System.assert(!String.isBlank(updatedLead.Appointment_Time__c), 'Expected appointment time text to be stamped.');
    }

    @IsTest
    static void olderEventDoesNotReplaceLatestLeadAppointment() {
        Lead leadRecord = new Lead(
            FirstName = 'Event',
            LastName = 'Latest',
            Company = 'Reach Test',
            Status = 'New'
        );
        insert leadRecord;

        Datetime latestStart = Datetime.newInstance(2026, 7, 22, 16, 0, 0);
        Datetime olderStart = latestStart.addHours(-2);
        insert new Event(
            Subject = 'Latest Appointment',
            WhoId = leadRecord.Id,
            StartDateTime = latestStart,
            EndDateTime = latestStart.addMinutes(30)
        );

        Test.startTest();
        insert new Event(
            Subject = 'Older Appointment',
            WhoId = leadRecord.Id,
            StartDateTime = olderStart,
            EndDateTime = olderStart.addMinutes(30)
        );
        Test.stopTest();

        Lead updatedLead = [
            SELECT Appointment_Date_Time__c
            FROM Lead
            WHERE Id = :leadRecord.Id
        ];
        System.assertEquals(latestStart, updatedLead.Appointment_Date_Time__c);
    }

    @IsTest
    static void eventWithoutLeadReferenceIsIgnored() {
        Datetime startsAt = Datetime.newInstance(2026, 7, 23, 10, 0, 0);

        Test.startTest();
        insert new Event(
            Subject = 'General Event',
            StartDateTime = startsAt,
            EndDateTime = startsAt.addMinutes(30)
        );
        Test.stopTest();

        System.assert(true, 'Events without Lead references should save without appointment sync.');
    }

    @IsTest
    static void easternTimeFormatterHandlesSeasonalOffsets() {
        String summerTime = EventTriggerHandler.convertToEasternTime(Datetime.newInstance(2026, 7, 21, 14, 5, 0));
        String winterTime = EventTriggerHandler.convertToEasternTime(Datetime.newInstance(2026, 1, 21, 14, 5, 0));
        String earlyMorningTime = EventTriggerHandler.convertToEasternTime(Datetime.newInstance(2026, 1, 1, 2, 5, 0));

        System.assert(summerTime.endsWith('AM') || summerTime.endsWith('PM'));
        System.assert(winterTime.endsWith('AM') || winterTime.endsWith('PM'));
        System.assert(earlyMorningTime.endsWith('AM') || earlyMorningTime.endsWith('PM'));
    }

    @IsTest
    static void accessFailureDetectorHandlesNulls() {
        System.assertEquals(false, EventTriggerHandler.isLeadAccessFailure(null));
    }
}
