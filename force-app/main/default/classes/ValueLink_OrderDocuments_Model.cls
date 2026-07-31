/**
 * Created by toma on 11/1/2022.
 */

public class ValueLink_OrderDocuments_Model implements ValueLink_ModelToMap{
    public String orderId;
    public String orderNumber;
    public String orderDocumentId;
    public String documentTypeName;
    public String documentFileName;
    public String orderDocument;
    public Boolean accessibleByClient;
    public Boolean accessibleByAppraiser;
    public String documentSubmittedOn;
    public String documentSubmittedBy;

    public Map<String, Object> getModelMap(){
        Map<string,Object> output = new Map<string,Object>();
        output.put('orderId',orderId);
        output.put('orderNumber',orderNumber);
        output.put('orderDocumentId',orderDocumentId);
        output.put('documentTypeName',documentTypeName);
        output.put('documentFileName',documentFileName);
        output.put('orderDocument',orderDocument);
        output.put('accessibleByClient',accessibleByClient);
        output.put('accessibleByAppraiser',accessibleByAppraiser);
        output.put('documentSubmittedOn',documentSubmittedOn);
        output.put('documentSubmittedBy',documentSubmittedBy);
        return output;
    }
}