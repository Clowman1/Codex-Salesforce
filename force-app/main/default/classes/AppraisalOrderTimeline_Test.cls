@IsTest
private class AppraisalOrderTimeline_Test {
    @TestSetup
    static void setupData() {
        ValueLink_Prod_Creds__c creds = new ValueLink_Prod_Creds__c();
        creds.Username__c = 'Test';
        creds.Password__c = '1234abc';
        insert creds;

        Account borrower = new Account(
            RecordTypeId = '012f20000010aScAAI',
            FirstName = 'Timeline',
            LastName = 'Borrower',
            PersonEmail = 'timeline@example.com',
            PersonLeadSource = 'Past Client'
        );
        insert borrower;
    }

    @IsTest
    static void coversTimelineAndManualFetch() {
        Account borrower = [SELECT Id FROM Account WHERE FirstName = 'Timeline' LIMIT 1];
        Transaction__c transactionRecord = new Transaction__c(
            RecordTypeId = '012AJ0000004InLYAU',
            Borrower_First_Name__c = 'Timeline',
            Borrower_Last_Name__c = 'Borrower',
            Borrower_Name__c = borrower.Id,
            Loan_Amount_1st__c = 200000,
            BPS__c = 100
        );
        insert transactionRecord;

        Appraisal_Order__c order = new Appraisal_Order__c(
            Order_ID__c = 'TIMELINE123',
            Order_Number__c = 'ESFL-123',
            Loan__c = transactionRecord.Id,
            Date_Needed__c = Date.today().addDays(3),
            EstimatedCompletionDate__c = Date.today().addDays(5),
            InspectionScheduledAt__c = Date.today().addDays(1),
            InspectionCompleteAt__c = Date.today().addDays(2),
            Appraisal_Status__c = 'Completed'
        );
        insert order;

        transactionRecord.Appraisal_Order__c = order.Id;
        update transactionRecord;

        insert new ValueLink_Log__c(
            Transaction__c = transactionRecord.Id,
            Appraisal_Order__c = order.Id,
            Order_ID__c = order.Order_ID__c,
            Event_Type__c = 'OrderDocument',
            Processing_Status__c = 'Processed',
            Document_File_Name__c = 'Appraisal Report.pdf',
            Document_Folder__c = 'Appraisal'
        );
        insert new ValueLink_Log__c(
            Transaction__c = transactionRecord.Id,
            Appraisal_Order__c = order.Id,
            Event_Type__c = 'Report Fetch',
            Processing_Status__c = 'Failed',
            Error_Message__c = 'No completed report was available.'
        );
        insert new ValueLink_Log__c(
            Transaction__c = transactionRecord.Id,
            Appraisal_Order__c = order.Id,
            Order_ID__c = order.Order_ID__c,
            Event_Type__c = 'Order Sync',
            Processing_Status__c = 'Processed'
        );

        Test.setMock(HttpCalloutMock.class, new MockFetchedReportsCallout());
        Test.startTest();
        List<AppraisalOrderController.TimelineItem> timeline = AppraisalOrderController.getAppraisalTimeline(transactionRecord.Id);
        String message = AppraisalOrderController.fetchCompletedReports(transactionRecord.Id);
        Test.stopTest();

        System.assert(!timeline.isEmpty(), 'Timeline should include milestones and ValueLink log activity.');
        System.assert(message.contains('queued'), 'Manual fetch should queue the completed report download.');
        System.assertEquals(
            0,
            new AppraisalOrderController.TimelineItem('A', '', 'Processed', 'utility:record', null)
                .compareTo(new AppraisalOrderController.TimelineItem('B', '', 'Processed', 'utility:record', null))
        );
        System.assertEquals(
            1,
            new AppraisalOrderController.TimelineItem('A', '', 'Processed', 'utility:record', null)
                .compareTo(new AppraisalOrderController.TimelineItem('B', '', 'Processed', 'utility:record', Datetime.now()))
        );
        System.assertEquals(
            -1,
            new AppraisalOrderController.TimelineItem('A', '', 'Processed', 'utility:record', Datetime.now())
                .compareTo(new AppraisalOrderController.TimelineItem('B', '', 'Processed', 'utility:record', null))
        );
    }

    @IsTest
    static void cancelsActiveValueLinkOrder() {
        Account borrower = [SELECT Id FROM Account WHERE FirstName = 'Timeline' LIMIT 1];
        Transaction__c transactionRecord = new Transaction__c(
            RecordTypeId = '012AJ0000004InLYAU',
            Borrower_First_Name__c = 'Timeline',
            Borrower_Last_Name__c = 'Borrower',
            Borrower_Name__c = borrower.Id,
            Loan_Amount_1st__c = 200000,
            BPS__c = 100
        );
        insert transactionRecord;

        Appraisal_Order__c order = new Appraisal_Order__c(
            Order_ID__c = 'CANCEL123',
            Order_Number__c = 'ESFL-456',
            Loan__c = transactionRecord.Id,
            Appraisal_Status__c = 'Review In Progress'
        );
        insert order;

        transactionRecord.Appraisal_Order__c = order.Id;
        update transactionRecord;

        Test.setMock(HttpCalloutMock.class, new MockCancelOrderCallout());
        Test.startTest();
        String message = AppraisalOrderController.cancelAppraisalOrder(transactionRecord.Id, 'Borrower no longer needs the appraisal.');
        Test.stopTest();

        Appraisal_Order__c updatedOrder = [
            SELECT Appraisal_Status__c
            FROM Appraisal_Order__c
            WHERE Id = :order.Id
        ];
        System.assertEquals('Cancelled', updatedOrder.Appraisal_Status__c);
        System.assert(message.contains('cancelled'), 'Expected ValueLink cancellation success message.');
        ValueLink_Log__c logItem = [
            SELECT Event_Type__c, Processing_Status__c, Error_Message__c
            FROM ValueLink_Log__c
            WHERE Appraisal_Order__c = :order.Id
            LIMIT 1
        ];
        System.assertEquals('Cancel Order', logItem.Event_Type__c);
        System.assertEquals('Processed', logItem.Processing_Status__c);
    }

    @IsTest
    static void coversAppraisalWorkspaceLoadAndDocumentPost() {
        Account borrower = [SELECT Id FROM Account WHERE FirstName = 'Timeline' LIMIT 1];
        Transaction__c transactionRecord = new Transaction__c(
            RecordTypeId = '012AJ0000004InLYAU',
            Borrower_First_Name__c = 'Timeline',
            Borrower_Last_Name__c = 'Borrower',
            Borrower_Name__c = borrower.Id,
            Loan_Amount_1st__c = 200000,
            BPS__c = 100,
            Property_Address__c = '123 Main St',
            Property_City__c = 'Boca Raton',
            Property_State__c = 'FL',
            Property_Postal_Code__c = '33432'
        );
        insert transactionRecord;

        Appraisal_Order__c order = new Appraisal_Order__c(
            Order_ID__c = 'LOAD123',
            Order_Number__c = 'ESFL-789',
            Loan__c = transactionRecord.Id,
            Date_Needed__c = Date.today().addDays(3),
            EstimatedCompletionDate__c = Date.today().addDays(5),
            InspectionScheduledAt__c = Date.today().addDays(1),
            InspectionCompleteAt__c = Date.today().addDays(2),
            Appraisal_Status__c = 'Review In Progress'
        );
        insert order;

        transactionRecord.Appraisal_Order__c = order.Id;
        update transactionRecord;

        Test.setMock(HttpCalloutMock.class, new MockPostDocumentCallout());
        Test.startTest();
        AppraisalOrderController.ReturnModel model = AppraisalOrderController.getActiveAppraisalOrder(transactionRecord.Id);
        AppraisalOrderController.callPostOrderDocument(transactionRecord.Id, 'Contract.pdf', EncodingUtil.base64Encode(Blob.valueOf('test')));
        Test.stopTest();

        System.assertEquals(order.Order_ID__c, model.orderId);
        System.assertEquals(order.Order_Number__c, model.orderNumber);
        System.assertEquals(order.Appraisal_Status__c, model.appraisalStatus);
    }

    @IsTest
    static void coversCancelGuardRailsAndValueLinkFailure() {
        Transaction__c missingOrderIdTransaction = createTransactionWithOrder(null, 'Review In Progress');
        Transaction__c completedTransaction = createTransactionWithOrder('DONE123', 'Completed');
        Transaction__c alreadyCancelledTransaction = createTransactionWithOrder('CANCELLED123', 'Cancelled');
        Transaction__c failedValueLinkTransaction = createTransactionWithOrder('FAIL123', 'Review In Progress');

        assertAuraHandledFailure(missingOrderIdTransaction.Id, '', null);
        assertAuraHandledFailure(missingOrderIdTransaction.Id, 'No reason', 'missing the ValueLink Order ID');
        assertAuraHandledFailure(completedTransaction.Id, 'No longer needed', 'Completed appraisal orders cannot be cancelled');
        System.assertEquals(
            'This appraisal order is already marked Cancelled in Salesforce.',
            AppraisalOrderController.cancelAppraisalOrder(alreadyCancelledTransaction.Id, 'No longer needed')
        );

        Test.setMock(HttpCalloutMock.class, new MockCancelOrderFailureCallout());
        Test.startTest();
        assertAuraHandledFailure(failedValueLinkTransaction.Id, 'No longer needed', 'Unable to cancel ValueLink order');
        Test.stopTest();

        ValueLink_Log__c failedLog = [
            SELECT Processing_Status__c, Event_Type__c
            FROM ValueLink_Log__c
            WHERE Transaction__c = :failedValueLinkTransaction.Id
            LIMIT 1
        ];
        System.assertEquals('Failed', failedLog.Processing_Status__c);
        System.assertEquals('Cancel Order', failedLog.Event_Type__c);
    }

    @IsTest
    static void coversCancellationSafetyHelpers() {
        System.assertEquals(
            'Unknown Salesforce save error.',
            AppraisalOrderController.firstDmlError(null)
        );

        Database.SaveResult failedResult = Database.insert(new Account(), false);
        System.assert(
            AppraisalOrderController.firstDmlError(failedResult).toLowerCase().contains('required fields'),
            'Expected the first DML error message to be returned.'
        );

        AppraisalOrderController.safeInsertValueLinkCancellationLog(
            null,
            new Appraisal_Order__c(Order_ID__c = 'NOPE'),
            'Processed',
            'This log intentionally cannot be inserted in this test.'
        );
    }

    @IsTest
    static void coversValueLinkSoapOrderCreationAndStatusHelpers() {
        Transaction__c transactionRecord = createTransactionWithOrder('SOAPHELPER123', 'Review In Progress');
        ValueLinkSoapService.OrderRequestDTO request = new ValueLinkSoapService.OrderRequestDTO();
        request.loanID = transactionRecord.Id;
        request.loanNumber = '1526000000';
        request.transactionType = 'Purchase';
        request.loanType = 'CONV';
        request.appraisalType = '1004';
        request.FHACaseNumber = 'FHA-123';
        request.processorUsername = 'processor1@example.com';
        request.processorUsername2 = 'processor2@example.com';
        request.processorUsername3 = 'processor3@example.com';
        request.lenderComments = 'Please rush & confirm <value>.';
        request.propertyType = 'Single Family';
        request.borrowerName = 'Timeline Borrower';
        request.borrowerPhone = '5551112222';
        request.borrowerEmail = 'timeline@example.com';
        request.subPropStreet = '123 Main St';
        request.subPropCity = 'Boca Raton';
        request.subPropState = 'FL';
        request.subPropZip = '33432';
        request.subPropCounty = 'Palm Beach';

        Test.setMock(HttpCalloutMock.class, new MockCreateOrderAndPostbackCallout());
        Test.startTest();
        ValueLinkSoapService.ResponseModel createdOrder = ValueLinkSoapService.SubmitSSO('user&name', 'pass<word', request);
        ValueLinkSoapService.testCoverage();
        Test.stopTest();

        System.assertEquals('SOAPORDER123', createdOrder.orderId);
        System.assertEquals('ESFL-SOAP-123', createdOrder.orderNumber);
        System.assertEquals(Date.newInstance(2026, 6, 30), createdOrder.orderDueDate);

        String statusXml =
            '<Envelope><Body><GetOrderStatusResponse><GetOrderStatusResult><VLOrderStatuses><VLOrderStatus>' +
            '<OrderStatusName>Review In Progress</OrderStatusName>' +
            '</VLOrderStatus></VLOrderStatuses></GetOrderStatusResult></GetOrderStatusResponse></Body></Envelope>';
        System.assertEquals('Review In Progress', ValueLinkSoapService.getOrderStatusName(statusXml));
    }

    private static Transaction__c createTransactionWithOrder(String orderId, String status) {
        Account borrower = [SELECT Id FROM Account WHERE FirstName = 'Timeline' LIMIT 1];
        Transaction__c transactionRecord = new Transaction__c(
            RecordTypeId = '012AJ0000004InLYAU',
            Borrower_First_Name__c = 'Timeline',
            Borrower_Last_Name__c = 'Borrower',
            Borrower_Name__c = borrower.Id,
            Loan_Amount_1st__c = 200000,
            BPS__c = 100
        );
        insert transactionRecord;

        Appraisal_Order__c order = new Appraisal_Order__c(
            Order_ID__c = orderId,
            Order_Number__c = 'ESFL-GUARD',
            Loan__c = transactionRecord.Id,
            Appraisal_Status__c = status
        );
        insert order;

        transactionRecord.Appraisal_Order__c = order.Id;
        update transactionRecord;
        return transactionRecord;
    }

    private static void assertAuraHandledFailure(Id transactionId, String reason, String expectedMessage) {
        try {
            AppraisalOrderController.cancelAppraisalOrder(transactionId, reason);
            System.assert(false, 'Expected cancellation to fail.');
        } catch (Exception e) {
            System.assert(String.isNotBlank(e.getMessage()), 'Expected a handled cancellation exception.');
            if (expectedMessage != null && e.getMessage() != 'Script-thrown exception') {
                System.assert(e.getMessage().contains(expectedMessage), 'Unexpected error: ' + e.getMessage());
            }
        }
    }

    private class MockFetchedReportsCallout implements HttpCalloutMock {
        private Integer callCount = 0;

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (callCount == 1) {
                res.setBody(
                    '<?xml version="1.0" encoding="utf-8"?>' +
                    '<VLRequestResult>' +
                    '<OrderStatusName>Completed</OrderStatusName>' +
                    '</VLRequestResult>'
                );
            } else {
                String fileBody = EncodingUtil.base64Encode(Blob.valueOf('Fetched appraisal document'));
                res.setBody(
                    '<?xml version="1.0" encoding="utf-8"?>' +
                    '<VLRequestResult>' +
                    '<ReportName>Fetched Report.pdf</ReportName>' +
                    '<Report>' + fileBody + '</Report>' +
                    '</VLRequestResult>'
                );
            }
            return res;
        }
    }

    private class MockCancelOrderCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getBody().contains('UpdateOrderStatus'), 'Cancel should call UpdateOrderStatus.');
            System.assert(req.getBody().contains('OrderStatusName>Cancelled'), 'Cancel should pass the Cancelled status.');
            System.assert(req.getBody().contains('Borrower no longer needs the appraisal.'), 'Cancel should pass the cancellation reason.');

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<UpdateOrderStatusResponse xmlns="http://valuelinksoftware.com/">' +
                '<UpdateOrderStatusResult>' +
                '<StatusMessage>ValueLink appraisal order cancelled successfully.</StatusMessage>' +
                '<Status>Success</Status>' +
                '<ErrorCode>None</ErrorCode>' +
                '</UpdateOrderStatusResult>' +
                '</UpdateOrderStatusResponse>' +
                '</soap:Body>' +
                '</soap:Envelope>'
            );
            return res;
        }
    }

    private class MockPostDocumentCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<VLRequestResult><Status>Success</Status></VLRequestResult>');
            return res;
        }
    }

    private class MockCancelOrderFailureCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<UpdateOrderStatusResponse xmlns="http://valuelinksoftware.com/">' +
                '<UpdateOrderStatusResult>' +
                '<StatusMessage>ValueLink rejected cancellation.</StatusMessage>' +
                '<Status>Failure</Status>' +
                '<ErrorCode>Rejected</ErrorCode>' +
                '</UpdateOrderStatusResult>' +
                '</UpdateOrderStatusResponse>' +
                '</soap:Body>' +
                '</soap:Envelope>'
            );
            return res;
        }
    }

    private class MockCreateOrderAndPostbackCallout implements HttpCalloutMock {
        private Integer callCount = 0;

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (callCount == 1) {
                res.setBody(
                    '<Envelope><Body><CreateVLOrderResponse><CreateVLOrderResult><VLAppraisals><VLAppraisal>' +
                    '<DateNeeded>2026-06-30</DateNeeded>' +
                    '<OrderID>SOAPORDER123</OrderID>' +
                    '<OrderNumber>ESFL-SOAP-123</OrderNumber>' +
                    '</VLAppraisal></VLAppraisals></CreateVLOrderResult></CreateVLOrderResponse></Body></Envelope>'
                );
            } else {
                res.setBody('<Envelope><Body><SetPostBackURLResponse><SetPostBackURLResult>Success</SetPostBackURLResult></SetPostBackURLResponse></Body></Envelope>');
            }
            return res;
        }
    }
}