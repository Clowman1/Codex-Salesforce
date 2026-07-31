/**
 * Created by toma on 10/31/2022.
 */

public class ValueLink_OrderCommentsModel_Parser {
    public List<ValueLink_OrderComments_Model> response;
    public ValueLink_OrderCommentsModel_Parser(String inputXML){
        Dom.Document xml = new Dom.Document();
        xml.load(inputXML);
        this.response = processXML(xml.getRootElement());
        System.debug(this.response);
    }
    public List<ValueLink_OrderComments_Model> processXML(Dom.XmlNode inputNode){
        List<ValueLink_OrderComments_Model> responseModel = new List<ValueLink_OrderComments_Model>();
        Dom.XmlNode payloadStatus = inputNode.getChildElement('Status',null);
        Dom.XmlNode payloadError = inputNode.getChildElement('ErrorCode',null);
        Dom.XmlNode payloadOrderComments = inputNode.getChildElement('VLOrderComments',null);
        for(Dom.XmlNode orderCommentNode : payloadOrderComments.getChildren()){
            ValueLink_OrderComments_Model orderComment = new ValueLink_OrderComments_Model();
            orderComment.orderNumber = orderCommentNode.getChildElement('OrderNumber',null).getText();
            orderComment.orderId = orderCommentNode.getChildElement('OrderID',null).getText();
            orderComment.commentId = orderCommentNode.getChildElement('CommentID',null).getText();
            orderComment.comment = orderCommentNode.getChildElement('Comment',null).getText();
            orderComment.userTypeName = orderCommentNode.getChildElement('UserTypeName',null).getText();
            orderComment.createdBy = orderCommentNode.getChildElement('CreatedBy',null).getText();
            orderComment.isRead = orderCommentNode.getChildElement('IsRead',null).getText() == 'true' ? true : false;
            orderComment.accessibleByAppraiser = orderCommentNode.getChildElement('AccessibleByAppraiser',null).getText() == 'true' ? true : false;
            orderComment.accessibleByLender = orderCommentNode.getChildElement('AccessibleByLender',null).getText() == 'true' ? true : false;
            orderComment.createdOn = orderCommentNode.getChildElement('CreatedOn',null).getText();
            responseModel.add(orderComment);
        }
        return responseModel;
    }
}