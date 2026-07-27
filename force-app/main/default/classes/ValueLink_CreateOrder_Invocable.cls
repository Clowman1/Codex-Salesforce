/**
 * Created by toma on 12/1/2022.
 */

public class ValueLink_CreateOrder_Invocable {
@InvocableMethod(label='create value link appraisal order')
    public static void createOrder(List<String> loanIDs){
    makeCall(loanIDs);
}
    public static void makeCall(List<String> loanIds){
        ValueLinkController.createDTORequest(loanIds[0]);
    }
}