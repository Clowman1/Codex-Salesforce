public with sharing class LeadDocumentRequestController {
    @AuraEnabled
    public static LeadDocumentRequestService.LeadDocumentRequestData initializeData(Id leadId) {
        return LeadDocumentRequestService.initializeInternalData(leadId);
    }

    @AuraEnabled
    public static List<LeadDocumentRequestService.RequestItem> saveRequests(
        Id leadId,
        List<LeadDocumentRequestService.RequestInput> requests
    ) {
        return LeadDocumentRequestService.saveRequests(leadId, requests);
    }

    @AuraEnabled
    public static void deleteRequest(Id requestId) {
        LeadDocumentRequestService.deleteRequest(requestId);
    }

    @AuraEnabled
    public static LeadDocumentRequestService.RequestItem saveNotes(
        Id requestId,
        String description,
        String internalNotes
    ) {
        return LeadDocumentRequestService.saveNotes(requestId, description, internalNotes);
    }

    @AuraEnabled
    public static LeadDocumentRequestService.RequestItem addComment(
        Id requestId,
        String commentText,
        Boolean publicComment
    ) {
        return LeadDocumentRequestService.addComment(requestId, commentText, publicComment);
    }

    @AuraEnabled
    public static LeadDocumentRequestService.RequestItem handleInternalFileUpload(
        Id requestId,
        List<Id> contentVersionIds
    ) {
        return LeadDocumentRequestService.handleInternalFileUpload(requestId, contentVersionIds);
    }

    @AuraEnabled(cacheable=true)
    public static List<LeadDocumentRequestService.DocumentItem> getRequestDocuments(Id requestId) {
        return LeadDocumentRequestService.getRequestDocuments(requestId);
    }

    @AuraEnabled
    public static LeadDocumentRequestService.RequestItem approveRequestDocument(
        Id requestId,
        Id contentDocumentId
    ) {
        return LeadDocumentRequestService.approveRequestDocument(requestId, contentDocumentId);
    }

    @AuraEnabled
    public static LeadDocumentRequestService.RequestItem rejectRequestDocument(
        Id requestId,
        Id contentDocumentId,
        String rejectionReason,
        String updatedRequestDescription
    ) {
        return LeadDocumentRequestService.rejectRequestDocument(
            requestId,
            contentDocumentId,
            rejectionReason,
            updatedRequestDescription
        );
    }

    @AuraEnabled
    public static LeadDocumentRequestService.EmailInformation getEmailPreview(Id leadId) {
        return LeadDocumentRequestService.getEmailPreview(leadId);
    }

    @AuraEnabled(cacheable=true)
    public static List<LeadDocumentRequestService.EmailTemplateOption> getEmailTemplateOptions() {
        return LeadDocumentRequestService.getEmailTemplateOptions();
    }

    @AuraEnabled
    public static LeadDocumentRequestService.EmailInformation getEmailTemplatePreview(
        Id leadId,
        String templateDeveloperName
    ) {
        return LeadDocumentRequestService.getEmailTemplatePreview(leadId, templateDeveloperName);
    }

    @AuraEnabled
    public static void sendRequestEmail(Id leadId) {
        LeadDocumentRequestService.sendRequestEmail(leadId);
    }

    @AuraEnabled
    public static void sendEditedRequestEmail(Id leadId, String subject, String htmlBody) {
        LeadDocumentRequestService.sendEditedRequestEmail(leadId, subject, htmlBody);
    }
}