public with sharing class AccountSmsEnrollmentService {

    private static final String CAMPAIGN_TYPE = 'Account Pre-Approval Message';
    private static final String EXECUTION_FLOW = 'SMS_Campaign_Account_Pre_Approval_Autolaunched';
    private static final String MESSAGE_TYPE = 'RingCentral SMS';
    private static final String WITHDRAWN_REASON = 'App Withdrawn By Borrower';
    private static final String TEMPLATE_FOLDER_NAME = 'Ring Central SMS';
    private static final String INITIAL_TEMPLATE_NAME = 'Pre-Approved Client – Follow-Up 1';

    public static void enrollByTransactionIds(Set<Id> transactionIds) {
        if (transactionIds == null || transactionIds.isEmpty()) {
            return;
        }

        List<Transaction__c> transactions = [
            SELECT Id, Status__c, Pre_Approval_Date__c, Withdrawn_Reason__c, Biz_Dev__c, Borrower_Name__c, Account__c
            FROM Transaction__c
            WHERE Id IN :transactionIds
        ];
        if (transactions.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Transaction__c txn : transactions) {
            Id resolvedAccountId = resolveAccountId(txn);
            if (resolvedAccountId != null) {
                accountIds.add(resolvedAccountId);
            }
        }
        if (accountIds.isEmpty()) {
            return;
        }

        Map<Id, Account> accountById = new Map<Id, Account>([
            SELECT Id, OwnerId, SMS_Opt_Out__c, PersonMobilePhone
            FROM Account
            WHERE Id IN :accountIds
        ]);

        Set<Id> accountsWithActiveMessages = new Set<Id>();
        for (Scheduled_Message__c existing : [
            SELECT Id, Account__c
            FROM Scheduled_Message__c
            WHERE Account__c IN :accountIds
                AND Campaign_Type__c = :CAMPAIGN_TYPE
                AND Type__c = :MESSAGE_TYPE
                AND Blocked__c = false
                AND Sent_DateTime__c = null
        ]) {
            if (existing.Account__c != null) {
                accountsWithActiveMessages.add(existing.Account__c);
            }
        }

        Set<String> allowedBizDevValues = new Set<String>();
        for (Lead_Pre_Approval_Allowed_Biz_Devs__c config : [
            SELECT Biz_Dev_Value__c
            FROM Lead_Pre_Approval_Allowed_Biz_Devs__c
        ]) {
            if (String.isNotBlank(config.Biz_Dev_Value__c)) {
                allowedBizDevValues.add(config.Biz_Dev_Value__c);
            }
        }

        Set<Id> allowedOwnerIds = getAllowedOwnerIds();
        Id initialTemplateId = getInitialTemplateId();
        if (allowedOwnerIds.isEmpty() || initialTemplateId == null) {
            return;
        }

        List<Scheduled_Message__c> toInsert = new List<Scheduled_Message__c>();
        for (Transaction__c txn : transactions) {
            if (!meetsTransactionCriteria(txn)) {
                continue;
            }

            Id accountId = resolveAccountId(txn);
            if (accountId == null || !accountById.containsKey(accountId)) {
                continue;
            }

            Account acc = accountById.get(accountId);
            if (acc.SMS_Opt_Out__c) {
                continue;
            }
            if (!allowedOwnerIds.contains(acc.OwnerId)) {
                continue;
            }

            String bizDevValue = String.valueOf(txn.Biz_Dev__c);
            if (!allowedBizDevValues.contains(bizDevValue)) {
                continue;
            }

            if (accountsWithActiveMessages.contains(acc.Id)) {
                continue;
            }
            if (String.isBlank(acc.PersonMobilePhone)) {
                continue;
            }

            toInsert.add(new Scheduled_Message__c(
                Campaign_Type__c = CAMPAIGN_TYPE,
                Execution_Flow__c = EXECUTION_FLOW,
                Account__c = acc.Id,
                Recipient_Phone_Number__c = acc.PersonMobilePhone,
                Scheduled_Send_DateTime__c = System.now(),
                Sender__c = acc.OwnerId,
                Template_ID__c = initialTemplateId,
                Type__c = MESSAGE_TYPE
            ));

            accountsWithActiveMessages.add(acc.Id);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }

    @TestVisible
    private static Set<Id> getAllowedOwnerIds() {
        Set<String> allowedOwnerUsernames = new Set<String>();
        for (Account_SMS_Allowed_Owner__mdt config : [
            SELECT Username__c
            FROM Account_SMS_Allowed_Owner__mdt
        ]) {
            if (String.isNotBlank(config.Username__c)) {
                allowedOwnerUsernames.add(config.Username__c.trim());
            }
        }

        Set<Id> allowedOwnerIds = new Set<Id>();
        if (allowedOwnerUsernames.isEmpty()) {
            return allowedOwnerIds;
        }

        for (User userRecord : [
            SELECT Id
            FROM User
            WHERE Username IN :allowedOwnerUsernames
                AND IsActive = true
        ]) {
            allowedOwnerIds.add(userRecord.Id);
        }
        return allowedOwnerIds;
    }

    @TestVisible
    private static Id getInitialTemplateId() {
        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE Name = :INITIAL_TEMPLATE_NAME
                AND Folder.Name = :TEMPLATE_FOLDER_NAME
                AND IsActive = true
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0].Id;
    }

    private static Boolean meetsTransactionCriteria(Transaction__c txn) {
        return txn != null
            && txn.Status__c == 'Cancelled'
            && txn.Pre_Approval_Date__c != null
            && txn.Withdrawn_Reason__c == WITHDRAWN_REASON;
    }

    private static Id resolveAccountId(Transaction__c txn) {
        if (txn == null) {
            return null;
        }
        if (txn.Borrower_Name__c != null) {
            return txn.Borrower_Name__c;
        }
        return txn.Account__c;
    }
}