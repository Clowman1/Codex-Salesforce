/**
 * Created by toma on 12/19/2022.
 */

public class ValueLink_GetOrderDocumentsList {
    private static String requestXML = '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:val="http://valuelinksoftware.com/">\n' +
            '   <soapenv:Header/>\n' +
            '   <soapenv:Body>\n' +
            '      <val:GetOrderDocumentList>\n' +
            '         <!--Optional:-->\n' +
            '         <val:UserName>{0}</val:UserName>\n' +
            '         <!--Optional:-->\n' +
            '         <val:Password>{1}</val:Password>\n' +
            '         <val:OrderID>{2}</val:OrderID>\n' +
            '      </val:GetOrderDocumentList>\n' +
            '   </soapenv:Body>\n' +
            '</soapenv:Envelope>';
			
    private static String singleFileRequest = '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:val="http://valuelinksoftware.com/">\n' +
            '   <soapenv:Header/>\n' +
            '   <soapenv:Body>\n' +
            '      <val:GetOrderDocumentFile>\n' +
            '         <!--Optional:-->\n' +
            '         <val:UserName>{0}</val:UserName>\n' +
            '         <!--Optional:-->\n' +
            '         <val:Password>{1}</val:Password>\n' +
            '         <val:DocumentID>{2}</val:DocumentID>\n' +
            '      </val:GetOrderDocumentFile>\n' +
            '   </soapenv:Body>\n' +
            '</soapenv:Envelope>';

			
			
    public static AppraisalOrderController.OrderDocument getSingleDocument(String username, String password, String orderId){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx');
        //production endpoint https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx
        //uat https://esusauat.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx
        request.setMethod('POST');
        request.setHeader('Content-Type', 'text/xml; charset=utf');
        request.setBody(String.format(singleFileRequest,new List<String>{username, password, orderId}));
        HttpResponse response = http.send(request);
        System.debug('res: '+response.getBody());
        List<AppraisalOrderController.OrderDocument> documents = parseSingleFileResponse(response.getBody());
        System.debug('documents: '+documents);
        return documents[0];
    }
    public static List<AppraisalOrderController.OrderDocument> getOrderDocuments(String username, String password, String orderId){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx');
        //production endpoint https://esusa.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx
        //uat https://esusauat.spurams.com/Modules/ValueLinkAPI/ValueLinkExternalAPI.asmx
        request.setMethod('POST');
        request.setHeader('Content-Type', 'text/xml; charset=utf');
        request.setBody(String.format(requestXML,new List<String>{username, password, orderId}));
        HttpResponse response = http.send(request);
        System.debug('res: '+response.getBody());
        List<AppraisalOrderController.OrderDocument> documents = parseResponse(response.getBody());
        System.debug('documents: '+documents);
        return documents;
    }
	
    private static List<AppraisalOrderController.OrderDocument> parseSingleFileResponse(String xmlResponse){
        List<AppraisalOrderController.OrderDocument> output = new List<AppraisalOrderController.OrderDocument>();
        XMLSerializer manipulateXMLString = new XMLSerializer();
        Object deserializedJSON = (Object) manipulateXMLString.deSerializeUnTyped(xmlResponse);
        System.debug('map xml: '+JSON.serializePretty(deserializedJSON));
        System.debug('map xml2: '+deserializedJSON);
        Map<String,Object> resMap = (Map<String,Object>) deserializedJSON;
        Map<String,Object> envelope = (Map<String,Object>) resMap.get('Envelope');
        Map<String,Object> body = (Map<String,Object>) envelope.get('Body');
        Map<String,Object> getOrderCommentsResponse = (Map<String,Object>) body.get('GetOrderDocumentFileResponse');
        Map<String,Object> result = (Map<String,Object>) getOrderCommentsResponse.get('GetOrderDocumentFileResult');
        Map<String,Object> documents;
        List<AppraisalOrderController.OrderDocument> documentsList;
        AppraisalOrderController.OrderDocument document;
        try{
            if(result.get('VLOrderDocuments') != null || result.get('VLOrderDocuments') != '') {
                documents = (Map<String, Object>) result.get('VLOrderDocuments');
                try {
                    documentsList = (List<AppraisalOrderController.OrderDocument>) JSON.deserialize(JSON.serialize(documents.get('VLOrderDocument')), List<AppraisalOrderController.OrderDocument>.class);
                    if (documentsList.size() > 0) {
                        for (AppraisalOrderController.OrderDocument docObj : documentsList) {
                            output.add(docObj);
                        }
                    }
                } catch (Exception e) {
                    if (e.getMessage().contains('Malformed JSON: Expected \'[\' at the beginning of List/Set')) {
                        document = (AppraisalOrderController.OrderDocument) JSON.deserialize(JSON.serialize(documents.get('VLOrderDocument')), AppraisalOrderController.OrderDocument.class);
                        output.add(document);
                    }
                }
                if(output.size() > 1){
                    return ValueLink_SortDocuments.sort(output);
                }else{
                    return output;
                }
        }
        }catch(Exception e){
            System.debug('no documents res '+e.getMessage());
            if(e.getMessage().contains('Invalid conversion from runtime type String to Map<String,ANY>')){
                return null;
            }
        }
        System.debug('output: '+output);
        if(output.size() > 1){
            return ValueLink_SortDocuments.sort(output);
        }else{
            return output;
        }
    }
    private static List<AppraisalOrderController.OrderDocument> parseResponse(String xmlResponse){
        List<AppraisalOrderController.OrderDocument> output = new List<AppraisalOrderController.OrderDocument>();
        XMLSerializer manipulateXMLString = new XMLSerializer();
        Object deserializedJSON = (Object) manipulateXMLString.deSerializeUnTyped(xmlResponse);
        System.debug('map xml: '+JSON.serializePretty(deserializedJSON));
        System.debug('map xml2: '+deserializedJSON);
        Map<String,Object> resMap = (Map<String,Object>) deserializedJSON;
        Map<String,Object> envelope = (Map<String,Object>) resMap.get('Envelope');
        Map<String,Object> body = (Map<String,Object>) envelope.get('Body');
        Map<String,Object> getOrderCommentsResponse = (Map<String,Object>) body.get('GetOrderDocumentListResponse');
        Map<String,Object> result = (Map<String,Object>) getOrderCommentsResponse.get('GetOrderDocumentListResult');
        Map<String,Object> documents;
        List<AppraisalOrderController.OrderDocument> documentsList;
        AppraisalOrderController.OrderDocument document;
        try{
            if(result.get('VLOrderDocuments') != null || result.get('VLOrderDocuments') != '') {
                documents = (Map<String, Object>) result.get('VLOrderDocuments');
                try {
                    documentsList = (List<AppraisalOrderController.OrderDocument>) JSON.deserialize(JSON.serialize(documents.get('VLOrderDocument')), List<AppraisalOrderController.OrderDocument>.class);
                    if (documentsList.size() > 0) {
                        for (AppraisalOrderController.OrderDocument docObj : documentsList) {
                            output.add(docObj);
                        }
                    }
                } catch (Exception e) {
                    if (e.getMessage().contains('Malformed JSON: Expected \'[\' at the beginning of List/Set')) {
                        document = (AppraisalOrderController.OrderDocument) JSON.deserialize(JSON.serialize(documents.get('VLOrderDocument')), AppraisalOrderController.OrderDocument.class);
                        output.add(document);
                    }
                }
                if(output.size() > 1){
                    return ValueLink_SortDocuments.sort(output);
                }else{
                    return output;
                }
        }
        }catch(Exception e){
            System.debug('no documents res '+e.getMessage());
            if(e.getMessage().contains('Invalid conversion from runtime type String to Map<String,ANY>')){
                return null;
            }
        }
        System.debug('output: '+output);
        if(output.size() > 1){
            return ValueLink_SortDocuments.sort(output);
        }else{
            return output;
        }
    }
}