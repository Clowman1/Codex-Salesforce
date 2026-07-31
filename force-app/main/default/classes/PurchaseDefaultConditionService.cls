public without sharing class PurchaseDefaultConditionService {
    private static final String PURCHASE = 'Purchase';
    private static final String STATUS_NEW = 'New';
    private static final String TYPE_PROCESSOR = 'Processor';
    private static final String ESCROW_DEPOSIT = 'Escrow Deposit';
    private static final String HOMEOWNERS_INSURANCE = 'Homeowner\'s Insurance';
    private static final Set<String> DEFAULT_CONDITION_NAMES = new Set<String>{ ESCROW_DEPOSIT, HOMEOWNERS_INSURANCE };

    private static final Set<String> CONDITIONAL_APPROVAL_OR_LATER_STATUSES = new Set<String>{
        'Conditionally Approved',
        'Re-Submitted',
        'Approved',
        'Closing',
        'Funding',
        'PC Review',
        'Post-Closed',
        'Cancelled'
    };

    // Files no longer being worked. Nothing is created or re-assigned on these, so historical
    // assignees on closed/cancelled loans stay as they were.
    private static final Set<String> INACTIVE_STATUSES = new Set<String>{
        'Cancelled',
        'PC Review',
        'QC Review',
        'Post-Closed',
        'Lost'
    };

    public static void ensureForPurchaseTransactions(
        List<Transaction__c> newRecords,
        Map<Id, Transaction__c> oldRecordsById
    ) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        Map<Id, Transaction__c> eligibleTransactionsById = new Map<Id, Transaction__c>();
        for (Transaction__c transactionRecord : newRecords) {
            if (!shouldEvaluate(transactionRecord, oldRecordsById)) {
                continue;
            }
            eligibleTransactionsById.put(transactionRecord.Id, transactionRecord);
        }

        if (eligibleTransactionsById.isEmpty()) {
            return;
        }

        Map<Id, Map<String, Condition__c>> existingDefaultsByTransactionId = getExistingDefaultsByTransactionId(eligibleTransactionsById.keySet());
        List<Condition__c> conditionsToCreate = new List<Condition__c>();
        List<Condition__c> conditionsToUpdate = new List<Condition__c>();

        for (Transaction__c transactionRecord : eligibleTransactionsById.values()) {
            if (transactionRecord.Processor__c == null) {
                continue;
            }

            Map<String, Condition__c> existingDefaults = existingDefaultsByTransactionId.get(transactionRecord.Id);
            if (existingDefaults == null) {
                existingDefaults = new Map<String, Condition__c>();
            }

            Id assignedToId = transactionRecord.Processor__c;
            Boolean allowCreate = canCreateDefaults(transactionRecord);
            Boolean allowReassign = canReassignDefaults(transactionRecord);

            if (!existingDefaults.containsKey(ESCROW_DEPOSIT)) {
                if (allowCreate) {
                    conditionsToCreate.add(buildCondition(
                        transactionRecord.Id,
                        assignedToId,
                        ESCROW_DEPOSIT,
                        'Assets',
                        'Source of $ escrow deposit: Most recent bank statement and transaction history (if needed) for the account the funds came out of\n\n'
                        + 'PLEASE NOTE: Login from a computer and select the specific account. View the transactions and use the date filters to select the appropriate date range ([insert date] - today\'s date), then apply the filter to view selected range. Finally, you will save as PDF via the Print function by pressing Ctrl + P (on Windows) or Cmd + P (on Mac). In the print window, change the destination to "Save as PDF." Click Save and choose where to save the file on your computer.'
                    ));
                }
            } else if (allowReassign && existingDefaults.get(ESCROW_DEPOSIT).Assigned_To__c != assignedToId) {
                conditionsToUpdate.add(new Condition__c(
                    Id = existingDefaults.get(ESCROW_DEPOSIT).Id,
                    Assigned_To__c = assignedToId
                ));
            }

            if (!existingDefaults.containsKey(HOMEOWNERS_INSURANCE)) {
                if (allowCreate) {
                    conditionsToCreate.add(buildCondition(
                        transactionRecord.Id,
                        assignedToId,
                        HOMEOWNERS_INSURANCE,
                        'HOI',
                        'INSURANCE:\n\n'
                        + 'Once you have chosen a quote to move forward with, please provide a copy of the quote you would like to move forward so I can work to finalize the policy for you.\n'
                        + 'We will want your insurance decision no later than DATE to stay on track for closing.'
                    ));
                }
            } else if (allowReassign && existingDefaults.get(HOMEOWNERS_INSURANCE).Assigned_To__c != assignedToId) {
                conditionsToUpdate.add(new Condition__c(
                    Id = existingDefaults.get(HOMEOWNERS_INSURANCE).Id,
                    Assigned_To__c = assignedToId
                ));
            }
        }

        if (!conditionsToCreate.isEmpty()) {
            Database.insert(conditionsToCreate, false);
        }
        if (!conditionsToUpdate.isEmpty()) {
            Database.update(conditionsToUpdate, false);
        }
    }

    private static Boolean shouldEvaluate(Transaction__c transactionRecord, Map<Id, Transaction__c> oldRecordsById) {
        if (transactionRecord == null || transactionRecord.Id == null) {
            return false;
        }
        if (transactionRecord.Loan_Purpose__c != PURCHASE) {
            return false;
        }

        return canCreateDefaults(transactionRecord) || canReassignDefaults(transactionRecord);
    }

    // Defaults are only seeded early in the file. Also blocked on inactive statuses so a Lost or
    // QC Review file never gets new conditions seeded onto it.
    private static Boolean canCreateDefaults(Transaction__c transactionRecord) {
        return !CONDITIONAL_APPROVAL_OR_LATER_STATUSES.contains(transactionRecord.Status__c)
            && !INACTIVE_STATUSES.contains(transactionRecord.Status__c);
    }

    // Re-assignment keeps running past Conditional Approval so that a Processor assigned or changed
    // late in the file still propagates to the default conditions. Inactive files are left alone.
    private static Boolean canReassignDefaults(Transaction__c transactionRecord) {
        return !INACTIVE_STATUSES.contains(transactionRecord.Status__c);
    }

    private static Map<Id, Map<String, Condition__c>> getExistingDefaultsByTransactionId(Set<Id> transactionIds) {
        Map<Id, Map<String, Condition__c>> existingDefaultsByTransactionId = new Map<Id, Map<String, Condition__c>>();
        for (Condition__c conditionRecord : [
            SELECT Id, Transaction__c, Name, Assigned_To__c
            FROM Condition__c
            WHERE Transaction__c IN :transactionIds
            AND Name IN :DEFAULT_CONDITION_NAMES
        ]) {
            if (!existingDefaultsByTransactionId.containsKey(conditionRecord.Transaction__c)) {
                existingDefaultsByTransactionId.put(conditionRecord.Transaction__c, new Map<String, Condition__c>());
            }
            existingDefaultsByTransactionId.get(conditionRecord.Transaction__c).put(conditionRecord.Name, conditionRecord);
        }
        return existingDefaultsByTransactionId;
    }

    private static Condition__c buildCondition(
        Id transactionId,
        Id assignedToId,
        String name,
        String category,
        String description
    ) {
        return new Condition__c(
            Transaction__c = transactionId,
            Assigned_To__c = assignedToId,
            Name = name,
            Category__c = category,
            Description__c = description,
            Status__c = STATUS_NEW,
            Type__c = TYPE_PROCESSOR,
            Can_Borrower_See__c = true,
            Include_In_Email__c = true,
            IncludeInEmail__c = true
        );
    }
}