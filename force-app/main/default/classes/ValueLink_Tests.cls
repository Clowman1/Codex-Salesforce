/**
 * Created by toma on 12/2/2022.
 */
@IsTest
public class ValueLink_Tests {
    @TestSetup
    public static void setupApiCreds(){
        ValueLink_Prod_Creds__c creds = new ValueLink_Prod_Creds__c();
        creds.Username__c='Test';
        creds.Password__c='1234abc';
        insert creds;
        Account a = new Account(RecordTypeId='012f20000010aScAAI',FirstName='Test',LastName='MR Testy',PersonEmail='test@testy.com',PersonLeadSource='Past Client');
        insert a;
    }
	@IsTest
	public static void testAttachFileWebservice(){
		Id a = [SELECT Id FROM Account WHERE FirstName='Test'].Id;
        Transaction__c t = new Transaction__c(RecordTypeId='012AJ0000004InLYAU',Borrower_First_Name__c='Test', Borrower_Last_Name__c='Test',Borrower_Name__c=a,Loan_Amount_1st__c=200000,BPS__c=100);
        insert t;
        Appraisal_Order__c order = new Appraisal_Order__c(Order_ID__c = '33621', Loan__c = t.Id);
        insert order;
        RestRequest request = new RestRequest();
        RestResponse res = new RestResponse();
        request.httpMethod = 'POST';
		request.requestBody = Blob.valueof('someData');
		request.addParameter('fileName','testFile');
		request.addParameter('orderId',order.Order_ID__c);
		RestContext.request = request;
        RestContext.response= res;
        Test.startTest();
        ValueLink_AttachFIleWebservice.doPost();
        Test.stopTest();
		System.assertEquals(1,[SELECT Id FROM ContentVersion WHERE CreatedDate = TODAY].size());
        ContentVersion attachedFile = [
            SELECT Folder__c
            FROM ContentVersion
            WHERE CreatedDate = TODAY
            LIMIT 1
        ];
        System.assertEquals('Appraisal', attachedFile.Folder__c);
	}
    @IsTest
    public static void testAttachFileWebserviceInvalidOrder(){
        RestRequest request = new RestRequest();
        RestResponse res = new RestResponse();
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof('someData');
        request.addParameter('fileName','testFile');
        RestContext.request = request;
        RestContext.response= res;

        ValueLink_AttachFIleWebservice.doPost();

        System.assertEquals(400, res.statusCode);
    }
    @IsTest
    public static void testFilesRecipesDirectAndBulkCreates(){
        Id a = [SELECT Id FROM Account WHERE FirstName='Test'].Id;
        Transaction__c t = new Transaction__c(RecordTypeId='012AJ0000004InLYAU',Borrower_First_Name__c='Test', Borrower_Last_Name__c='Test',Borrower_Name__c=a,Loan_Amount_1st__c=200000,BPS__c=100);
        insert t;

        FilesRecipes.createFileFromStringAttachedToRecord('Hello ValueLink', t.Id, 'ValueLinkString.txt');

        FilesRecipes.FileAndLinkObject fileAndLink = new FilesRecipes.FileAndLinkObject();
        fileAndLink.fileContents = Blob.valueOf('Linked file');
        fileAndLink.attachedTo = t.Id;
        fileAndLink.fileName = 'ValueLinkLinked.txt';
        FilesRecipes.createFileAttachedToRecord(fileAndLink);

        FilesRecipes.FileAndLinkObject bulkFile = new FilesRecipes.FileAndLinkObject();
        bulkFile.fileContents = Blob.valueOf('Bulk file');
        bulkFile.attachedTo = t.Id;
        bulkFile.fileName = 'ValueLinkBulk.txt';
        List<Database.SaveResult> bulkResults = FilesRecipes.createFilesAttachedToRecords(new List<FilesRecipes.FileAndLinkObject>{ bulkFile });

        System.assertEquals(1, bulkResults.size());
        System.assertEquals(3, [SELECT count() FROM ContentVersion WHERE FirstPublishLocationId = :t.Id]);
    }
    @IsTest
    public static void testWebservice(){
        Id a = [SELECT Id FROM Account WHERE FirstName='Test'].Id;
        Transaction__c t = new Transaction__c(RecordTypeId='012AJ0000004InLYAU',Borrower_First_Name__c='Test', Borrower_Last_Name__c='Test',Borrower_Name__c=a,Loan_Amount_1st__c=200000,BPS__c=100);
        insert t;
        Appraisal_Order__c order = new Appraisal_Order__c(Order_ID__c = '33621', Loan__c = t.Id);
        insert order;
        RestRequest request = new RestRequest();
        RestResponse res = new RestResponse();
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof('<?xml version="1.0" encoding="US-ASCII"?><VLRequestResult xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><Status xsi:nil="true"/><ErrorCode>None</ErrorCode><VLOrderInspectionComplete><OrderID>33621</OrderID><OrderNumber>R19-00398</OrderNumber><InspectionCompleteAt>2019-12-02T10:30:00.300</InspectionCompleteAt><EstimatedCompletionDate>2019-12-27T00:00:00</EstimatedCompletionDate><Comment>Inspection Completed on Date: 2019-12-02. Time:10:30:00 AM.</Comment></VLOrderInspectionComplete></VLRequestResult>');
        RestContext.request = request;
        RestContext.response= res;
        Test.startTest();
        ValueLink_Webservice.doPost();
        ValueLink_Webservice.handleOrderNotUpdated('Test error message');
        Test.stopTest();
        Appraisal_Order__c o = [SELECT Id, InspectionCompleteAt__c,EstimatedCompletionDate__c FROM Appraisal_Order__c WHERE Order_ID__c = '33621'];
        System.assertNotEquals(null, o.EstimatedCompletionDate__c);
        System.assertEquals(Date.valueOf('2019-12-27'), o.EstimatedCompletionDate__c);
        System.assertNotEquals(null, o);
        System.assertNotEquals(null,o.InspectionCompleteAt__c);
    }
    @IsTest
    public static void testWebservice2(){
        Id a = [SELECT Id FROM Account WHERE FirstName='Test'].Id;
        Transaction__c t = new Transaction__c(RecordTypeId='012AJ0000004InLYAU',Borrower_First_Name__c='Test', Borrower_Last_Name__c='Test',Borrower_Name__c=a,Loan_Amount_1st__c=200000,BPS__c=100);
        insert t;
        Appraisal_Order__c order = new Appraisal_Order__c(Order_ID__c = '33621', Loan__c = t.Id);
        insert order;
        RestRequest request = new RestRequest();
        RestResponse res = new RestResponse();
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof('<?xml version="1.0" encoding="US-ASCII"?><VLRequestResult xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><Status xsi:nil="true"/><ErrorCode>None</ErrorCode><VLOrderInspectionSchedule><OrderID>33621</OrderID><OrderNumber>R19-00398</OrderNumber><InspectionScheduledAt>2019-11-28T09:00:00.00</InspectionScheduledAt><EstimatedCompletionDate>2019-12-27T00:00:00</EstimatedCompletionDate><Comment>Inspection date set: 2019-11-28. Time:9:00:00 AM.</Comment></VLOrderInspectionSchedule></VLRequestResult>');
        RestContext.request = request;
        RestContext.response= res;
        Test.startTest();
        ValueLink_Webservice.doPost();
        Test.stopTest();
        Appraisal_Order__c o = [SELECT Id, InspectionScheduledAt__c,EstimatedCompletionDate__c FROM Appraisal_Order__c WHERE Order_ID__c = '33621'];
        System.assertNotEquals(null, o.EstimatedCompletionDate__c);
        System.assertEquals(Date.valueOf('2019-12-27'), o.EstimatedCompletionDate__c);
        System.assertNotEquals(null, o);
        System.assertNotEquals(null,o.InspectionScheduledAt__c);
    }
    @IsTest
    public static void testWebservice3OrderComment(){
        Id a = [SELECT Id FROM Account WHERE FirstName='Test'].Id;
        Transaction__c t = new Transaction__c(RecordTypeId='012AJ0000004InLYAU',Borrower_First_Name__c='Test', Borrower_Last_Name__c='Test',Borrower_Name__c=a,Loan_Amount_1st__c=200000,BPS__c=100);
        insert t;
        Appraisal_Order__c order = new Appraisal_Order__c(Order_ID__c = '17208', Loan__c = t.Id);
        insert order;
        RestRequest request = new RestRequest();
        RestResponse res = new RestResponse();
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof('<?xml version="1.0" encoding="US-ASCII"?><VLRequestResult xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><Status xsi:nil="true"/><ErrorCode>None</ErrorCode><VLOrderComments><VLOrderComment><CommentID>85537</CommentID><OrderID>17208</OrderID><OrderNumber>R19-00398</OrderNumber><Comment>Test comment posted for client</Comment><UserTypeName>Admin</UserTypeName><IsRead>true</IsRead><AccessibleByLender>true</AccessibleByLender><AccessibleByAppraiser>false</AccessibleByAppraiser><CreatedOn>2019-11-26T11:44:25</CreatedOn><CreatedBy>adminuser</CreatedBy></VLOrderComment></VLOrderComments></VLRequestResult>');
        RestContext.request = request;
        RestContext.response= res;
        Test.startTest();
        ValueLink_Webservice.doPost();
        Test.stopTest();
        Appraisal_Order__c o = [SELECT Id, Comment_ID__c FROM Appraisal_Order__c WHERE Order_ID__c = '17208'];
        System.assertNotEquals(null, o);
        System.assertEquals(null, o.Comment_ID__c);
    }
    @IsTest
    public static void testWebserviceOrderDocumentsEvents(){
        Id a = [SELECT Id FROM Account WHERE FirstName='Test'].Id;
        Transaction__c t = new Transaction__c(RecordTypeId='012AJ0000004InLYAU',Borrower_First_Name__c='Test', Borrower_Last_Name__c='Test',Borrower_Name__c=a,Loan_Amount_1st__c=200000,BPS__c=100);
        insert t;
        Appraisal_Order__c order = new Appraisal_Order__c(Order_ID__c = '1139', Loan__c = t.Id);
        insert order;
        RestRequest request = new RestRequest();
        RestResponse res = new RestResponse();
        request.httpMethod = 'POST';
        String fileBody = EncodingUtil.base64Encode(Blob.valueOf('Test appraisal document'));
        request.requestBody = Blob.valueof('<?xml version="1.0" encoding="US-ASCII"?><VLRequestResult xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><Status xsi:nil="true"/><ErrorCode>None</ErrorCode><VLOrderDocuments><VLOrderDocument><OrderDocumentID>7062</OrderDocumentID><OrderID>1139</OrderID><OrderNumber>204-00029</OrderNumber><DocumentTypeName>Special Instructions</DocumentTypeName><DocumentFileName>Test Sample Document.pdf</DocumentFileName><OrderDocument><![CDATA[' + fileBody + ']]></OrderDocument><AccessibleByClient>true</AccessibleByClient><AccessibleByAppraiser>false</AccessibleByAppraiser><DocumentSubmittedOn>2020-04-17T10:04:05</DocumentSubmittedOn><DocumentSubmittedBy>amsadmin</DocumentSubmittedBy></VLOrderDocument></VLOrderDocuments></VLRequestResult>');
        RestContext.request = request;
        RestContext.response= res;
        Test.startTest();
        ValueLink_Webservice.doPost();
        Test.stopTest();
        System.assertEquals(200, res.statusCode, res.responseBody == null ? null : res.responseBody.toString());
        List<ContentVersion> appraisalDocuments = [
            SELECT Folder__c
            FROM ContentVersion
            WHERE Folder__c = 'Appraisal'
            LIMIT 1
        ];
        if(appraisalDocuments.isEmpty()){
            List<ValueLink_Log__c> logs = [
                SELECT Order_ID__c, Event_Type__c, Processing_Status__c, Error_Message__c, Document_File_Name__c, Document_Folder__c, Content_Version_ID__c
                FROM ValueLink_Log__c
                ORDER BY CreatedDate DESC
                LIMIT 5
            ];
            System.assertEquals(1, appraisalDocuments.size(), 'Expected Appraisal ContentVersion. Logs: ' + JSON.serialize(logs));
        }
        ContentVersion appraisalDocument = appraisalDocuments[0];
        System.assertEquals('Appraisal', appraisalDocument.Folder__c);
        ValueLink_Log__c valueLinkLog = [
            SELECT Document_File_Name__c, Document_Folder__c, Content_Version_ID__c, Content_Document_ID__c
            FROM ValueLink_Log__c
            WHERE Order_ID__c = '1139'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Test Sample Document.pdf', valueLinkLog.Document_File_Name__c);
        System.assertEquals('Appraisal', valueLinkLog.Document_Folder__c);
        System.assertNotEquals(null, valueLinkLog.Content_Version_ID__c);
        System.assertNotEquals(null, valueLinkLog.Content_Document_ID__c);
    }
    @IsTest
    public static void testWebserviceUnsupportedPayload(){
        RestRequest request = new RestRequest();
        RestResponse res = new RestResponse();
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof('<?xml version="1.0" encoding="US-ASCII"?><VLRequestResult><Status>Success</Status></VLRequestResult>');
        RestContext.request = request;
        RestContext.response= res;

        ValueLink_Webservice.doPost();

        System.assertEquals(200, res.statusCode);
        ValueLink_Log__c valueLinkLog = [
            SELECT Event_Type__c, Processing_Status__c
            FROM ValueLink_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Unsupported Payload', valueLinkLog.Event_Type__c);
        System.assertEquals('Ignored', valueLinkLog.Processing_Status__c);
    }
    @IsTest
    public static void testWebserviceLargePayloadWithoutOrderIsIgnored(){
        RestRequest request = new RestRequest();
        RestResponse res = new RestResponse();
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof('payload over test threshold');
        RestContext.request = request;
        RestContext.response= res;

        Integer originalLimit = ValueLink_Webservice.largePayloadSizeBytes;
        ValueLink_Webservice.largePayloadSizeBytes = 10;
        try {
            ValueLink_Webservice.doPost();
        } finally {
            ValueLink_Webservice.largePayloadSizeBytes = originalLimit;
        }

        ValueLink_Log__c valueLinkLog = [
            SELECT Event_Type__c, Processing_Status__c
            FROM ValueLink_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Large Payload', valueLinkLog.Event_Type__c);
        System.assertEquals('Ignored', valueLinkLog.Processing_Status__c);
    }
    @IsTest
    public static void testDataFetchQueueableRoutesFetchedReportsToAppraisalFolder(){
        Id a = [SELECT Id FROM Account WHERE FirstName='Test'].Id;
        Transaction__c t = new Transaction__c(RecordTypeId='012AJ0000004InLYAU',Borrower_First_Name__c='Test', Borrower_Last_Name__c='Test',Borrower_Name__c=a,Loan_Amount_1st__c=200000,BPS__c=100);
        insert t;
        Appraisal_Order__c order = new Appraisal_Order__c(Order_ID__c = 'FETCH123', Order_Number__c = 'FETCH-001', Loan__c = t.Id);
        insert order;

        Test.setMock(HttpCalloutMock.class, new MockFetchedReportsCallout());
        Test.startTest();
        List<Map<String,Object>> operationsToTest = new List<Map<String,Object>>{
            new Map<String,Object>{ 'name' => 'GetOrderReportFile', 'reportNumber' => '1' },
            new Map<String,Object>{ 'name' => 'GetOrderUADReportFile' },
            new Map<String,Object>{ 'name' => 'GetOrderEADSSRReportFile' },
            new Map<String,Object>{ 'name' => 'GetAIRComplianceCertificateFile' },
            new Map<String,Object>{ 'name' => 'GetClientInvoiceFile' },
            new Map<String,Object>{ 'name' => 'GetOrderSSRReportFiles' }
        };
        for(Map<String,Object> operation : operationsToTest){
            System.enqueueJob(new ValueLinkDataFetchQueueable(
                new List<Map<String,Object>>{ operation },
                'FETCH123'
            ));
        }
        Test.stopTest();

        List<ContentVersion> appraisalDocuments = [
            SELECT Folder__c
            FROM ContentVersion
            WHERE FirstPublishLocationId = :t.Id
        ];
        System.assert(appraisalDocuments.size() > 0, 'Expected fetched ValueLink reports to create ContentVersion records.');
        for(ContentVersion appraisalDocument : appraisalDocuments){
            System.assertEquals('Appraisal', appraisalDocument.Folder__c);
        }
    }
    @IsTest
    public static void testInvocable(){
        ValueLinkSoapService.testCoverage();
        Id a = [SELECT Id FROM Account WHERE FirstName='Test'].Id;
        Transaction__c t = new Transaction__c(RecordTypeId='012AJ0000004InLYAU',Borrower_First_Name__c='Test', Borrower_Last_Name__c='Test',Borrower_Name__c=a,Loan_Amount_1st__c=200000,BPS__c=100);
        insert t;
        Test.setMock(HttpCalloutMock.class, new MockAPICAll());
        Test.startTest();
        ValueLink_CreateOrder_Invocable.createOrder(new List<String>{t.Id});
        Test.stopTest();
        Appraisal_Order__c order = [SELECT Id FROM Appraisal_Order__c WHERE Loan__c =: t.Id];
        System.assertNotEquals(null,order);
    }

    @IsTest
    public static void testCreateOrderWithContactsAndContractPdf(){
        Id a = [SELECT Id FROM Account WHERE FirstName='Test'].Id;
        Transaction__c t = new Transaction__c(
            RecordTypeId='012AJ0000004InLYAU',
            Borrower_First_Name__c='Test',
            Borrower_Last_Name__c='Test',
            Borrower_Name__c=a,
            Loan_Amount_1st__c=200000,
            BPS__c=100,
            Loan_Type_1st_TD__c='FHA',
            FHA_Case_Number__c='123-4567890',
            ValueLink_Appraisal_Type__c='1004 FHA',
            Processor__c=UserInfo.getUserId()
        );
        insert t;
        insert new ContentVersion(
            Title='Purchase Contract',
            PathOnClient='Purchase Contract.pdf',
            VersionData=Blob.valueOf('Fake contract pdf'),
            FirstPublishLocationId=t.Id
        );
        ContentVersion contractVersion = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE FirstPublishLocationId = :t.Id
            LIMIT 1
        ];

        ValueLinkController.OrderActionModel model = ValueLinkController.getOrderActionModel(t.Id);
        System.assertEquals(t.Id, model.transactionId);
        System.assertEquals('FHA', model.loanType);
        System.assertEquals('123-4567890', model.fhaCaseNumber);
        System.assertEquals('1004 FHA', model.appraisalType);
        System.assert(!model.appraisalTypeOptions.isEmpty(), 'Appraisal product options should be available.');

        ValueLinkController.OrderActionRequest request = new ValueLinkController.OrderActionRequest();
        request.loanId = t.Id;
        request.processorUserId1 = UserInfo.getUserId();
        request.processorUserId2 = UserInfo.getUserId();
        request.processorUserId3 = UserInfo.getUserId();
        request.fhaCaseNumber = '123-4567890';
        request.appraisalType = '1004 FHA';
        request.generalComment = 'Please include the contract package on this order.';
        request.contractContentDocumentIds = new List<String>{ contractVersion.ContentDocumentId };

        Test.setMock(HttpCalloutMock.class, new MockAPICAll());
        Test.startTest();
        ValueLinkController.OrderActionResult result = ValueLinkController.createOrderWithContacts(request);
        Test.stopTest();

        System.assertNotEquals(null, result.orderId);
        System.assertEquals(1, [SELECT count() FROM Appraisal_Order__c WHERE Loan__c = :t.Id]);
        System.assertEquals(1, [SELECT count() FROM ValueLink_Log__c WHERE Transaction__c = :t.Id AND Event_Type__c = 'Contract PDF Posted']);
    }

    @IsTest
    public static void testCreateOrderWithContactsWithoutContractPdf(){
        Id a = [SELECT Id FROM Account WHERE FirstName='Test'].Id;
        Transaction__c t = new Transaction__c(
            RecordTypeId='012AJ0000004InLYAU',
            Borrower_First_Name__c='Test',
            Borrower_Last_Name__c='Test',
            Borrower_Name__c=a,
            Loan_Amount_1st__c=200000,
            BPS__c=100,
            Processor__c=UserInfo.getUserId()
        );
        insert t;
        t = [
            SELECT Id, Name
            FROM Transaction__c
            WHERE Id = :t.Id
        ];

        Test.setMock(HttpCalloutMock.class, new MockAPICAll());
        Test.startTest();
        ValueLinkController.OrderActionResult result = ValueLinkController.createOrderWithContactValues(
            null,
            t.Name,
            UserInfo.getUserId(),
            null,
            null,
            null,
            '1004 Conventional',
            'Refinance order with no contract.',
            new List<String>()
        );
        Test.stopTest();

        System.assertEquals('Appraisal order created.', result.message);
        System.assertEquals(1, [SELECT count() FROM Appraisal_Order__c WHERE Loan__c = :t.Id]);
        System.assertEquals(0, [SELECT count() FROM ValueLink_Log__c WHERE Transaction__c = :t.Id AND Event_Type__c = 'Contract PDF Posted']);
        Transaction__c updatedTransaction = [
            SELECT ValueLink_Appraisal_Type__c
            FROM Transaction__c
            WHERE Id = :t.Id
            LIMIT 1
        ];
        System.assertEquals('1004 Conventional', updatedTransaction.ValueLink_Appraisal_Type__c, 'Expected selected ValueLink product to save back to the Transaction.');
    }

    @IsTest
    public static void testProcessorUsernameUsesSelectedUserNotOrgDefault(){
        User selectedUser = [SELECT Id, Email FROM User WHERE Id = :UserInfo.getUserId()];

        System.assertEquals(
            selectedUser.Email,
            ValueLinkController.getProcessorUsernameByUserId(selectedUser.Id),
            'Processor contacts without exact ValueLink credentials should use the selected user email, not the org default credential.'
        );
    }

	 @IsTest
    public static void testOrderStatusBatch(){
		Id a = [SELECT Id FROM Account WHERE FirstName='Test'].Id;
		Transaction__c t = new Transaction__c(RecordTypeId='012AJ0000004InLYAU',Borrower_First_Name__c='Test', Borrower_Last_Name__c='Test',Borrower_Name__c=a,Loan_Amount_1st__c=200000,BPS__c=100);
		insert t;
		Appraisal_Order__c order = new Appraisal_Order__c(Order_ID__c = '1139', Loan__c = t.Id);
		insert order;
        System.assertEquals('Completed', ValueLinkSoapService.getOrderStatusName(new MockCompletedOrderStatusAndReportsCallout().completedStatusEnvelope()));
        Test.setMock(HttpCalloutMock.class, new MockCompletedOrderStatusAndReportsCallout());
        Test.startTest();
		ValueLinkOrderStatusBatchable obj = new ValueLinkOrderStatusBatchable();
		Database.executeBatch(obj, 20);
        Test.stopTest();

        Appraisal_Order__c updatedOrder = [SELECT Appraisal_Status__c FROM Appraisal_Order__c WHERE Id = :order.Id];
        System.assertEquals('Completed', updatedOrder.Appraisal_Status__c);
	}

	@IsTest
    public static void testOrderStatusSchedule(){
		Id a = [SELECT Id FROM Account WHERE FirstName='Test'].Id;
		Transaction__c t = new Transaction__c(RecordTypeId='012AJ0000004InLYAU',Borrower_First_Name__c='Test', Borrower_Last_Name__c='Test',Borrower_Name__c=a,Loan_Amount_1st__c=200000,BPS__c=100);
		insert t;
		Appraisal_Order__c order = new Appraisal_Order__c(Order_ID__c = '1139', Loan__c = t.Id);
		insert order;
        Test.setMock(HttpCalloutMock.class, new MockCompletedOrderStatusAndReportsCallout());
		Test.startTest();
		String jobId = System.schedule('testBasicScheduledApex',
      '0 0 0 3 9 ? 2042',new ValueLinkOrderStatusBatchable());
	  Test.stopTest();
	}

    public class MockCompletedOrderStatusAndReportsCallout implements HttpCalloutMock{
        private Integer postCallCount = 0;

        public HttpResponse respond(HttpRequest req){
            String fileBody = EncodingUtil.base64Encode(Blob.valueOf('Fetched appraisal document'));
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if(req.getMethod() == 'GET'){
                res.setBody(completedStatusEnvelope());
            }else{
                postCallCount++;
                if(postCallCount == 1){
                    res.setBody(completedStatusEnvelope());
                    return res;
                }
                res.setBody(
                    '<?xml version="1.0" encoding="utf-8"?>' +
                    '<VLRequestResult>' +
                    '<ReportName>Fetched Report.pdf</ReportName>' +
                    '<Report>' + fileBody + '</Report>' +
                    '<EADReportName>EAD Report.pdf</EADReportName>' +
                    '<EADReport>' + fileBody + '</EADReport>' +
                    '<AIRComplianceCertificateName>AIR Certificate.pdf</AIRComplianceCertificateName>' +
                    '<OrderAIRCertificate>' + fileBody + '</OrderAIRCertificate>' +
                    '<InvoiceName>Invoice.pdf</InvoiceName>' +
                    '<Invoice>' + fileBody + '</Invoice>' +
                    '<FannieMaeReportName>Fannie Mae SSR.pdf</FannieMaeReportName>' +
                    '<FannieMaeReport>' + fileBody + '</FannieMaeReport>' +
                    '<FreddieMacReportName>Freddie Mac SSR.pdf</FreddieMacReportName>' +
                    '<FreddieMacReport>' + fileBody + '</FreddieMacReport>' +
                    '</VLRequestResult>'
                );
            }
            return res;
        }

        public String completedStatusEnvelope(){
            return '<?xml version="1.0" encoding="utf-8"?>' +
                '<Envelope>' +
                '<Body>' +
                '<GetOrderStatusResponse>' +
                '<GetOrderStatusResult>' +
                '<VLOrderStatuses>' +
                '<VLOrderStatus>' +
                '<OrderStatusName>Completed</OrderStatusName>' +
                '</VLOrderStatus>' +
                '</VLOrderStatuses>' +
                '</GetOrderStatusResult>' +
                '</GetOrderStatusResponse>' +
                '</Body>' +
                '</Envelope>';
        }
    }

    public class MockAPICAll implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            String xmlString = '<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><CreateVLOrderResponse xmlns="http://valuelinksoftware.com/"><CreateVLOrderResult><StatusMessage>Order created successfully</StatusMessage><Status>Success</Status><ErrorCode>None</ErrorCode><VLAppraisals><VLAppraisal><VLAgent><Name /><Email /><Phone /><WorkPhone /><CellPhone /></VLAgent><VLBorrower><Name>MCR Report</Name><Email>alan@nimbuscloudsolutions.com</Email><Phone>7342455468</Phone><WorkPhone /><CellPhone /><BorrowerMailingAddress /><BorrowerMailingCity /><BorrowerMailingState /><BorrowerMailingZip /></VLBorrower><VLBroker><Name /><Email /><Phone /><WorkPhone /><CellPhone /></VLBroker><VLProperty><Address>8240 Test Rd</Address><City>Test</City><StateCode>MI</StateCode><Zip>48185</Zip><LegalDesc /><CurrentOwner /><County>null</County><ParcelID /><PropertyTypeName>Single Family Residential</PropertyTypeName><AccessInformation /><YearBuilt /><OccupiedBy /><EstimatedSquareFootage /><EstimatedLotSize /></VLProperty><VLAppraiserLicense><LicenseNumber xsi:nil="true" /><LicenseState xsi:nil="true" /><IsASCVerified xsi:nil="true" /><LastVerifiedOn xsi:nil="true" /><EffectiveDate xsi:nil="true" /><ExpDate xsi:nil="true" /><Certified xsi:nil="true" /><YearCertified xsi:nil="true" /></VLAppraiserLicense><OrderID>1125</OrderID><OrderTypeCode>RES</OrderTypeCode><OrderTypeName>Residential Appraisal</OrderTypeName><ClientName>Reach Home Loans LLC</ClientName><IsLenderDifferent>false</IsLenderDifferent><LenderNameOnReport /><LenderAddressOnReport /><WholesaleLenderName /><WholesaleLenderAddress /><LoanNumber>1522142878</LoanNumber><LoanTypeName>Conventional</LoanTypeName><LoanPurposeName /><FHACaseNumber /><TransactionTypeName>Purchase</TransactionTypeName><DateNeeded>2022-12-09T11:34:19</DateNeeded><OrderPriority>Normal</OrderPriority><FileOnHold>false</FileOnHold><OnHoldReasonID xsi:nil="true" /><AppraisalOnHoldDate xsi:nil="true" /><AppraisalResumeDate xsi:nil="true" /><InspectedDate xsi:nil="true" /><InspectionScheduledTime /><InspectedTime /><InspectionScheduledDate xsi:nil="true" /><InspectionComplete>false</InspectionComplete><AppraisalStatusName>Unassigned</AppraisalStatusName><TrackingNumber /><VendorFileNumber /><AppraisalSentToBorrowerOn xsi:nil="true" /><AppraisalSentToBorrower>false</AppraisalSentToBorrower><ReportDownloadedByBorrower>false</ReportDownloadedByBorrower><ReportDownloadedByBorrowerOn xsi:nil="true" /><BorrowerReportAuthorizationCode /><TermsAcknowledgedByBorrower>false</TermsAcknowledgedByBorrower><TermsAcknowledgedByBorrowerOn xsi:nil="true" /><IsRevisionRequest>false</IsRevisionRequest><RevisionRequestedOn xsi:nil="true" /><LenderComments /><InvoiceComments /><LoanApplicationDate xsi:nil="true" /><LoanClosingDate xsi:nil="true" /><LenderAddress>327 PLAZA REAL BLVD SUITE 215, BOCA RATON FL 33432</LenderAddress><InvestorName /><OrderNumber>ESMI-0000049</OrderNumber><AppraisalFee>645.00</AppraisalFee><AppraisalFileName /><AppraisalFileReleased>false</AppraisalFileReleased><AppraisalFileReleasedOn>0001-01-01T00:00:00</AppraisalFileReleasedOn><AppraisalFileReleasedBy /><UADStatusName /><UADReportNeeded>true</UADReportNeeded><UADDocumentFileIdentifier /><ReportTypeName /><AppraisalXMLFileName /><AppraisalXMLFileSubmittedtoPortal>false</AppraisalXMLFileSubmittedtoPortal><AppraisalTypeName>1004 plus 1007</AppraisalTypeName><AppraisalType2Name /><AppraisalType3Name /><AppraisalType4Name /><AppraisalType1Fee>645.00</AppraisalType1Fee><AppraisalType2Fee xsi:nil="true" /><AppraisalType3Fee xsi:nil="true" /><AppraisalType4Fee xsi:nil="true" /><AppraisalReport2FileName /><AppraisalReport3FileName /><AppraisalReport4FileName /><SalesTaxAmount xsi:nil="true" /><SalesTaxRate xsi:nil="true" /><DisclosureDate xsi:nil="true" /><LoanAmount xsi:nil="true" /><AppraisedValue xsi:nil="true" /><SalesPrice xsi:nil="true" /><CommercialCompanyName /><CommercialContactPerson /><CommercialContactPhone /><CommercialContactWorkPhone /><CommercialContactCellPhone /><CommercialLoanTypeName /><CommercialAppraisalPurposeName /><CommercialAppraisalCategoryName /><CommercialPropertyTypeName /><CommercialRealEstateValuedTypeName /><CommercialContactEmail /><OrderedOn>2022-12-02T11:34:19</OrderedOn><OrderedByUsername>rhluatapiuser</OrderedByUsername><OrderedByName>RHL UAT API User</OrderedByName><OrderedByPhone /><OrderedByEmail>rhluatapiuser@valuelinkams.com</OrderedByEmail><LoanProcessorUser1 /><LoanProcessorUser2 /><LoanProcessorUser3 /><AppraiserFee xsi:nil="true" /><TechnologyFee xsi:nil="true" /><NetAppraiserFee xsi:nil="true" /><AppointmentContact /><AppointmentContactName /><AppointmentContactEmail /><AppointmentContactPhone /><AdditionalClientEmails /><CreatedOn>2022-12-02T11:34:19</CreatedOn><CreatedBy>rhluatapiuser</CreatedBy><OrderSource>API</OrderSource><AppraisalPostBackURL>https://reachhomeloans--ncskev.sandbox.my.salesforce-sites.com/services/apexrest/valueLink/pipeline/ping/v1</AppraisalPostBackURL><AppraiserDueDate xsi:nil="true" /><EstimatedClientDeliveryDate xsi:nil="true" /><InspectionScheduledOn xsi:nil="true" /><LastStatusUpdatedOn xsi:nil="true" /><IsEscalated>false</IsEscalated><EscalatedOn xsi:nil="true" /><EscalatedBy /><EscalatedRemovedOn xsi:nil="true" /><EscalatedRemovedBy /><IsFlagged>false</IsFlagged><FlaggedOn xsi:nil="true" /><FlaggedBy /><AppraiserID xsi:nil="true" /><AppraiserName /><DUCaseFileID /><LenderBranchName /><IsQuoteRequest>false</IsQuoteRequest><ManagementFee xsi:nil="true" /><UCDPDetails /><EADDetails /><ClientTurnTimeBusinessDays xsi:nil="true" /><ClientTurnTimeCalendarDays xsi:nil="true" /><IncidentName /><IncidentDate xsi:nil="true" /><CommercialInterestValuedType /><CommercialEffectiveValuationType /><ReviewDetails><ReviewerName /><AssignedToReviewerOn /><ReviewerFee /><EffectiveDate /><AppraisedValue /><PropertyCondition /><QuickSaleValue /><ReportAccepted /><ReportReviewDate /><ReportRejectionReason /></ReviewDetails></VLAppraisal></VLAppraisals></CreateVLOrderResult></CreateVLOrderResponse></soap:Body></soap:Envelope>';
            HttpResponse res = new HttpResponse();
            res.setBody(xmlString);
            res.setStatus('200');
            return res;
        }
    }
    public class MockDocumentsEvent implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            String xmlString = '<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><CreateVLOrderResponse xmlns="http://valuelinksoftware.com/"><CreateVLOrderResult><StatusMessage>Order created successfully</StatusMessage><Status>Success</Status><ErrorCode>None</ErrorCode><VLAppraisals><VLAppraisal><VLAgent><Name /><Email /><Phone /><WorkPhone /><CellPhone /></VLAgent><VLBorrower><Name>MCR Report</Name><Email>alan@nimbuscloudsolutions.com</Email><Phone>7342455468</Phone><WorkPhone /><CellPhone /><BorrowerMailingAddress /><BorrowerMailingCity /><BorrowerMailingState /><BorrowerMailingZip /></VLBorrower><VLBroker><Name /><Email /><Phone /><WorkPhone /><CellPhone /></VLBroker><VLProperty><Address>8240 Test Rd</Address><City>Test</City><StateCode>MI</StateCode><Zip>48185</Zip><LegalDesc /><CurrentOwner /><County>null</County><ParcelID /><PropertyTypeName>Single Family Residential</PropertyTypeName><AccessInformation /><YearBuilt /><OccupiedBy /><EstimatedSquareFootage /><EstimatedLotSize /></VLProperty><VLAppraiserLicense><LicenseNumber xsi:nil="true" /><LicenseState xsi:nil="true" /><IsASCVerified xsi:nil="true" /><LastVerifiedOn xsi:nil="true" /><EffectiveDate xsi:nil="true" /><ExpDate xsi:nil="true" /><Certified xsi:nil="true" /><YearCertified xsi:nil="true" /></VLAppraiserLicense><OrderID>1125</OrderID><OrderTypeCode>RES</OrderTypeCode><OrderTypeName>Residential Appraisal</OrderTypeName><ClientName>Reach Home Loans LLC</ClientName><IsLenderDifferent>false</IsLenderDifferent><LenderNameOnReport /><LenderAddressOnReport /><WholesaleLenderName /><WholesaleLenderAddress /><LoanNumber>1522142878</LoanNumber><LoanTypeName>Conventional</LoanTypeName><LoanPurposeName /><FHACaseNumber /><TransactionTypeName>Purchase</TransactionTypeName><DateNeeded>2022-12-09T11:34:19</DateNeeded><OrderPriority>Normal</OrderPriority><FileOnHold>false</FileOnHold><OnHoldReasonID xsi:nil="true" /><AppraisalOnHoldDate xsi:nil="true" /><AppraisalResumeDate xsi:nil="true" /><InspectedDate xsi:nil="true" /><InspectionScheduledTime /><InspectedTime /><InspectionScheduledDate xsi:nil="true" /><InspectionComplete>false</InspectionComplete><AppraisalStatusName>Unassigned</AppraisalStatusName><TrackingNumber /><VendorFileNumber /><AppraisalSentToBorrowerOn xsi:nil="true" /><AppraisalSentToBorrower>false</AppraisalSentToBorrower><ReportDownloadedByBorrower>false</ReportDownloadedByBorrower><ReportDownloadedByBorrowerOn xsi:nil="true" /><BorrowerReportAuthorizationCode /><TermsAcknowledgedByBorrower>false</TermsAcknowledgedByBorrower><TermsAcknowledgedByBorrowerOn xsi:nil="true" /><IsRevisionRequest>false</IsRevisionRequest><RevisionRequestedOn xsi:nil="true" /><LenderComments /><InvoiceComments /><LoanApplicationDate xsi:nil="true" /><LoanClosingDate xsi:nil="true" /><LenderAddress>327 PLAZA REAL BLVD SUITE 215, BOCA RATON FL 33432</LenderAddress><InvestorName /><OrderNumber>ESMI-0000049</OrderNumber><AppraisalFee>645.00</AppraisalFee><AppraisalFileName /><AppraisalFileReleased>false</AppraisalFileReleased><AppraisalFileReleasedOn>0001-01-01T00:00:00</AppraisalFileReleasedOn><AppraisalFileReleasedBy /><UADStatusName /><UADReportNeeded>true</UADReportNeeded><UADDocumentFileIdentifier /><ReportTypeName /><AppraisalXMLFileName /><AppraisalXMLFileSubmittedtoPortal>false</AppraisalXMLFileSubmittedtoPortal><AppraisalTypeName>1004 plus 1007</AppraisalTypeName><AppraisalType2Name /><AppraisalType3Name /><AppraisalType4Name /><AppraisalType1Fee>645.00</AppraisalType1Fee><AppraisalType2Fee xsi:nil="true" /><AppraisalType3Fee xsi:nil="true" /><AppraisalType4Fee xsi:nil="true" /><AppraisalReport2FileName /><AppraisalReport3FileName /><AppraisalReport4FileName /><SalesTaxAmount xsi:nil="true" /><SalesTaxRate xsi:nil="true" /><DisclosureDate xsi:nil="true" /><LoanAmount xsi:nil="true" /><AppraisedValue xsi:nil="true" /><SalesPrice xsi:nil="true" /><CommercialCompanyName /><CommercialContactPerson /><CommercialContactPhone /><CommercialContactWorkPhone /><CommercialContactCellPhone /><CommercialLoanTypeName /><CommercialAppraisalPurposeName /><CommercialAppraisalCategoryName /><CommercialPropertyTypeName /><CommercialRealEstateValuedTypeName /><CommercialContactEmail /><OrderedOn>2022-12-02T11:34:19</OrderedOn><OrderedByUsername>rhluatapiuser</OrderedByUsername><OrderedByName>RHL UAT API User</OrderedByName><OrderedByPhone /><OrderedByEmail>rhluatapiuser@valuelinkams.com</OrderedByEmail><LoanProcessorUser1 /><LoanProcessorUser2 /><LoanProcessorUser3 /><AppraiserFee xsi:nil="true" /><TechnologyFee xsi:nil="true" /><NetAppraiserFee xsi:nil="true" /><AppointmentContact /><AppointmentContactName /><AppointmentContactEmail /><AppointmentContactPhone /><AdditionalClientEmails /><CreatedOn>2022-12-02T11:34:19</CreatedOn><CreatedBy>rhluatapiuser</CreatedBy><OrderSource>API</OrderSource><AppraisalPostBackURL>https://reachhomeloans--ncskev.sandbox.my.salesforce-sites.com/services/apexrest/valueLink/pipeline/ping/v1</AppraisalPostBackURL><AppraiserDueDate xsi:nil="true" /><EstimatedClientDeliveryDate xsi:nil="true" /><InspectionScheduledOn xsi:nil="true" /><LastStatusUpdatedOn xsi:nil="true" /><IsEscalated>false</IsEscalated><EscalatedOn xsi:nil="true" /><EscalatedBy /><EscalatedRemovedOn xsi:nil="true" /><EscalatedRemovedBy /><IsFlagged>false</IsFlagged><FlaggedOn xsi:nil="true" /><FlaggedBy /><AppraiserID xsi:nil="true" /><AppraiserName /><DUCaseFileID /><LenderBranchName /><IsQuoteRequest>false</IsQuoteRequest><ManagementFee xsi:nil="true" /><UCDPDetails /><EADDetails /><ClientTurnTimeBusinessDays xsi:nil="true" /><ClientTurnTimeCalendarDays xsi:nil="true" /><IncidentName /><IncidentDate xsi:nil="true" /><CommercialInterestValuedType /><CommercialEffectiveValuationType /><ReviewDetails><ReviewerName /><AssignedToReviewerOn /><ReviewerFee /><EffectiveDate /><AppraisedValue /><PropertyCondition /><QuickSaleValue /><ReportAccepted /><ReportReviewDate /><ReportRejectionReason /></ReviewDetails></VLAppraisal></VLAppraisals></CreateVLOrderResult></CreateVLOrderResponse></soap:Body></soap:Envelope>';
            HttpResponse res = new HttpResponse();
            res.setBody(xmlString);
            res.setStatus('200');
            return res;
        }
    }
    public class MockFetchedReportsCallout implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            String fileBody = EncodingUtil.base64Encode(Blob.valueOf('Fetched appraisal document'));
            String xmlString =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<VLRequestResult>' +
                '<OrderStatusName>Completed</OrderStatusName>' +
                '<ReportName>Fetched Report.pdf</ReportName>' +
                '<Report>' + fileBody + '</Report>' +
                '<EADReportName>EAD Report.pdf</EADReportName>' +
                '<EADReport>' + fileBody + '</EADReport>' +
                '<AIRComplianceCertificateName>AIR Certificate.pdf</AIRComplianceCertificateName>' +
                '<OrderAIRCertificate>' + fileBody + '</OrderAIRCertificate>' +
                '<InvoiceName>Invoice.pdf</InvoiceName>' +
                '<Invoice>' + fileBody + '</Invoice>' +
                '<FannieMaeReportName>Fannie Mae SSR.pdf</FannieMaeReportName>' +
                '<FannieMaeReport>' + fileBody + '</FannieMaeReport>' +
                '<FreddieMacReportName>Freddie Mac SSR.pdf</FreddieMacReportName>' +
                '<FreddieMacReport>' + fileBody + '</FreddieMacReport>' +
                '</VLRequestResult>';
            HttpResponse res = new HttpResponse();
            res.setBody(xmlString);
            res.setStatusCode(200);
            return res;
        }
    }
}
