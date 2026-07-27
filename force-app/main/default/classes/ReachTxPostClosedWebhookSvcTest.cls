@IsTest
private class ReachTxPostClosedWebhookSvcTest {
    private static Integer requestCount = 0;
    private static Map<String, Object> lastPayload;

    @IsTest
    static void sendsOnlyForBizDevReachStatusTransitionToPostClosed() {
        Transaction__c qualifyingTransaction = createTransaction('Funding', 'Biz Dev - Reach');
        Transaction__c otherBizDevTransaction = createTransaction('Funding', 'Biz Dev - Pugh');
        insert new List<Transaction__c>{ qualifyingTransaction, otherBizDevTransaction };

        requestCount = 0;
        lastPayload = null;
        ReachTxPostClosedWebhookSvc.endpointOverride = 'https://hooks.zapier.com/test';
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        qualifyingTransaction.Status__c = 'Post-Closed';
        otherBizDevTransaction.Status__c = 'Post-Closed';
        update new List<Transaction__c>{ qualifyingTransaction, otherBizDevTransaction };
        Test.stopTest();

        System.assertEquals(1, requestCount, 'Expected one webhook callout.');
        System.assertEquals(
            String.valueOf(qualifyingTransaction.Id),
            String.valueOf(lastPayload.get('transactionId'))
        );
        System.assertEquals('Biz Dev - Reach', lastPayload.get('bizDev'));
        System.assertEquals('Funding', lastPayload.get('oldStatus'));
        System.assertEquals('Post-Closed', lastPayload.get('newStatus'));
        System.assertEquals('TransactionStatusChanged', lastPayload.get('eventType'));
        System.assert(lastPayload.containsKey('transactionFields'), 'Expected full Transaction field payload.');
        Map<String, Object> transactionFields =
            (Map<String, Object>) lastPayload.get('transactionFields');
        System.assertEquals(transactionFields.size(), lastPayload.get('transactionFieldCount'));
        System.assertEquals('Post-Closed', transactionFields.get('Status__c'));
        System.assertEquals('Biz Dev - Reach', transactionFields.get('Biz_Dev__c'));
        System.assertEquals('1526000001', transactionFields.get('Loan_Number__c'));
    }

    @IsTest
    static void doesNotSendWhenStatusDoesNotChangeIntoPostClosed() {
        Transaction__c transactionRecord = createTransaction('Post-Closed', 'Biz Dev - Reach');
        insert transactionRecord;

        requestCount = 0;
        ReachTxPostClosedWebhookSvc.enqueuedJobCount = 0;
        ReachTxPostClosedWebhookSvc.endpointOverride = 'https://hooks.zapier.com/test';
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        transactionRecord.Name = 'Updated Name';
        update transactionRecord;
        Test.stopTest();

        System.assertEquals(0, requestCount, 'Expected no webhook callout.');
        System.assertEquals(
            0,
            ReachTxPostClosedWebhookSvc.enqueuedJobCount,
            'Expected no webhook job when the status is already Post-Closed.'
        );
    }

    private static Transaction__c createTransaction(String status, String bizDev) {
        return new Transaction__c(
            Name = 'Webhook Test ' + status + ' ' + bizDev,
            Status__c = status,
            Biz_Dev__c = bizDev,
            Loan_Number__c = '1526000001',
            Loan_Amount_1st__c = 425000
        );
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            requestCount++;
            lastPayload = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            System.assertEquals('POST', request.getMethod());
            System.assertEquals('application/json', request.getHeader('Content-Type'));

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"ok":true}');
            return response;
        }
    }
}
