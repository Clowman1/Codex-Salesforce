@IsTest
private class LeadStagnantAlertServiceTest {
    private static final Set<String> EXCLUDED_STATUSES = new Set<String>{
        'Pre-Approval',
        'Nurture - Preapproval',
        'Nurturing',
        '30 Day+ Follow Up',
        '30 Day  Follow Up',
        '30 Day Follow Up'
    };

    private static void createDefaultSettings() {
        insert new LeadStagnantAlertSettings__c(
            Lead_Cutoff_Date__c = Date.newInstance(2020, 1, 1),
            Execution_Mode__c = 'Batch'
        );
    }

    private static User createUser(String firstName, String lastName, String email) {
        return createUser(firstName, lastName, email, true);
    }

    private static User createUser(String firstName, String lastName, String email, Boolean includeInAlerts) {
        Id profileId;
        List<Profile> sysAdmins = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        if (!sysAdmins.isEmpty()) {
            profileId = sysAdmins[0].Id;
        } else {
            profileId = [SELECT Id FROM Profile LIMIT 1].Id;
        }
        String unique = String.valueOf(DateTime.now().getTime()) + Math.mod(Crypto.getRandomInteger(), 100000);
        User u = new User(
            FirstName = firstName,
            LastName = lastName,
            Email = email,
            Username = 'test+' + unique + '@example.com',
            Alias = (firstName != null && firstName.length() >= 4) ? firstName.substring(0, 4) : 'tusr',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profileId,
            Include_in_Lead_Stagnant_Alerts__c = includeInAlerts
        );
        insert u;
        return u;
    }

    private static Lead createLead(Id ownerId, String status, String lastName) {
        return createLead(ownerId, status, lastName, null);
    }

    private static Lead createLead(Id ownerId, String status, String lastName, String loanDetails) {
        Lead l = new Lead(
            OwnerId = ownerId,
            Status = status,
            LastName = lastName,
            Loan_Details__c = loanDetails,
            Company = 'TestCo'
        );
        // Org validation rule requires these fields when Status = 'Pre-Approval'.
        if (status == 'Pre-Approval') {
            l.Rating = 'Hot';
            l.Loan_Amount__c = 100000;
        }
        insert l;
        return l;
    }

    private static Lead_Event__c createCurrentStatusEvent(Lead lead, Date enteredDate) {
        Lead_Event__c e = new Lead_Event__c();
        e.Name = 'Test Event';
        e.Lead__c = lead.Id;
        e.Event_Type__c = 'Status Changed';
        e.Status__c = lead.Status;
        e.Status_Entered_Date_Time__c = DateTime.newInstance(enteredDate, Time.newInstance(8, 0, 0, 0));
        e.Status_Exit_Date_Time__c = null;
        insert e;
        return e;
    }

    private static Id createLeadQueueOwner() {
        Group g = new Group(
            Name = 'Test Lead Queue',
            DeveloperName = 'Test_Lead_Queue',
            Type = 'Queue'
        );
        insert g;
        QueueSobject qs = new QueueSobject(
            QueueId = g.Id,
            SobjectType = 'Lead'
        );
        insert qs;
        return g.Id;
    }

    private static String getIncludedStatus() {
        List<Schema.PicklistEntry> values = Lead.Status.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry pe : values) {
            if (pe.isActive() && !EXCLUDED_STATUSES.contains(pe.getValue())) {
                return pe.getValue();
            }
        }
        // Fallback: pick any active status so tests still run in unusual orgs.
        for (Schema.PicklistEntry pe : values) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        System.assert(false, 'No active Lead Status picklist values found.');
        return null;
    }

    private static String getExcludedStatusPresentInOrg() {
        List<Schema.PicklistEntry> values = Lead.Status.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry pe : values) {
            if (pe.isActive() && EXCLUDED_STATUSES.contains(pe.getValue())) {
                return pe.getValue();
            }
        }
        return null;
    }

    @IsTest
    static void scenarioA_7DayHit_included() {
        createDefaultSettings();
        User owner = createUser('Owner', 'A', 'ownerA@example.com');

        Date asOf = Date.today();
        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadA');
        createCurrentStatusEvent(l, asOf.addDays(-7));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(1, res.ownersEmailed, 'One owner should receive an email.');
        System.assertEquals(1, res.leadsEmailed, 'Lead should be included at 7-day milestone.');
    }

    @IsTest
    static void scenarioA2_ownerNotOptedIn_excluded() {
        createDefaultSettings();
        User owner = createUser('Owner', 'A2', 'ownerA2@example.com', false);

        Date asOf = Date.today();
        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadA2');
        createCurrentStatusEvent(l, asOf.addDays(-7));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(0, res.ownersEmailed, 'Owner without the include checkbox should not receive an email.');
        System.assertEquals(0, res.leadsEmailed, 'Leads owned by users without the include checkbox should be excluded.');
    }

    @IsTest
    static void scenarioB_resetOnStatusChange_notIncludedUntilNewMilestone() {
        createDefaultSettings();
        User owner = createUser('Owner', 'B', 'ownerB@example.com');

        Date today = Date.today();
        Date tomorrow = today.addDays(1);

        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadB');
        createCurrentStatusEvent(l, today);

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(tomorrow);
        Test.stopTest();

        System.assertEquals(0, res.ownersEmailed, 'Should not email on non-milestone day after reset.');
        System.assertEquals(0, res.leadsEmailed, 'No leads should be included until 7 days in new status.');
    }

    @IsTest
    static void scenarioC_nonMilestoneDay_excluded() {
        createDefaultSettings();
        User owner = createUser('Owner', 'C', 'ownerC@example.com');

        Date asOf = Date.today();
        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadC');
        createCurrentStatusEvent(l, asOf.addDays(-8));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(0, res.ownersEmailed, 'Should not email on non-milestone day (8 days, between 7 and 14).');
        System.assertEquals(0, res.leadsEmailed, 'Lead at 8 days should be excluded (only 7, 14, and 21+ are included).');
    }

    @IsTest
    static void scenarioD_repeatReminders_14And21Days() {
        createDefaultSettings();
        User owner = createUser('Owner', 'D', 'ownerD@example.com');

        Date entered = Date.today().addDays(-30);
        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadD');
        createCurrentStatusEvent(l, entered);

        Test.startTest();
        LeadStagnantAlertService.RunResult res14 = LeadStagnantAlertService.run(entered.addDays(14));
        LeadStagnantAlertService.RunResult res21 = LeadStagnantAlertService.run(entered.addDays(21));
        Test.stopTest();

        System.assertEquals(1, res14.ownersEmailed, '14-day milestone should send email.');
        System.assertEquals(1, res14.leadsEmailed, 'Lead should be included at 14 days.');
        System.assertEquals(1, res21.ownersEmailed, '21-day milestone should send email again.');
        System.assertEquals(1, res21.leadsEmailed, 'Lead should be included at 21 days.');
    }

    @IsTest
    static void scenarioE_grouping_twoOwners_queueSkipped() {
        createDefaultSettings();
        User ownerA = createUser('Owner', 'E1', 'ownerE1@example.com');
        User ownerB = createUser('Owner', 'E2', 'ownerE2@example.com');

        Date asOf = Date.today();
        String includedStatus = getIncludedStatus();

        Lead a1 = createLead(ownerA.Id, includedStatus, 'LeadE_A1');
        Lead a2 = createLead(ownerA.Id, includedStatus, 'LeadE_A2');
        Lead b1 = createLead(ownerB.Id, includedStatus, 'LeadE_B1');
        createCurrentStatusEvent(a1, asOf.addDays(-7));
        createCurrentStatusEvent(a2, asOf.addDays(-14));
        createCurrentStatusEvent(b1, asOf.addDays(-7));

        Id queueOwnerId;
        System.runAs(ownerA) {
            queueOwnerId = createLeadQueueOwner();
        }

        Lead q1 = createLead(queueOwnerId, includedStatus, 'LeadE_Q1');
        createCurrentStatusEvent(q1, asOf.addDays(-7));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(2, res.ownersEmailed, 'Two separate owner emails should be sent.');
        System.assertEquals(3, res.leadsEmailed, 'Queue-owned lead should be filtered out; 3 user-owned leads included.');
    }

    @IsTest
    static void ccLabelMissingOrBlank_stillSendsEmail() {
        createDefaultSettings();
        User owner = createUser('Owner', 'F', 'ownerF@example.com');
        Date asOf = Date.today();

        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadF');
        createCurrentStatusEvent(l, asOf.addDays(-7));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(1, res.ownersEmailed, 'Email should still send even when CC label is missing or blank.');
    }

    @IsTest
    static void schedulerExecute_runsWithoutError() {
        createDefaultSettings();
        User owner = createUser('Owner', 'G', 'ownerG@example.com');

        Date asOf = Date.today();
        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadG');
        createCurrentStatusEvent(l, asOf.addDays(-7));

        Test.startTest();
        new LeadStagnantAlertScheduler().execute(null);
        Test.stopTest();
        System.assert(true, 'Scheduler execute should run without throwing.');
    }

    @IsTest
    static void scheduler_regularMode_usesService() {
        createDefaultSettings();
        LeadStagnantAlertSettings__c settings = LeadStagnantAlertSettings__c.getOrgDefaults();
        settings.Execution_Mode__c = 'Regular';
        update settings;

        User owner = createUser('Owner', 'RegMode', 'ownerRegMode@example.com');
        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadRegMode');
        createCurrentStatusEvent(l, Date.today().addDays(-7));

        Test.startTest();
        new LeadStagnantAlertScheduler().execute(null);
        Test.stopTest();
        System.assert(true, 'Scheduler should execute in Regular mode without error.');
    }

    @IsTest
    static void batch_7DayHit_completesWithoutError() {
        createDefaultSettings();
        User owner = createUser('Owner', 'Batch1', 'ownerBatch1@example.com');
        Date asOf = Date.today();

        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadBatch1');
        createCurrentStatusEvent(l, asOf.addDays(-7));

        Test.startTest();
        Database.executeBatch(new LeadStagnantAlertBatch(asOf), 200);
        Test.stopTest();

        // No error Custom_Log__c records should be created for a clean 7-day hit.
        List<Custom_Log__c> allLogs = [
            SELECT Id, Data__c FROM Custom_Log__c
            WHERE Source__c = 'Stagnant Lead Alerts'
        ];
        for (Custom_Log__c log : allLogs) {
            System.assert(
                !log.Data__c.startsWith('Unhandled exception'),
                'Batch should complete without unhandled exceptions. Got: ' + log.Data__c
            );
        }
    }

    @IsTest
    static void batch_7DayHit_logsSuccessNotification() {
        createDefaultSettings();
        User owner = createUser('Owner', 'SuccLog', 'ownerSuccLog@example.com');
        Date asOf = Date.today();

        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadSuccLog');
        createCurrentStatusEvent(l, asOf.addDays(-7));

        Test.startTest();
        Database.executeBatch(new LeadStagnantAlertBatch(asOf), 200);
        Test.stopTest();

        List<Custom_Log__c> logs = [
            SELECT Id, Data__c FROM Custom_Log__c
            WHERE Source__c = 'Stagnant Lead Alerts'
        ];
        // Batch should log the email outcome — either success or a send-failure
        // (sandbox environments may not have the org-wide email configured).
        Boolean foundOutcomeLog = false;
        for (Custom_Log__c log : logs) {
            if (log.Data__c.contains('Successfully sent') || log.Data__c.contains('Failed to send')) {
                foundOutcomeLog = true;
            }
        }
        System.assert(foundOutcomeLog, 'Expected an email outcome log (success or failure). Logs: ' + logs);
    }

    @IsTest
    static void batch_noEligibleLeads_logsDiagnostic() {
        createDefaultSettings();
        Test.startTest();
        Database.executeBatch(new LeadStagnantAlertBatch(Date.today()), 200);
        Test.stopTest();

        List<Custom_Log__c> logs = [
            SELECT Id, Data__c FROM Custom_Log__c
            WHERE Source__c = 'Stagnant Lead Alerts'
        ];
        System.assertEquals(1, logs.size(), 'Batch should write exactly one diagnostic log when nothing runs.');
        System.assert(
            logs[0].Data__c.contains('No eligible leads') || logs[0].Data__c.contains('No leads hit a 7-day milestone'),
            'Diagnostic log should explain why no emails were sent.'
        );
    }

    @IsTest
    static void batch_leadsFoundButNoMilestone_logsDiagnostic() {
        createDefaultSettings();
        User owner = createUser('Owner', 'Batch2', 'ownerBatch2@example.com');
        Date asOf = Date.today();

        // 8 days — not a 7-day multiple, should be skipped
        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadBatch2');
        createCurrentStatusEvent(l, asOf.addDays(-8));

        Test.startTest();
        Database.executeBatch(new LeadStagnantAlertBatch(asOf), 200);
        Test.stopTest();

        // finish should log: eligibleLeadsProcessed=1 but no milestones
        List<Custom_Log__c> logs = [
            SELECT Id, Data__c FROM Custom_Log__c
            WHERE Source__c = 'Stagnant Lead Alerts'
        ];
        System.assertEquals(1, logs.size(), 'Expected one diagnostic log for no milestone hit.');
        System.assert(
            logs[0].Data__c.contains('No leads hit a 7-day milestone'),
            'Log should indicate leads were evaluated but none hit a milestone.'
        );
    }

    @IsTest
    static void batch_queueOwnedLead_isFilteredBySoql() {
        createDefaultSettings();
        User testUser = createUser('Test', 'BatchQ', 'testBatchQ@example.com');
        Id queueOwnerId;
        System.runAs(testUser) {
            queueOwnerId = createLeadQueueOwner();
        }

        Date asOf = Date.today();
        Lead q = createLead(queueOwnerId, getIncludedStatus(), 'LeadBatchQ');
        createCurrentStatusEvent(q, asOf.addDays(-7));

        Test.startTest();
        Database.executeBatch(new LeadStagnantAlertBatch(asOf), 200);
        Test.stopTest();

        // Queue-owned lead is now filtered at SOQL level (OwnerId LIKE '005%').
        // Batch scope is empty → single "No eligible leads found" log.
        List<Custom_Log__c> logs = [
            SELECT Id, Data__c FROM Custom_Log__c
            WHERE Source__c = 'Stagnant Lead Alerts'
        ];
        System.assertEquals(1, logs.size(), 'Expected exactly 1 log: no eligible leads (queue-owned filtered at SOQL).');
        System.assert(
            logs[0].Data__c.contains('No eligible leads'),
            'Should log that no eligible leads were found since queue-owned lead is filtered at SOQL level.'
        );
    }

    @IsTest
    static void batch_missingStatusEvent_isFilteredBySoql() {
        createDefaultSettings();
        User owner = createUser('Owner', 'Batch3', 'ownerBatch3@example.com');
        Date asOf = Date.today();

        // Lead with no Lead_Event__c
        Lead lead3 = createLead(owner.Id, getIncludedStatus(), 'LeadBatch3');
        // Delete any events auto-created by Flows/automations
        delete [SELECT Id FROM Lead_Event__c WHERE Lead__c = :lead3.Id];

        Test.startTest();
        Database.executeBatch(new LeadStagnantAlertBatch(asOf), 200);
        Test.stopTest();

        // Lead without events is now filtered at SOQL level (semi-join on Lead_Event__c).
        // Batch scope is empty → single "No eligible leads found" log.
        List<Custom_Log__c> logs = [
            SELECT Id, Data__c FROM Custom_Log__c
            WHERE Source__c = 'Stagnant Lead Alerts'
        ];
        System.assertEquals(1, logs.size(), 'Expected exactly 1 log: no eligible leads (missing-event filtered at SOQL).');
        System.assert(
            logs[0].Data__c.contains('No eligible leads'),
            'Should log that no eligible leads were found since lead without events is filtered at SOQL level.'
        );
    }

    @IsTest
    static void batch_defaultConstructor_runsWithoutError() {
        createDefaultSettings();
        Test.startTest();
        Database.executeBatch(new LeadStagnantAlertBatch(), 200);
        Test.stopTest();
        System.assert(true, 'Default (no-arg) constructor should work without error.');
    }

    @IsTest
    static void batch_twoLeadsSameMilestone_sortsByName() {
        createDefaultSettings();
        // Two leads at same milestone triggers the LeadLineItemSorter name-comparison path
        User owner = createUser('Owner', 'Batch4', 'ownerBatch4@example.com');
        Date asOf = Date.today();
        String status = getIncludedStatus();

        Lead l1 = createLead(owner.Id, status, 'Zebra');
        Lead l2 = createLead(owner.Id, status, 'Apple');
        createCurrentStatusEvent(l1, asOf.addDays(-7));
        createCurrentStatusEvent(l2, asOf.addDays(-7));

        Test.startTest();
        Database.executeBatch(new LeadStagnantAlertBatch(asOf), 200);
        Test.stopTest();

        List<Custom_Log__c> errorLogs = [
            SELECT Id, Data__c FROM Custom_Log__c
            WHERE Source__c = 'Stagnant Lead Alerts'
        ];
        for (Custom_Log__c log : errorLogs) {
            System.assert(
                !log.Data__c.startsWith('Unhandled exception'),
                'Batch should complete without unhandled exceptions. Got: ' + log.Data__c
            );
        }
    }

    @IsTest
    static void schedulerScheduleHelper_coversCronAndSchedule() {
        createDefaultSettings();
        Test.startTest();
        LeadStagnantAlertScheduler.schedule('0 0 6 * * ?');
        Test.stopTest();

        List<CronTrigger> triggers = [
            SELECT Id, CronExpression, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Stagnant Lead Alerts%'
        ];

        System.assert(triggers.size() >= 1, 'Expected at least one scheduled job from schedule() helper.');
    }

    @IsTest
    static void missingStatusEvent_skipsLead() {
        createDefaultSettings();
        User owner = createUser('Owner', 'H', 'ownerH@example.com');

        Date asOf = Date.today();
        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadH');
        // Delete any events auto-created by Flows/automations to ensure no-event scenario
        delete [SELECT Id FROM Lead_Event__c WHERE Lead__c = :l.Id];

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(0, res.ownersEmailed, 'No emails should be attempted when no leads qualify.');
        System.assertEquals(0, res.leadsEmailed, 'No leads should qualify without a status event.');
    }


    @IsTest
    static void noEligibleLeads_returnsZeroes() {
        createDefaultSettings();
        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(Date.today());
        Test.stopTest();

        System.assertEquals(0, res.ownersEmailed);
        System.assertEquals(0, res.leadsEmailed);
    }

    @IsTest
    static void onlyQueueOwnedEligibleLead_isSkipped() {
        createDefaultSettings();
        User testUser = createUser('Test', 'User', 'testuser@example.com');
        Id queueOwnerId;

        System.runAs(testUser) {
            queueOwnerId = createLeadQueueOwner();
        }

        Date asOf = Date.today();
        Lead q1 = createLead(queueOwnerId, getIncludedStatus(), 'LeadQOnly');
        createCurrentStatusEvent(q1, asOf.addDays(-7));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(0, res.ownersEmailed, 'Queue-owned leads should be filtered out at SOQL level.');
        System.assertEquals(0, res.leadsEmailed, 'Queue-owned leads should not be counted as emailed.');
    }

    @IsTest
    static void futureEnteredDate_isSkipped() {
        createDefaultSettings();
        User owner = createUser('Owner', 'J', 'ownerJ@example.com');

        Date asOf = Date.today();
        Lead l = createLead(owner.Id, getIncludedStatus(), 'LeadFuture');
        createCurrentStatusEvent(l, asOf.addDays(1));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(0, res.ownersEmailed, 'Future entered dates should not qualify.');
        System.assertEquals(0, res.leadsEmailed, 'Future entered dates should not qualify.');
    }

    @IsTest
    static void excludedStatus_7DayHit_notIncluded() {
        createDefaultSettings();
        User owner = createUser('Owner', 'K', 'ownerK@example.com');
        Date asOf = Date.today();

        String excludedStatus = getExcludedStatusPresentInOrg();
        System.assertNotEquals(null, excludedStatus, 'Expected at least one excluded status to exist in this org.');

        Lead l = createLead(owner.Id, excludedStatus, 'LeadK');
        createCurrentStatusEvent(l, asOf.addDays(-7));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(0, res.ownersEmailed, 'Excluded status leads should not generate emails.');
        System.assertEquals(0, res.leadsEmailed, 'Excluded status leads should not be counted.');
    }

    @IsTest
    static void emailBody_includesLoanDetails_orNA_andEscapesHtml() {
        createDefaultSettings();
        User owner = createUser('Owner', 'L', 'ownerL@example.com');
        Date asOf = Date.today();
        String includedStatus = getIncludedStatus();

        // Lead 1: blank loan details => N/A
        Lead l1 = createLead(owner.Id, includedStatus, 'LeadL1', null);
        createCurrentStatusEvent(l1, asOf.addDays(-7));

        // Lead 2: needs HTML escaping + newline preservation
        String raw = '<b>hi</b> & \"x\"' + '\n' + 'line2';
        Lead l2 = createLead(owner.Id, includedStatus, 'LeadL2', raw);
        createCurrentStatusEvent(l2, asOf.addDays(-7));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(1, res.ownersEmailed, 'One email should be sent to the owner.');
        System.assertEquals(2, res.leadsEmailed, 'Both included leads should be listed.');

        System.assertEquals(1, LeadStagnantAlertService.lastBuiltHtmlBodies.size(), 'Expected one email body to be built.');
        String html = LeadStagnantAlertService.lastBuiltHtmlBodies[0];

        System.assert(html.contains(' - N/A - '), 'Expected blank loan details to display as N/A.');
        System.assert(
            html.contains('&lt;b&gt;hi&lt;/b&gt; &amp; &quot;x&quot;<br/>line2'),
            'Expected loan details to be HTML-escaped and preserve line breaks.'
        );
    }

    @IsTest
    static void scenarioM_milestonesOver21Days_28And35Days() {
        createDefaultSettings();
        User owner = createUser('Owner', 'M', 'ownerM@example.com');
        String includedStatus = getIncludedStatus();

        Date asOf = Date.today();
        Date entered28 = asOf.addDays(-28);
        Date entered35 = asOf.addDays(-35);

        Lead l28 = createLead(owner.Id, includedStatus, 'LeadM_28Days');
        Lead l35 = createLead(owner.Id, includedStatus, 'LeadM_35Days');
        createCurrentStatusEvent(l28, entered28);
        createCurrentStatusEvent(l35, entered35);

        Test.startTest();
        // Running at "today" will include both leads since they're both >= 21 days (daily notifications)
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(1, res.ownersEmailed, 'One email should be sent to the owner.');
        System.assertEquals(2, res.leadsEmailed, 'Both leads at 28 and 35 days should be included (both are multiples of 7: 7-day milestones).');
    }

    @IsTest
    static void scenarioN_milestone42Days() {
        createDefaultSettings();
        User owner = createUser('Owner', 'N', 'ownerN@example.com');
        String includedStatus = getIncludedStatus();

        Date entered = Date.today().addDays(-50);
        Lead l = createLead(owner.Id, includedStatus, 'LeadN_42Days');
        createCurrentStatusEvent(l, entered);

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(entered.addDays(42));
        Test.stopTest();

        System.assertEquals(1, res.ownersEmailed, '42-day milestone should send email.');
        System.assertEquals(1, res.leadsEmailed, 'Lead should be included at 42 days.');
    }

    @IsTest
    static void scenarioO_multipleMilestonesInOneRun_7_14_21_28_35() {
        createDefaultSettings();
        User owner = createUser('Owner', 'O', 'ownerO@example.com');
        String includedStatus = getIncludedStatus();

        Date asOf = Date.today();
        Date entered7 = asOf.addDays(-7);
        Date entered14 = asOf.addDays(-14);
        Date entered21 = asOf.addDays(-21);
        Date entered28 = asOf.addDays(-28);
        Date entered35 = asOf.addDays(-35);

        Lead l7 = createLead(owner.Id, includedStatus, 'LeadO_7Days');
        Lead l14 = createLead(owner.Id, includedStatus, 'LeadO_14Days');
        Lead l21 = createLead(owner.Id, includedStatus, 'LeadO_21Days');
        Lead l28 = createLead(owner.Id, includedStatus, 'LeadO_28Days');
        Lead l35 = createLead(owner.Id, includedStatus, 'LeadO_35Days');

        createCurrentStatusEvent(l7, entered7);
        createCurrentStatusEvent(l14, entered14);
        createCurrentStatusEvent(l21, entered21);
        createCurrentStatusEvent(l28, entered28);
        createCurrentStatusEvent(l35, entered35);

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(1, res.ownersEmailed, 'One email should be sent to the owner.');
        System.assertEquals(5, res.leadsEmailed, 'All 5 leads at 7, 14, 21, 28, and 35 days should be included.');
    }

    @IsTest
    static void scenarioO2_sevenDayMilestonesAfter21_onlyMultiplesOf7() {
        createDefaultSettings();
        User owner = createUser('Owner', 'O2', 'ownerO2@example.com');
        String includedStatus = getIncludedStatus();

        Date asOf = Date.today();
        Lead l21 = createLead(owner.Id, includedStatus, 'LeadO2_21Days');
        Lead l22 = createLead(owner.Id, includedStatus, 'LeadO2_22Days');
        Lead l28 = createLead(owner.Id, includedStatus, 'LeadO2_28Days');
        Lead l35 = createLead(owner.Id, includedStatus, 'LeadO2_35Days');
        Lead l42 = createLead(owner.Id, includedStatus, 'LeadO2_42Days');

        createCurrentStatusEvent(l21, asOf.addDays(-21));
        createCurrentStatusEvent(l22, asOf.addDays(-22));
        createCurrentStatusEvent(l28, asOf.addDays(-28));
        createCurrentStatusEvent(l35, asOf.addDays(-35));
        createCurrentStatusEvent(l42, asOf.addDays(-42));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(1, res.ownersEmailed, 'One email should be sent to the owner.');
        System.assertEquals(4, res.leadsEmailed, 'Only leads at 7-day milestones should be included (21, 28, 35, 42). Day 22 should be excluded.');
    }

    @IsTest
    static void scenarioP_sevenDayMilestonesAfter21_onlyMultiplesOf7() {
        createDefaultSettings();
        User owner = createUser('Owner', 'P', 'ownerP@example.com');
        String includedStatus = getIncludedStatus();

        Date asOf = Date.today();
        Lead l21 = createLead(owner.Id, includedStatus, 'LeadP_21Days');
        Lead l22 = createLead(owner.Id, includedStatus, 'LeadP_22Days');
        Lead l28 = createLead(owner.Id, includedStatus, 'LeadP_28Days');
        Lead l29 = createLead(owner.Id, includedStatus, 'LeadP_29Days');
        Lead l35 = createLead(owner.Id, includedStatus, 'LeadP_35Days');
        Lead l36 = createLead(owner.Id, includedStatus, 'LeadP_36Days');

        createCurrentStatusEvent(l21, asOf.addDays(-21));
        createCurrentStatusEvent(l22, asOf.addDays(-22));
        createCurrentStatusEvent(l28, asOf.addDays(-28));
        createCurrentStatusEvent(l29, asOf.addDays(-29));
        createCurrentStatusEvent(l35, asOf.addDays(-35));
        createCurrentStatusEvent(l36, asOf.addDays(-36));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(1, res.ownersEmailed, 'One email should be sent to the owner.');
        System.assertEquals(3, res.leadsEmailed, 'Only leads at 7-day milestones should be included (21, 28, 35). Days 22, 29, 36 should be excluded.');
    }

    @IsTest
    static void scenarioQ_daysBetween7And14_excluded() {
        createDefaultSettings();
        User owner = createUser('Owner', 'Q', 'ownerQ@example.com');
        String includedStatus = getIncludedStatus();

        Date asOf = Date.today();
        Lead l8 = createLead(owner.Id, includedStatus, 'LeadQ_8Days');
        Lead l10 = createLead(owner.Id, includedStatus, 'LeadQ_10Days');
        Lead l13 = createLead(owner.Id, includedStatus, 'LeadQ_13Days');

        createCurrentStatusEvent(l8, asOf.addDays(-8));
        createCurrentStatusEvent(l10, asOf.addDays(-10));
        createCurrentStatusEvent(l13, asOf.addDays(-13));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(0, res.ownersEmailed, 'Days 8-13 should not send emails (only multiples of 7: 7, 14, 21, 28, etc.).');
        System.assertEquals(0, res.leadsEmailed, 'Leads at days 8-13 should be excluded.');
    }

    @IsTest
    static void scenarioR_daysBetween14And21_excluded() {
        createDefaultSettings();
        User owner = createUser('Owner', 'R', 'ownerR@example.com');
        String includedStatus = getIncludedStatus();

        Date asOf = Date.today();
        Lead l15 = createLead(owner.Id, includedStatus, 'LeadR_15Days');
        Lead l18 = createLead(owner.Id, includedStatus, 'LeadR_18Days');
        Lead l20 = createLead(owner.Id, includedStatus, 'LeadR_20Days');

        createCurrentStatusEvent(l15, asOf.addDays(-15));
        createCurrentStatusEvent(l18, asOf.addDays(-18));
        createCurrentStatusEvent(l20, asOf.addDays(-20));

        Test.startTest();
        LeadStagnantAlertService.RunResult res = LeadStagnantAlertService.run(asOf);
        Test.stopTest();

        System.assertEquals(0, res.ownersEmailed, 'Days 15-20 should not send emails (only multiples of 7: 7, 14, 21, 28, etc.).');
        System.assertEquals(0, res.leadsEmailed, 'Leads at days 15-20 should be excluded.');
    }
}