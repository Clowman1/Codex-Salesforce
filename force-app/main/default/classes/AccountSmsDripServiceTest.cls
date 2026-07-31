@IsTest(SeeAllData=true)
private class AccountSmsDripServiceTest {
    private static final String CAMPAIGN_TYPE = 'Account Pre-Approval Message';
    private static final String EXECUTION_FLOW = 'SMS_Campaign_Account_Pre_Approval_Autolaunched';
    private static final String MESSAGE_TYPE = 'RingCentral SMS';
    private static final String WITHDRAWN_REASON = 'App Withdrawn By Borrower';

    private class AllowedOwnerContext {
        Id ownerId;
        Boolean isResolved;
    }

    private class RingCentralSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse response = new HttpResponse();
            String endpoint = req.getEndpoint();

            if (endpoint.contains('/phone-number') && req.getMethod() == 'GET') {
                response.setStatusCode(200);
                response.setBody('{"records":[{"phoneNumber":"+15550000000"}]}');
                return response;
            }

            if (endpoint.contains('/extension/~') && req.getMethod() == 'GET') {
                response.setStatusCode(200);
                response.setBody('{}');
                return response;
            }

            if (endpoint.contains('/sms') && req.getMethod() == 'POST') {
                response.setStatusCode(201);
                response.setBody('{"id":"mock-sms-id"}');
                return response;
            }

            if (endpoint.contains('/oauth/token') && req.getMethod() == 'POST') {
                response.setStatusCode(200);
                response.setBody('{"access_token":"newAccess","refresh_token":"newRefresh"}');
                return response;
            }

            response.setStatusCode(400);
            response.setBody('Unexpected endpoint: ' + endpoint);
            return response;
        }
    }

    private static Id getPersonAccountRecordTypeId() {
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
                AND Name = 'Person Account'
                AND IsActive = true
            LIMIT 1
        ];
        System.assert(!recordTypes.isEmpty(), 'Expected Person Account record type to exist.');
        return recordTypes[0].Id;
    }

    private static AllowedOwnerContext getAllowedOwnerContext() {
        AllowedOwnerContext context = new AllowedOwnerContext();
        Set<Id> allowedOwnerIds = AccountSmsEnrollmentService.getAllowedOwnerIds();
        for (Id allowedOwnerId : allowedOwnerIds) {
            context.ownerId = allowedOwnerId;
            context.isResolved = true;
            return context;
        }

        for (Account_SMS_Allowed_Owner__mdt config : [
            SELECT Username__c
            FROM Account_SMS_Allowed_Owner__mdt
        ]) {
            String allowedUsername = config.Username__c == null ? null : config.Username__c.trim();
            if (String.isBlank(allowedUsername)) {
                continue;
            }

            try {
                User allowedUser = createUser(allowedUsername, 'Allowed Owner');
                Set<Id> refreshedAllowedOwnerIds = AccountSmsEnrollmentService.getAllowedOwnerIds();
                if (refreshedAllowedOwnerIds.contains(allowedUser.Id)) {
                    context.ownerId = allowedUser.Id;
                    context.isResolved = true;
                    return context;
                }
            } catch (DmlException ex) {
                // Ignore org-specific usernames that cannot be created in this test context.
            }
        }

        context.ownerId = UserInfo.getUserId();
        context.isResolved = false;
        return context;
    }

    private static String getFirstTemplateId() {
        Id templateId = AccountSmsEnrollmentService.getInitialTemplateId();
        System.assertNotEquals(null, templateId, 'Expected the first SMS drip template to be configured.');
        return (String) templateId;
    }

    private static String getSecondTemplateId() {
        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE Name = 'Pre-Approved Client – Follow-Up 2'
                AND Folder.Name = 'Ring Central SMS'
                AND IsActive = true
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        System.assert(!templates.isEmpty(), 'Expected the second SMS drip template to be configured.');
        return templates[0].Id;
    }

    private static String getActiveBizDevValue() {
        for (Schema.PicklistEntry entry : Transaction__c.Biz_Dev__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        System.assert(false, 'Expected at least one active Biz Dev picklist value.');
        return null;
    }

    private static String getDifferentBizDevValue(String excludedValue) {
        for (Schema.PicklistEntry entry : Transaction__c.Biz_Dev__c.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() != excludedValue) {
                return entry.getValue();
            }
        }
        return excludedValue + ' - not allowed';
    }

    private static User createUser(String username, String lastName) {
        String suffix = String.valueOf(DateTime.now().getTime());
        User userRecord = new User(
            ProfileId = UserInfo.getProfileId(),
            Username = username,
            Email = 'account-sms-' + suffix + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            Alias = ('u' + suffix).left(8),
            LastName = lastName
        );
        insert userRecord;
        return userRecord;
    }

    private static User createNonAllowedUser() {
        String suffix = String.valueOf(DateTime.now().getTime());
        return createUser('account-sms-' + suffix + '@example.com', 'Sms Test');
    }

    private static Account createPersonAccount(Id ownerId, Boolean optOut, String mobilePhone) {
        String suffix = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.mod(Crypto.getRandomInteger(), 1000));
        Account accountRecord = new Account(
            RecordTypeId = getPersonAccountRecordTypeId(),
            FirstName = 'Test',
            LastName = 'Borrower ' + suffix,
            PersonEmail = 'borrower-' + suffix + '@example.com',
            SMS_Opt_Out__c = optOut
        );
        if (ownerId != null) {
            accountRecord.OwnerId = ownerId;
        }
        if (mobilePhone != null) {
            accountRecord.PersonMobilePhone = mobilePhone;
        }
        insert accountRecord;

        return [
            SELECT Id, OwnerId, SMS_Opt_Out__c, PersonMobilePhone, PersonContactId, Last_RC_Call__c, Last_RC_SMS__c
            FROM Account
            WHERE Id = :accountRecord.Id
        ];
    }

    private static Transaction__c createTransaction(
        Id borrowerId,
        Id accountId,
        String status,
        Date preApprovalDate,
        String withdrawnReason,
        String bizDevValue
    ) {
        Transaction__c transactionRecord = new Transaction__c(
            Borrower_Name__c = borrowerId,
            Account__c = accountId,
            Status__c = status,
            Pre_Approval_Date__c = preApprovalDate,
            Withdrawn_Reason__c = withdrawnReason,
            Biz_Dev__c = bizDevValue
        );
        insert transactionRecord;
        return transactionRecord;
    }

    private static Scheduled_Message__c createScheduledMessage(
        Id accountId,
        Id senderId,
        String templateId,
        DateTime scheduledDateTime,
        DateTime sentDateTime,
        Boolean blocked,
        String phoneNumber
    ) {
        Scheduled_Message__c message = new Scheduled_Message__c(
            Campaign_Type__c = CAMPAIGN_TYPE,
            Execution_Flow__c = EXECUTION_FLOW,
            Sender__c = senderId,
            Recipient_Phone_Number__c = phoneNumber,
            Scheduled_Send_DateTime__c = scheduledDateTime,
            Template_ID__c = templateId,
            Type__c = MESSAGE_TYPE,
            Blocked__c = blocked
        );
        if (accountId != null) {
            message.Account__c = accountId;
        }
        if (sentDateTime != null) {
            message.Sent_DateTime__c = sentDateTime;
        }
        insert message;
        return message;
    }

    private static void allowBizDevValue(String bizDevValue) {
        insert new Lead_Pre_Approval_Allowed_Biz_Devs__c(
            Name = 'Allowed Biz Dev ' + String.valueOf(DateTime.now().getTime()),
            Biz_Dev_Value__c = bizDevValue
        );
    }

    private static void upsertRingCentralCredentials() {
        List<RingCentral_Credentials__c> existingSettings = [
            SELECT Id, SetupOwnerId
            FROM RingCentral_Credentials__c
            WHERE SetupOwnerId = :UserInfo.getOrganizationId()
            LIMIT 1
        ];

        RingCentral_Credentials__c settingsRecord = existingSettings.isEmpty()
            ? new RingCentral_Credentials__c(SetupOwnerId = UserInfo.getOrganizationId(), Name = 'Org Defaults')
            : existingSettings[0];
        settingsRecord.Client_Id__c = 'client-id';
        settingsRecord.Client_Secret__c = 'client-secret';
        upsert settingsRecord;
    }

    private static void authenticateCurrentUser() {
        update new User(
            Id = UserInfo.getUserId(),
            RingCentral_Access_Token__c = 'access-token',
            RingCentral_Refresh_Token__c = 'refresh-token',
            RingCentral_Access_Token_DateTime__c = System.now(),
            RingCentral_Refresh_Token_DateTime__c = System.now()
        );
    }

    private static EmailTemplate createAccountTemplate() {
        String suffix = String.valueOf(DateTime.now().getTime());
        EmailTemplate templateRecord = new EmailTemplate(
            IsActive = true,
            Name = 'Account SMS Test ' + suffix,
            DeveloperName = 'Account_SMS_Test_' + suffix,
            TemplateType = 'custom',
            FolderId = UserInfo.getUserId(),
            Subject = 'Account SMS Subject',
            HtmlValue = '<p>Hello from account SMS drip</p>',
            UIType = 'SFX',
            RelatedEntityType = 'Account'
        );
        insert templateRecord;
        return templateRecord;
    }

    private static String getRenderableTemplateId() {
        Id firstTemplateId = AccountSmsEnrollmentService.getInitialTemplateId();
        if (firstTemplateId != null) {
            return (String) firstTemplateId;
        }
        return createAccountTemplate().Id;
    }

    private static Integer monthNumber(String monthName) {
        if (monthName == 'January') return 1;
        if (monthName == 'February') return 2;
        if (monthName == 'March') return 3;
        if (monthName == 'April') return 4;
        if (monthName == 'May') return 5;
        if (monthName == 'June') return 6;
        if (monthName == 'July') return 7;
        if (monthName == 'August') return 8;
        if (monthName == 'September') return 9;
        if (monthName == 'October') return 10;
        if (monthName == 'November') return 11;
        if (monthName == 'December') return 12;
        return 0;
    }

    @IsTest
    static void testEnrollmentInvocableCreatesScheduledMessageForQualifiedTransaction() {
        String allowedBizDev = getActiveBizDevValue();
        allowBizDevValue(allowedBizDev);
        AllowedOwnerContext allowedOwnerContext = getAllowedOwnerContext();

        Account borrower = createPersonAccount(allowedOwnerContext.ownerId, false, '+15551110001');
        Transaction__c transactionRecord = createTransaction(
            borrower.Id,
            borrower.Id,
            'Cancelled',
            Date.today(),
            WITHDRAWN_REASON,
            allowedBizDev
        );

        AccountSmsEnrollmentInvocable.Input inputRecord = new AccountSmsEnrollmentInvocable.Input();
        inputRecord.transactionId = transactionRecord.Id;

        Test.startTest();
        AccountSmsEnrollmentInvocable.enroll(new List<AccountSmsEnrollmentInvocable.Input>{ inputRecord, null });
        Test.stopTest();

        List<Scheduled_Message__c> messages = [
            SELECT Account__c, Campaign_Type__c, Execution_Flow__c, Recipient_Phone_Number__c, Sender__c, Template_ID__c, Type__c
            FROM Scheduled_Message__c
            WHERE Account__c = :borrower.Id
                AND Campaign_Type__c = :CAMPAIGN_TYPE
        ];

        if (allowedOwnerContext.isResolved) {
            System.assertEquals(1, messages.size(), 'Expected one scheduled message for the qualifying transaction.');
            System.assertEquals(EXECUTION_FLOW, messages[0].Execution_Flow__c);
            System.assertEquals('+15551110001', messages[0].Recipient_Phone_Number__c);
            System.assertEquals(borrower.OwnerId, messages[0].Sender__c);
            System.assertEquals(MESSAGE_TYPE, messages[0].Type__c);
        } else {
            System.assertEquals(0, messages.size(), 'Expected enrollment to skip when no allowlisted owner can be resolved in the org.');
        }
    }

    @IsTest
    static void testEnrollmentServiceSkipsIneligibleTransactionsAndUsesAccountFallback() {
        String allowedBizDev = getActiveBizDevValue();
        allowBizDevValue(allowedBizDev);
        String disallowedBizDev = getDifferentBizDevValue(allowedBizDev);
        String firstTemplateId = getFirstTemplateId();
        AllowedOwnerContext allowedOwnerContext = getAllowedOwnerContext();

        Id allowedOwnerId = allowedOwnerContext.ownerId;
        User disallowedOwner = createNonAllowedUser();

        Account fallbackAccount = createPersonAccount(allowedOwnerId, false, '+15551110002');
        Account accountWithActiveMessage = createPersonAccount(allowedOwnerId, false, '+15551110003');
        Account optedOutAccount = createPersonAccount(allowedOwnerId, true, '+15551110004');
        Account noPhoneAccount = createPersonAccount(allowedOwnerId, false, null);
        Account disallowedOwnerAccount = createPersonAccount(disallowedOwner.Id, false, '+15551110005');
        Account disallowedBizDevAccount = createPersonAccount(allowedOwnerId, false, '+15551110006');

        createScheduledMessage(
            accountWithActiveMessage.Id,
            allowedOwnerId,
            firstTemplateId,
            System.now(),
            null,
            false,
            accountWithActiveMessage.PersonMobilePhone
        );

        Transaction__c fallbackTransaction = createTransaction(
            null,
            fallbackAccount.Id,
            'Cancelled',
            Date.today(),
            WITHDRAWN_REASON,
            allowedBizDev
        );
        Transaction__c duplicateTransaction = createTransaction(
            accountWithActiveMessage.Id,
            accountWithActiveMessage.Id,
            'Cancelled',
            Date.today(),
            WITHDRAWN_REASON,
            allowedBizDev
        );
        Transaction__c optedOutTransaction = createTransaction(
            optedOutAccount.Id,
            optedOutAccount.Id,
            'Cancelled',
            Date.today(),
            WITHDRAWN_REASON,
            allowedBizDev
        );
        Transaction__c noPhoneTransaction = createTransaction(
            noPhoneAccount.Id,
            noPhoneAccount.Id,
            'Cancelled',
            Date.today(),
            WITHDRAWN_REASON,
            allowedBizDev
        );
        Transaction__c badOwnerTransaction = createTransaction(
            disallowedOwnerAccount.Id,
            disallowedOwnerAccount.Id,
            'Cancelled',
            Date.today(),
            WITHDRAWN_REASON,
            allowedBizDev
        );
        Transaction__c badBizDevTransaction = createTransaction(
            disallowedBizDevAccount.Id,
            disallowedBizDevAccount.Id,
            'Cancelled',
            Date.today(),
            WITHDRAWN_REASON,
            disallowedBizDev
        );
        Transaction__c wrongStatusTransaction = createTransaction(
            fallbackAccount.Id,
            fallbackAccount.Id,
            'Application',
            Date.today(),
            WITHDRAWN_REASON,
            allowedBizDev
        );

        Test.startTest();
        AccountSmsEnrollmentService.enrollByTransactionIds(new Set<Id>{
            fallbackTransaction.Id,
            duplicateTransaction.Id,
            optedOutTransaction.Id,
            noPhoneTransaction.Id,
            badOwnerTransaction.Id,
            badBizDevTransaction.Id,
            wrongStatusTransaction.Id
        });
        Test.stopTest();

        List<Scheduled_Message__c> fallbackMessages = [
            SELECT Id
            FROM Scheduled_Message__c
            WHERE Account__c = :fallbackAccount.Id
                AND Campaign_Type__c = :CAMPAIGN_TYPE
        ];
        List<Scheduled_Message__c> duplicateMessages = [
            SELECT Id
            FROM Scheduled_Message__c
            WHERE Account__c = :accountWithActiveMessage.Id
                AND Campaign_Type__c = :CAMPAIGN_TYPE
        ];
        Integer skippedMessageCount = [
            SELECT COUNT()
            FROM Scheduled_Message__c
            WHERE Account__c IN :new Set<Id>{
                optedOutAccount.Id,
                noPhoneAccount.Id,
                disallowedOwnerAccount.Id,
                disallowedBizDevAccount.Id
            }
                AND Campaign_Type__c = :CAMPAIGN_TYPE
        ];

        System.assertEquals(
            allowedOwnerContext.isResolved ? 1 : 0,
            fallbackMessages.size(),
            allowedOwnerContext.isResolved
                ? 'Expected one message created through Account__c fallback resolution.'
                : 'Expected fallback enrollment to skip when no allowlisted owner can be resolved in the org.'
        );
        System.assertEquals(1, duplicateMessages.size(), 'Expected duplicate enrollment to be skipped when an active message exists.');
        System.assertEquals(0, skippedMessageCount, 'Expected all disqualified transactions to be skipped.');
    }

    @IsTest
    static void testCampaignInvocablePostponesForRecentSentAndRecentRingCentralActivity() {
        String firstTemplateId = getFirstTemplateId();
        Account recentSentAccount = createPersonAccount(UserInfo.getUserId(), false, '+15551110007');
        Account recentRcAccount = createPersonAccount(UserInfo.getUserId(), false, '+15551110008');
        recentRcAccount.Last_RC_SMS__c = System.now().addDays(-2);
        update recentRcAccount;

        Scheduled_Message__c currentRecentSentMessage = createScheduledMessage(
            recentSentAccount.Id,
            UserInfo.getUserId(),
            firstTemplateId,
            System.now(),
            null,
            false,
            recentSentAccount.PersonMobilePhone
        );
        DateTime priorSentDateTime = System.now().addDays(-1);
        createScheduledMessage(
            recentSentAccount.Id,
            UserInfo.getUserId(),
            firstTemplateId,
            System.now().addDays(-1),
            priorSentDateTime,
            false,
            recentSentAccount.PersonMobilePhone
        );

        Scheduled_Message__c currentRecentRcMessage = createScheduledMessage(
            recentRcAccount.Id,
            UserInfo.getUserId(),
            firstTemplateId,
            System.now(),
            null,
            false,
            recentRcAccount.PersonMobilePhone
        );
        Scheduled_Message__c noAccountMessage = createScheduledMessage(
            null,
            UserInfo.getUserId(),
            firstTemplateId,
            System.now(),
            null,
            false,
            '+15551110009'
        );

        AccountSmsCampaignInvocable.Input firstInput = new AccountSmsCampaignInvocable.Input();
        firstInput.scheduledMessageId = currentRecentSentMessage.Id;
        AccountSmsCampaignInvocable.Input secondInput = new AccountSmsCampaignInvocable.Input();
        secondInput.scheduledMessageId = currentRecentRcMessage.Id;
        AccountSmsCampaignInvocable.Input thirdInput = new AccountSmsCampaignInvocable.Input();
        thirdInput.scheduledMessageId = noAccountMessage.Id;

        Test.startTest();
        AccountSmsCampaignInvocable.process(new List<AccountSmsCampaignInvocable.Input>{
            firstInput,
            secondInput,
            thirdInput,
            null
        });
        Test.stopTest();

        Scheduled_Message__c postponedForRecentSent = [
            SELECT Scheduled_Send_DateTime__c, Info_Message__c
            FROM Scheduled_Message__c
            WHERE Id = :currentRecentSentMessage.Id
        ];
        Scheduled_Message__c postponedForRecentRc = [
            SELECT Scheduled_Send_DateTime__c, Info_Message__c
            FROM Scheduled_Message__c
            WHERE Id = :currentRecentRcMessage.Id
        ];
        Scheduled_Message__c untouchedNoAccountMessage = [
            SELECT Account__c, Info_Message__c
            FROM Scheduled_Message__c
            WHERE Id = :noAccountMessage.Id
        ];

        System.assertEquals(priorSentDateTime.addDays(7), postponedForRecentSent.Scheduled_Send_DateTime__c);
        System.assert(postponedForRecentSent.Info_Message__c.contains('Activity detected within last 7 days'));
        System.assertEquals(recentRcAccount.Last_RC_SMS__c.addDays(7), postponedForRecentRc.Scheduled_Send_DateTime__c);
        System.assert(postponedForRecentRc.Info_Message__c.contains('Activity detected within last 7 days'));
        System.assertEquals(null, untouchedNoAccountMessage.Account__c);
        System.assertEquals(null, untouchedNoAccountMessage.Info_Message__c);
    }

    @IsTest
    static void testCampaignServiceBlocksOptOutMessage() {
        String firstTemplateId = getFirstTemplateId();
        Account optedOutAccount = createPersonAccount(UserInfo.getUserId(), true, '+15551110010');
        Scheduled_Message__c optedOutMessage = createScheduledMessage(
            optedOutAccount.Id,
            UserInfo.getUserId(),
            firstTemplateId,
            System.now(),
            null,
            false,
            optedOutAccount.PersonMobilePhone
        );

        Test.startTest();
        AccountSmsCampaignService.processByScheduledMessageIds(new Set<Id>{ optedOutMessage.Id });
        Test.stopTest();

        Scheduled_Message__c blockedMessage = [
            SELECT Blocked__c, Info_Message__c
            FROM Scheduled_Message__c
            WHERE Id = :optedOutMessage.Id
        ];

        System.assertEquals(true, blockedMessage.Blocked__c);
        System.assertEquals('Opted Out', blockedMessage.Info_Message__c);
    }

    @IsTest
    static void testCampaignServiceHelperMethods() {
        DateTime newerDateTime = System.now();
        DateTime olderDateTime = newerDateTime.addDays(-1);
        String firstTemplateId = getFirstTemplateId();
        String secondTemplateId = getSecondTemplateId();

        System.assertEquals(newerDateTime, AccountSmsCampaignService.getLatestActivity(newerDateTime, olderDateTime));
        System.assertEquals(newerDateTime, AccountSmsCampaignService.getLatestActivity(olderDateTime, newerDateTime));
        System.assertEquals(newerDateTime, AccountSmsCampaignService.getLatestActivity(newerDateTime, null));
        System.assertEquals(newerDateTime, AccountSmsCampaignService.getLatestActivity(null, newerDateTime));

        System.assertEquals('January', AccountSmsCampaignService.monthName(1));
        System.assertEquals('December', AccountSmsCampaignService.monthName(12));
        System.assertEquals('', AccountSmsCampaignService.monthName(13));

        System.assertEquals(secondTemplateId, AccountSmsCampaignService.nextTemplate(firstTemplateId));
        System.assertEquals(null, AccountSmsCampaignService.nextTemplate('non-existent-template'));

        Map<Id, DateTime> latestEmailActivity = AccountSmsCampaignService.getLatestEmailActivityByAccount(
            new List<Account>{ createPersonAccount(UserInfo.getUserId(), false, '+15551110012') },
            System.now().addDays(-7)
        );
        System.assertEquals(0, latestEmailActivity.size(), 'Expected no recent email activity for a newly-created account.');

        Holiday holidayToday = AccountSmsCampaignService.getHolidayToday(Date.newInstance(2099, 2, 27));
        System.assertEquals(null, holidayToday, 'Expected no holiday for a far-future date in test context.');
    }

    @IsTest
    static void testCampaignServiceEarlyReturnsAndHolidayHelperMatchesRecords() {
        Id fakeScheduledMessageId = (Id) (Scheduled_Message__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA');

        Test.startTest();
        AccountSmsCampaignService.processByScheduledMessageIds(null);
        AccountSmsCampaignService.processByScheduledMessageIds(new Set<Id>());
        AccountSmsCampaignService.processByScheduledMessageIds(new Set<Id>{ fakeScheduledMessageId });
        Test.stopTest();

        System.assertEquals(
            0,
            AccountSmsCampaignService.getLatestRecentSentByAccount(new Set<Id>(), System.now().addDays(-7), new Set<Id>()).size()
        );
        System.assertEquals(
            0,
            AccountSmsCampaignService.getLatestEmailActivityByAccount(new List<Account>(), System.now().addDays(-7)).size()
        );

        Date directHolidayDate = Date.newInstance(2099, 8, 18);
        insert new Holiday(
            Name = 'Direct Holiday Match',
            ActivityDate = directHolidayDate,
            IsAllDay = true
        );

        Holiday directHoliday = AccountSmsCampaignService.getHolidayToday(directHolidayDate);
        System.assertEquals('Direct Holiday Match', directHoliday.Name);
    }

    @IsTest
    static void testCampaignServiceLeavesMessageUnsentWhenRingCentralSendFails() {
        Account accountRecord = createPersonAccount(UserInfo.getUserId(), false, '+15551110015');
        Scheduled_Message__c message = createScheduledMessage(
            accountRecord.Id,
            UserInfo.getUserId(),
            getRenderableTemplateId(),
            System.now(),
            null,
            false,
            accountRecord.PersonMobilePhone
        );

        Test.startTest();
        AccountSmsCampaignService.processByScheduledMessageIds(new Set<Id>{ message.Id });
        Test.stopTest();

        List<Scheduled_Message__c> storedMessages = [
            SELECT Sent_DateTime__c, Info_Message__c
            FROM Scheduled_Message__c
            WHERE Id = :message.Id
               OR (Account__c = :accountRecord.Id AND Id != :message.Id)
            ORDER BY CreatedDate ASC
        ];

        System.assertEquals(1, storedMessages.size(), 'Expected no follow-up message when RingCentral send fails.');
        System.assertEquals(null, storedMessages[0].Sent_DateTime__c);
        System.assertEquals('Unknown login issues. Please re-login from Home page', storedMessages[0].Info_Message__c);
    }

    @IsTest
    static void testHolidayHelperMatchesRecurringYearlyHoliday() {
        Holiday sourceHoliday = [
            SELECT Name, RecurrenceDayOfMonth, RecurrenceMonthOfYear
            FROM Holiday
            WHERE IsRecurrence = true
                AND RecurrenceType = 'RecursYearly'
                AND RecurrenceDayOfMonth != null
                AND RecurrenceMonthOfYear != null
            LIMIT 1
        ];

        Date recurringHolidayDate = Date.newInstance(
            2099,
            monthNumber(String.valueOf(sourceHoliday.get('RecurrenceMonthOfYear'))),
            Integer.valueOf(String.valueOf(sourceHoliday.get('RecurrenceDayOfMonth')))
        );

        Holiday recurringHoliday = AccountSmsCampaignService.getHolidayToday(recurringHolidayDate);
        System.assertEquals(sourceHoliday.Name, recurringHoliday.Name);
    }

    @IsTest
    static void testHolidayHelperMatchesRecurringYearlyHolidayWithoutDayOfMonth() {
        Date recurringHolidayDate = Date.newInstance(2099, 8, 22);
        Holiday recurringHoliday = new Holiday(
            Name = 'Recurring Holiday Without Day',
            IsRecurrence = true,
            RecurrenceType = 'RecursYearly'
        );
        recurringHoliday.put('RecurrenceMonthOfYear', 'August');

        System.assertEquals(
            true,
            AccountSmsCampaignService.matchesYearlyRecurringHoliday(
                recurringHoliday,
                recurringHolidayDate.month(),
                recurringHolidayDate.day()
            )
        );
    }

    @IsTest
    static void testLatestRecentSentByAccountHelperReturnsNewestMessage() {
        String firstTemplateId = getFirstTemplateId();
        Account accountRecord = createPersonAccount(UserInfo.getUserId(), false, '+15551110014');
        Scheduled_Message__c oldestMessage = createScheduledMessage(
            accountRecord.Id,
            UserInfo.getUserId(),
            firstTemplateId,
            System.now().addDays(-3),
            System.now().addDays(-3),
            false,
            accountRecord.PersonMobilePhone
        );
        Scheduled_Message__c newestMessage = createScheduledMessage(
            accountRecord.Id,
            UserInfo.getUserId(),
            firstTemplateId,
            System.now().addDays(-1),
            System.now().addDays(-1),
            false,
            accountRecord.PersonMobilePhone
        );

        Map<Id, Scheduled_Message__c> latestByAccount = AccountSmsCampaignService.getLatestRecentSentByAccount(
            new Set<Id>{ accountRecord.Id },
            System.now().addDays(-7),
            new Set<Id>()
        );
        Map<Id, Scheduled_Message__c> latestByAccountExcludingNewest = AccountSmsCampaignService.getLatestRecentSentByAccount(
            new Set<Id>{ accountRecord.Id },
            System.now().addDays(-7),
            new Set<Id>{ newestMessage.Id }
        );

        System.assertEquals(newestMessage.Id, latestByAccount.get(accountRecord.Id).Id);
        System.assertEquals(oldestMessage.Id, latestByAccountExcludingNewest.get(accountRecord.Id).Id);
    }

    @IsTest
    static void testRingCentralSmsServiceReturnsAuthFailureForAccountMergeContext() {
        upsertRingCentralCredentials();
        Test.setMock(HttpCalloutMock.class, new RingCentralSuccessMock());

        Account sendAccount = createPersonAccount(UserInfo.getUserId(), false, '+15551110013');
        Scheduled_Message__c sendMessage = createScheduledMessage(
            sendAccount.Id,
            UserInfo.getUserId(),
            getRenderableTemplateId(),
            System.now(),
            null,
            false,
            sendAccount.PersonMobilePhone
        );

        Test.startTest();
        Boolean isSent = RingCentralSMSService.sendScheduledMessage(sendMessage.Id);
        Test.stopTest();

        Scheduled_Message__c storedMessage = [
            SELECT Sent_DateTime__c, Info_Message__c
            FROM Scheduled_Message__c
            WHERE Id = :sendMessage.Id
        ];

        System.assertEquals(false, isSent);
        System.assertEquals(null, storedMessage.Sent_DateTime__c);
        System.assertEquals('Unknown login issues. Please re-login from Home page', storedMessage.Info_Message__c);
    }

    @IsTest
    static void testRingCentralSmsServiceReturnsFalseWithoutMergeContext() {
        Scheduled_Message__c message = new Scheduled_Message__c(
            Recipient_Phone_Number__c = '+15551110012',
            Template_ID__c = createAccountTemplate().Id,
            Type__c = MESSAGE_TYPE
        );
        insert message;

        Test.startTest();
        Boolean isSent = RingCentralSMSService.sendScheduledMessage(message.Id);
        Test.stopTest();

        Scheduled_Message__c storedMessage = [
            SELECT Info_Message__c
            FROM Scheduled_Message__c
            WHERE Id = :message.Id
        ];

        System.assertEquals(false, isSent);
        System.assertEquals('No Lead or Account found for template merge context', storedMessage.Info_Message__c);
    }
}