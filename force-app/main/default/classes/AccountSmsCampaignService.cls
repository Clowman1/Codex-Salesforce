public with sharing class AccountSmsCampaignService {

    private static final String CAMPAIGN_TYPE = 'Account Pre-Approval Message';
    private static final String EXECUTION_FLOW = 'SMS_Campaign_Account_Pre_Approval_Autolaunched';
    private static final String MESSAGE_TYPE = 'RingCentral SMS';

    public static void processByScheduledMessageIds(Set<Id> scheduledMessageIds) {
        if (scheduledMessageIds == null || scheduledMessageIds.isEmpty()) {
            return;
        }

        List<Scheduled_Message__c> scheduledMessages = [
            SELECT Id, Account__c, Sender__c, Template_ID__c, Campaign_Type__c, Type__c
            FROM Scheduled_Message__c
            WHERE Id IN :scheduledMessageIds
        ];
        if (scheduledMessages.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Scheduled_Message__c message : scheduledMessages) {
            if (message.Account__c != null) {
                accountIds.add(message.Account__c);
            }
        }

        Map<Id, Account> accountById = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            accountById = new Map<Id, Account>([
                SELECT Id, OwnerId, SMS_Opt_Out__c, PersonMobilePhone, PersonContactId, Last_RC_Call__c, Last_RC_SMS__c
                FROM Account
                WHERE Id IN :accountIds
            ]);
        }

        DateTime sevenDaysAgo = System.now().addDays(-7);
        Map<Id, Scheduled_Message__c> latestRecentSentByAccount = getLatestRecentSentByAccount(accountIds, sevenDaysAgo, scheduledMessageIds);
        Map<Id, DateTime> latestEmailActivityByAccount = getLatestEmailActivityByAccount(accountById.values(), sevenDaysAgo);
        Holiday holidayToday = getHolidayToday(Date.today());

        List<Scheduled_Message__c> updates = new List<Scheduled_Message__c>();
        List<Scheduled_Message__c> nextMessages = new List<Scheduled_Message__c>();

        for (Scheduled_Message__c message : scheduledMessages) {
            if (message.Account__c == null) {
                continue;
            }
            if (!accountById.containsKey(message.Account__c)) {
                updates.add(new Scheduled_Message__c(
                    Id = message.Id,
                    Blocked__c = true,
                    Info_Message__c = 'Blocked. Related Account was not found'
                ));
                continue;
            }

            Account acc = accountById.get(message.Account__c);
            if (acc.SMS_Opt_Out__c) {
                updates.add(new Scheduled_Message__c(
                    Id = message.Id,
                    Blocked__c = true,
                    Info_Message__c = 'Opted Out'
                ));
                continue;
            }

            if (holidayToday != null) {
                updates.add(new Scheduled_Message__c(
                    Id = message.Id,
                    Scheduled_Send_DateTime__c = System.now().addDays(1),
                    Info_Message__c = 'Postponed. Today is a holiday: ' + holidayToday.Name
                ));
                continue;
            }

            Scheduled_Message__c recentSent = latestRecentSentByAccount.get(acc.Id);
            if (recentSent != null && recentSent.Sent_DateTime__c != null) {
                updates.add(new Scheduled_Message__c(
                    Id = message.Id,
                    Scheduled_Send_DateTime__c = recentSent.Sent_DateTime__c.addDays(7),
                    Info_Message__c = 'Postponed. Activity detected within last 7 days'
                ));
                continue;
            }

            DateTime latestRcActivity = getLatestActivity(acc.Last_RC_Call__c, acc.Last_RC_SMS__c);
            if (latestRcActivity != null && latestRcActivity >= sevenDaysAgo) {
                updates.add(new Scheduled_Message__c(
                    Id = message.Id,
                    Scheduled_Send_DateTime__c = latestRcActivity.addDays(7),
                    Info_Message__c = 'Postponed. Activity detected within last 7 days'
                ));
                continue;
            }

            DateTime latestEmailActivity = latestEmailActivityByAccount.get(acc.Id);
            if (latestEmailActivity != null && latestEmailActivity >= sevenDaysAgo) {
                updates.add(new Scheduled_Message__c(
                    Id = message.Id,
                    Scheduled_Send_DateTime__c = latestEmailActivity.addDays(7),
                    Info_Message__c = 'Postponed. Email activity detected within last 7 days on this Account'
                ));
                continue;
            }

            Boolean isSent = RingCentralSMSService.sendScheduledMessage(message.Id);
            if (!isSent) {
                continue;
            }

            String nextTemplateId = nextTemplate(message.Template_ID__c);
            if (String.isBlank(nextTemplateId)) {
                continue;
            }

            nextMessages.add(new Scheduled_Message__c(
                Campaign_Type__c = CAMPAIGN_TYPE,
                Execution_Flow__c = EXECUTION_FLOW,
                Account__c = acc.Id,
                Recipient_Phone_Number__c = acc.PersonMobilePhone,
                Scheduled_Send_DateTime__c = System.now().addDays(7),
                Sender__c = message.Sender__c != null ? message.Sender__c : acc.OwnerId,
                Template_ID__c = nextTemplateId,
                Type__c = MESSAGE_TYPE
            ));
        }

        if (!updates.isEmpty()) {
            update updates;
        }
        if (!nextMessages.isEmpty()) {
            insert nextMessages;
        }
    }

    @TestVisible
    private static Map<Id, Scheduled_Message__c> getLatestRecentSentByAccount(
        Set<Id> accountIds,
        DateTime sevenDaysAgo,
        Set<Id> excludedMessageIds
    ) {
        Map<Id, Scheduled_Message__c> latestByAccount = new Map<Id, Scheduled_Message__c>();
        if (accountIds == null || accountIds.isEmpty()) {
            return latestByAccount;
        }

        for (Scheduled_Message__c message : [
            SELECT Id, Account__c, Sent_DateTime__c
            FROM Scheduled_Message__c
            WHERE Account__c IN :accountIds
                AND Campaign_Type__c = :CAMPAIGN_TYPE
                AND Type__c = :MESSAGE_TYPE
                AND Sent_DateTime__c >= :sevenDaysAgo
            ORDER BY Sent_DateTime__c DESC
        ]) {
            if (excludedMessageIds.contains(message.Id)) {
                continue;
            }
            if (!latestByAccount.containsKey(message.Account__c)) {
                latestByAccount.put(message.Account__c, message);
            }
        }

        return latestByAccount;
    }

    @TestVisible
    private static Map<Id, DateTime> getLatestEmailActivityByAccount(List<Account> accounts, DateTime sevenDaysAgo) {
        Map<Id, DateTime> latestByAccount = new Map<Id, DateTime>();
        if (accounts == null || accounts.isEmpty()) {
            return latestByAccount;
        }

        Map<Id, Id> relationIdToAccountId = new Map<Id, Id>();
        Set<Id> relationIds = new Set<Id>();
        for (Account acc : accounts) {
            relationIds.add(acc.Id);
            relationIdToAccountId.put(acc.Id, acc.Id);
            if (acc.PersonContactId != null) {
                relationIds.add(acc.PersonContactId);
                relationIdToAccountId.put(acc.PersonContactId, acc.Id);
            }
        }
        if (relationIds.isEmpty()) {
            return latestByAccount;
        }

        for (EmailMessageRelation relation : [
            SELECT Id, RelationId, CreatedDate
            FROM EmailMessageRelation
            WHERE RelationId IN :relationIds
                AND CreatedDate >= :sevenDaysAgo
            ORDER BY CreatedDate DESC
        ]) {
            Id accountId = relationIdToAccountId.get(relation.RelationId);
            if (accountId == null || latestByAccount.containsKey(accountId)) {
                continue;
            }
            latestByAccount.put(accountId, relation.CreatedDate);
        }

        return latestByAccount;
    }

    @TestVisible
    private static Holiday getHolidayToday(Date todayDate) {
        List<Holiday> holidays = [
            SELECT Id, Name, ActivityDate, IsRecurrence, RecurrenceType, RecurrenceDayOfMonth, RecurrenceMonthOfYear
            FROM Holiday
            WHERE ActivityDate = :todayDate
                OR IsRecurrence = true
            LIMIT 200
        ];

        Integer todayMonth = todayDate.month();
        Integer todayDay = todayDate.day();
        for (Holiday holiday : holidays) {
            if (holiday.ActivityDate == todayDate) {
                return holiday;
            }
            if (matchesYearlyRecurringHoliday(holiday, todayMonth, todayDay)) {
                return holiday;
            }
        }

        return null;
    }

    @TestVisible
    private static Boolean matchesYearlyRecurringHoliday(Holiday holiday, Integer todayMonth, Integer todayDay) {
        if (
            holiday == null
            || !holiday.IsRecurrence
            || (holiday.RecurrenceType != 'Yearly' && holiday.RecurrenceType != 'RecursYearly')
        ) {
            return false;
        }

        Integer recurrenceDay = null;
        Object recurrenceDayObj = holiday.get('RecurrenceDayOfMonth');
        if (recurrenceDayObj != null) {
            recurrenceDay = Integer.valueOf(String.valueOf(recurrenceDayObj));
        }
        if (recurrenceDay != null && recurrenceDay != todayDay) {
            return false;
        }

        String recurrenceMonth = null;
        Object recurrenceMonthObj = holiday.get('RecurrenceMonthOfYear');
        if (recurrenceMonthObj != null) {
            recurrenceMonth = String.valueOf(recurrenceMonthObj);
        }
        if (String.isBlank(recurrenceMonth)) {
            return false;
        }

        return recurrenceMonth == String.valueOf(todayMonth) || recurrenceMonth == monthName(todayMonth);
    }

    @TestVisible
    private static DateTime getLatestActivity(DateTime firstDateTime, DateTime secondDateTime) {
        if (firstDateTime == null) {
            return secondDateTime;
        }
        if (secondDateTime == null) {
            return firstDateTime;
        }
        return firstDateTime > secondDateTime ? firstDateTime : secondDateTime;
    }

    @TestVisible
    private static String monthName(Integer monthNumber) {
        if (monthNumber == 1) return 'January';
        if (monthNumber == 2) return 'February';
        if (monthNumber == 3) return 'March';
        if (monthNumber == 4) return 'April';
        if (monthNumber == 5) return 'May';
        if (monthNumber == 6) return 'June';
        if (monthNumber == 7) return 'July';
        if (monthNumber == 8) return 'August';
        if (monthNumber == 9) return 'September';
        if (monthNumber == 10) return 'October';
        if (monthNumber == 11) return 'November';
        if (monthNumber == 12) return 'December';
        return '';
    }

    @TestVisible
    private static String nextTemplate(String templateId) {
        Map<String, String> mapByTemplate = new Map<String, String>{
            '00XQi000008PhA1MAK' => '00XQi000008PhDFMA0',
            '00XQi000008PhDFMA0' => '00XQi000008PhGTMA0',
            '00XQi000008PhGTMA0' => '00XQi000008PhI5MAK',
            '00XQi000008PhI5MAK' => '00XQi000008PhLJMA0',
            '00XQi000008PhLJMA0' => '00XQi000008PhQ9MAK',
            '00XQi000008PhQ9MAK' => '00XQi000008PhbRMAS',
            '00XQi000008PhbRMAS' => '00XQi000008PhefMAC',
            '00XQi000008PhefMAC' => '00XQi000008PhhtMAC',
            '00XQi000008PhhtMAC' => '00XQi000008Phl7MAC',
            '00XQi000008Phl7MAC' => '00XQi000008PhmjMAC',
            '00XQi000008PhmjMAC' => '00XQi000008PhoLMAS'
        };
        return mapByTemplate.get(templateId);
    }
}