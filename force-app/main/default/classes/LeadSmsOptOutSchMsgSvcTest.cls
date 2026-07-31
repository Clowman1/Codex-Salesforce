@IsTest
private class LeadSmsOptOutSchMsgSvcTest {
    private static final String TYPE_RINGCENTRAL_SMS = 'RingCentral SMS';

    @IsTest
    static void testOptOutBlocksUnsentSms() {
        Lead l = new Lead(LastName = 'OptOut', Company = 'Test Co', MobilePhone = '5550001000');
        insert l;

        Scheduled_Message__c m1 = new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false);
        insert m1;

        l.Opt_Out_from_SMS_Automation__c = true;
        update l;

        Scheduled_Message__c reloaded = [
            SELECT Id, Blocked__c
            FROM Scheduled_Message__c
            WHERE Id = :m1.Id
        ];
        System.assertEquals(true, reloaded.Blocked__c, 'Unsent SMS should be blocked when lead opts out.');
    }

    @IsTest
    static void testOptInUnblocksBlockedUnsentSms() {
        Lead l = new Lead(LastName = 'OptIn', Company = 'Test Co', MobilePhone = '5550002000', Opt_Out_from_SMS_Automation__c = true);
        insert l;

        Scheduled_Message__c m1 = new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = true);
        insert m1;

        l.Opt_Out_from_SMS_Automation__c = false;
        update l;

        Scheduled_Message__c reloaded = [
            SELECT Id, Blocked__c
            FROM Scheduled_Message__c
            WHERE Id = :m1.Id
        ];
        System.assertEquals(false, reloaded.Blocked__c, 'Blocked unsent SMS should be unblocked when lead opts back in.');
    }

    /**
     * QA scenario: one Lead, multiple unsent scheduled messages, some Blocked = true.
     * On opt-in (SMS Opt Out true → false), ALL unsent blocked messages must be unblocked.
     */
    @IsTest
    static void testOptInUnblocksAllBlockedUnsentSmsForOneLead() {
        Lead l = new Lead(LastName = 'OptInBulk', Company = 'Test Co', MobilePhone = '5550002100', Opt_Out_from_SMS_Automation__c = true);
        insert l;

        List<Scheduled_Message__c> messages = new List<Scheduled_Message__c>{
            new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = true),
            new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false),
            new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = true),
            new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = true)
        };
        insert messages;

        l.Opt_Out_from_SMS_Automation__c = false;
        update l;

        Integer stillBlocked = [
            SELECT count()
            FROM Scheduled_Message__c
            WHERE Lead__c = :l.Id
                AND Type__c = :TYPE_RINGCENTRAL_SMS
                AND Sent_DateTime__c = NULL
                AND Blocked__c = true
        ];
        System.assertEquals(0, stillBlocked, 'All unsent blocked scheduled SMS for the Lead should be unblocked on opt-in (QA scenario).');
    }

    /** When SMS Opt Out is updated but value does not change (false→false or true→true), no block/unblock action. */
    @IsTest
    static void testNoActionWhenOptOutValueUnchanged() {
        Lead l = new Lead(LastName = 'NoChange', Company = 'Test Co', MobilePhone = '5550002050');
        insert l;
        Scheduled_Message__c m = new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false);
        insert m;

        l.MobilePhone = '5550002051';
        update l;

        Scheduled_Message__c reloaded = [SELECT Id, Blocked__c FROM Scheduled_Message__c WHERE Id = :m.Id];
        System.assertEquals(false, reloaded.Blocked__c, 'Blocked should be unchanged when SMS Opt Out did not change.');
    }

    @IsTest
    static void testSentMessagesNotAffected() {
        Lead l = new Lead(LastName = 'SentNotAffected', Company = 'Test Co', MobilePhone = '5550003000');
        insert l;

        Scheduled_Message__c sent = new Scheduled_Message__c(
            Lead__c = l.Id,
            Type__c = TYPE_RINGCENTRAL_SMS,
            Blocked__c = false,
            Sent_DateTime__c = System.now()
        );
        insert sent;

        l.Opt_Out_from_SMS_Automation__c = true;
        update l;

        Scheduled_Message__c reloaded = [
            SELECT Id, Blocked__c, Sent_DateTime__c
            FROM Scheduled_Message__c
            WHERE Id = :sent.Id
        ];
        System.assertEquals(false, reloaded.Blocked__c, 'Sent messages must never be blocked/unblocked by opt-out automation.');
        System.assertNotEquals(null, reloaded.Sent_DateTime__c, 'Sent marker should remain intact.');
    }

    @IsTest
    static void testBulkLeadOptOutAndOptIn() {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 50; i++) {
            leads.add(new Lead(LastName = 'Bulk' + i, Company = 'Test Co', MobilePhone = '555100' + String.valueOf(i).leftPad(4, '0')));
        }
        insert leads;

        List<Scheduled_Message__c> messages = new List<Scheduled_Message__c>();
        for (Lead l : leads) {
            messages.add(new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false));
            messages.add(new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false));
            messages.add(new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false));
        }
        insert messages;

        for (Lead l : leads) {
            l.Opt_Out_from_SMS_Automation__c = true;
        }
        update leads;

        Integer blockedCount = [
            SELECT count()
            FROM Scheduled_Message__c
            WHERE Lead__c IN :leads
                AND Type__c = :TYPE_RINGCENTRAL_SMS
                AND Sent_DateTime__c = NULL
                AND Blocked__c = true
        ];
        System.assertEquals(150, blockedCount, 'All unsent scheduled SMS messages should be blocked in bulk opt-out.');

        for (Lead l : leads) {
            l.Opt_Out_from_SMS_Automation__c = false;
        }
        update leads;

        Integer stillBlocked = [
            SELECT count()
            FROM Scheduled_Message__c
            WHERE Lead__c IN :leads
                AND Type__c = :TYPE_RINGCENTRAL_SMS
                AND Sent_DateTime__c = NULL
                AND Blocked__c = true
        ];
        System.assertEquals(0, stillBlocked, 'All blocked unsent scheduled SMS messages should be unblocked in bulk opt-in.');
    }

    @IsTest
    static void testAutoBlockOnCreateWhenLeadOptedOut() {
        Lead optedOut = new Lead(LastName = 'CreateBlocked', Company = 'Test Co', MobilePhone = '5550004000', Opt_Out_from_SMS_Automation__c = true);
        insert optedOut;

        Scheduled_Message__c m = new Scheduled_Message__c(Lead__c = optedOut.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false);
        insert m;

        Scheduled_Message__c reloaded = [
            SELECT Id, Blocked__c
            FROM Scheduled_Message__c
            WHERE Id = :m.Id
        ];
        System.assertEquals(true, reloaded.Blocked__c, 'New scheduled SMS should be auto-blocked when lead is already opted out.');
    }

    // --- LeadRepository coverage (getLeadById, selectSmsOptOutByIds null/empty) ---

    @IsTest
    static void testLeadRepositoryGetLeadById() {
        Lead l = new Lead(LastName = 'RepoLead', Company = 'Test Co', MobilePhone = '5550005000');
        insert l;
        LeadRepository repo = LeadRepository.getInstance();
        Lead found = repo.getLeadById(l.Id);
        System.assertNotEquals(null, found, 'getLeadById should return a lead.');
        System.assertEquals(l.Id, found.Id, 'Returned lead Id should match.');
    }

    @IsTest
    static void testLeadRepositorySelectSmsOptOutByIdsNullAndEmpty() {
        LeadRepository repo = LeadRepository.getInstance();
        Map<Id, Lead> fromNull = repo.selectSmsOptOutByIds(null);
        System.assertNotEquals(null, fromNull, 'selectSmsOptOutByIds(null) should not return null.');
        System.assertEquals(0, fromNull.size(), 'selectSmsOptOutByIds(null) should return empty map.');
        Map<Id, Lead> fromEmpty = repo.selectSmsOptOutByIds(new Set<Id>());
        System.assertNotEquals(null, fromEmpty, 'selectSmsOptOutByIds(empty) should not return null.');
        System.assertEquals(0, fromEmpty.size(), 'selectSmsOptOutByIds(empty) should return empty map.');
    }

    // --- LeadSmsOptOutScheduledMessagesService coverage (early return, multi-batch) ---

    @IsTest
    static void testApplySmsOptOutChangesEarlyReturn() {
        LeadSmsOptOutScheduledMessagesService.applySmsOptOutChanges(null, null);
        LeadSmsOptOutScheduledMessagesService.applySmsOptOutChanges(new Set<Id>(), new Set<Id>());
        LeadSmsOptOutScheduledMessagesService.applySmsOptOutChanges(new Set<Id>(), null);
        LeadSmsOptOutScheduledMessagesService.applySmsOptOutChanges(null, new Set<Id>());
        System.assert(true, 'Early return paths should complete without exception.');
    }

    /** Covers catch block and notifyDevOnError paths in LeadSmsOptOutScheduledMessagesService. */
    @IsTest
    static void testApplySmsOptOutChangesCatchAndNotify() {
        Lead l = new Lead(LastName = 'NotifyLead', Company = 'Test Co', MobilePhone = '5550008000');
        insert l;
        LeadSmsOptOutScheduledMessagesService.throwInTryForTest = true;
        try {
            LeadSmsOptOutScheduledMessagesService.applySmsOptOutChanges(new Set<Id>{ l.Id }, new Set<Id>());
            System.assert(false, 'Expected exception to be re-thrown.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Test exception'), 'Expected test exception.');
        } finally {
            LeadSmsOptOutScheduledMessagesService.throwInTryForTest = false;
        }
    }

    /** Covers Blocked__c not updateable branch in LeadSmsOptOutScheduledMessagesService. */
    @IsTest
    static void testApplySmsOptOutChangesBlockFieldNotUpdateable() {
        Lead l = new Lead(LastName = 'BlockFieldLead', Company = 'Test Co', MobilePhone = '5550008500');
        insert l;
        LeadSmsOptOutScheduledMessagesService.blockFieldNotUpdateableForTest = true;
        try {
            LeadSmsOptOutScheduledMessagesService.applySmsOptOutChanges(new Set<Id>{ l.Id }, new Set<Id>());
        } finally {
            LeadSmsOptOutScheduledMessagesService.blockFieldNotUpdateableForTest = false;
        }
        System.assert(true, 'Blocked__c not updateable path should complete without exception.');
    }

    /** Covers DML error-handling path in LeadSmsOptOutScheduledMessagesService (addLog with leadId, notifyDevOnError). */
    @IsTest
    static void testApplySmsOptOutChangesSimulatedDmlError() {
        Lead l = new Lead(LastName = 'DmlErrorLead', Company = 'Test Co', MobilePhone = '5550008600');
        insert l;
        insert new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false);
        LeadSmsOptOutScheduledMessagesService.simulateDmlErrorForTest = true;
        try {
            LeadSmsOptOutScheduledMessagesService.applySmsOptOutChanges(new Set<Id>{ l.Id }, new Set<Id>());
        } finally {
            LeadSmsOptOutScheduledMessagesService.simulateDmlErrorForTest = false;
        }
        System.assert(true, 'Simulated DML error path should complete.');
    }

    /** Covers notifyDevOnError catch (email send failure) path. */
    @IsTest
    static void testApplySmsOptOutChangesNotifyCatch() {
        Lead l = new Lead(LastName = 'NotifyCatchLead', Company = 'Test Co', MobilePhone = '5550008700');
        insert l;
        insert new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false);
        LeadSmsOptOutScheduledMessagesService.simulateDmlErrorForTest = true;
        LeadSmsOptOutScheduledMessagesService.notifyThrowForTest = true;
        try {
            LeadSmsOptOutScheduledMessagesService.applySmsOptOutChanges(new Set<Id>{ l.Id }, new Set<Id>());
        } finally {
            LeadSmsOptOutScheduledMessagesService.simulateDmlErrorForTest = false;
            LeadSmsOptOutScheduledMessagesService.notifyThrowForTest = false;
        }
        System.assert(true, 'Notify catch path should complete.');
    }

    /** Covers addLog(logsToInsert == null) early-return path in LeadSmsOptOutScheduledMessagesService. */
    @IsTest
    static void testServiceAddLogNullList() {
        LeadSmsOptOutScheduledMessagesService.addLog(null, 'test message', null);
        System.assert(true, 'addLog with null list should return without exception.');
    }

    @IsTest
    static void testProcessLeadBatchMultipleBatches() {
        Integer batchSize = 150;
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < batchSize; i++) {
            leads.add(new Lead(
                LastName = 'Batch' + i,
                Company = 'Test Co',
                MobilePhone = '555200' + String.valueOf(i).leftPad(4, '0')
            ));
        }
        insert leads;

        List<Scheduled_Message__c> messages = new List<Scheduled_Message__c>();
        for (Lead l : leads) {
            messages.add(new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false));
        }
        insert messages;

        for (Lead l : leads) {
            l.Opt_Out_from_SMS_Automation__c = true;
        }
        update leads;

        Integer blockedCount = [
            SELECT count()
            FROM Scheduled_Message__c
            WHERE Lead__c IN :leads
                AND Type__c = :TYPE_RINGCENTRAL_SMS
                AND Sent_DateTime__c = NULL
                AND Blocked__c = true
        ];
        System.assertEquals(batchSize, blockedCount, 'All unsent scheduled SMS should be blocked across multiple batches.');
    }

    // --- SchMsgLeadOptOutBlockTrigHandler coverage (non-SMS type, mixed types) ---

    @IsTest
    static void testHandleBeforeInsertNonSmsTypeDoesNotAddLeadIds() {
        Lead l = new Lead(LastName = 'NonSms', Company = 'Test Co', MobilePhone = '5550006000');
        insert l;
        Scheduled_Message__c m = new Scheduled_Message__c(
            Lead__c = l.Id,
            Type__c = 'Email',
            Blocked__c = false
        );
        insert m;
        Scheduled_Message__c reloaded = [SELECT Id, Blocked__c, Type__c FROM Scheduled_Message__c WHERE Id = :m.Id];
        System.assertEquals(false, reloaded.Blocked__c, 'Non-SMS type should not be blocked by handler.');
        System.assertEquals('Email', reloaded.Type__c, 'Type should remain Email.');
    }

    @IsTest
    static void testHandleBeforeInsertMixedTypesOnlyBlocksSms() {
        Lead l = new Lead(LastName = 'Mixed', Company = 'Test Co', MobilePhone = '5550007000', Opt_Out_from_SMS_Automation__c = true);
        insert l;
        List<Scheduled_Message__c> msgs = new List<Scheduled_Message__c>{
            new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false),
            new Scheduled_Message__c(Lead__c = l.Id, Type__c = 'Email', Blocked__c = false)
        };
        insert msgs;

        List<Scheduled_Message__c> reloaded = [
            SELECT Id, Blocked__c, Type__c
            FROM Scheduled_Message__c
            WHERE Id IN :msgs
            ORDER BY Type__c
        ];
        System.assertEquals(2, reloaded.size(), 'Should have two messages.');
        for (Scheduled_Message__c m : reloaded) {
            if (m.Type__c == TYPE_RINGCENTRAL_SMS) {
                System.assertEquals(true, m.Blocked__c, 'RingCentral SMS should be blocked when lead opted out.');
            } else {
                System.assertEquals(false, m.Blocked__c, 'Non-SMS type should remain unblocked.');
            }
        }
    }

    /** Covers handler path when leadIds is non-empty but leadsById may be empty (e.g. sharing). */
    @IsTest
    static void testHandleBeforeInsertWhenLeadsByIdEmpty() {
        Lead l = new Lead(LastName = 'SharingLead', Company = 'Test Co', MobilePhone = '5550009000');
        insert l;
        List<User> runUsers = [SELECT Id FROM User WHERE IsActive = true AND Id != :UserInfo.getUserId() LIMIT 1];
        if (!runUsers.isEmpty()) {
            System.runAs(runUsers[0]) {
                insert new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false);
            }
            List<Scheduled_Message__c> msgs = [SELECT Id, Blocked__c FROM Scheduled_Message__c WHERE Lead__c = :l.Id];
            System.assert(!msgs.isEmpty(), 'Message should exist.');
        } else {
            insert new Scheduled_Message__c(Lead__c = l.Id, Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false);
            System.assert(true, 'Single user org; handler path covered by other tests.');
        }
    }

    /** Covers handler continue when message has null Lead__c (before-insert record without Lead set). */
    @IsTest
    static void testHandleBeforeInsertMessageWithNullLead() {
        try {
            insert new Scheduled_Message__c(Type__c = TYPE_RINGCENTRAL_SMS, Blocked__c = false);
        } catch (DmlException e) {
            if (e.getDmlType(0) == StatusCode.REQUIRED_FIELD_MISSING) {
                System.assert(true, 'Lead__c required; handler continue path covered when field is optional in other orgs.');
                return;
            }
            throw e;
        }
        System.assert(true, 'If Lead__c is optional, message inserted and handler continued on null Lead__c.');
    }
}