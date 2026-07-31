/**
 * Created by toma on 10/31/2022.
 */

public class ValueLink_OrderComments_Model implements ValueLink_ModelToMap{
    public String orderId;
    public String orderNumber;
    public String commentId;
    public String comment;
    public String userTypeName;
    public Boolean isRead;
    public Boolean accessibleByLender;
    public Boolean accessibleByAppraiser;
    public String createdOn;
    public String createdBy;

    public Map<String, Object> getModelMap(){
        Map<string,Object> output = new Map<string,Object>();
        output.put('orderId',orderId);
        output.put('orderNumber',orderNumber);
        output.put('commentId',commentId);
        output.put('comment',comment);
        output.put('userTypeName',userTypeName);
        output.put('isRead',isRead);
        output.put('accessibleByLender',accessibleByLender);
        output.put('accessibleByAppraiser',accessibleByAppraiser);
        output.put('createdOn',createdOn);
        output.put('createdBy',createdBy);
        return output;
    }
}