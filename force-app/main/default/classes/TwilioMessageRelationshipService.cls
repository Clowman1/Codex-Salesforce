/**
 * Relates TwilioSF__Message__c rows to Account / Transaction for record-page SMS (TwilioSF:TwoWayMessages).
 * DML only here. SOQL via LeadRepository + RingCentralLeadPriorityMatcher.
 */
public without sharing class TwilioMessageRelationshipService {

    private static Id cachedAutomatedProcessUserId;

    /** Test-only override so reassignOutboundOwnerByMessageIds can be exercised without real Automated Process ownership. */
    @TestVisible
    private static Id automatedProcessOverrideForTest;

    public static Id getAutomatedProcessUserId() {
        if (Test.isRunningTest() && automatedProcessOverrideForTest != null) {
            return automatedProcessOverrideForTest;
        }
        if (cachedAutomatedProcessUserId != null) {
            return cachedAutomatedProcessUserId;
        }
        List<User> rows = [
            SELECT Id
            FROM User
            WHERE Name = 'Automated Process'
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            cachedAutomatedProcessUserId = rows[0].Id;
        }
        return cachedAutomatedProcessUserId;
    }

    /**
     * Stamps TwilioSF__Account__c / TwilioSF__Contact__c / TwilioSF__SF_Parent_Record_Id__c when resolvable.
     */
    public static void relateByMessageIds(Set<Id> messageIds) {
        if (messageIds == null || messageIds.isEmpty()) {
            return;
        }

        List<TwilioSF__Message__c> rows = queryMessages(messageIds);
        if (rows.isEmpty()) {
            return;
        }
        Map<Id, TwilioSF__Message__c> originals = new Map<Id, TwilioSF__Message__c>();
        for (TwilioSF__Message__c row : rows) {
            originals.put(row.Id, row.clone(true, true, false, false));
        }

        Set<Id> leadIds = new Set<Id>();
        for (TwilioSF__Message__c row : rows) {
            if (row.TwilioSF__Lead__c != null) {
                leadIds.add(row.TwilioSF__Lead__c);
            }
        }
        Map<Id, Lead> convertedByLeadId = leadIds.isEmpty()
            ? new Map<Id, Lead>()
            : LeadRepository.getInstance().selectConvertedByIds(leadIds);

        Set<String> phonesForMatch = new Set<String>();
        for (TwilioSF__Message__c row : rows) {
            collectPhoneForMatch(row, phonesForMatch);
        }
        Map<String, Id> contactIdsByPhone = RingCentralLeadPriorityMatcher.getContactIdsByPhoneNumbers(phonesForMatch);
        Map<Id, Id> accountIdsByContactId = RingCentralLeadPriorityMatcher.getAccountIdsByContactIds(
            new Set<Id>(contactIdsByPhone.values())
        );
        Map<Id, Id> transactionByAccountFromPhone = RingCentralLeadPriorityMatcher.getMostRecentActiveTransactionByAccountIds(
            new Set<Id>(accountIdsByContactId.values())
        );

        Set<Id> accountIdsForTxn = new Set<Id>();
        for (TwilioSF__Message__c row : rows) {
            Lead conv = row.TwilioSF__Lead__c != null ? convertedByLeadId.get(row.TwilioSF__Lead__c) : null;
            if (conv != null) {
                if (row.TwilioSF__Account__c == null && conv.ConvertedAccountId != null) {
                    row.TwilioSF__Account__c = conv.ConvertedAccountId;
                }
                if (row.TwilioSF__Contact__c == null && conv.ConvertedContactId != null) {
                    row.TwilioSF__Contact__c = conv.ConvertedContactId;
                }
            }
            if (row.TwilioSF__Account__c != null) {
                accountIdsForTxn.add(row.TwilioSF__Account__c);
            }
        }

        Map<Id, Id> transactionByAccountId = RingCentralLeadPriorityMatcher.getMostRecentActiveTransactionByAccountIds(
            accountIdsForTxn
        );

        for (TwilioSF__Message__c row : rows) {
            Id accountId = row.TwilioSF__Account__c;
            Id contactId = row.TwilioSF__Contact__c;
            String parentStr = row.TwilioSF__SF_Parent_Record_Id__c;

            Id resolvedTransactionId = accountId != null ? transactionByAccountId.get(accountId) : null;

            if (resolvedTransactionId == null) {
                String clientPhone = resolveClientPhone(row);
                if (!String.isBlank(clientPhone)) {
                    String norm = RingCentralLeadPriorityMatcher.normalizePhoneNumber(clientPhone);
                    Id cId = contactIdsByPhone.get(norm);
                    Id accFromContact = cId != null ? accountIdsByContactId.get(cId) : null;
                    if (accountId == null && accFromContact != null) {
                        row.TwilioSF__Account__c = accFromContact;
                        accountId = accFromContact;
                    }
                    if (contactId == null && cId != null) {
                        row.TwilioSF__Contact__c = cId;
                    }
                    resolvedTransactionId = accFromContact != null
                        ? transactionByAccountFromPhone.get(accFromContact)
                        : null;
                }
            }

            Boolean parentIsLead = !String.isBlank(parentStr) && parentStr.length() >= 3 && parentStr.startsWith('00Q');
            Boolean parentBlank = String.isBlank(parentStr);
            if (resolvedTransactionId != null && (parentBlank || parentIsLead)) {
                row.TwilioSF__SF_Parent_Record_Id__c = String.valueOf(resolvedTransactionId);
            }
        }

        List<TwilioSF__Message__c> toSave = new List<TwilioSF__Message__c>();
        for (TwilioSF__Message__c row : rows) {
            TwilioSF__Message__c orig = originals.get(row.Id);
            if (orig == null) {
                continue;
            }
            if (row.TwilioSF__Account__c != orig.TwilioSF__Account__c
                || row.TwilioSF__Contact__c != orig.TwilioSF__Contact__c
                || row.TwilioSF__SF_Parent_Record_Id__c != orig.TwilioSF__SF_Parent_Record_Id__c) {
                toSave.add(row);
            }
        }
        if (!toSave.isEmpty()) {
            update toSave;
        }
    }

    /**
     * Outbound-api messages owned by Automated Process: set Owner to Transaction.LastModifiedById.
     */
    public static void reassignOutboundOwnerByMessageIds(Set<Id> messageIds) {
        if (messageIds == null || messageIds.isEmpty()) {
            return;
        }
        Id autoProc = getAutomatedProcessUserId();
        if (autoProc == null) {
            return;
        }

        List<TwilioSF__Message__c> rows = [
            SELECT Id, OwnerId, TwilioSF__Direction__c, TwilioSF__SF_Parent_Record_Id__c
            FROM TwilioSF__Message__c
            WHERE Id IN :messageIds
            AND TwilioSF__Direction__c = 'outbound-api'
            AND OwnerId = :autoProc
            AND TwilioSF__SF_Parent_Record_Id__c != null
        ];
        if (rows.isEmpty()) {
            return;
        }

        Set<Id> txnIds = new Set<Id>();
        for (TwilioSF__Message__c row : rows) {
            String p = row.TwilioSF__SF_Parent_Record_Id__c;
            if (!String.isBlank(p) && isLikelyTransactionId(p)) {
                try {
                    txnIds.add((Id) p);
                } catch (Exception ignore) {
                }
            }
        }
        if (txnIds.isEmpty()) {
            return;
        }

        Map<Id, Transaction__c> txns = new Map<Id, Transaction__c>(
            [SELECT Id, LastModifiedById FROM Transaction__c WHERE Id IN :txnIds]
        );

        List<TwilioSF__Message__c> updates = new List<TwilioSF__Message__c>();
        for (TwilioSF__Message__c row : rows) {
            String p = row.TwilioSF__SF_Parent_Record_Id__c;
            if (String.isBlank(p)) {
                continue;
            }
            Transaction__c t = txns.get(p);
            if (t == null || t.LastModifiedById == null) {
                continue;
            }
            if (row.OwnerId != t.LastModifiedById) {
                row.OwnerId = t.LastModifiedById;
                updates.add(row);
            }
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static Boolean isLikelyTransactionId(String value) {
        if (String.isBlank(value) || value.length() < 3) {
            return false;
        }
        String keyPrefix = Transaction__c.SObjectType.getDescribe().getKeyPrefix();
        return value.startsWith(keyPrefix);
    }

    private static List<TwilioSF__Message__c> queryMessages(Set<Id> messageIds) {
        return [
            SELECT
                Id,
                TwilioSF__Lead__c,
                TwilioSF__Account__c,
                TwilioSF__Contact__c,
                TwilioSF__SF_Parent_Record_Id__c,
                TwilioSF__Direction__c,
                TwilioSF__From_Number_Unformatted__c,
                TwilioSF__To_Number_Unformatted__c
            FROM TwilioSF__Message__c
            WHERE Id IN :messageIds
        ];
    }

    private static void collectPhoneForMatch(TwilioSF__Message__c row, Set<String> phones) {
        String client = resolveClientPhone(row);
        if (!String.isBlank(client)) {
            phones.add(client);
        }
    }

    @TestVisible
    private static String resolveClientPhone(TwilioSF__Message__c row) {
        String direction = row.TwilioSF__Direction__c;
        String fromNum = row.TwilioSF__From_Number_Unformatted__c;
        String toNum = row.TwilioSF__To_Number_Unformatted__c;

        if (direction == 'inbound') {
            return fromNum;
        }
        if (direction == 'outbound-api' || direction == 'outbound-reply' || direction == 'outbound-call') {
            return toNum;
        }
        return fromNum != null ? fromNum : toNum;
    }
}