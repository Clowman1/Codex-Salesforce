public class ValueLinkContractPostQueueable implements Queueable, Database.AllowsCallouts {
    private Id loanId;
    private String orderId;
    private List<String> contentDocumentIds;
    private String apiUsername;
    private String apiPassword;

    public ValueLinkContractPostQueueable(
        Id loanId,
        String orderId,
        List<String> contentDocumentIds,
        String apiUsername,
        String apiPassword
    ) {
        this.loanId = loanId;
        this.orderId = orderId;
        this.contentDocumentIds = contentDocumentIds == null ? new List<String>() : contentDocumentIds;
        this.apiUsername = apiUsername;
        this.apiPassword = apiPassword;
    }

    public void execute(QueueableContext context) {
        Set<Id> documentIds = new Set<Id>();
        for (String contentDocumentId : contentDocumentIds) {
            if (String.isNotBlank(contentDocumentId)) {
                documentIds.add((Id) contentDocumentId);
            }
        }
        if (documentIds.isEmpty() || String.isBlank(orderId)) {
            return;
        }

        List<ValueLink_Log__c> logs = new List<ValueLink_Log__c>();
        for (ContentVersion contractVersion : [
            SELECT Id, ContentDocumentId, Title, FileExtension, VersionData
            FROM ContentVersion
            WHERE IsLatest = true
            AND ContentDocumentId IN :documentIds
            ORDER BY CreatedDate DESC
        ]) {
            if (String.valueOf(contractVersion.FileExtension).toLowerCase() != 'pdf') {
                continue;
            }
            String fileName = contractVersion.Title;
            if (!fileName.toLowerCase().endsWith('.pdf')) {
                fileName += '.pdf';
            }

            ValueLinkSoapService_PostDocument.RequestModel req = new ValueLinkSoapService_PostDocument.RequestModel();
            req.orderId = orderId;
            req.fileName = fileName;
            req.fileData = EncodingUtil.base64Encode(contractVersion.VersionData);
            ValueLinkSoapService_PostDocument.sendDocument(apiUsername, apiPassword, req);

            logs.add(new ValueLink_Log__c(
                Transaction__c = loanId,
                Order_ID__c = orderId,
                Event_Type__c = 'Contract PDF Posted',
                Processing_Status__c = 'Processed',
                Content_Document_ID__c = contractVersion.ContentDocumentId,
                Content_Version_ID__c = contractVersion.Id,
                Document_File_Name__c = fileName,
                Payload__c = 'Contract PDF posted to ValueLink during appraisal order creation.'
            ));
        }
        if (!logs.isEmpty()) {
            insert logs;
        }
    }
}
