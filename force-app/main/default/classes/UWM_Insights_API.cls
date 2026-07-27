public class UWM_Insights_API {
	 public final static String BASE_URL = 'callout:UWMInsights';
    public interface IConsumer extends IApiConsumer { 
        String consume(); 
    }
    public class GraphQLQueryRequest extends Consumer{ 
        public GraphQLQueryRequest(String query){
            super( BASE_URL, 'POST');
            this.request.setHeader('content-type','application/json');
            this.request.setTImeout(120000);
            this.request.setBody(query); 
        }
        public override String consume(){
            System.debug(this.request.getBody());
            send();
            return this.response.getBody();
        }
    }
    public virtual class Consumer extends RestApiConsumer implements IConsumer{
        public Consumer(String endpoint, String method){
            super(endpoint,method);
        }
        public virtual String consume(){
            send();
            return this.response.getBody();
        }
    }
    private class UWM_Insights_API_Exception extends Exception{}
}