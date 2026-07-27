public class ValueLinkDataFetchQueueable implements Queueable, Database.AllowsCallouts {
    
    private static final String ENDPOINT = 'https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx';
    private static final Double RESPONSE_LIMIT_MB = 11.90;
    private static final String APPRAISAL_FOLDER = 'Appraisal';
    
    private static ValueLink_Prod_Creds__c userDefaultCreds = ValueLink_Prod_Creds__c.getInstance(UserInfo.getUserId());
    private static ValueLink_Prod_Creds__c orgDefaultCreds = ValueLink_Prod_Creds__c.getOrgDefaults();
    
    private String username;
    private String password;

    private String orderId;
    private List<Map<String, Object>> operations;
    private Map<String, Object> currentOperation;
    
    @InvocableMethod(label = 'Fetch files from completed ValueLink order')
    public static void fetchReports(List<String> orderIds) {
        String orderId = orderIds[0];
        Map<String, Object> operation = new Map<String, Object> { 'name' => 'GetOrderStatus' };
        List<Map<String, Object>> operations = new List<Map<String, Object>> { operation };
                
        System.enqueueJob(new ValueLinkDataFetchQueueable(operations, orderId));
    }
   
    public ValueLinkDataFetchQueueable(List<Map<String, Object>> operations, String orderId) {
        this.orderId = orderId;
        this.operations = operations;
        this.currentOperation = operations.remove(0);
    }
    
    public void execute(QueueableContext context) {
        String username = userDefaultCreds != null ? userDefaultCreds.Username__c : orgDefaultCreds.Username__c;
        String password = userDefaultCreds != null ? userDefaultCreds.Password__c : orgDefaultCreds.Password__c;
        
        List<Appraisal_Order__c> orders = [SELECT Id, Loan__c, Order_Id__c, Order_Number__c FROM Appraisal_Order__c WHERE Order_Id__c = :orderId AND Loan__c != NULL];
        Appraisal_Order__c order = null;
        Transaction__c loan = null;
        if (orders.size() > 0) {
            order = orders[0];
            loan = [SELECT Id, ValueLink_Last_Report_Fetch__c, Appraisal_1_Received_Date__c FROM Transaction__c WHERE Id = :order.Loan__c];
        } else {
            return;
        }
        
        String operationName = (String) currentOperation.get('name');
        
        // obtaining status, if equals to Completed then try fetch all files
        if (operationName.equals('GetOrderStatus')) {
            String body = String.format(simpleOperationRequest, new List<String> { operationName, username, password, orderId });
            String response = makeRequest(body);
            
            Dom.Document doc = new Dom.Document();
            doc.load(response);
            String orderStatus = findTextValueFromNode(doc.getRootElement(), 'OrderStatusName');
            if (orderStatus.equals('Completed')) {
                operations.add(new Map<String, Object> { 'name' => 'GetOrderEADSSRReportFile' });
                operations.add(new Map<String, Object> { 'name' => 'GetOrderSSRReportFiles' });
                operations.add(new Map<String, Object> { 'name' => 'GetAIRComplianceCertificateFile' });
                operations.add(new Map<String, Object> { 'name' => 'GetClientInvoiceFile' });
                operations.add(new Map<String, Object> { 'name' => 'GetOrderReportFile', 'reportNumber' => '1' });
                operations.add(new Map<String, Object> { 'name' => 'GetOrderUADReportFile' });
            }
        }
        
        // get PDF report, usually it's the first from GetOrderReportFile
        if (operationName.equals('GetOrderReportFile')) {
            try {
                String body = String.format(getReportOperationRequest, new List<String> { username, password, orderId, (String) currentOperation.get('reportNumber') });
                String response = makeRequest(body);
                
                Dom.Document doc = new Dom.Document();
                doc.load(response);
                String reportName = findTextValueFromNode(doc.getRootElement(), 'ReportName');
                String reportData = findTextValueFromNode(doc.getRootElement(), 'Report');
                
                if (String.isBlank(reportName)) {
                    reportName = 'Report #1';
                }
                
                if (String.isNotEmpty(reportData)) {
                    createOrderDocumentArtifact(order.Loan__c, reportName, reportData);
                }
            } catch (ValueLinkDataFetchException e) {}
        }
        
        // get UAD Report File (xml)
        if (operationName.equals('GetOrderUADReportFile')) {
            try {
                String body = String.format(simpleOperationRequest, new List<String> { operationName, username, password, orderId });
                String response = makeRequest(body);
                
                Dom.Document doc = new Dom.Document();
                doc.load(response);
                String reportName = findTextValueFromNode(doc.getRootElement(), 'ReportName');
                String reportData = findTextValueFromNode(doc.getRootElement(), 'Report');
                
                if (String.isBlank(reportName)) {
                    reportName = 'UAD Report';
                }
                
                if (String.isNotEmpty(reportData)) {
                    createOrderDocumentArtifact(order.Loan__c, reportName, reportData);
                }
            } catch (ValueLinkDataFetchException e) {}
        }
        
        if (operationName.equals('GetOrderEADSSRReportFile')) {
            try {
                String body = String.format(simpleOperationRequest, new List<String> { operationName, username, password, orderId });
                String response = makeRequest(body);
                
                Dom.Document doc = new Dom.Document();
                doc.load(response);
                String reportName = findTextValueFromNode(doc.getRootElement(), 'EADReportName');
                String reportData = findTextValueFromNode(doc.getRootElement(), 'EADReport');
                
                if (String.isBlank(reportName)) {
                    reportName = 'EAD Report';
                }
                
                if (String.isNotEmpty(reportData)) {
                    createOrderDocumentArtifact(order.Loan__c, reportName, reportData);
                }
            } catch (ValueLinkDataFetchException e) {}
        }
        
        //// 1
        if (operationName.equals('GetAIRComplianceCertificateFile')) {
            try {
                String body = String.format(simpleOperationRequest, new List<String> { operationName, username, password, orderId });
                String response = makeRequest(body);
                
                Dom.Document doc = new Dom.Document();
                doc.load(response);
                String reportName = findTextValueFromNode(doc.getRootElement(), 'AIRComplianceCertificateName');
                String reportData = findTextValueFromNode(doc.getRootElement(), 'OrderAIRCertificate');
                
                if (String.isBlank(reportName)) {
                    reportName = 'AIR Certificate';
                }
                
                if (String.isNotEmpty(reportData)) {
                    createOrderDocumentArtifact(order.Loan__c, reportName, reportData);
                }
            } catch (ValueLinkDataFetchException e) {}
        }
        
        //// 2
        if (operationName.equals('GetClientInvoiceFile')) {
            try {
                String body = String.format(simpleOperationRequest, new List<String> { operationName, username, password, orderId });
                String response = makeRequest(body);
                
                Dom.Document doc = new Dom.Document();
                doc.load(response);
                String reportName = findTextValueFromNode(doc.getRootElement(), 'InvoiceName');
                String reportData = findTextValueFromNode(doc.getRootElement(), 'Invoice');
                
                if (String.isBlank(reportName)) {
                    reportName = 'Invoice';
                }
                
                if (String.isNotEmpty(reportData)) {
                    createOrderDocumentArtifact(order.Loan__c, reportName, reportData);
                }
            } catch (ValueLinkDataFetchException e) {}
        }
        
        if (operationName.equals('GetOrderSSRReportFiles')) {
            try {
                String body = String.format(getSSRReportOperationRequest, new List<String> { username, password, orderId });
                String response = makeRequest(body);
                
                Dom.Document doc = new Dom.Document();
                doc.load(response);
                String fmReportName = findTextValueFromNode(doc.getRootElement(), 'FannieMaeReportName');
                String fmReportData = findTextValueFromNode(doc.getRootElement(), 'FannieMaeReport');
                
                if (String.isNotEmpty(fmReportData)) {
                    createOrderDocumentArtifact(order.Loan__c, order.Order_Number__c + '_' + fmReportName, fmReportData); // the same naming as in UI
                }
                
                String feReportName = findTextValueFromNode(doc.getRootElement(), 'FreddieMacReportName');
                String feReportData = findTextValueFromNode(doc.getRootElement(), 'FreddieMacReport');
                
                if (String.isNotEmpty(feReportName)) {
                    createOrderDocumentArtifact(order.Loan__c, order.Order_Number__c + '_' + feReportName, feReportData); // the same naming as in UI
                }
            } catch (ValueLinkDataFetchException e) {}
        }
        

        if (operations.size() > 0 && !Test.isRunningTest()) {
            System.enqueueJob(new ValueLinkDataFetchQueueable(this.operations, this.orderId));
        } else {
            loan.ValueLink_Last_Report_Fetch__c = Datetime.now();
            // Stamp Appraisal 1 Received Date when reports are successfully fetched
            if (loan.Appraisal_1_Received_Date__c == null) {
                loan.Appraisal_1_Received_Date__c = Date.today();
            }
            update loan;
        }
    }
    
    private static String makeRequest(String body) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'text/xml; charset=utf');
        request.setTimeout(2 * 60 * 1000);
        
        request.setBody(body);
        HttpResponse response = http.send(request);
        
        String contentLengthStr = response.getHeader('Content-Length');
        
        if (contentLengthStr != null) {
            Integer contentLength = Integer.valueOf(contentLengthStr);
            
            if (contentLength > RESPONSE_LIMIT_MB * 1024 * 1024) {
                throw new ValueLinkDataFetchException();
            }
        }
        
        String respBody = response.getBody();
        Integer statusCode = response.getStatusCode();
        System.debug(respBody);
        System.debug(statusCode);
        
        return respBody;
    }
    
    public static String findTextValueFromNode(Dom.XMLNode root, String nodeName) {     
        Integer counter = 0;
        List<Dom.XmlNode> nodes = new List<Dom.XmlNode> { root };
        
        while (counter < nodes.size()) {
            Dom.XmlNode currentNode = nodes.get(counter++);
            
            if (currentNode == null || String.isBlank(currentNode.getName())) {
                continue;
            }

            if (currentNode.getName().equals(nodeName)) {
                return currentNode.getText();
            }
            
            nodes.addAll(currentNode.getChildElements());
        }
 
        return null;
    }
    
    private static String simpleOperationRequest = 
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:val="http://valuelinksoftware.com/">\n' +
        '   <soapenv:Header/>\n' +
        '   <soapenv:Body>\n' +
        '      <val:{0}>\n' +
        '         <val:UserName>{1}</val:UserName>\n' +
        '         <val:Password>{2}</val:Password>\n' +
        '		  <val:OrderID>{3}</val:OrderID>\n' +
        '      </val:{0}>\n' +
        '   </soapenv:Body>\n' +
        '</soapenv:Envelope>';
    
    private static String getReportOperationRequest = 
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:val="http://valuelinksoftware.com/">\n' +
        '   <soapenv:Header/>\n' +
        '   <soapenv:Body>\n' +
        '      <val:GetOrderReportFile>\n' +
        '         <val:UserName>{0}</val:UserName>\n' +
        '         <val:Password>{1}</val:Password>\n' +
        '		  <val:OrderID>{2}</val:OrderID>\n' +
        '		  <val:ReportNumber>{3}</val:ReportNumber>\n' +
        '      </val:GetOrderReportFile>\n' +
        '   </soapenv:Body>\n' +
        '</soapenv:Envelope>';
    
    private static String getSSRReportOperationRequest = 
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:val="http://valuelinksoftware.com/">\n' +
        '   <soapenv:Header/>\n' +
        '   <soapenv:Body>\n' +
        '      <val:GetOrderSSRReportFiles>\n' +
        '         <val:UserName>{0}</val:UserName>\n' +
        '         <val:Password>{1}</val:Password>\n' +
        '		  <val:OrderID>{2}</val:OrderID>\n' +
        '		  <val:FannieMaeSSRReport>true</val:FannieMaeSSRReport>' +
        '         <val:FreddieMacSSRReport>true</val:FreddieMacSSRReport>' +
        '      </val:GetOrderSSRReportFiles>\n' +
        '   </soapenv:Body>\n' +
        '</soapenv:Envelope>';    
    
    // taken from Webservice
    private static void createOrderDocumentArtifact(String parentId, String fileName, String fileBase64Data) {
        
        List<ContentVersion> contentVersions = [SELECT Id FROM ContentVersion WHERE Title = :fileName AND FirstPublishLocationId = :parentId];
        
        if (contentVersions.size() > 0) {
            // duplicate
            return;
        }
        
        Blob fileData = EncodingUtil.base64Decode(fileBase64Data);
        try {
            FilesRecipes.createFileAttachedToRecord(fileData, parentId, fileName, APPRAISAL_FOLDER);
        } catch(Exception e) {
            System.debug(e.getMessage());
            throw e;
        }
    }
    
    public class ValueLinkDataFetchException extends Exception {
    }
    
}
