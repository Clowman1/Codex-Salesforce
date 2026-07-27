public class RingCentralUserAuthController {
    
    // Hardcoded for now, will update later
    private static RingCentral_Credentials__c  credentials = RingCentral_Credentials__c.getOrgDefaults();
    private static final String CLIENT_ID = credentials.Client_Id__c;
    private static final String REDIRECT_URI = credentials.Redirect_URI__c;
    
    public class UserAuthUrlWrapper {
        @AuraEnabled public String Id { get; set; }
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public Boolean IsLoggedIn { get; set; }
        @AuraEnabled public String AuthUrl { get; set; }
        
        public UserAuthUrlWrapper(String id, String name, String url, Boolean IsLoggedIn) {
            this.Id = id;
            this.Name = name;
            this.AuthUrl = url;
            this.IsLoggedIn = IsLoggedIn;
        }
    }
    
    @AuraEnabled
    public static List<UserAuthUrlWrapper> getUsersWithAuthUrl() {
        List<UserAuthUrlWrapper> results = new List<UserAuthUrlWrapper>();
        List<User> users = [SELECT Id, RingCentral_Refresh_Token_DateTime__c, Name FROM User WHERE Id = :UserInfo.getUserId()];
        Profile profile = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
        if (profile.Name.equals('System Administrator')) {
            users = [SELECT Id, RingCentral_Refresh_Token_DateTime__c, Name FROM User WHERE IsActive = true AND Profile.Name IN ('System Administrator', 'Loan Officer Profile', 'Processor Profile', 'Processor Profile (SF)', 'Manager') ORDER BY Name];
        }
        
        for (User u : users) {
            RingCentralAuthService service = new RingCentralAuthService(u.Id);
            Boolean isLoggedIn = u.RingCentral_Refresh_Token_DateTime__c != NULL && u.RingCentral_Refresh_Token_DateTime__c >= DateTime.now().addDays(-4);
            
            String encodedRedirect = null; 
            if (Test.isRunningTest()) {
                encodedRedirect = '';
            } else {
                encodedRedirect = EncodingUtil.urlEncode(REDIRECT_URI, 'UTF-8');
            }
            
            
            String url = 'https://platform.ringcentral.com/restapi/oauth/authorize'
                + '?client_id=' + CLIENT_ID
                + '&redirect_uri=' + encodedRedirect
                + '&response_type=code'
                + '&state=' + EncodingUtil.urlEncode(u.Id, 'UTF-8');
            results.add(new UserAuthUrlWrapper(u.Id, u.Name, url, isLoggedIn));
        }
        return results;
    }
}