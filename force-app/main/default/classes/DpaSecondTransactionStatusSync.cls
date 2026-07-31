public with sharing class DpaSecondTransactionStatusSync {
    private static Boolean isSyncing = false;
    private static Boolean finalSyncQueued = false;

    public static void syncCurrentStatusesByFirstId(Map<Id, Id> secondIdByFirstId) {
        if (isSyncing || secondIdByFirstId == null || secondIdByFirstId.isEmpty()) {
            return;
        }

        Map<Id, Transaction__c> secondsToUpdateById = new Map<Id, Transaction__c>();
        for (Transaction__c firstTransaction : [
            SELECT
                Id,
                Status__c,
                Property_Address__c,
                Property_City__c,
                Property_State__c,
                Property_Postal_Code__c,
                Property_Unit__c,
                Property_Type__c,
                Purchase_Date__c,
                Appraisal__c,
                Appraised_Value__c,
                Purchase_Price__c,
                Processor__c,
                Closing_Date__c,
                Funding_Date__c,
                Disclosures_Out_Date__c,
                Disclosures_Received_Date__c,
                Rate_Lock_Status__c,
                Rate_Lock_Exp_Date__c,
                Occupancy__c,
                Submission_Form_Date__c
            FROM Transaction__c
            WHERE Id IN :secondIdByFirstId.keySet()
        ]) {
            Id secondId = secondIdByFirstId.get(firstTransaction.Id);
            if (secondId == null) {
                continue;
            }

            secondsToUpdateById.put(
                secondId,
                buildSecondSyncUpdate(secondId, firstTransaction)
            );
        }

        updateSeconds(secondsToUpdateById);
    }

    public static void syncAfterUpdate(List<Transaction__c> newRecords, Map<Id, Transaction__c> oldRecordsById) {
        if (isSyncing || newRecords == null || oldRecordsById == null) {
            return;
        }

        Set<Id> firstIdsForFinalSync = new Set<Id>();
        Map<Id, Transaction__c> secondsToUpdateById = new Map<Id, Transaction__c>();
        for (Transaction__c transactionRecord : newRecords) {
            Transaction__c oldRecord = oldRecordsById.get(transactionRecord.Id);
            firstIdsForFinalSync.add(transactionRecord.Id);
            Boolean isLinkedFirst =
                oldRecord != null &&
                transactionRecord.Second_Mortgage__c != null &&
                String.valueOf(transactionRecord.Lien_Position__c) != '2nd';

            if (isLinkedFirst) {
                firstIdsForFinalSync.add(transactionRecord.Id);
            }

            if (!isLinkedFirst || transactionRecord.Status__c == oldRecord.Status__c) {
                continue;
            }

            secondsToUpdateById.put(
                transactionRecord.Second_Mortgage__c,
                buildSecondSyncUpdate(transactionRecord.Second_Mortgage__c, transactionRecord)
            );
        }

        updateSeconds(secondsToUpdateById);
        enqueueFinalSync(firstIdsForFinalSync);
    }

    private static void enqueueFinalSync(Set<Id> firstIds) {
        if (finalSyncQueued || firstIds == null || firstIds.isEmpty()) {
            return;
        }

        finalSyncQueued = true;
        System.enqueueJob(new FinalStatusSyncJob(firstIds));
    }

    private static void updateSeconds(Map<Id, Transaction__c> secondsToUpdateById) {
        if (secondsToUpdateById == null || secondsToUpdateById.isEmpty()) {
            return;
        }

        isSyncing = true;
        try {
            update secondsToUpdateById.values();
        } finally {
            isSyncing = false;
        }
    }

    public class FinalStatusSyncJob implements Queueable {
        private Set<Id> firstIds;

        public FinalStatusSyncJob(Set<Id> firstIds) {
            this.firstIds = firstIds == null ? new Set<Id>() : new Set<Id>(firstIds);
        }

        public void execute(QueueableContext context) {
            if (firstIds.isEmpty()) {
                return;
            }

            Map<Id, Transaction__c> secondsToUpdateById = new Map<Id, Transaction__c>();
            for (Transaction__c firstTransaction : [
                SELECT
                    Id,
                    Status__c,
                    Second_Mortgage__c,
                    Property_Address__c,
                    Property_City__c,
                    Property_State__c,
                    Property_Postal_Code__c,
                    Property_Unit__c,
                    Property_Type__c,
                    Purchase_Date__c,
                    Appraisal__c,
                    Appraised_Value__c,
                    Purchase_Price__c,
                    Processor__c,
                    Closing_Date__c,
                    Funding_Date__c,
                    Disclosures_Out_Date__c,
                    Disclosures_Received_Date__c,
                    Rate_Lock_Status__c,
                    Rate_Lock_Exp_Date__c,
                    Occupancy__c,
                    Submission_Form_Date__c
                FROM Transaction__c
                WHERE Id IN :firstIds
                AND Second_Mortgage__c != null
            ]) {
                secondsToUpdateById.put(
                    firstTransaction.Second_Mortgage__c,
                    buildSecondSyncUpdate(firstTransaction.Second_Mortgage__c, firstTransaction)
                );
            }

            updateSeconds(secondsToUpdateById);
        }
    }

    private static Transaction__c buildSecondSyncUpdate(Id secondId, Transaction__c firstTransaction) {
        return new Transaction__c(
            Id = secondId,
            Status__c = firstTransaction.Status__c,
            Property_Address__c = firstTransaction.Property_Address__c,
            Property_City__c = firstTransaction.Property_City__c,
            Property_State__c = firstTransaction.Property_State__c,
            Property_Postal_Code__c = firstTransaction.Property_Postal_Code__c,
            Property_Unit__c = firstTransaction.Property_Unit__c,
            Property_Type__c = firstTransaction.Property_Type__c,
            Purchase_Date__c = firstTransaction.Purchase_Date__c,
            Appraisal__c = firstTransaction.Appraisal__c,
            Appraised_Value__c = firstTransaction.Appraised_Value__c,
            Purchase_Price__c = firstTransaction.Purchase_Price__c,
            Processor__c = firstTransaction.Processor__c,
            Closing_Date__c = firstTransaction.Closing_Date__c,
            Funding_Date__c = firstTransaction.Funding_Date__c,
            Disclosures_Out_Date__c = firstTransaction.Disclosures_Out_Date__c,
            Disclosures_Received_Date__c = firstTransaction.Disclosures_Received_Date__c,
            Rate_Lock_Status__c = firstTransaction.Rate_Lock_Status__c,
            Rate_Lock_Exp_Date__c = firstTransaction.Rate_Lock_Exp_Date__c,
            Occupancy__c = firstTransaction.Occupancy__c,
            Submission_Form_Date__c = firstTransaction.Submission_Form_Date__c
        );
    }
}