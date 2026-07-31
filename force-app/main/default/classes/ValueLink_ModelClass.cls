/**
 * Created by toma on 11/1/2022.
 */

public abstract class ValueLink_ModelClass {
    public String orderId;
    public String orderNumber;
    public abstract Map<String,Object> extractFieldValues();
    public void mapCommonFields(){
        extractFieldValues().put('ValueLink_Order_ID__c',orderId);
        extractFieldValues().put('ValueLink_Order_Number__c',orderNumber);
    }
}