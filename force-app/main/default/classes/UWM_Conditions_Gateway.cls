/**
 * Created by toma on 11/9/2022.
 */

public with sharing class UWM_Conditions_Gateway {
    public static UWM_Conditions_API_Res_Model getLoanConditions(String uwmLoanId){
        UWM_Conditions_API.GetLoanConditions getConditions = new UWM_Conditions_API.GetLoanConditions(uwmLoanId);
        return getConditions.consume();
    }
}