public without sharing class LeadDocumentPortalRedirectController {
    @TestVisible
    private static String testLeadHomeUrlOverride;

    public PageReference redirect() {
        String portalHash = ApexPages.currentPage().getParameters().get('id');
        String redirectUrl = buildLeadPortalUrl(portalHash);

        if (String.isNotBlank(portalHash)) {
            String convertedRedirectUrl = buildConvertedTransactionRedirectUrl(portalHash);
            if (String.isNotBlank(convertedRedirectUrl)) {
                redirectUrl = convertedRedirectUrl;
            }
        }

        if (String.isBlank(redirectUrl)) {
            return null;
        }
        PageReference redirectPage = new PageReference(redirectUrl);
        redirectPage.setRedirect(true);
        return redirectPage;
    }

    private static String buildConvertedTransactionRedirectUrl(String portalHash) {
        List<Lead> leadRecords = [
            SELECT Id, Converted_Transaction_ID__c
            FROM Lead
            WHERE Portal_Hash_Parameter__c = :portalHash
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (leadRecords.isEmpty() || leadRecords[0].Converted_Transaction_ID__c == null) {
            return null;
        }

        List<Transaction__c> transactionRecords = [
            SELECT Id, Portal_Hash_Parameter__c
            FROM Transaction__c
            WHERE Id = :leadRecords[0].Converted_Transaction_ID__c
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (transactionRecords.isEmpty() || String.isBlank(transactionRecords[0].Portal_Hash_Parameter__c)) {
            return null;
        }

        return buildBorrowerPortalUrl(transactionRecords[0].Portal_Hash_Parameter__c);
    }

    private static String buildBorrowerPortalUrl(String portalHash) {
        if (String.isBlank(portalHash)) {
            return null;
        }

        BorrowerPortalSettings__c defaults = BorrowerPortalSettings__c.getOrgDefaults();
        if (defaults == null || String.isBlank(defaults.Borrower_Home_Url__c)) {
            return null;
        }

        return appendQueryParameter(defaults.Borrower_Home_Url__c.trim(), 'id', portalHash.trim());
    }

    @TestVisible
    private static String buildLeadPortalUrl(String portalHash) {
        if (String.isBlank(portalHash)) {
            return null;
        }

        String leadHomeUrl = getConfiguredLeadHomeUrl();
        if (String.isBlank(leadHomeUrl)) {
            return null;
        }

        return appendQueryParameter(leadHomeUrl.trim(), 'id', portalHash.trim());
    }

    private static String getConfiguredLeadHomeUrl() {
        if (Test.isRunningTest() && testLeadHomeUrlOverride != null) {
            return testLeadHomeUrlOverride;
        }
        if (!BorrowerPortalSettings__c.SObjectType.getDescribe().fields.getMap().containsKey('Lead_Borrower_Home_Url__c')) {
            return null;
        }

        BorrowerPortalSettings__c defaults = BorrowerPortalSettings__c.getOrgDefaults();
        return defaults == null ? null : (String) defaults.get('Lead_Borrower_Home_Url__c');
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