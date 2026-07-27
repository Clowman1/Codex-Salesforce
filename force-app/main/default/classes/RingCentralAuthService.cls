public class RingCentralAuthService {
    private RingCentral_Credentials__c  credentials = RingCentral_Credentials__c.getOrgDefaults();
    private final String CLIENT_ID = credentials.Client_Id__c; 
    private final String CLIENT_SECRET = credentials.Client_Secret__c;
    private User user;
    
    public RingCentralAuthService(String userId) {
        this.user = [SELECT Id,	RingCentral_Access_Token__c, RingCentral_Access_Token_DateTime__c, RingCentral_Access_Token_Expired__c,
                     			RingCentral_Refresh_Token__c, RingCentral_Refresh_Token_DateTime__c, RingCentral_Refresh_Token_Expired__c
                     FROM User
                     WHERE Id = :userId
                     LIMIT 1];
    }
    
    public Boolean isNeverAuthenticated() {
        return String.isBlank(user.RingCentral_Refresh_Token__c);
    }
   
    public Boolean isAuthenticated() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://platform.ringcentral.com/restapi/v1.0/account/~/extension/~');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + user.RingCentral_Access_Token__c);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        return res.getStatusCode() == 200;
    }
    
    public String getAccessToken() {
        if (user.RingCentral_Access_Token_Expired__c || !isAuthenticated()) {
            refreshTokens();
        }
        
        return this.user.RingCentral_Access_Token__c;
    }
    
    public void refreshTokens() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://platform.ringcentral.com/restapi/oauth/token');
        req.setMethod('POST');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64encode(Blob.valueOf(CLIENT_ID + ':' + CLIENT_SECRET)));
        
        String body = 'grant_type=refresh_token'
            + '&refresh_token=' + EncodingUtil.urlEncode(nullToEmpty(user.RingCentral_Refresh_Token__c), 'UTF-8')
            + '&client_id=' + EncodingUtil.urlEncode(nullToEmpty(CLIENT_ID), 'UTF-8');
        req.setBody(body);
        
        Http http = new Http();
        HttpResponse res = http.send(req); 
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> jsonRes = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            user.RingCentral_Access_Token__c = (String) jsonRes.get('access_token');
            user.RingCentral_Refresh_Token__c = (String) jsonRes.get('refresh_token');
            
            user.RingCentral_Access_Token_DateTime__c = DateTime.now();
            user.RingCentral_Refresh_Token_DateTime__c = DateTime.now();
        } else {
           	throw new RingCentralAuthServiceException('Failed to update credentials. Status '
                + res.getStatusCode() + ': ' + res.getBody());
        }
    }
    
    public void commitUpdates() {
        update user;
    }
    
    public class RingCentralAuthServiceException extends Exception {}

    private static String nullToEmpty(String value) {
        return value == null ? '' : value;
    }
    
}