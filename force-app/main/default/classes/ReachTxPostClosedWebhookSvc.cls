public with sharing class ReachTxPostClosedWebhookSvc {
    private static final String BIZ_DEV_REACH = 'Biz Dev - Reach';
    private static final String POST_CLOSED_STATUS = 'Post-Closed';
    private static final String EVENT_TYPE = 'TransactionStatusChanged';
    private static final String WEBHOOK_ENDPOINT =
        'https://hooks.zapier.com/hooks/catch/24167621/4u772qa/';

    @TestVisible private static String endpointOverride;
    @TestVisible private static Integer enqueuedJobCount = 0;

    public static void enqueueForStatusChanges(
        List<Transaction__c> newTransactions,
        Map<Id, Transaction__c> oldTransactionMap
    ) {
        if (newTransactions == null || oldTransactionMap == null) {
            return;
        }

        List<StatusChange> changes = new List<StatusChange>();
        for (Transaction__c newTransaction : newTransactions) {
            Transaction__c oldTransaction = oldTransactionMap.get(newTransaction.Id);
            if (oldTransaction == null
                || newTransaction.Biz_Dev__c != BIZ_DEV_REACH
                || newTransaction.Status__c != POST_CLOSED_STATUS
                || oldTransaction.Status__c == POST_CLOSED_STATUS) {
                continue;
            }

            changes.add(new StatusChange(
                newTransaction.Id,
                oldTransaction.Status__c,
                newTransaction.Status__c
            ));
        }

        if (!changes.isEmpty()) {
            enqueuedJobCount++;
            System.enqueueJob(new WebhookJob(changes));
        }
    }

    public class StatusChange {
        public Id transactionId;
        public String oldStatus;
        public String newStatus;

        public StatusChange(Id transactionId, String oldStatus, String newStatus) {
            this.transactionId = transactionId;
            this.oldStatus = oldStatus;
            this.newStatus = newStatus;
        }
    }

    public class WebhookJob implements Queueable, Database.AllowsCallouts {
        private List<StatusChange> changes;

        public WebhookJob(List<StatusChange> changes) {
            this.changes = changes == null ? new List<StatusChange>() : changes;
        }

        public void execute(QueueableContext context) {
            Map<Id, StatusChange> changesByTransactionId = new Map<Id, StatusChange>();
            for (StatusChange change : changes) {
                if (change != null && change.transactionId != null) {
                    changesByTransactionId.put(change.transactionId, change);
                }
            }
            if (changesByTransactionId.isEmpty()) {
                return;
            }

            Http http = new Http();
            for (Transaction__c transactionRecord : [
                SELECT Id, Name, Biz_Dev__c, Status__c, Loan_Number__c,
                    Borrower_First_Name__c, Borrower_Last_Name__c, Borrower_Name__c,
                    Account__c, Funding_Date__c, Post_Closed_Date__c,
                    OwnerId, Owner.Name, LastModifiedDate
                FROM Transaction__c
                WHERE Id IN :changesByTransactionId.keySet()
                    AND Biz_Dev__c = :BIZ_DEV_REACH
                    AND Status__c = :POST_CLOSED_STATUS
            ]) {
                HttpRequest request = new HttpRequest();
                request.setEndpoint(getEndpoint());
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setTimeout(10000);
                request.setBody(JSON.serialize(
                    buildPayload(transactionRecord, changesByTransactionId.get(transactionRecord.Id))
                ));

                try {
                    HttpResponse response = http.send(request);
                    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                        throw new WebhookException(
                            'Biz Dev - Reach Post-Closed Transaction webhook failed for Transaction '
                            + transactionRecord.Id + ': ' + response.getStatusCode() + ' ' + response.getBody()
                        );
                    }
                } catch (Exception caughtException) {
                    throw new WebhookException(
                        'Biz Dev - Reach Post-Closed Transaction webhook exception for Transaction '
                        + transactionRecord.Id + ': ' + caughtException.getMessage()
                    );
                }
            }
        }
    }

    public class WebhookException extends Exception {}

    private static String getEndpoint() {
        return String.isBlank(endpointOverride) ? WEBHOOK_ENDPOINT : endpointOverride;
    }

    private static Map<String, Object> buildPayload(
        Transaction__c transactionRecord,
        StatusChange change
    ) {
        Map<String, Object> transactionFields = buildTransactionFields(transactionRecord.Id);
        return new Map<String, Object>{
            'eventType' => EVENT_TYPE,
            'changedAt' => formatDateTime(System.now()),
            'transactionFields' => transactionFields,
            'transactionFieldCount' => transactionFields.size(),
            'transactionId' => String.valueOf(transactionRecord.Id),
            'transactionName' => transactionRecord.Name,
            'loanNumber' => transactionRecord.Loan_Number__c,
            'bizDev' => transactionRecord.Biz_Dev__c,
            'oldStatus' => change == null ? null : change.oldStatus,
            'newStatus' => change == null ? transactionRecord.Status__c : change.newStatus,
            'borrowerFirstName' => transactionRecord.Borrower_First_Name__c,
            'borrowerLastName' => transactionRecord.Borrower_Last_Name__c,
            'borrowerAccountId' => String.valueOf(transactionRecord.Borrower_Name__c),
            'accountId' => String.valueOf(transactionRecord.Account__c),
            'ownerId' => String.valueOf(transactionRecord.OwnerId),
            'ownerName' => transactionRecord.Owner == null ? null : transactionRecord.Owner.Name,
            'fundingDate' => transactionRecord.Funding_Date__c,
            'postClosedDate' => transactionRecord.Post_Closed_Date__c,
            'salesforceLastModifiedAt' => formatDateTime(transactionRecord.LastModifiedDate)
        };
    }

    private static Map<String, Object> buildTransactionFields(Id transactionId) {
        Map<String, Object> valuesByFieldApiName = new Map<String, Object>();
        Map<String, Schema.SObjectField> fieldsByApiName =
            Transaction__c.SObjectType.getDescribe().fields.getMap();
        List<String> sortedFieldApiNames = new List<String>();
        for (Schema.SObjectField fieldToken : fieldsByApiName.values()) {
            sortedFieldApiNames.add(fieldToken.getDescribe().getName());
        }
        sortedFieldApiNames.sort();

        List<String> currentChunk = new List<String>();
        Integer currentLength = 0;
        for (String fieldApiName : sortedFieldApiNames) {
            Integer additionalLength = fieldApiName.length() + 2;
            if (!currentChunk.isEmpty() && currentLength + additionalLength > 12000) {
                addQueriedFieldValues(valuesByFieldApiName, transactionId, currentChunk);
                currentChunk.clear();
                currentLength = 0;
            }
            currentChunk.add(fieldApiName);
            currentLength += additionalLength;
        }
        if (!currentChunk.isEmpty()) {
            addQueriedFieldValues(valuesByFieldApiName, transactionId, currentChunk);
        }
        return valuesByFieldApiName;
    }

    private static void addQueriedFieldValues(
        Map<String, Object> valuesByFieldApiName,
        Id transactionId,
        List<String> fieldApiNames
    ) {
        if (fieldApiNames == null || fieldApiNames.isEmpty()) {
            return;
        }

        try {
            Transaction__c queriedTransaction = Database.query(
                'SELECT ' + String.join(fieldApiNames, ',') +
                ' FROM Transaction__c WHERE Id = :transactionId LIMIT 1'
            );
            for (String fieldApiName : fieldApiNames) {
                Object normalizedValue = normalizeFieldValue(queriedTransaction.get(fieldApiName));
                if (hasPayloadValue(normalizedValue)) {
                    valuesByFieldApiName.put(fieldApiName, normalizedValue);
                }
            }
        } catch (Exception chunkException) {
            if (fieldApiNames.size() == 1) {
                return;
            }

            Integer midpoint = fieldApiNames.size() / 2;
            addQueriedFieldValues(
                valuesByFieldApiName,
                transactionId,
                copyFieldRange(fieldApiNames, 0, midpoint)
            );
            addQueriedFieldValues(
                valuesByFieldApiName,
                transactionId,
                copyFieldRange(fieldApiNames, midpoint, fieldApiNames.size())
            );
        }
    }

    private static List<String> copyFieldRange(List<String> fieldApiNames, Integer startIndex, Integer endIndex) {
        List<String> copiedValues = new List<String>();
        for (Integer index = startIndex; index < endIndex; index++) {
            copiedValues.add(fieldApiNames[index]);
        }
        return copiedValues;
    }

    private static Object normalizeFieldValue(Object value) {
        if (value instanceof Datetime) {
            return formatDateTime((Datetime) value);
        }
        if (value instanceof Date) {
            return String.valueOf((Date) value);
        }
        if (value instanceof Time) {
            return String.valueOf((Time) value);
        }
        if (value instanceof Id) {
            return String.valueOf((Id) value);
        }
        return value;
    }

    private static Boolean hasPayloadValue(Object value) {
        if (value == null) {
            return false;
        }
        if (value instanceof String) {
            return !String.isBlank((String) value);
        }
        return true;
    }

    private static String formatDateTime(Datetime value) {
        return value == null ? null : value.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
}
