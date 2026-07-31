/**
 * Created by toma on 10/31/2022.
 */

public class ValueLink_InspectionRequest_Model implements ValueLink_ModelToMap{
    public String orderId;
    public String orderNumber;
    public String inspectionScheduledAt;
    public String inspectionCompleteAt;
    public String estimatedCompletionTime;
    public String comment;

    public Map<String, Object> getModelMap(){
        Map<string,Object> output = new Map<string,Object>();
        output.put('orderId',orderId);
        output.put('orderNumber',orderNumber);
        if(inspectionCompleteAt != null){
            output.put('inspectionCompleteAt',inspectionCompleteAt);
        }else if(inspectionScheduledAt != null){
            output.put('inspectionScheduledAt',inspectionScheduledAt);
        }
        output.put('estimatedCompletionTime',estimatedCompletionTime);
        output.put('comment',comment);
        return output;
    }
}