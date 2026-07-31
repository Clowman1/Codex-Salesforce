/**
 * Created by toma on 11/9/2022.
 */

public with sharing class UWM_Conditions_API {
    public final static String BASE_URL = 'callout:UWMConditions';
    public final static String CONDITIONS_ENDPOINT = '/{0}/conditions';

    public class GetLoanConditions extends Consumer{
        public GetLoanConditions(String loanNumber){
			super(
                String.format(BASE_URL + CONDITIONS_ENDPOINT, new List<String>{loanNumber}),
                'GET'
            );
        }
        public UWM_Conditions_API_Res_Model consume(){
            send();
            UWM_Conditions_API_Res_Model res = (UWM_Conditions_API_Res_Model) JSON.deserialize(this.response.getBody(),UWM_Conditions_API_Res_Model.class);
            res.flatten();
            return res;
        }
    }
    public virtual class Consumer extends RestApiConsumer {
        public Consumer(String endpoint, String method){
            super(endpoint,method);
        }
    }
    private class UWM_Conditions_API_Exception extends Exception{}
}