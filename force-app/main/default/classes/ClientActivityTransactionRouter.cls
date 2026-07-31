public without sharing class ClientActivityTransactionRouter {
    private static final Set<String> INACTIVE_TRANSACTION_STATUSES = new Set<String>{
        'Cancelled',
        'Lost',
        'PC Review',
        'Post-Closed'
    };

    // Only consumer-borrower leads are re-pointed. Realtor and Loan Officer leads are legitimately
    // the right home for a call, so they are left alone.
    private static final Set<String> CONSUMER_LEAD_RECORD_TYPES = new Set<String>{
        'Consumer_Lead_record_type',
        'Consumer_Under_Contract_Lead_Record_Type'
    };

    // Salesforce forbids a Task from carrying both a Lead WhoId and any WhatId, so a call that
    // lands on a stale lead can never be attached to the borrower's transaction. This re-points
    // those tasks before save, applying the intended order:
    //   1. an active transaction for that person,
    //   2. an active (non-nurture) lead,
    //   3. otherwise the Person Account.
    @TestVisible
    private static void repointStaleLeadTasks(List<Task> taskRecords) {
        String leadPrefix = Lead.SObjectType.getDescribe().getKeyPrefix();
        Set<Id> leadIds = new Set<Id>();
        for (Task taskRecord : taskRecords) {
            if (!isClientCommunicationTask(taskRecord) || taskRecord.WhoId == null) {
                continue;
            }
            if (String.valueOf(taskRecord.WhoId).left(3) == leadPrefix) {
                leadIds.add(taskRecord.WhoId);
            }
        }
        if (leadIds.isEmpty()) {
            return;
        }

        Map<Id, Lead> leadsById = new Map<Id, Lead>([
            SELECT Id, Status, Phone, MobilePhone, RecordType.DeveloperName
            FROM Lead
            WHERE Id IN :leadIds
        ]);

        Set<String> phoneNumbers = new Set<String>();
        for (Lead leadRecord : leadsById.values()) {
            if (!isConsumerLead(leadRecord)) {
                continue;
            }
            if (String.isNotBlank(leadRecord.Phone)) {
                phoneNumbers.add(leadRecord.Phone);
            }
            if (String.isNotBlank(leadRecord.MobilePhone)) {
                phoneNumbers.add(leadRecord.MobilePhone);
            }
        }
        if (phoneNumbers.isEmpty()) {
            return;
        }

        Map<String, Id> contactIdByPhone = RingCentralLeadPriorityMatcher.getContactIdsByPhoneNumbers(phoneNumbers);
        Map<String, Id> transactionIdByPhone = RingCentralLeadPriorityMatcher.getTransactionIdsByPhoneNumbers(phoneNumbers);

        for (Task taskRecord : taskRecords) {
            if (!isClientCommunicationTask(taskRecord) || taskRecord.WhoId == null) {
                continue;
            }
            Lead leadRecord = leadsById.get(taskRecord.WhoId);
            if (leadRecord == null || !isConsumerLead(leadRecord)) {
                continue;
            }

            Id transactionId = phoneLookup(transactionIdByPhone, leadRecord);
            Id contactId = phoneLookup(contactIdByPhone, leadRecord);
            if (contactId == null) {
                // Nothing better to point at, so the lead keeps the activity.
                continue;
            }

            if (transactionId != null) {
                taskRecord.WhoId = contactId;
                taskRecord.WhatId = transactionId;
            } else if (isNurtureStatus(leadRecord.Status)) {
                taskRecord.WhoId = contactId;
                taskRecord.WhatId = null;
            }
        }
    }

    private static Boolean isConsumerLead(Lead leadRecord) {
        return leadRecord != null
            && leadRecord.RecordType != null
            && CONSUMER_LEAD_RECORD_TYPES.contains(leadRecord.RecordType.DeveloperName);
    }

    // The org carries several spellings ('Nurturing', 'Nurture - Preapproval', 'Nurture-Pre-Approval',
    // 'Nurtured'), so this matches on the stem rather than a value list.
    private static Boolean isNurtureStatus(String status) {
        return String.isNotBlank(status) && status.toLowerCase().contains('nurtur');
    }

    private static Id phoneLookup(Map<String, Id> idsByNormalizedPhone, Lead leadRecord) {
        if (idsByNormalizedPhone == null || idsByNormalizedPhone.isEmpty()) {
            return null;
        }
        for (String rawPhone : new List<String>{ leadRecord.Phone, leadRecord.MobilePhone }) {
            String normalized = RingCentralLeadPriorityMatcher.normalizePhoneNumber(rawPhone);
            if (String.isNotBlank(normalized) && idsByNormalizedPhone.containsKey(normalized)) {
                return idsByNormalizedPhone.get(normalized);
            }
        }
        return null;
    }

    public static void routeTasks(List<Task> taskRecords) {
        repointStaleLeadTasks(taskRecords);

        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        Set<Id> transactionIds = new Set<Id>();
        Set<Id> opportunityIds = new Set<Id>();

        for (Task taskRecord : taskRecords) {
            if (!isClientCommunicationTask(taskRecord)) {
                continue;
            }
            collectReferenceIds(taskRecord.WhatId, accountIds, contactIds, transactionIds, opportunityIds);
            collectReferenceIds(taskRecord.WhoId, accountIds, contactIds, transactionIds, opportunityIds);
        }

        Map<Id, Id> accountIdByContactId = getAccountIdByContactId(contactIds);
        Map<Id, Id> accountIdByOpportunityId = getAccountIdByOpportunityId(opportunityIds);
        RouteContext context = buildRouteContext(accountIds, accountIdByContactId.values(), accountIdByOpportunityId.values(), transactionIds);

        for (Task taskRecord : taskRecords) {
            if (!isClientCommunicationTask(taskRecord)) {
                continue;
            }
            Id resolvedTransactionId = resolveTransactionId(taskRecord.WhatId, taskRecord.WhoId, accountIdByContactId, accountIdByOpportunityId, context);
            if (resolvedTransactionId != null && taskRecord.WhatId != resolvedTransactionId) {
                taskRecord.WhatId = resolvedTransactionId;
            }
        }
    }

    public static void routeEmailMessages(List<EmailMessage> emailMessages) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        Set<Id> transactionIds = new Set<Id>();
        Set<Id> opportunityIds = new Set<Id>();

        for (EmailMessage emailMessage : emailMessages) {
            if (emailMessage.Incoming == null) {
                continue;
            }
            collectReferenceIds(emailMessage.RelatedToId, accountIds, contactIds, transactionIds, opportunityIds);
        }

        RouteContext context = buildRouteContext(accountIds, new List<Id>(), new List<Id>(), transactionIds);

        for (EmailMessage emailMessage : emailMessages) {
            Id resolvedTransactionId = resolveTransactionId(emailMessage.RelatedToId, null, new Map<Id, Id>(), new Map<Id, Id>(), context);
            if (resolvedTransactionId != null && emailMessage.RelatedToId != resolvedTransactionId) {
                emailMessage.RelatedToId = resolvedTransactionId;
            }
        }
    }

    public static void routeCallInsights(List<Call_Insight__c> insightRecords) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> transactionIds = new Set<Id>();
        for (Call_Insight__c insightRecord : insightRecords) {
            if (insightRecord.Account__c != null) {
                accountIds.add(insightRecord.Account__c);
            }
            if (insightRecord.Transaction__c != null) {
                transactionIds.add(insightRecord.Transaction__c);
            }
        }

        RouteContext context = buildRouteContext(accountIds, new List<Id>(), new List<Id>(), transactionIds);
        for (Call_Insight__c insightRecord : insightRecords) {
            Id resolvedTransactionId = resolveTransactionId(insightRecord.Transaction__c, null, new Map<Id, Id>(), new Map<Id, Id>(), context);
            if (resolvedTransactionId == null) {
                resolvedTransactionId = resolveTransactionForAccount(insightRecord.Account__c, context);
            }
            if (resolvedTransactionId != null) {
                insightRecord.Transaction__c = resolvedTransactionId;
                Transaction__c transactionRecord = context.transactionsById.get(resolvedTransactionId);
                if (transactionRecord != null && transactionRecord.Borrower_Name__c != null) {
                    insightRecord.Account__c = transactionRecord.Borrower_Name__c;
                }
            }
        }
    }

    public static void stampProcessorCallFromInsights(List<Call_Insight__c> insightRecords) {
        Map<Id, DateTime> latestCallByTransactionId = new Map<Id, DateTime>();
        for (Call_Insight__c insightRecord : insightRecords) {
            if (insightRecord.Transaction__c == null || insightRecord.Recording_Start_DateTime__c == null) {
                continue;
            }
            DateTime callDateTime = insightRecord.Recording_Start_DateTime__c;
            if (!latestCallByTransactionId.containsKey(insightRecord.Transaction__c)
                || callDateTime > latestCallByTransactionId.get(insightRecord.Transaction__c)) {
                latestCallByTransactionId.put(insightRecord.Transaction__c, callDateTime);
            }
        }
        if (latestCallByTransactionId.isEmpty()) {
            return;
        }

        List<Transaction__c> updates = new List<Transaction__c>();
        for (Transaction__c transactionRecord : [
            SELECT Id, Last_Processor_RC_Call__c
            FROM Transaction__c
            WHERE Id IN :latestCallByTransactionId.keySet()
            AND Status__c NOT IN :INACTIVE_TRANSACTION_STATUSES
        ]) {
            DateTime latestCallDateTime = latestCallByTransactionId.get(transactionRecord.Id);
            if (latestCallDateTime != null
                && (transactionRecord.Last_Processor_RC_Call__c == null
                    || latestCallDateTime > transactionRecord.Last_Processor_RC_Call__c)) {
                updates.add(new Transaction__c(
                    Id = transactionRecord.Id,
                    Last_Processor_RC_Call__c = latestCallDateTime
                ));
            }
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public static void routeSmsHistory(List<smagicinteract__smsMagic__c> smsRecords) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        Set<Id> transactionIds = new Set<Id>();
        for (smagicinteract__smsMagic__c smsRecord : smsRecords) {
            if (smsRecord.smagicinteract__Account__c != null) {
                accountIds.add(smsRecord.smagicinteract__Account__c);
            }
            if (smsRecord.smagicinteract__Contact__c != null) {
                contactIds.add(smsRecord.smagicinteract__Contact__c);
            }
            if (smsRecord.Transaction__c != null) {
                transactionIds.add(smsRecord.Transaction__c);
            }
        }

        Map<Id, Id> accountIdByContactId = getAccountIdByContactId(contactIds);
        RouteContext context = buildRouteContext(accountIds, accountIdByContactId.values(), new List<Id>(), transactionIds);
        for (smagicinteract__smsMagic__c smsRecord : smsRecords) {
            Id resolvedTransactionId = resolveTransactionId(smsRecord.Transaction__c, smsRecord.smagicinteract__Contact__c, accountIdByContactId, new Map<Id, Id>(), context);
            if (resolvedTransactionId == null) {
                resolvedTransactionId = resolveTransactionForAccount(smsRecord.smagicinteract__Account__c, context);
            }
            if (resolvedTransactionId != null) {
                smsRecord.Transaction__c = resolvedTransactionId;
                Transaction__c transactionRecord = context.transactionsById.get(resolvedTransactionId);
                if (transactionRecord != null && transactionRecord.Borrower_Name__c != null) {
                    smsRecord.smagicinteract__Account__c = transactionRecord.Borrower_Name__c;
                }
            }
        }
    }

    public static void stampProcessorSmsFromHistory(List<smagicinteract__smsMagic__c> smsRecords) {
        Map<Id, DateTime> latestSmsByTransactionId = new Map<Id, DateTime>();
        for (smagicinteract__smsMagic__c smsRecord : smsRecords) {
            if (smsRecord.Transaction__c == null) {
                continue;
            }
            DateTime smsDateTime = smsRecord.CreatedDate == null ? System.now() : smsRecord.CreatedDate;
            if (!latestSmsByTransactionId.containsKey(smsRecord.Transaction__c)
                || smsDateTime > latestSmsByTransactionId.get(smsRecord.Transaction__c)) {
                latestSmsByTransactionId.put(smsRecord.Transaction__c, smsDateTime);
            }
        }
        if (latestSmsByTransactionId.isEmpty()) {
            return;
        }

        List<Transaction__c> updates = new List<Transaction__c>();
        for (Transaction__c transactionRecord : [
            SELECT Id, Last_Processor_RC_SMS__c
            FROM Transaction__c
            WHERE Id IN :latestSmsByTransactionId.keySet()
            AND Status__c NOT IN :INACTIVE_TRANSACTION_STATUSES
        ]) {
            DateTime latestSmsDateTime = latestSmsByTransactionId.get(transactionRecord.Id);
            if (latestSmsDateTime != null
                && (transactionRecord.Last_Processor_RC_SMS__c == null
                    || latestSmsDateTime > transactionRecord.Last_Processor_RC_SMS__c)) {
                updates.add(new Transaction__c(
                    Id = transactionRecord.Id,
                    Last_Processor_RC_SMS__c = latestSmsDateTime
                ));
            }
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static Boolean isClientCommunicationTask(Task taskRecord) {
        String subject = String.isBlank(taskRecord.Subject) ? '' : taskRecord.Subject.toLowerCase();
        String subtype = String.isBlank(taskRecord.TaskSubtype) ? '' : taskRecord.TaskSubtype.toLowerCase();
        return subtype == 'call'
            || subtype == 'email'
            || subject.contains(' texted ')
            || subject.contains(' called ')
            || subject.startsWith('call on ')
            || subject.contains('ringcentral')
            || subject.contains('ace call details');
    }

    private static void collectReferenceIds(Id recordId, Set<Id> accountIds, Set<Id> contactIds, Set<Id> transactionIds, Set<Id> opportunityIds) {
        if (recordId == null) {
            return;
        }
        String prefix = String.valueOf(recordId).left(3);
        if (prefix == Account.SObjectType.getDescribe().getKeyPrefix()) {
            accountIds.add(recordId);
        } else if (prefix == Contact.SObjectType.getDescribe().getKeyPrefix()) {
            contactIds.add(recordId);
        } else if (prefix == Transaction__c.SObjectType.getDescribe().getKeyPrefix()) {
            transactionIds.add(recordId);
        } else if (prefix == Opportunity.SObjectType.getDescribe().getKeyPrefix()) {
            opportunityIds.add(recordId);
        }
    }

    private static Id resolveTransactionId(
        Id primaryReferenceId,
        Id secondaryReferenceId,
        Map<Id, Id> accountIdByContactId,
        Map<Id, Id> accountIdByOpportunityId,
        RouteContext context
    ) {
        Id resolvedTransactionId = resolveTransactionFromReference(primaryReferenceId, accountIdByContactId, accountIdByOpportunityId, context);
        if (resolvedTransactionId == null) {
            resolvedTransactionId = resolveTransactionFromReference(secondaryReferenceId, accountIdByContactId, accountIdByOpportunityId, context);
        }
        return resolvedTransactionId;
    }

    private static Id resolveTransactionFromReference(
        Id referenceId,
        Map<Id, Id> accountIdByContactId,
        Map<Id, Id> accountIdByOpportunityId,
        RouteContext context
    ) {
        if (referenceId == null) {
            return null;
        }
        String prefix = String.valueOf(referenceId).left(3);
        if (prefix == Transaction__c.SObjectType.getDescribe().getKeyPrefix()) {
            return resolvePrimaryTransaction(referenceId, context);
        }
        if (prefix == Account.SObjectType.getDescribe().getKeyPrefix()) {
            return resolveTransactionForAccount(referenceId, context);
        }
        if (prefix == Contact.SObjectType.getDescribe().getKeyPrefix()) {
            return resolveTransactionForAccount(accountIdByContactId.get(referenceId), context);
        }
        if (prefix == Opportunity.SObjectType.getDescribe().getKeyPrefix()) {
            return resolveTransactionForAccount(accountIdByOpportunityId.get(referenceId), context);
        }
        return null;
    }

    private static Id resolveTransactionForAccount(Id accountId, RouteContext context) {
        if (accountId == null) {
            return null;
        }
        List<Transaction__c> transactionRecords = context.activeTransactionsByAccountId.get(accountId);
        if (transactionRecords == null || transactionRecords.isEmpty()) {
            return null;
        }
        for (Transaction__c transactionRecord : transactionRecords) {
            if (transactionRecord.First_Mortgage__c == null) {
                return transactionRecord.Id;
            }
        }
        return transactionRecords[0].Id;
    }

    private static Id resolvePrimaryTransaction(Id transactionId, RouteContext context) {
        if (transactionId == null) {
            return null;
        }
        Transaction__c transactionRecord = context.transactionsById.get(transactionId);
        if (transactionRecord == null) {
            return transactionId;
        }
        if (isActive(transactionRecord) && transactionRecord.First_Mortgage__c != null) {
            Transaction__c firstMortgage = context.transactionsById.get(transactionRecord.First_Mortgage__c);
            if (firstMortgage != null && isActive(firstMortgage)) {
                return firstMortgage.Id;
            }
        }
        if (isActive(transactionRecord)) {
            return transactionRecord.Id;
        }
        if (transactionRecord.Borrower_Name__c != null) {
            Id accountTransactionId = resolveTransactionForAccount(transactionRecord.Borrower_Name__c, context);
            if (accountTransactionId != null) {
                return accountTransactionId;
            }
        }
        return null;
    }

    private static RouteContext buildRouteContext(Set<Id> directAccountIds, List<Id> contactAccountIds, List<Id> opportunityAccountIds, Set<Id> directTransactionIds) {
        Set<Id> accountIds = new Set<Id>();
        accountIds.addAll(directAccountIds);
        accountIds.addAll(contactAccountIds);
        accountIds.addAll(opportunityAccountIds);

        Map<Id, Transaction__c> transactionsById = new Map<Id, Transaction__c>();
        if (!directTransactionIds.isEmpty()) {
            for (Transaction__c transactionRecord : [
                SELECT Id, Name, Status__c, Borrower_Name__c, First_Mortgage__c, CreatedDate, LastModifiedDate
                FROM Transaction__c
                WHERE Id IN :directTransactionIds
            ]) {
                transactionsById.put(transactionRecord.Id, transactionRecord);
                if (transactionRecord.Borrower_Name__c != null) {
                    accountIds.add(transactionRecord.Borrower_Name__c);
                }
                if (transactionRecord.First_Mortgage__c != null) {
                    transactionsById.put(transactionRecord.First_Mortgage__c, null);
                }
            }
        }

        Set<Id> firstMortgageIds = new Set<Id>();
        for (Id transactionId : transactionsById.keySet()) {
            if (transactionsById.get(transactionId) == null) {
                firstMortgageIds.add(transactionId);
            }
        }
        if (!firstMortgageIds.isEmpty()) {
            for (Transaction__c transactionRecord : [
                SELECT Id, Name, Status__c, Borrower_Name__c, First_Mortgage__c, CreatedDate, LastModifiedDate
                FROM Transaction__c
                WHERE Id IN :firstMortgageIds
            ]) {
                transactionsById.put(transactionRecord.Id, transactionRecord);
                if (transactionRecord.Borrower_Name__c != null) {
                    accountIds.add(transactionRecord.Borrower_Name__c);
                }
            }
        }

        List<Transaction__c> activeTransactions = new List<Transaction__c>();
        if (!accountIds.isEmpty()) {
            activeTransactions = [
                SELECT Id, Name, Status__c, Borrower_Name__c, First_Mortgage__c, CreatedDate, LastModifiedDate
                FROM Transaction__c
                WHERE Borrower_Name__c IN :accountIds
                AND Status__c NOT IN :INACTIVE_TRANSACTION_STATUSES
                ORDER BY CreatedDate ASC, LastModifiedDate DESC
            ];
        }

        Map<Id, List<Transaction__c>> activeTransactionsByAccountId = new Map<Id, List<Transaction__c>>();
        for (Transaction__c transactionRecord : activeTransactions) {
            transactionsById.put(transactionRecord.Id, transactionRecord);
            if (!activeTransactionsByAccountId.containsKey(transactionRecord.Borrower_Name__c)) {
                activeTransactionsByAccountId.put(transactionRecord.Borrower_Name__c, new List<Transaction__c>());
            }
            activeTransactionsByAccountId.get(transactionRecord.Borrower_Name__c).add(transactionRecord);
        }

        return new RouteContext(transactionsById, activeTransactionsByAccountId);
    }

    private static Boolean isActive(Transaction__c transactionRecord) {
        return transactionRecord != null
            && !String.isBlank(transactionRecord.Status__c)
            && !INACTIVE_TRANSACTION_STATUSES.contains(transactionRecord.Status__c);
    }

    private static Map<Id, Id> getAccountIdByContactId(Set<Id> contactIds) {
        Map<Id, Id> accountIdByContactId = new Map<Id, Id>();
        if (contactIds.isEmpty()) {
            return accountIdByContactId;
        }
        for (Contact contactRecord : [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id IN :contactIds
        ]) {
            accountIdByContactId.put(contactRecord.Id, contactRecord.AccountId);
        }
        return accountIdByContactId;
    }

    private static Map<Id, Id> getAccountIdByOpportunityId(Set<Id> opportunityIds) {
        Map<Id, Id> accountIdByOpportunityId = new Map<Id, Id>();
        if (opportunityIds.isEmpty()) {
            return accountIdByOpportunityId;
        }
        for (Opportunity opportunityRecord : [
            SELECT Id, AccountId
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ]) {
            accountIdByOpportunityId.put(opportunityRecord.Id, opportunityRecord.AccountId);
        }
        return accountIdByOpportunityId;
    }

    private class RouteContext {
        Map<Id, Transaction__c> transactionsById;
        Map<Id, List<Transaction__c>> activeTransactionsByAccountId;

        RouteContext(Map<Id, Transaction__c> transactionsById, Map<Id, List<Transaction__c>> activeTransactionsByAccountId) {
            this.transactionsById = transactionsById;
            this.activeTransactionsByAccountId = activeTransactionsByAccountId;
        }
    }
}