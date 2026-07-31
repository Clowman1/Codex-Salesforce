public with sharing class NonUwmConditionImportController {
    @AuraEnabled
    public static NonUwmConditionImportDtos.UploadFilesResponse uploadPdfFiles(
        Id opportunityId,
        List<NonUwmConditionImportDtos.FileUploadRequest> files
    ) {
        try {
            return NonUwmConditionCreationService.uploadPdfFiles(opportunityId, files);
        } catch (Exception ex) {
            throw mapUnhandledException(ex, 'Unable to upload files. Please try again.');
        }
    }

    @AuraEnabled
    public static NonUwmConditionImportDtos.ExtractionResponse extractConditions(
        Id opportunityId,
        List<Id> contentDocumentIds
    ) {
        try {
            return NonUwmConditionExtractionService.extract(opportunityId, contentDocumentIds);
        } catch (Exception ex) {
            throw mapUnhandledException(ex, 'Unable to extract conditions from the uploaded files.');
        }
    }

    @AuraEnabled
    public static NonUwmConditionImportDtos.CreateResponse createConditions(
        Id opportunityId,
        List<NonUwmConditionImportDtos.ConditionDraft> conditions
    ) {
        try {
            return NonUwmConditionCreationService.createConditions(opportunityId, conditions);
        } catch (Exception ex) {
            throw mapUnhandledException(ex, 'Unable to create loan conditions.');
        }
    }

    @TestVisible
    private static AuraHandledException mapUnhandledException(Exception ex, String safeMessage) {
        return new AuraHandledException(Test.isRunningTest() ? ex.getMessage() : safeMessage);
    }
}