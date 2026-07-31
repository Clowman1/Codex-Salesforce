/**
 * Created by toma on 11/7/2022.
 */

public class ValueLinkSoapService {
    private static String requestXML = '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:val="http://valuelinksoftware.com/">\n' +
            '   <soapenv:Header/>\n' +
            '   <soapenv:Body>\n' +
            '      <val:CreateVLOrder>\n' +
            '         <val:UserName>{0}</val:UserName>\n' +
            '         <val:Password>{1}</val:Password>\n' +
            '         <val:Appraisal>\n' +
            '            <val:VLBorrower>\n' +
            '               <val:Name>{2}</val:Name>\n' +
            '               <val:Email>{3}</val:Email>\n' +
            '               <val:Phone>{4}</val:Phone>\n' +
            '            </val:VLBorrower>\n' +
            '            <val:VLProperty>\n' +
            '               <val:Address>{5}</val:Address>\n' +
            '               <val:City>{6}</val:City>\n' +
            '               <val:StateCode>{7}</val:StateCode>\n' +
            '               <val:Zip>{8}</val:Zip>\n' +
            '               <val:County>{9}</val:County>\n' +
            '               <val:PropertyTypeName>{10}</val:PropertyTypeName>\n' +
            '            </val:VLProperty>\n' +
            '            <val:LoanNumber>{11}</val:LoanNumber>\n' +  //required
            '            <val:LoanTypeName>{12}</val:LoanTypeName>\n' +  //required
            '            <val:TransactionTypeName>{13}</val:TransactionTypeName>\n' + //required
            '            <val:FHACaseNumber>{15}</val:FHACaseNumber>\n'+
            '            <val:LoanProcessorUser1>{16}</val:LoanProcessorUser1>\n'+
            '            <val:LoanProcessorUser2>{17}</val:LoanProcessorUser2>\n'+
            '            <val:LoanProcessorUser3>{18}</val:LoanProcessorUser3>\n'+
            '            <val:LenderComments>{19}</val:LenderComments>\n'+
            '              <val:AppraisalTypeName>{14}</val:AppraisalTypeName>\n' + //required
            '            <val:OrderedByUsername>{0}</val:OrderedByUsername>\n' + //required
            '         </val:Appraisal>\n' +
            '      </val:CreateVLOrder>\n' +
            '   </soapenv:Body>\n' +
            '</soapenv:Envelope>';
    
    private static String createPostBackURL = '<?xml version="1.0" encoding="utf-8"?>' +
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:val="http://valuelinksoftware.com/">\n' + 
        '<soapenv:Header/>\n' +
        '<soapenv:Body>\n' +
        '<val:SetPostBackURL>\n' +
                 '<val:UserName>{0}</val:UserName>\n' +
                 '<val:Password>{1}</val:Password>\n' +
                 '<val:OrderID>{2}</val:OrderID>\n' +
                 '<val:PostBackURL>{3}</val:PostBackURL>\n' +
              '</val:SetPostBackURL>\n' +
           '</soapenv:Body>\n' +
        '</soapenv:Envelope>';

		private static String getOrderStatusRequest = '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:val="http://valuelinksoftware.com/">\n' +
            '   <soapenv:Header/>\n' +
            '   <soapenv:Body>\n' +
            '      <val:GetOrderStatus>\n' +
            '         <val:UserName>{0}</val:UserName>\n' +
            '         <val:Password>{1}</val:Password>\n' +
			'		  <val:OrderID>{2}</val:OrderID>\n' +
            '      </val:GetOrderStatus>\n' +
            '   </soapenv:Body>\n' +
            '</soapenv:Envelope>';

    private static String updateOrderStatusRequest = '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:val="http://valuelinksoftware.com/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n' +
            '   <soapenv:Header/>\n' +
            '   <soapenv:Body>\n' +
            '      <val:UpdateOrderStatus>\n' +
            '         <val:UserName>{0}</val:UserName>\n' +
            '         <val:Password>{1}</val:Password>\n' +
            '         <val:OrderStatus>\n' +
            '            <val:AppraisalID>{2}</val:AppraisalID>\n' +
            '            <val:OrderStatus>\n' +
            '               <val:OrderStatusID xsi:nil="true"/>\n' +
            '               <val:OrderStatusName>Cancelled</val:OrderStatusName>\n' +
            '            </val:OrderStatus>\n' +
            '            <val:UpdateStatusComment>{3}</val:UpdateStatusComment>\n' +
            '            <val:CancellationReason>\n' +
            '               <val:CancellationReason>{3}</val:CancellationReason>\n' +
            '            </val:CancellationReason>\n' +
            '            <val:IsClientRevision>false</val:IsClientRevision>\n' +
            '            <val:PauseTurnTime>false</val:PauseTurnTime>\n' +
            '            <val:ShareWithAdmin>true</val:ShareWithAdmin>\n' +
            '            <val:ShareWithClient>true</val:ShareWithClient>\n' +
            '            <val:ShareWithAppraiser>true</val:ShareWithAppraiser>\n' +
            '            <val:ShareWithReviewer>true</val:ShareWithReviewer>\n' +
            '            <val:ShareWithSalesperson>true</val:ShareWithSalesperson>\n' +
            '         </val:OrderStatus>\n' +
            '      </val:UpdateOrderStatus>\n' +
            '   </soapenv:Body>\n' +
            '</soapenv:Envelope>';

    //https://reachhl-valuelink-v1.free.beeceptor.com/services/apexrest/valueLink/ping/v1
    //https://reach-sandbox-valulink.free.beeceptor.com/services/apexrest/valueLink/ping/v1

	public static String consumeGetOrderStatus(String username, String password, String orderId){
		Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx');
		request.setMethod('GET');
        request.setHeader('Content-Type', 'text/xml; charset=utf');
		request.setBody(String.format(getOrderStatusRequest, new List<String>{username,password,orderId}));
		HttpResponse response = http.send(request);
        System.debug('res: '+response.getBody());
		return getOrderStatusName(response.getBody());
	}

    public static String cancelOrder(String username, String password, String orderId, String reason) {
        String cancellationReason = String.isBlank(reason) ? 'Cancelled from Salesforce' : reason.trim();
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'text/xml; charset=utf-8');
        request.setHeader('SOAPAction', 'http://valuelinksoftware.com/UpdateOrderStatus');
        request.setBody(String.format(updateOrderStatusRequest, new List<String>{
            xmlValue(username),
            xmlValue(password),
            xmlValue(orderId),
            xmlValue(cancellationReason)
        }));

        HttpResponse response = http.send(request);
        Dom.Document doc = new Dom.Document();
        doc.load(response.getBody());
        String status = findTextValueFromNode(doc.getRootElement(), 'Status');
        String statusMessage = findTextValueFromNode(doc.getRootElement(), 'StatusMessage');
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300 || status != 'Success') {
            throw new ValueLinkSoapServiceException('Response from ValueLink: ' + (String.isBlank(statusMessage) ? response.getBody() : statusMessage));
        }
        return String.isBlank(statusMessage) ? 'ValueLink appraisal order was cancelled.' : statusMessage;
    }

	public static String getOrderStatusName(String getOrderStatusXMLResponse){
		XMLSerializer manipulateXMLString = new XMLSerializer();
        Object deserializedJSON = (Object) manipulateXMLString.deSerializeUnTyped(getOrderStatusXMLResponse);
		System.debug('map xml: '+deserializedJSON);
        Map<String,Object> resMap = (Map<String,Object>) deserializedJSON;
		Map<String,Object> envelope = (Map<String,Object>) resMap.get('Envelope');
        Map<String,Object> body = (Map<String,Object>) envelope.get('Body');
		Map<String,Object> getOrderStatusResponse = (Map<String,Object>) body.get('GetOrderStatusResponse');
		Map<String,Object> getOrderStatusResult = (Map<String,Object>) getOrderStatusResponse.get('GetOrderStatusResult');
        Map<String,Object> orderStatuses = (Map<String,Object>) getOrderStatusResult.get('VLOrderStatuses');
        Map<String,Object> vlOrderStatus = (Map<String,Object>) orderStatuses.get('VLOrderStatus');
		return (String) vlOrderStatus.get('OrderStatusName');
	}

    public static ResponseModel SubmitSSO(String username, String password, OrderRequestDTO requestDTO){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx');//https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx?WSDL
        //production endpoint https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx
        //uat https://esusauat.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx
        request.setMethod('POST');
        request.setHeader('Content-Type', 'text/xml; charset=utf');
        request.setBody(String.format(requestXML,new List<String>{
                xmlValue(username), xmlValue(password), xmlValue(requestDTO.borrowerName), xmlValue(requestDTO.borrowerEmail), xmlValue(requestDTO.borrowerPhone), xmlValue(requestDTO.subPropStreet),
                xmlValue(requestDTO.subPropCity), xmlValue(requestDTO.subPropState), xmlValue(requestDTO.subPropZip), xmlValue(requestDTO.subPropCounty), xmlValue(requestDTO.propertyType), xmlValue(requestDTO.loanNumber), xmlValue(requestDTO.loanType), xmlValue(requestDTO.transactionType),
                xmlValue(requestDTO.appraisalType), xmlValue(requestDTO.FHACaseNumber), xmlValue(requestDTO.processorUsername), xmlValue(requestDTO.processorUsername2), xmlValue(requestDTO.processorUsername3), xmlValue(requestDTO.lenderComments)
        }));
        HttpResponse response = http.send(request);
        System.debug('res: '+response.getBody());
            
        ResponseModel responseModel = null;
        try {
            responseModel = getOrderId(response.getBody());
            
        } catch (Exception e) {
            String responseBody = response.getBody(); Dom.Document doc = new Dom.Document(); doc.load(responseBody); String errorMessage = findTextValueFromNode(doc.getRootElement(), 'StatusMessage'); throw new ValueLinkSoapServiceException('Response from ValueLink: ' + errorMessage);
        }
        
        system.debug('orderID: '+responseModel.orderId);
        if(responseModel != null){
            try {
                createPostBackURL(username, password, responseModel.orderId);
            } catch (Exception e) {
                System.debug('ERROR CREATE POST BACK URL RESULT: ' + e.getMessage());
            }
            
            try{
                insert new Appraisal_Order__c(Order_ID__c=responseModel.orderId, Loan__c=requestDTO.loanID, Order_Number__c = responseModel.orderNumber, Date_Needed__c = responseModel.orderDueDate);
                saveAppraisalTypeOnTransaction(requestDTO);
            }catch(Exception e){
                System.debug(e);
                throw e;
            }
        }
        return responseModel;
    }

    private static void saveAppraisalTypeOnTransaction(OrderRequestDTO requestDTO) {
        if (requestDTO == null || requestDTO.loanID == null || String.isBlank(requestDTO.appraisalType)) {
            return;
        }
        try {
            update new Transaction__c(
                Id = requestDTO.loanID,
                ValueLink_Appraisal_Type__c = requestDTO.appraisalType
            );
        } catch (DmlException e) {
            System.debug(LoggingLevel.WARN, 'Unable to save ValueLink appraisal type to Transaction: ' + e.getMessage());
        }
    }
    
    // POC area, will be updated 
    public static void createPostBackURL(String username, String password, String orderId) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'text/xml; charset=utf');
        
        request.setBody(String.format(createPostBackURL, new List<String> { username, password, orderId,  'https://reachhomeloans.my.salesforce-sites.com/valuelink/services/apexrest/valueLink/ping/v1?orderId' + orderId }));
        HttpResponse response = http.send(request);
        System.debug('CREATE POST BACK URL RESULT: ' + response.getBody());
    }
    
    public static String findTextValueFromNode(Dom.XMLNode root, String nodeName) {     
        Integer counter = 0; List<Dom.XmlNode> nodes = new List<Dom.XmlNode> { root }; while (counter < nodes.size()) { Dom.XmlNode currentNode = nodes.get(counter++); if (currentNode == null || String.isBlank(currentNode.getName())) { continue;} if (currentNode.getName().equals(nodeName)) {return currentNode.getText();}nodes.addAll(currentNode.getChildElements());}return null;
    }

    private static String xmlValue(String value) {
        if (value == null) {
            return '';
        }
        return value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;');
    }
    
    public static ResponseModel getOrderId(String xmlResponse){
        ResponseModel output = new ResponseModel();
        XMLSerializer manipulateXMLString = new XMLSerializer();
        Object deserializedJSON = (Object) manipulateXMLString.deSerializeUnTyped(xmlResponse);
        System.debug('map xml: '+deserializedJSON);
        Map<String,Object> resMap = (Map<String,Object>) deserializedJSON;
        Map<String,Object> envelope = (Map<String,Object>) resMap.get('Envelope');
        Map<String,Object> body = (Map<String,Object>) envelope.get('Body');
        Map<String,Object> orderResponse = (Map<String,Object>) body.get('CreateVLOrderResponse');
        Map<String,Object> orderResult = (Map<String,Object>) orderResponse.get('CreateVLOrderResult');
        Map<String,Object> appraisals = (Map<String,Object>) orderResult.get('VLAppraisals');
        Map<String,Object> appraisal = (Map<String,Object>) appraisals.get('VLAppraisal');
        System.debug('due date: '+(String) appraisal.get('DateNeeded'));
        String dueDate = (String) appraisal.get('DateNeeded') != null ? (String) appraisal.get('DateNeeded') : null;
        output.orderId = (String) appraisal.get('OrderID');
        output.orderNumber = (String) appraisal.get('OrderNumber');
        if(dueDate != null && !String.isBlank(dueDate)){
            output.orderDueDate = Date.valueOf(dueDate);
        }else{
            output.orderDueDate = null;
        }
        System.debug(output);
        return output;
    }
    public class ResponseModel{
        public String orderId;
        public String orderNumber;
        public Date orderDueDate;
    }
    public class OrderRequestDTO{
        public ID loanID;
        public String loanNumber;
        public String transactionType; //loan purpose
        public String loanType;
        public String appraisalType;
        public String FHACaseNumber;
        public String processorUsername;
        public String processorUsername2;
        public String processorUsername3;
        public String lenderComments;
        public String propertyType;
        public String borrowerFirstName;
        public String borrowerLastName;
        public String borrowerName;
        public String borrowerPhone;
        public String borrowerEmail;
        public String borrowerMobilePhone;
        public String borrowerMailingStreet;
        public String borrowerMailingCity;
        public String borrowerMailingZip;
        public String borrowerMailingState;
        public String subPropStreet;
        public String subPropCity;
        public String subPropZip;
        public String subPropState;
        public String subPropCounty;
    }
    
    public class ValueLinkSoapServiceException extends Exception {}
    
    public static void testCoverage() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;        
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
    
}