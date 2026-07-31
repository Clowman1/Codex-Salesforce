/**
 * Created by toma on 10/21/2022.
 */
@RestResource(UrlMapping='/valueLink/ping/v1')
global without sharing class ValueLink_Webservice {
    private static final Integer MAX_ERROR_LENGTH = 32768;
    @TestVisible private static Integer largePayloadSizeBytes = 5500000;
    private static final String APPRAISAL_FOLDER = 'Appraisal';
    
    @HttpPost
    global  static void doPost(){
        RestResponse res = RestContext.response;
        RestRequest req = RestContext.request;
        
        
        String orderId = req.params.get('orderId');
        ValueLink_Log__c log = new ValueLink_Log__c(
            Order_ID__c = orderId,
            Processing_Status__c = 'Received'
        );

        if (req.requestBody.size() > largePayloadSizeBytes) {
            log.Event_Type__c = 'Large Payload';
            log.Processing_Status__c = orderId != null ? 'Fetch Scheduled' : 'Ignored';
            if (orderId != null) { ValueLinkDataFetchQueueable.fetchReports(new List<String> { orderId }); }
            saveLog(log);
            return;
		}
        
        log.Payload__c = req.requestBody.toString();
        saveLog(log);

        try {
            List<Map<String,Object>> payloadMap = parsePayloadToDetermineTypeOfEvent(req.requestBody.toString());
            List<Appraisal_Order__c> ordersToUpdate = new List<Appraisal_Order__c>();
            try{
                if(payloadMap.size()>0){
                    for(Map<String,Object> payload : payloadMap){
                        List<Appraisal_Order__c> updates = updateAppraisalRecord(payload, log);
                        if(!updates.isEmpty()){
                            Appraisal_Order__c updatedOrder = updates[0];
                            ordersToUpdate.add(updatedOrder);
                            applyPayloadDetailsToLog(log, payload, updatedOrder);
                        }
                    }
                }else {
                    log.Event_Type__c = 'Unsupported Payload';
                    log.Processing_Status__c = 'Ignored';
                }
                if(ordersToUpdate.size() > 0){
                    try{
                        update ordersToUpdate;
                        log.Processing_Status__c = 'Processed';
                    }catch(DmlException e){
                        System.debug('There was a problem while updating orders: '+e.getMessage());
                        log.Processing_Status__c = 'Failed';
                        log.Error_Message__c = truncateError(e.getMessage() + ' ' + e.getStackTraceString());
                        if(!Test.isRunningTest())
                            handleOrderNotUpdated(e.getMessage() + ' ' + e.getStackTraceString());
                    }
                }
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('Appraisal Order Was Updated. Thank you!');
            }catch(System.Exception e){
                System.debug(e);
                log.Processing_Status__c = 'Failed';
                log.Error_Message__c = truncateError(e.getMessage() + ' ' + e.getStackTraceString());
                res.statusCode = 500; res.responseBody = Blob.valueOf('Error occured: '+ e.getMessage());
                //throw e;
            }
        } catch(Exception e){
            log.Processing_Status__c = 'Failed';
            log.Error_Message__c = truncateError(e.getMessage() + ' ' + e.getStackTraceString());
            res.statusCode = 500; res.responseBody = Blob.valueOf('Error occured: '+ e.getMessage());
            //throw e;
        } finally {
            saveLog(log);
        }
        
        
    }
    public static void handleOrderNotUpdated(String errorMessage){
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        string htmlBody = '<div> ';
        htmlBody += '<p> ' +'Error message while trying to update appraisal orders: '+errorMEssage+'</p>';
        htmlBody += '</div>';
        message.setHtmlBody(htmlBody);
        message.toAddresses = new String[] { 'clowman@reachhomeloans.com','adamstephens250@gmail.com', 'development@nimbuscloudsolutions.com' };
        message.subject = 'There was a problem while updating appraisal orders';
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        mails.add(message);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(mails);
        }
        
    }
    private static List<Map<String,Object>> parsePayloadToDetermineTypeOfEvent(String requestBody){
        List<Map<String,Object>> outputResponse = new List<Map<String,Object>>();
        Dom.Document xml = new Dom.Document();
        xml.load(requestBody);
        Dom.XmlNode rootElm = xml.getRootElement();
        if(requestBody != null && requestBody.contains('VLOrderDocument')){
            addOrderDocumentPayloads(rootElm, outputResponse);
            applyRawOrderDocumentFallback(outputResponse, requestBody);
            return outputResponse;
        }
        Dom.XmlNode[] payload = rootElm.getChildren();
        for(Dom.XmlNode childNode : payload){
            if(childNode.getName() == null){
                continue;
            }
            else if(childNode.getName() == 'VLOrderComments'){
                continue;
            }
            else if(childNode.getName().contains('Inspection')){
                ValueLink_InspectionRequest_Model payloadRes = (ValueLink_InspectionRequest_Model) new ValueLink_InspectionRequestModel_Parser(requestBody).response;
                Map<String,Object> inspectionMap = (Map<String,Object>) payloadRes.getModelMap();
                inspectionMap.put('eventType','Inspection');
                outputResponse.add(inspectionMap);
            }
//            else if(childNode.getName() == 'VLOrderComments'){
//                List<ValueLink_OrderComments_Model> payloadRes = (List<ValueLink_OrderComments_Model>) new ValueLink_OrderCommentsModel_Parser(requestBody).response;
//                for(ValueLink_OrderComments_Model orderComm : payloadRes){
//                    outputResponse = (Map<String,Object>) orderComm.getModelMap();
//                    outputResponse.put('eventType','OrderComments');
//                }
//            }
            else if(getNodeName(childNode) == 'VLOrderDocuments'){
                for(Dom.XmlNode orderDocumentNode : childNode.getChildElements()){
                    if(getNodeName(orderDocumentNode) != 'VLOrderDocument'){
                        continue;
                    }

                    Map<String,Object> documentMap = new Map<String,Object>();
                    documentMap.put('orderId', getChildText(orderDocumentNode, 'OrderID'));
                    documentMap.put('orderNumber', getChildText(orderDocumentNode, 'OrderNumber'));
                    documentMap.put('orderDocumentId', getChildText(orderDocumentNode, 'OrderDocumentID'));
                    documentMap.put('documentTypeName', getChildText(orderDocumentNode, 'DocumentTypeName'));
                    documentMap.put('documentFileName', getChildText(orderDocumentNode, 'DocumentFileName'));
                    documentMap.put('orderDocument', getChildText(orderDocumentNode, 'OrderDocument'));
                    documentMap.put('accessibleByClient', getChildText(orderDocumentNode, 'AccessibleByClient') == 'true');
                    documentMap.put('accessibleByAppraiser', getChildText(orderDocumentNode, 'AccessibleByAppraiser') == 'true');
                    documentMap.put('documentSubmittedOn', getChildText(orderDocumentNode, 'DocumentSubmittedOn'));
                    documentMap.put('documentSubmittedBy', getChildText(orderDocumentNode, 'DocumentSubmittedBy'));
                    documentMap.put('eventType','OrderDocuments');
                    outputResponse.add(documentMap);
                }
                applyRawOrderDocumentFallback(outputResponse, requestBody);
            }
        }
        if(outputResponse.isEmpty() && requestBody != null && requestBody.contains('VLOrderDocument')){
            addOrderDocumentPayloads(rootElm, outputResponse);
            applyRawOrderDocumentFallback(outputResponse, requestBody);
        }
        return outputResponse;
    }

    private static void addOrderDocumentPayloads(Dom.XmlNode parentNode, List<Map<String,Object>> outputResponse){
        if(parentNode == null){
            return;
        }

        if(getNodeName(parentNode) == 'VLOrderDocument'){
            Map<String,Object> documentMap = new Map<String,Object>();
            documentMap.put('orderId', getChildText(parentNode, 'OrderID'));
            documentMap.put('orderNumber', getChildText(parentNode, 'OrderNumber'));
            documentMap.put('orderDocumentId', getChildText(parentNode, 'OrderDocumentID'));
            documentMap.put('documentTypeName', getChildText(parentNode, 'DocumentTypeName'));
            documentMap.put('documentFileName', getChildText(parentNode, 'DocumentFileName'));
            documentMap.put('orderDocument', getChildText(parentNode, 'OrderDocument'));
            documentMap.put('accessibleByClient', getChildText(parentNode, 'AccessibleByClient') == 'true');
            documentMap.put('accessibleByAppraiser', getChildText(parentNode, 'AccessibleByAppraiser') == 'true');
            documentMap.put('documentSubmittedOn', getChildText(parentNode, 'DocumentSubmittedOn'));
            documentMap.put('documentSubmittedBy', getChildText(parentNode, 'DocumentSubmittedBy'));
            documentMap.put('eventType','OrderDocuments');
            outputResponse.add(documentMap);
            return;
        }

        for(Dom.XmlNode childNode : parentNode.getChildElements()){
            addOrderDocumentPayloads(childNode, outputResponse);
        }
    }

    private static String getChildText(Dom.XmlNode parentNode, String childName){
        if(parentNode == null){
            return null;
        }

        for(Dom.XmlNode childNode : parentNode.getChildElements()){
            if(getNodeName(childNode) == childName){
                return childNode.getText();
            }
        }

        Dom.XmlNode childNode = parentNode.getChildElement(childName, null);
        return childNode == null ? null : childNode.getText();
    }

    private static String getNodeName(Dom.XmlNode node){
        if(node == null || node.getName() == null){
            return null;
        }

        String nodeName = node.getName();
        return nodeName.contains(':') ? nodeName.substringAfter(':') : nodeName;
    }

    private static void applyRawOrderDocumentFallback(List<Map<String,Object>> payloads, String requestBody){
        if(payloads == null || payloads.isEmpty() || String.isBlank(requestBody)){
            return;
        }

        for(Map<String,Object> payload : payloads){
            putRawTagIfBlank(payload, 'orderId', requestBody, 'OrderID');
            putRawTagIfBlank(payload, 'orderNumber', requestBody, 'OrderNumber');
            putRawTagIfBlank(payload, 'orderDocumentId', requestBody, 'OrderDocumentID');
            putRawTagIfBlank(payload, 'documentTypeName', requestBody, 'DocumentTypeName');
            putRawTagIfBlank(payload, 'documentFileName', requestBody, 'DocumentFileName');
            putRawTagIfBlank(payload, 'orderDocument', requestBody, 'OrderDocument');
            putRawTagIfBlank(payload, 'documentSubmittedOn', requestBody, 'DocumentSubmittedOn');
            putRawTagIfBlank(payload, 'documentSubmittedBy', requestBody, 'DocumentSubmittedBy');
        }
    }

    private static void putRawTagIfBlank(Map<String,Object> payload, String key, String requestBody, String tagName){
        if(payload == null || !String.isBlank((String) payload.get(key))){
            return;
        }

        String rawValue = extractFirstTagValue(requestBody, tagName);
        if(!String.isBlank(rawValue)){
            payload.put(key, rawValue);
        }
    }

    private static String extractFirstTagValue(String xmlBody, String tagName){
        if(String.isBlank(xmlBody) || String.isBlank(tagName)){
            return null;
        }

        Pattern pattern = Pattern.compile('(?s)<(?:[A-Za-z0-9_]+:)?' + tagName + '\\b[^>]*>(.*?)</(?:[A-Za-z0-9_]+:)?' + tagName + '>');
        Matcher matcher = pattern.matcher(xmlBody);
        if(!matcher.find()){
            return null;
        }

        String value = matcher.group(1);
        if(value == null){
            return null;
        }

        value = value.trim();
        if(value.startsWith('<![CDATA[') && value.endsWith(']]>')){
            value = value.substring(9, value.length() - 3);
        }
        return value.trim();
    }

    private static void applyPayloadDetailsToLog(
        ValueLink_Log__c log,
        Map<String,Object> payload,
        Appraisal_Order__c appraisalOrder
    ){
        if(payload == null){
            return;
        }

        String payloadOrderId = (String) payload.get('orderId');
        if(String.isNotBlank(payloadOrderId)){
            log.Order_ID__c = payloadOrderId;
        }
        log.Event_Type__c = (String) payload.get('eventType');

        if(appraisalOrder != null){
            log.Appraisal_Order__c = appraisalOrder.Id;
            log.Transaction__c = appraisalOrder.Loan__c;
        }
    }

    private static void applyDocumentDetailsToLog(ValueLink_Log__c log, DocumentArtifactResult artifact){
        if(log == null || artifact == null){
            return;
        }

        log.Document_File_Name__c = artifact.fileName;
        log.Document_Folder__c = artifact.folderName;
        log.Content_Version_ID__c = artifact.contentVersionId;
        log.Content_Document_ID__c = artifact.contentDocumentId;
    }

    private static void saveLog(ValueLink_Log__c log){
        if(log == null){
            return;
        }

        try{
            if(log.Id == null){
                insert log;
            }else{
                update log;
            }
        }catch(Exception e){
            System.debug('ValueLink log save failed: ' + e.getMessage());
        }
    }

    private static String truncateError(String errorMessage){
        if(String.isBlank(errorMessage)){
            return null;
        }

        return errorMessage.length() > MAX_ERROR_LENGTH
            ? errorMessage.substring(0, MAX_ERROR_LENGTH)
            : errorMessage;
    }
    
    /*private void downloadReports(ValueLink_Order__c valueLinkOrder) {
        String orderId = valueLinkOrder.OrderId__c;
        
        ValueLinkSoapAPI.VLRequestResult listOfReports = ValueLinkComponentController.getOrderReportListByOrderId(Integer.valueOf(orderId));
        if (listOfReports.Status != 'Success') return ;
        List<Report> reports = new List<Report>();
        for (ValueLinkSoapAPI.VLOrderReport report : listOfReports.VLOrderReports.VLOrderReport) {
            if (report.ReportNumber == null) continue;
            ValueLinkSoapAPI.VLRequestResult reportFile = ValueLinkComponentController.getReportFile(Integer.valueOf(orderId), report.ReportNumber);
            if (reportFile.Status != 'Success') continue;
            
            String base64 = reportFile.VLOrderReports.VLOrderReport[0].Report;
            String filename = reportFile.VLOrderReports.VLOrderReport[0].ReportName;
            
            reports.add(new Report(base64, filename, orderId + ' ' + report.ReportName));
        }
        
        System.enqueueJob(new ValueLinkUploadReport(reports, valueLinkOrder));
        
    }*/
    
    private static List<Appraisal_Order__c> updateAppraisalRecord(Map<String,Object> payload, ValueLink_Log__c log){
        List<Appraisal_Order__c> appraisalOrdersToUpdate = new List<Appraisal_Order__c>();
        Appraisal_Order__c appraisalOrder;
        String orderId, inspectionScheduledAt, inspectionCompleteAt, estimatedCompletionTime;
        orderId = (String) payload.get('orderId');
//        comment = (String) payload.get('comment') != null ? (String) payload.get('comment') : '';
//        commentID = (String) payload.get('commentId') != null ? (String) payload.get('commentId') : '';
        if(orderId != null){
            appraisalOrder = [SELECT Id, EstimatedCompletionDate__c, InspectionCompleteAt__c, InspectionScheduledAt__c, Order_Number__c, Loan__c FROM Appraisal_Order__c WHERE Order_ID__c =: orderId];
        }
        if((String) payload.get('eventType') == 'Inspection'){
            if((String) payload.get('inspectionScheduledAt') != null){
                inspectionScheduledAt = (String) payload.get('inspectionScheduledAt');
            }else{
                inspectionCompleteAt = (String) payload.get('inspectionCompleteAt');
            }
            estimatedCompletionTime = (String) payload.get('estimatedCompletionTime');
        }
        if(appraisalOrder != null){
//            appraisalOrder.Comment_ID__c = commentID;
//            appraisalOrder.Comment__c = comment;
            if((String) payload.get('eventType') == 'Inspection'){
                appraisalOrder.EstimatedCompletionDate__c = Date.valueOf(estimatedCompletionTime);
                if(inspectionCompleteAt != null){
                    appraisalOrder.InspectionCompleteAt__c = Date.valueOf(inspectionCompleteAt);
                }else{
                    appraisalOrder.InspectionScheduledAt__c = Date.valueOf(inspectionScheduledAt);
                }
            }else if((String) payload.get('eventType') == 'OrderDocuments'){
                DocumentArtifactResult artifact = createOrderDocumentArtifact(appraisalOrder.Loan__c,(String)payload.get('documentFileName'), (String) payload.get('orderDocument'));
                applyDocumentDetailsToLog(log, artifact);
            }
            appraisalOrdersToUpdate.add(appraisalOrder);
        }
        return appraisalOrdersToUpdate;
    }
    private static DocumentArtifactResult createOrderDocumentArtifact(String parentId, String fileName, String fileBase64Data){
        if(String.isBlank(parentId)){
            throw new ValueLinkDocumentException('Cannot attach ValueLink document because the appraisal order is not linked to a transaction.');
        }
        if(String.isBlank(fileBase64Data)){
            throw new ValueLinkDocumentException('Cannot attach ValueLink document because the document payload is blank.');
        }

        Blob fileData = EncodingUtil.base64Decode(fileBase64Data);
        try{
            Database.SaveResult saveResult = FilesRecipes.createFileAttachedToRecord(fileData, parentId, fileName, APPRAISAL_FOLDER);
            return buildDocumentArtifactResult(saveResult, fileName, APPRAISAL_FOLDER);
        }catch(Exception e){
            System.debug(e.getMessage());
            throw e;
        }
    }

    private static DocumentArtifactResult buildDocumentArtifactResult(Database.SaveResult saveResult, String fileName, String folderName){
        DocumentArtifactResult artifact = new DocumentArtifactResult();
        artifact.fileName = fileName;
        artifact.folderName = folderName;
        if(saveResult == null || !saveResult.isSuccess()){
            return artifact;
        }

        artifact.contentVersionId = String.valueOf(saveResult.getId());
        List<ContentVersion> versions = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :saveResult.getId()
            LIMIT 1
        ];
        if(!versions.isEmpty()){
            artifact.contentDocumentId = String.valueOf(versions[0].ContentDocumentId);
        }
        return artifact;
    }

    private class DocumentArtifactResult {
        String fileName;
        String folderName;
        String contentVersionId;
        String contentDocumentId;
    }

    private class ValueLinkDocumentException extends Exception {}

}