public without sharing class TransactionUtmCopyService {
    private static Boolean isRunning = false;

    public static void copyFromConvertedLeads(List<Transaction__c> newRecords) {
        copyFromConvertedLeads(newRecords, null);
    }

    public static void copyFromConvertedLeads(List<Transaction__c> newRecords, Map<Id, Transaction__c> oldMap) {
        if (isRunning || newRecords == null || newRecords.isEmpty()) {
            return;
        }

        Set<Id> transactionIds = new Set<Id>();
        Set<Id> borrowerAccountIds = new Set<Id>();
        for (Transaction__c transactionRecord : newRecords) {
            transactionIds.add(transactionRecord.Id);
            if (transactionRecord.Borrower_Name__c != null) {
                borrowerAccountIds.add(transactionRecord.Borrower_Name__c);
            }
            if (transactionRecord.Account__c != null) {
                borrowerAccountIds.add(transactionRecord.Account__c);
            }
        }

        if (transactionIds.isEmpty() && borrowerAccountIds.isEmpty()) {
            return;
        }

        Map<Id, Lead> leadByTransactionId = new Map<Id, Lead>();
        Map<Id, Lead> leadByAccountId = new Map<Id, Lead>();

        for (Lead leadRecord : [
            SELECT Id, Converted_Transaction_ID__c, ConvertedAccountId, ConvertedDate,
                First_UTM_Campaign__c, First_UTM_Content__c, First_UTM_Medium__c,
                First_UTM_Source__c, First_UTM_Term__c, Last_UTM_Campaign__c,
                Last_UTM_Content__c, Last_UTM_Medium__c, Last_UTM_Source__c,
                Last_UTM_Term__c, Meta_Campaign_ID__c, Meta_Adset_ID__c,
                Meta_Ad_ID__c, Hyros_Ad_ID__c, FB_Click_ID__c, Source_URL__c,
                Form_Name__c, Landing_Page__c, Referrer__c, Loan_Partner__c
            FROM Lead
            WHERE IsConverted = true
            AND (
                Converted_Transaction_ID__c IN :transactionIds
                OR ConvertedAccountId IN :borrowerAccountIds
            )
            ORDER BY ConvertedDate DESC, LastModifiedDate DESC
        ]) {
            if (
                leadRecord.Converted_Transaction_ID__c != null &&
                transactionIds.contains(leadRecord.Converted_Transaction_ID__c) &&
                !leadByTransactionId.containsKey(leadRecord.Converted_Transaction_ID__c)
            ) {
                leadByTransactionId.put(leadRecord.Converted_Transaction_ID__c, leadRecord);
            }
            if (
                leadRecord.ConvertedAccountId != null &&
                borrowerAccountIds.contains(leadRecord.ConvertedAccountId) &&
                !leadByAccountId.containsKey(leadRecord.ConvertedAccountId)
            ) {
                leadByAccountId.put(leadRecord.ConvertedAccountId, leadRecord);
            }
        }

        List<Transaction__c> updates = new List<Transaction__c>();
        for (Transaction__c transactionRecord : newRecords) {
            Lead sourceLead = leadByTransactionId.get(transactionRecord.Id);
            if (sourceLead == null && transactionRecord.Borrower_Name__c != null) {
                sourceLead = leadByAccountId.get(transactionRecord.Borrower_Name__c);
            }
            if (sourceLead == null && transactionRecord.Account__c != null) {
                sourceLead = leadByAccountId.get(transactionRecord.Account__c);
            }
            if (sourceLead == null) {
                continue;
            }

            Transaction__c updateRecord = new Transaction__c(Id = transactionRecord.Id);
            Boolean hasChanges = copyBlankUtmFields(updateRecord, transactionRecord, sourceLead);
            hasChanges = copyLeadLoanPartner(updateRecord, transactionRecord, sourceLead, oldMap) || hasChanges;
            if (hasChanges) {
                updates.add(updateRecord);
            }
        }

        if (!updates.isEmpty()) {
            isRunning = true;
            try {
                update updates;
            } finally {
                isRunning = false;
            }
        }
    }

    @TestVisible
    private static Boolean copyBlankUtmFields(Transaction__c target, Transaction__c existing, Lead source) {
        Boolean changed = false;
        changed = setIfBlank(target, existing, source, 'First_UTM_Campaign__c') || changed;
        changed = setIfBlank(target, existing, source, 'First_UTM_Content__c') || changed;
        changed = setIfBlank(target, existing, source, 'First_UTM_Medium__c') || changed;
        changed = setIfBlank(target, existing, source, 'First_UTM_Source__c') || changed;
        changed = setIfBlank(target, existing, source, 'First_UTM_Term__c') || changed;
        changed = setIfBlank(target, existing, source, 'Last_UTM_Campaign__c') || changed;
        changed = setIfBlank(target, existing, source, 'Last_UTM_Content__c') || changed;
        changed = setIfBlank(target, existing, source, 'Last_UTM_Medium__c') || changed;
        changed = setIfBlank(target, existing, source, 'Last_UTM_Source__c') || changed;
        changed = setIfBlank(target, existing, source, 'Last_UTM_Term__c') || changed;
        changed = setIfBlank(target, existing, source, 'Meta_Campaign_ID__c') || changed;
        changed = setIfBlank(target, existing, source, 'Meta_Adset_ID__c') || changed;
        changed = setIfBlank(target, existing, source, 'Meta_Ad_ID__c') || changed;
        changed = setIfBlank(target, existing, source, 'Hyros_Ad_ID__c') || changed;
        changed = setIfBlank(target, existing, source, 'FB_Click_ID__c') || changed;
        changed = setIfBlank(target, existing, source, 'Source_URL__c') || changed;
        changed = setIfBlank(target, existing, source, 'Form_Name__c') || changed;
        changed = setIfBlank(target, existing, source, 'Landing_Page__c') || changed;
        changed = setIfBlank(target, existing, source, 'Referrer__c') || changed;
        return changed;
    }

    @TestVisible
    private static Boolean copyLeadLoanPartner(
        Transaction__c target,
        Transaction__c existing,
        Lead source,
        Map<Id, Transaction__c> oldMap
    ) {
        if (source == null || source.Loan_Partner__c == null || existing == null) {
            return false;
        }

        Boolean isInsertContext = oldMap == null || !oldMap.containsKey(existing.Id);
        Boolean isBlankUpdate = !isInsertContext && existing.Loan_Partner__c == null;
        if (!isInsertContext && !isBlankUpdate) {
            return false;
        }

        if (existing.Loan_Partner__c == source.Loan_Partner__c) {
            return false;
        }

        target.Loan_Partner__c = source.Loan_Partner__c;
        return true;
    }

    private static Boolean setIfBlank(SObject target, SObject existing, SObject source, String fieldName) {
        Object sourceValue = source.get(fieldName);
        if (sourceValue == null || existing.get(fieldName) != null) {
            return false;
        }

        if (sourceValue instanceof String && String.isBlank((String) sourceValue)) {
            return false;
        }

        target.put(fieldName, sourceValue);
        return true;
    }
}