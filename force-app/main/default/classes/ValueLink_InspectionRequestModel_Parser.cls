/**
 * Created by toma on 10/31/2022.
 */

public class ValueLink_InspectionRequestModel_Parser {
    public ValueLink_InspectionRequest_Model response;
    public ValueLink_InspectionRequestModel_Parser(String inputXML){
        Dom.Document xml = new Dom.Document();
        xml.load(inputXML);
        this.response = processXML(xml.getRootElement());
        System.debug(this.response);
    }
    public ValueLink_InspectionRequest_Model processXML(Dom.XmlNode inputNode){
        ValueLink_InspectionRequest_Model responseModel = new ValueLink_InspectionRequest_Model();
        Dom.XmlNode[] payload = inputNode.getChildren();
        Dom.XmlNode payloadError = inputNode.getChildElement('ErrorCode',null);
        Dom.XmlNode payloadInspectionComplete;
        Dom.XmlNode payloadInspectionSchedule;
        String orderId;
        String orderNumber;
        String inspectionScheduledAt;
        String estCompletionDate;
        String comment;
        String inspectionCompleteAt;

        for(Dom.XmlNode childNode : payload){
            if(childNode.getName() == 'VLOrderInspectionComplete'){
                payloadInspectionComplete = childNode;
            }else if(childNode.getName() == 'VLOrderInspectionSchedule'){
                payloadInspectionSchedule = childNode;
            }
        }
        if(payloadError.getText() == 'None'){
            if(payloadInspectionComplete != null){
                orderId = payloadInspectionComplete.getChildElement('OrderID', null).getText();
                orderNumber = payloadInspectionComplete.getChildElement('OrderNumber', null).getText();
                inspectionCompleteAt = payloadInspectionComplete.getChildElement('InspectionCompleteAt', null).getText();
                estCompletionDate = payloadInspectionComplete.getChildElement('EstimatedCompletionDate', null).getText();
                comment = payloadInspectionComplete.getChildElement('Comment', null).getText();
            }else if(payloadInspectionSchedule != null){
                orderId = payloadInspectionSchedule.getChildElement('OrderID', null).getText();
                orderNumber = payloadInspectionSchedule.getChildElement('OrderNumber', null).getText();
                inspectionScheduledAt = payloadInspectionSchedule.getChildElement('InspectionScheduledAt', null).getText();
                estCompletionDate = payloadInspectionSchedule.getChildElement('EstimatedCompletionDate', null).getText();
                comment = payloadInspectionSchedule.getChildElement('Comment', null).getText();
            }
        }
        responseModel.comment = comment;
        responseModel.estimatedCompletionTime = estCompletionDate;
        responseModel.inspectionCompleteAt = inspectionCompleteAt;
        responseModel.inspectionScheduledAt = inspectionScheduledAt;
        responseModel.orderId = orderId;
        responseModel.orderNumber = orderNumber;
        return responseModel;
    }
}