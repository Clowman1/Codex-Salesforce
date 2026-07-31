/**
 * Created by toma on 11/1/2022.
 */

public with sharing class ValueLink_OrderDocuments_Parser {
    public List<ValueLink_OrderDocuments_Model> response;
    public ValueLink_OrderDocuments_Parser(String inputXML){
        Dom.Document xml = new Dom.Document();
        xml.load(inputXML);
        this.response = processXML(xml.getRootElement());
        System.debug(this.response);
    }
    public List<ValueLink_OrderDocuments_Model> processXML(Dom.XmlNode inputNode){
        List<ValueLink_OrderDocuments_Model> responseModel = new List<ValueLink_OrderDocuments_Model>();
        Dom.XmlNode payloadStatus = inputNode.getChildElement('Status',null);
        Dom.XmlNode payloadError = inputNode.getChildElement('ErrorCode',null);
        Dom.XmlNode payloadOrderDocuments = inputNode.getChildElement('VLOrderDocuments',null);
        System.debug('children: '+payloadOrderDocuments.getChildren());
        for(Dom.XmlNode orderDocumentNode : payloadOrderDocuments.getChildren()){
            if(orderDocumentNode.getName() == 'VLOrderDocument'){
                ValueLink_OrderDocuments_Model orderDocument = new ValueLink_OrderDocuments_Model();
                orderDocument.orderNumber = orderDocumentNode.getChildElement('OrderNumber',null).getText();
                orderDocument.orderId = orderDocumentNode.getChildElement('OrderID',null).getText();
                orderDocument.orderDocumentId = orderDocumentNode.getChildElement('OrderDocumentID',null).getText();
                orderDocument.orderDocument = orderDocumentNode.getChildElement('OrderDocument',null).getText();
                orderDocument.documentSubmittedBy = orderDocumentNode.getChildElement('DocumentSubmittedBy',null).getText();
                orderDocument.accessibleByAppraiser = orderDocumentNode.getChildElement('AccessibleByAppraiser',null).getText() == 'true' ? true : false;
                orderDocument.accessibleByClient = orderDocumentNode.getChildElement('AccessibleByClient',null).getText() == 'true' ? true : false;
                orderDocument.documentSubmittedOn = orderDocumentNode.getChildElement('DocumentSubmittedOn',null).getText();
                orderDocument.documentFileName = orderDocumentNode.getChildElement('DocumentFileName', null).getText();
                orderDocument.documentTypeName = orderDocumentNode.getChildElement('DocumentTypeName', null).getText();
                responseModel.add(orderDocument);
            }
        }
        return responseModel;
    }
}