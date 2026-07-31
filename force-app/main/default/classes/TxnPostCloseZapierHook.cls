public without sharing class TxnPostCloseZapierHook {
    private static final String WEBHOOK_ENDPOINT = 'https://hooks.zapier.com/hooks/catch/449994/4o71r3y/';
    private static final String POST_CLOSED_STATUS = 'Post-Closed';
    private static final String PURCHASE_LOAN_PURPOSE = 'Purchase';
    private static final String REACH_BIZ_DEV = 'Biz Dev - Reach';
    private static final List<String> TXN_FIELD_NAMES = buildTxnFieldNames();

    @InvocableMethod(label='Send Post Closed Zapier Webhook')
    public static void send(List<Request> requests) {
        Set<Id> transactionIds = new Set<Id>();
        for (Request requestItem : requests) {
            if (requestItem != null && requestItem.transactionId != null) {
                transactionIds.add(requestItem.transactionId);
            }
        }

        if (!transactionIds.isEmpty()) {
            System.enqueueJob(new TxnPostCloseZapierQueueable(new List<Id>(transactionIds)));
        }
    }

    public class Request {
        @InvocableVariable(required=true)
        public Id transactionId;
    }

    public class TxnPostCloseZapierQueueable implements Queueable, Database.AllowsCallouts {
        private final List<Id> transactionIds;

        public TxnPostCloseZapierQueueable(List<Id> transactionIds) {
            this.transactionIds = transactionIds;
        }

        public void execute(QueueableContext context) {
            List<Transaction__c> transactions = Database.query(
                'SELECT ' + String.join(TXN_FIELD_NAMES, ',') + ' FROM Transaction__c ' +
                'WHERE Id IN :transactionIds ' +
                'AND Status__c = :POST_CLOSED_STATUS ' +
                'AND Biz_Dev__c = :REACH_BIZ_DEV ' +
                'AND Loan_Purpose__c = :PURCHASE_LOAN_PURPOSE ' +
                'AND Zapier_Post_Closed_Webhook_Sent_At__c = NULL'
            );

            if (transactions.isEmpty()) {
                return;
            }

            Http http = new Http();
            List<Transaction__c> transactionsToUpdate = new List<Transaction__c>();

            for (Transaction__c transactionRecord : transactions) {
                HttpRequest request = new HttpRequest();
                request.setEndpoint(WEBHOOK_ENDPOINT);
                request.setMethod('POST');
                request.setHeader('Content-Type', 'application/json');
                request.setBody(JSON.serialize(buildPayload(transactionRecord)));

                try {
                    HttpResponse response = http.send(request);
                    if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                        transactionsToUpdate.add(new Transaction__c(
                            Id = transactionRecord.Id,
                            Zapier_Post_Closed_Webhook_Sent_At__c = System.now()
                        ));
                    } else {
                        System.debug(LoggingLevel.ERROR,
                            'Zapier webhook failed for Transaction ' + transactionRecord.Id +
                            ' with status code ' + response.getStatusCode() +
                            ' and response ' + response.getBody());
                    }
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR,
                        'Zapier webhook exception for Transaction ' + transactionRecord.Id + ': ' + ex.getMessage());
                }
            }

            if (!transactionsToUpdate.isEmpty()) {
                update transactionsToUpdate;
            }
        }
    }

    private static Map<String, Object> buildPayload(Transaction__c transactionRecord) {
        Map<String, Object> transactionData = new Map<String, Object>();
        for (String fieldName : TXN_FIELD_NAMES) {
            transactionData.put(fieldName, transactionRecord.get(fieldName));
        }

        return new Map<String, Object>{
            'transactionId' => transactionRecord.Id,
            'transaction' => transactionData
        };
    }

    private static List<String> buildTxnFieldNames() {
        List<String> fieldNames = new List<String>(Transaction__c.SObjectType.getDescribe().fields.getMap().keySet());
        fieldNames.sort();
        return fieldNames;
    }
}