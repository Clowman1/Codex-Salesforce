public abstract class RestApiConsumer{ 
    protected HttpRequest request = new HttpRequest();
    protected HttpResponse response = new HttpResponse();
    private Http http = new Http();
    protected IAuthenticationStrategy authStrategy;
    private final Integer SUCCESS_RESPONSE_UPPER_LIMIT = 299, SUCCESS_RESPONSE_LOWER_LIMIT = 200;
    public interface IAuthenticationStrategy{
        Map<String,Object> authenticate();
    }
    public RestApiConsumer(String endpoint, String method){
        this.request.setEndpoint(endpoint);
        this.request.setMethod(method);
    }
    private void setHeaders(Map<String,Object> headers){
        for(String header : headers.keySet()){
            this.request.setHeader(header, (String)headers.get(header));
        }
    }
	/*
    public virtual void send(){
        Datetime requestTime,responseTime;
        if(this.authStrategy != null){
            Map<String,Object> headers = this.authStrategy.authenticate();
            this.setHeaders(headers);
        }
        try{
            requestTime=Datetime.now();
            System.debug(LoggingLevel.FINEST,
                    '\nREQUEST PAYLOAD GOING OUT AS ' + this.request.getMethod()  + '\n'
                    + ' TO ' +this.request.getEndpoint()  + '\n'
                    + 'WITH PAYLOAD: ' + JSON.serializePretty(JSON.deserializeUntyped(this.request.getBody())) + '\n'
            );

            this.response = http.send(this.request);
            responseTime=Datetime.now();
            checkStatusCode();
        }catch(HttpException e){
            System.debug('There was an unexpected response from the server: \n' + e.getMessage());
            throw e;
        }finally{
            //Log.addMessage(new HttpLogMessage('Log Created for ' + this.request.getEndpoint(), this.request, requestTime, this.response, responseTime));
        }
    }
	*/ 
	 class Payload{
        Object body;

        Payload(Object body){
            this.body = body;
        }
    }
	public virtual void send(){
        Datetime requestTime,responseTime;
        if(this.authStrategy != null){
            Map<String,Object> headers = this.authStrategy.authenticate();
            this.setHeaders(headers);
        }
        try{
            Payload p = new Payload(this.request.getBody());
            requestTime=Datetime.now(); 
            System.debug(LoggingLevel.FINEST,
                    '\nREQUEST PAYLOAD GOING OUT AS ' + this.request.getMethod()  + '\n'
                            + ' TO ' +this.request.getEndpoint()  + '\n' 
                            + 'WITH PAYLOAD: ' + JSON.serializePretty(p) + '\n'
            );

            this.response = http.send(this.request);
            responseTime=Datetime.now();
            checkStatusCode(); 
        }catch(HttpException e){
            System.debug('There was an unexpected response from the server: \n' + e.getMessage());
            throw e;
        }finally{
            //Log.addMessage(new HttpLogMessage('Log Created for ' + this.request.getEndpoint(), this.request, requestTime, this.response, responseTime));
        }
    } 
    private void checkStatusCode(){
        if(this.response.getStatusCode() > SUCCESS_RESPONSE_UPPER_LIMIT || this.response.getStatusCode() < SUCCESS_RESPONSE_LOWER_LIMIT){
            throw new HttpException(  this.request,this.response,'Status Code Reported Error - StatusCode: ' + this.response.getStatusCode() + ' -- response payload: '+  this.response.getBody());
        }
    }
    public class HttpException extends Exception{
        private HttpResponse response;
        private HttpRequest request;

        public HttpException(HttpRequest request, HttpResponse response, String message){
            this.setMessage(message);
            this.request = request;
            this.response = response;
        }
        public HttpResponse getResponse(){
            return this.response;
        }
        public HttpRequest getRequest(){
            return this.request;
        }
    }
    //TODO: ADD LOGGER
   /* public class HttpLogMessage extends Log.LogMessage{
        public HttpLogMessage(Log__c log){
            super(log);
        }
        public HttpLogMessage(String message, HttpRequest request,DateTime requestTime, HttpResponse response, Datetime responseTime){
            super(message);
            this.log.Method__c = request.getMethod();
            this.log.StatusCode__c = response.getStatusCode();
            this.log.RequestPayload__c = request.getBody();
            this.log.ResponsePayload__c = response.getBody();
            this.log.RequestTime__c = requestTime;
            this.log.ResponseTime__c = responseTime;
        }
    }*/
}