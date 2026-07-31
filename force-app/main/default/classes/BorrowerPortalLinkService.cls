public with sharing class BorrowerPortalLinkService {
    @TestVisible
    private static String testBorrowerHomeUrlOverride;

    public static String buildBorrowerHomeUrl(String portalHash) {
        if (String.isBlank(portalHash)) {
            return null;
        }

        String configuredUrl = getConfiguredBorrowerHomeUrl();
        if (String.isBlank(configuredUrl)) {
            return null;
        }

        return appendQueryParameter(configuredUrl.trim(), 'id', portalHash.trim());
    }

    @TestVisible
    private static String getConfiguredBorrowerHomeUrl() {
        if (Test.isRunningTest() && testBorrowerHomeUrlOverride != null) {
            return testBorrowerHomeUrlOverride;
        }

        BorrowerPortalSettings__c defaults = BorrowerPortalSettings__c.getOrgDefaults();
        return defaults == null ? null : defaults.Borrower_Home_Url__c;
    }

    private static String appendQueryParameter(String url, String parameterName, String parameterValue) {
        String separator = url.contains('?') ? '&' : '?';
        return url
            + separator
            + EncodingUtil.urlEncode(parameterName, 'UTF-8')
            + '='
            + EncodingUtil.urlEncode(parameterValue, 'UTF-8');
    }
}