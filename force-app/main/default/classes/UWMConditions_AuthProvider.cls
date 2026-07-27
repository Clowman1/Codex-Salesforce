/**
 * Auth provider for the UWM Conditions API named credential.
 */
public with sharing class UWMConditions_AuthProvider extends Auth.AuthProviderPluginClass {
    public static String currentOwnerId;

    private static final String SETTINGS_DEVELOPER_NAME = 'UWM_ConditionsAuth';
    private static final String TOKEN_ENDPOINT = 'https://login.microsoftonline.com/13d3189d-22a4-4f96-bbc9-2af46c222581/oauth2/v2.0/token';
    private static final String CONDITIONS_SCOPE = 'https://api.uwm.com/loan/.default';
    private static final String CONDITIONS_AUDIENCE = 'https://amc-api-dev.anow.com';

    public String getCustomMetadataType() {
        return 'UWM_InsightsAuthSettings__mdt';
    }

    public Auth.UserData getUserInfo(Map<String, String> authProviderConfiguration, Auth.AuthProviderTokenResponse response) {
        return new Auth.UserData(null, null, null, null, null, null, null, null, null, null, null);
    }

    public Auth.AuthProviderTokenResponse handleCallback(Map<String, String> config, Auth.AuthProviderCallbackState state) {
        TokenResponse response = refreshToken(config);
        return new Auth.AuthProviderTokenResponse(
            config.get('AuthProviderName__c'),
            response.getAccessToken(),
            config.get('ClientSecret__c'),
            state.queryParameters.get('state')
        );
    }

    public PageReference initiate(Map<String, String> config, String state) {
        final PageReference pageRef = new PageReference(URL.getOrgDomainUrl().toExternalForm() + '/services/authcallback/UWM_ConditionsAuth'); //NOSONAR
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
            WHERE DeveloperName = :SETTINGS_DEVELOPER_NAME
            LIMIT 1
        ];

        return requestToken(settings.ClientSecret__c, settings.AuthProviderName__c);
    }

    private static TokenResponse refreshToken(Map<String, String> config) {
        String clientId = config.get('ClientSecret__c');
        String clientSecret = config.get('AuthProviderName__c');

        if (String.isBlank(clientId) || String.isBlank(clientSecret)) {
            return refreshToken();
        }

        return requestToken(clientId, clientSecret);
    }

    private static TokenResponse requestToken(String clientId, String clientSecret) {
        HttpRequest request = new HttpRequest();
        String authHeader = EncodingUtil.base64Encode(Blob.valueOf(clientId + ':' + clientSecret));

        String payload = 'grant_type='
            + EncodingUtil.urlEncode('client_credentials', 'UTF-8')
            + '&scope='
            + EncodingUtil.urlEncode(CONDITIONS_SCOPE, 'UTF-8')
            + '&audience='
            + EncodingUtil.urlEncode(CONDITIONS_AUDIENCE, 'UTF-8');

        request.setBody(payload);
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        request.setHeader('Authorization', 'Basic ' + authHeader);
        request.setEndpoint(TOKEN_ENDPOINT);
        request.setMethod('POST');

        HttpResponse response = new Http().send(request);
        return (TokenResponse)JSON.deserialize(response.getBody(), TokenResponse.class);
    }

    public class TokenResponse {
        public String access_token; //NOPMD - External API response property.
        public String token_type; //NOPMD - External API response property.

        public String getAccessToken() {
            return this.access_token;
        }

        public String getTokenType() {
            return this.token_type;
        }
    }
}
