public with sharing class LeadDocumentPortalController {
    @AuraEnabled
    public static LeadDocumentPortalService.PortalData initializeData(String hashFromURL, Boolean isInSitePreview) {
        try {
            return LeadDocumentPortalService.initializeData(hashFromURL, isInSitePreview);
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static LeadDocumentPortalService.PortalRequest updateRequestOnFileUpload(
        List<Id> contentVersionIds,
        Id requestId,
        String hashFromURL
    ) {
        try {
            return LeadDocumentPortalService.updateRequestOnFileUpload(contentVersionIds, requestId, hashFromURL);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                'LeadDocumentPortalController.updateRequestOnFileUpload failed for requestId=' +
                requestId + ' hash=' + hashFromURL + ' versions=' + contentVersionIds + ' :: ' +
                ex.getTypeName() + ': ' + ex.getMessage() + '\n' + ex.getStackTraceString()
            );
            throw new AuraHandledException(ex.getTypeName() + ': ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static void sendGenericDocumentUpload(List<Id> contentVersionIds, String hashFromURL) {
        try {
            LeadDocumentPortalService.handleGenericUpload(contentVersionIds, hashFromURL);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR,
                'LeadDocumentPortalController.sendGenericDocumentUpload failed for hash=' +
                hashFromURL + ' versions=' + contentVersionIds + ' :: ' + ex.getTypeName() + ': ' +
                ex.getMessage() + '\n' + ex.getStackTraceString()
            );
            throw new AuraHandledException(ex.getTypeName() + ': ' + ex.getMessage());
        }
    }
}