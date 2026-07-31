public without sharing class RingCentralAuthCallbackController {   
    
    private RingCentral_Credentials__c  credentials = RingCentral_Credentials__c.getOrgDefaults();
    private final String CLIENT_ID = credentials.Client_Id__c; 
    private final String CLIENT_SECRET = credentials.Client_Secret__c;
    private final String REDIRECT_URI = credentials.Redirect_Uri__c;
    
    public String resultJson { get; set; }
    public String code  { get; set; }
    public String state  { get; set; }

    public RingCentralAuthCallbackController() {
       	this.code = ApexPages.currentPage().getParameters().get('code');
        this.state = ApexPages.currentPage().getParameters().get('state');
        
        if (String.isBlank(code)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'No authorization code received.'));
            return;
        }
    }
    
    public void updateTokens() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://platform.ringcentral.com/restapi/oauth/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        // TODO replace
        String clientId     = CLIENT_ID;
        String clientSecret = CLIENT_SECRET;
        String redirectUri  = REDIRECT_URI;
        // END 
        
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64encode(Blob.valueOf(clientId + ':' + clientSecret)));
        
        String body = 'grant_type=authorization_code'
            + '&code=' + EncodingUtil.urlEncode(code, 'UTF-8')
            + '&redirect_uri=' + redirectUri;
        req.setBody(body);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 200) {
            //resultJson = 'Token request failed: ' + res.getBody();
            return;
        }
        
        // Parse JSON response
        Map<String, Object> tokenResp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String accessToken  = (String) tokenResp.get('access_token');
        String refreshToken = (String) tokenResp.get('refresh_token');
        
        if (String.isBlank(accessToken) || String.isBLank(refreshToken)) {
            //resultJson = 'No Access/Refresh Token';
            return;
        }

        try {
			User u = [SELECT Id, Name, RingCentral_Access_Token__c, RingCentral_Refresh_Token__c FROM User WHERE Id = :state];
            u.RingCentral_Access_Token__c = accessToken;
            u.RingCentral_Refresh_Token__c = refreshToken;
            u.RingCentral_Access_Token_DateTime__c = DateTime.now();
            u.RingCentral_Refresh_Token_DateTime__c = DateTime.now();
            update u;
            
            resultJson = 'Success';
        } catch (Exception e) {
            //resultJson = e.getMessage();
        }
        
    }
}