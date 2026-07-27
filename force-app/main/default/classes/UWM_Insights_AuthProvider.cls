global class UWM_Insights_AuthProvider extends Auth.AuthProviderPluginClass {

    global String getCustomMetadataType() {
        return 'UWM_InsightsAuthSettings__mdt';
    }

    global Auth.UserData getUserInfo(Map<String, String> authProviderConfiguration, Auth.AuthProviderTokenResponse response) {
        return new Auth.UserData(null, null, null, null, null, null, null, null, null, null, null);
    }

    global Auth.AuthProviderTokenResponse handleCallback(Map<String, String> config, Auth.AuthProviderCallbackState state) {
        TokenResponse response = refreshToken(config);
        return new Auth.AuthProviderTokenResponse(
                config.get('AuthProviderName__c'),
                response.getAccessToken(),
                config.get('ClientSecret__c'),
                state.queryParameters.get('state')
        );
    }

    global PageReference initiate(Map<String, String> config, String state) {
        final PageReference pageRef = new PageReference(URL.getSalesforceBaseUrl().toExternalForm() + '/services/authcallback/UWM_InsightsOAuth'); //NOSONAR
        pageRef.getParameters().put('state', state);
        pageRef.getParameters().put('code', '999');
        return pageRef;
    }

    public override Auth.OAuthRefreshResult refresh(Map<String, String> config, String refreshToken) {
        TokenResponse response = refreshToken(config);
        return new Auth.OAuthRefreshResult(response.getAccessToken(), response.getTokenType(), null);
    }

    public static TokenResponse refreshToken() {
        UWM_InsightsAuthSettings__mdt settings = [
            SELECT ClientSecret__c, AuthProviderName__c
            FROM UWM_InsightsAuthSettings__mdt
            WHERE DeveloperName = 'UWM_InsightsOAuth'
            LIMIT 1
        ];
        return requestToken(settings.ClientSecret__c, settings.AuthProviderName__c);
    }

    private static TokenResponse refreshToken(Map<String, String> config) {
        return requestToken(config.get('ClientSecret__c'), config.get('AuthProviderName__c'));
    }

    private static TokenResponse requestToken(String clientId, String clientSecret) {
        String authHeader = EncodingUtil.base64Encode(Blob.valueOf(clientId + ':' + clientSecret));

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        String payload = 'grant_type=' + EncodingUtil.urlEncode('client_credentials', 'UTF-8') + 
                         '&scope=' + EncodingUtil.urlEncode('api://5260c3e4-e629-4b1c-b26d-3bb08407fc75/.default', 'UTF-8') + 
                         '&audience=' + EncodingUtil.urlEncode('https://amc-api-dev.anow.com', 'UTF-8');
        request.setBody(payload);
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setHeader('Authorization', 'Basic ' + authHeader);
        request.setEndpoint('https://login.microsoftonline.com/13d3189d-22a4-4f96-bbc9-2af46c222581/oauth2/v2.0/token');
        request.setMethod('POST');

        HttpResponse response = http.send(request);

        return (TokenResponse)JSON.deserialize(response.getBody(), TokenResponse.class);
    }

    public class TokenResponse {
        public String access_token;
        public String token_type;

        public String getAccessToken() {
            return this.access_token;
        }

        public String getTokenType() {
            return this.token_type;
        }
    }
}
