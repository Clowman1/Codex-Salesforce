@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class LoanConditionController {
    public static PersistenceStrategy.BulkifiedSave strategy = new PersistenceStrategy.BulkifiedSave();

    public class DataWrapper {
        @AuraEnabled
        public List<TransactionCondition> conditions;

        @AuraEnabled
        public Transaction__c application;

        public DataWrapper(List<TransactionCondition> conditions, Loan loan) {
            this.conditions = conditions;
            if (loan != null) {
                this.application = loan.getData();
            }
        }
    }

    public class EmailInformation {
        @AuraEnabled
        public String subject;

        @AuraEnabled
        public String htmlBody;

        public EmailInformation(Messaging.SingleEmailMessage message) {
            this.subject = message.getSubject();
            this.htmlBody = message.getHtmlBody();
        }
    }

    public class ConditionFieldDescription {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean isEditable;
        @AuraEnabled public Boolean isUserLookup;

        public ConditionFieldDescription(String apiName, String label, String type, Boolean isEditable, Boolean isUserLookup) {
            this.apiName = apiName;
            this.label = label;
            this.type = type;
            this.isEditable = isEditable;
            this.isUserLookup = isUserLookup;
        }
    }

    public class PdfAttachmentOption {
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String title;
        @AuraEnabled public String filename;
        @AuraEnabled public String sizeLabel;
        @AuraEnabled public Datetime uploadedDate;

        public PdfAttachmentOption(ContentVersion versionRecord) {
            this.contentVersionId = versionRecord.Id;
            this.contentDocumentId = versionRecord.ContentDocumentId;
            this.title = versionRecord.Title;
            this.filename = String.isBlank(versionRecord.FileExtension)
                ? versionRecord.Title
                : versionRecord.Title + '.' + versionRecord.FileExtension;
            this.sizeLabel = formatFileSize(versionRecord.ContentSize);
            this.uploadedDate = versionRecord.CreatedDate;
        }
    }

    private class NoOneDriveLinkException extends Exception {}
    public class LoanConditionControllerException extends Exception {}

    @AuraEnabled(Cacheable=true)
    public static List<ConditionFieldDescription> getConditionFieldDescriptions(List<String> fieldApiNames) {
        List<ConditionFieldDescription> results = new List<ConditionFieldDescription>();
        if (fieldApiNames == null) {
            return results;
        }

        for (String fieldApiName : fieldApiNames) {
            if (String.isBlank(fieldApiName)) {
                continue;
            }

            DescribeFieldResult fieldDescribe = describeFieldPath(fieldApiName);
            if (fieldDescribe == null) {
                continue;
            }

            results.add(
                new ConditionFieldDescription(
                    fieldApiName,
                    fieldDescribe.getLabel(),
                    String.valueOf(fieldDescribe.getType()),
                    !fieldApiName.contains('.') && fieldDescribe.isUpdateable(),
                    isUserLookupField(fieldApiName, fieldDescribe)
                )
            );
        }
        return results;
    }

    @AuraEnabled
    public static DataWrapper getConditionsByType(Id loanId, String type, List<String> columnFields) {
        return new DataWrapper(
            TransactionConditionRepository.getConditionsByType(loanId, type, columnFields),
            LoanRepository.getInstance().getLoanById(loanId)
        );
    }

    @AuraEnabled
    public static List<TransactionCondition> getConditionsForLoan(Id loanId) {
        return TransactionConditionRepository.getInstance().getConditionsRelatedToLoan(loanId);
    }

    @AuraEnabled
    public static List<String> getEmailSenders(Map<String, Object> parameters) {
        try {
            String currentUserEmail = getCurrentUserEmail();
            return String.isBlank(currentUserEmail) ? new List<String>() : new List<String>{ currentUserEmail };
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled(Cacheable=true)
    public static List<PdfAttachmentOption> getPdfAttachmentsForTransaction(Id loanId) {
        List<PdfAttachmentOption> options = new List<PdfAttachmentOption>();
        if (loanId == null) {
            return options;
        }

        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :loanId
            WITH USER_MODE
        ]) {
            contentDocumentIds.add(link.ContentDocumentId);
        }
        if (contentDocumentIds.isEmpty()) {
            return options;
        }

        for (ContentVersion versionRecord : [
            SELECT Id, ContentDocumentId, Title, FileExtension, ContentSize, CreatedDate
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
              AND IsLatest = TRUE
              AND FileExtension = 'pdf'
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ]) {
            options.add(new PdfAttachmentOption(versionRecord));
        }
        return options;
    }

    @AuraEnabled
    public static List<PdfAttachmentOption> getPdfAttachmentsForContentDocuments(List<Id> contentDocumentIds) {
        List<PdfAttachmentOption> options = new List<PdfAttachmentOption>();
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return options;
        }

        for (ContentVersion versionRecord : [
            SELECT Id, ContentDocumentId, Title, FileExtension, ContentSize, CreatedDate
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
              AND IsLatest = TRUE
              AND FileExtension = 'pdf'
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ]) {
            options.add(new PdfAttachmentOption(versionRecord));
        }
        return options;
    }

    @AuraEnabled
    public static void sendConditionsEmail(Map<String, Object> parameters) {
        try {
            String recordId = (String) parameters.get('recordId');
            String conditionType = (String) parameters.get('conditionType');
            String templateName = (String) parameters.get('templateName');
            List<Object> emailToAddresses = (List<Object>) parameters.get('emailToAddresses');

            sendEmailWithHtmlBody(parameters);
            InitialItemsNeededSmsService.enqueueIfApplicable(recordId, templateName, emailToAddresses);
            moveStatusToRequestedForConditions(recordId, conditionType);
            UserActionController.saveUserInteraction(
                new Map<String, Object>{
                    'transactionId' => recordId,
                    'type' => 'Loan Conditions Email Sent'
                }
            );
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static void sendEmailWithHtmlBody(Map<String, Object> parameters) {
        String recordId = (String) parameters.get('recordId');
        String subject = (String) parameters.get('subject');
        String htmlBody = (String) parameters.get('htmlBody');
        String senderEmail = (String) parameters.get('senderEmail');
        List<Object> ccAddresses = (List<Object>) parameters.get('ccAddressEmailList');
        List<Object> bccAddresses = (List<Object>) parameters.get('bccAddressEmailList');
        List<Object> toAddressesBeforeConvert = (List<Object>) parameters.get('emailToAddresses');
        List<Object> attachmentVersionIdsBeforeConvert = (List<Object>) parameters.get('attachmentContentVersionIds');

        if (String.isBlank(senderEmail) || senderEmail == 'None') {
            senderEmail = getCurrentUserEmail();
        }

        if (toAddressesBeforeConvert == null || toAddressesBeforeConvert.isEmpty()) {
            throw new LoanConditionControllerException('The to array is required for all personalization objects');
        }

        Id transactionId = Id.valueOf(recordId);
        ensureBorrowerPortalHash(transactionId);
        htmlBody = repairBorrowerPortalLinks(htmlBody, transactionId);

        List<String> toAddresses = new List<String>();
        for (Object email : toAddressesBeforeConvert) {
            toAddresses.add((String) email);
        }

        List<String> ccAddressList = new List<String>();
        if (ccAddresses != null) {
            for (Object ccAddress : ccAddresses) {
                ccAddressList.add((String) ccAddress);
            }
        }

        List<String> bccAddressList = new List<String>();
        if (bccAddresses != null) {
            for (Object bccAddress : bccAddresses) {
                bccAddressList.add((String) bccAddress);
            }
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setReplyTo(senderEmail);
        mail.setWhatId(recordId);
        mail.setToAddresses(toAddresses);
        mail.setHtmlBody(htmlBody);
        mail.setSubject(subject);
        mail.setCcAddresses(ccAddressList);
        mail.setBccAddresses(bccAddressList);
        mail.setSaveAsActivity(true);

        List<Messaging.EmailFileAttachment> attachments = buildPdfEmailAttachments(attachmentVersionIdsBeforeConvert);
        if (!attachments.isEmpty()) {
            mail.setFileAttachments(attachments);
        }

        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
    }

    @TestVisible
    private static List<Messaging.EmailFileAttachment> buildPdfEmailAttachments(List<Object> rawVersionIds) {
        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
        if (rawVersionIds == null || rawVersionIds.isEmpty()) {
            return attachments;
        }

        Set<Id> versionIds = new Set<Id>();
        for (Object rawId : rawVersionIds) {
            if (rawId != null && String.isNotBlank(String.valueOf(rawId))) {
                versionIds.add((Id) String.valueOf(rawId));
            }
        }
        if (versionIds.isEmpty()) {
            return attachments;
        }

        Integer totalBytes = 0;
        for (ContentVersion versionRecord : [
            SELECT Id, Title, FileExtension, ContentSize, VersionData
            FROM ContentVersion
            WHERE Id IN :versionIds
              AND IsLatest = TRUE
              AND FileExtension = 'pdf'
            WITH USER_MODE
        ]) {
            Integer fileBytes = versionRecord.ContentSize == null ? 0 : Integer.valueOf(versionRecord.ContentSize);
            totalBytes += fileBytes;
            if (totalBytes > 24000000) {
                throw new LoanConditionControllerException('Selected attachments are too large to send by email. Please remove one or more PDFs.');
            }

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName(versionRecord.Title + '.pdf');
            attachment.setBody(versionRecord.VersionData);
            attachment.setContentType('application/pdf');
            attachments.add(attachment);
        }
        return attachments;
    }

    private static String formatFileSize(Decimal bytes) {
        if (bytes == null || bytes <= 0) {
            return '0 KB';
        }
        if (bytes < 1024) {
            return bytes.intValue() + ' B';
        }
        Decimal kb = bytes / 1024;
        if (kb < 1024) {
            return kb.setScale(0, System.RoundingMode.HALF_UP) + ' KB';
        }
        return (kb / 1024).setScale(1, System.RoundingMode.HALF_UP) + ' MB';
    }

    private static String getCurrentUserEmail() {
        try {
            return [
                SELECT Id, Email
                FROM User
                WHERE Id = :UserInfo.getUserId()
                WITH USER_MODE
            ].Email;
        } catch (QueryException ex) {
            throw new LoanConditionControllerException('There was an error retrieving the current user email');
        }
    }

    private static void moveStatusToRequestedForConditions(Id recordId, String type) {
        String includeFieldName = getIncludeInEmailFieldName();
        String query =
            'SELECT Id, Status__c FROM Condition__c WHERE Transaction__c = :recordId' +
            ' AND Status__c = \'New\'';
        if (String.isNotBlank(type)) {
            query += ' AND Type__c = :type';
        }
        if (includeFieldName != null) {
            query += ' AND ' + includeFieldName + ' = TRUE';
        }
        query += ' WITH USER_MODE';

        List<Condition__c> conditions = (List<Condition__c>) Database.query(query);
        if (conditions.isEmpty()) {
            return;
        }
        for (Condition__c condition : conditions) {
            condition.Status__c = 'Requested';
        }
        Database.update(conditions, false, AccessLevel.USER_MODE);
    }

    private static String getIncludeInEmailFieldName() {
        Map<String, SObjectField> fieldMap = Condition__c.SObjectType.getDescribe().fields.getMap();
        if (fieldMap.containsKey('Include_In_Email__c')) {
            return 'Include_In_Email__c';
        }
        if (fieldMap.containsKey('IncludeInEmail__c')) {
            return 'IncludeInEmail__c';
        }
        return null;
    }

    @AuraEnabled
    public static EmailInformation getHtmlForTemplate(String loanId, String templateName) {
        ensureBorrowerPortalHash(Id.valueOf(loanId));
        Loan loan = LoanRepository.getInstance().getLoanById(loanId);
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        List<EmailTemplate> templates = [SELECT Id, Subject FROM EmailTemplate WHERE DeveloperName = :templateName WITH USER_MODE];
        if (!templates.isEmpty()) {
            email = Messaging.renderStoredEmailTemplate(templates[0].Id, loan.getPersonAccountId(), loan.getId());
            email.setHtmlBody(appendProcessorSignature(repairBorrowerPortalLinks(email.getHtmlBody(), loan.getId()), loan.getId()));
        }
        return new EmailInformation(email);
    }

    private static void ensureBorrowerPortalHash(Id loanId) {
        if (loanId == null) {
            return;
        }
        try {
            BorrowerPortalService.populateMissingPortalHashes(new Set<Id>{ loanId });
        } catch (Exception ex) {
            // A missing portal encryption key should not block composing or sending the email.
            // When the key is configured, this repairs older transactions with blank portal hashes.
        }
    }

    private static String repairBorrowerPortalLinks(String htmlBody, Id loanId) {
        if (String.isBlank(htmlBody) || loanId == null) {
            return htmlBody;
        }

        List<Transaction__c> transactions = [
            SELECT Id, Portal_Link_As_URL__c
            FROM Transaction__c
            WHERE Id = :loanId
            WITH USER_MODE
            LIMIT 1
        ];
        if (transactions.isEmpty() || String.isBlank(transactions[0].Portal_Link_As_URL__c)) {
            return htmlBody;
        }

        String portalUrl = htmlEncode(transactions[0].Portal_Link_As_URL__c);
        String repairedBody = htmlBody;
        repairedBody = repairedBody.replace('href=""', 'href="' + portalUrl + '"');
        repairedBody = repairedBody.replace('href=" "', 'href="' + portalUrl + '"');
        repairedBody = repairedBody.replace('href="null"', 'href="' + portalUrl + '"');
        repairedBody = repairedBody.replace('href="&quot;&quot;"', 'href="' + portalUrl + '"');
        return repairedBody;
    }

    @TestVisible
    private static String appendProcessorSignature(String htmlBody, Id loanId) {
        String signature = getProcessorSignature(loanId);
        if (String.isBlank(signature)) {
            return htmlBody;
        }

        String baseBody = htmlBody == null ? '' : htmlBody;
        return baseBody + '<br/><div class="processor-email-signature">' + signature + '</div>';
    }

    private static String getProcessorSignature(Id loanId) {
        if (loanId == null) {
            return null;
        }

        try {
            List<Transaction__c> transactions = [
                SELECT Id,
                    Processor__r.FirstName,
                    Processor__r.LastName,
                    Processor__r.Name,
                    Processor__r.Title,
                    Processor__r.Phone,
                    Processor__r.MobilePhone,
                    Processor__r.Email,
                    Processor__r.Fax,
                    Processor__r.NMLS__c,
                    Processor__r.Headshot_URL__c
                FROM Transaction__c
                WHERE Id = :loanId
                WITH USER_MODE
                LIMIT 1
            ];
            if (transactions.isEmpty() || transactions[0].Processor__r == null) {
                return null;
            }
            return buildProcessorSignature(transactions[0].Processor__r);
        } catch (QueryException ex) {
            return null;
        }
    }

    @TestVisible
    private static String buildProcessorSignature(User processor) {
        if (processor == null) {
            return null;
        }

        String displayName = processor.Name;
        if (String.isBlank(displayName)) {
            List<String> nameParts = new List<String>();
            if (!String.isBlank(processor.FirstName)) {
                nameParts.add(processor.FirstName);
            }
            if (!String.isBlank(processor.LastName)) {
                nameParts.add(processor.LastName);
            }
            displayName = String.join(nameParts, ' ');
        }
        if (String.isBlank(displayName)) {
            return null;
        }

        String photoUrl = htmlEncode(processor.Headshot_URL__c);
        String title = htmlEncode(processor.Title);
        String phone = htmlEncode(FormattingUtility.formatPhone(processor.Phone));
        String mobilePhone = htmlEncode(FormattingUtility.formatPhone(processor.MobilePhone));
        String fax = htmlEncode(FormattingUtility.formatPhone(processor.Fax));
        String email = htmlEncode(processor.Email);
        String nmls = htmlEncode(processor.NMLS__c);

        List<String> detailLines = new List<String>();
        if (!String.isBlank(title)) {
            detailLines.add('<div style="font-size:13px;line-height:18px;color:#4b5563;">' + title + '</div>');
        }
        if (!String.isBlank(phone)) {
            detailLines.add('<div style="font-size:13px;line-height:18px;color:#4b5563;">Direct: ' + phone + '</div>');
        } else if (!String.isBlank(mobilePhone)) {
            detailLines.add('<div style="font-size:13px;line-height:18px;color:#4b5563;">Mobile: ' + mobilePhone + '</div>');
        }
        if (!String.isBlank(email)) {
            detailLines.add('<div style="font-size:13px;line-height:18px;color:#4b5563;"><a href="mailto:' + email + '" style="color:#1a2541;text-decoration:none;">' + email + '</a></div>');
        }
        if (!String.isBlank(fax)) {
            detailLines.add('<div style="font-size:13px;line-height:18px;color:#4b5563;">Fax: ' + fax + '</div>');
        }
        if (!String.isBlank(nmls)) {
            detailLines.add('<div style="font-size:13px;line-height:18px;color:#4b5563;">NMLS #' + nmls + '</div>');
        }

        String imageMarkup = String.isBlank(photoUrl)
            ? ''
            : '<td style="padding-right:14px;vertical-align:top;width:82px;">'
                + '<img src="' + photoUrl + '" alt="' + htmlEncode(displayName) + '" width="72" height="72" '
                + 'style="display:block;border-radius:50%;width:72px;height:72px;object-fit:cover;">'
                + '</td>';

        return '<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="font-family:Arial,sans-serif;color:#1f2937;">'
            + '<tr>'
            + imageMarkup
            + '<td style="vertical-align:top;">'
            + '<div style="font-size:15px;line-height:20px;font-weight:bold;color:#1a2541;">' + htmlEncode(displayName) + '</div>'
            + String.join(detailLines, '')
            + '</td>'
            + '</tr>'
            + '</table>';
    }

    private static String htmlEncode(String value) {
        return String.isBlank(value) ? '' : value.escapeHtml4();
    }

    @AuraEnabled
    public static TransactionCondition approveCondition(String recordId) {
        Condition__c condition = [
            SELECT Id, Status__c
            FROM Condition__c
            WHERE Id = :recordId
            WITH USER_MODE
        ];
        condition.Status__c = 'Approved';
        Database.update(condition, true, AccessLevel.USER_MODE);
        return TransactionConditionRepository.getInstance().getConditionById(recordId);
    }

    @AuraEnabled
    public static void deleteCondition(String recordId) {
        List<Condition__c> condition = [
            SELECT Id
            FROM Condition__c
            WHERE Id = :recordId
            WITH USER_MODE
        ];
        Database.delete(condition, true, AccessLevel.USER_MODE);
    }

    @AuraEnabled
    public static TransactionCondition reviewCondition(String recordId) {
        Condition__c condition = [
            SELECT Id, Status__c
            FROM Condition__c
            WHERE Id = :recordId
            WITH USER_MODE
        ];
        condition.Status__c = 'Review';
        Database.update(condition, true, AccessLevel.USER_MODE);
        return TransactionConditionRepository.getInstance().getConditionById(recordId);
    }

    @AuraEnabled
    public static TransactionCondition fieldValueSave(String recordId, String fieldName, Object value) {
        Condition__c condition = new Condition__c(Id = recordId);
        condition.put(fieldName, extractValueFromField(fieldName, value));
        Database.update(condition, true, AccessLevel.USER_MODE);
        return TransactionConditionRepository.getInstance().getConditionById(condition.Id);
    }

    @AuraEnabled
    public static TransactionCondition saveCondition(Condition__c condition) {
        Map<String, Object> conditionMap = new Map<String, Object>(condition.getPopulatedFieldsAsMap());
        Map<String, SObjectField> fields = Condition__c.SObjectType.getDescribe().fields.getMap();
        Condition__c filteredCondition = new Condition__c();

        for (String fieldName : conditionMap.keySet()) {
            if (fields.containsKey(fieldName) && canUserUpdateField(fields.get(fieldName))) {
                filteredCondition.put(fieldName, conditionMap.get(fieldName));
            }
        }
        if (Schema.SObjectType.Condition__c.isUpdateable()) {
            filteredCondition.Id = condition.Id;
            Database.update(filteredCondition, false, System.AccessLevel.USER_MODE);
        }
        return TransactionConditionRepository.getInstance().getConditionById(condition.Id);
    }

    @AuraEnabled
    public static TransactionCondition refreshCondition(Condition__c condition) {
        return TransactionConditionRepository.getInstance().getConditionById(condition.Id);
    }

    @AuraEnabled
    public static void contentVersionUpdate(Id conditionId, List<Id> contentVersionIds) {
        Set<Id> contentVersionIdsSet = new Set<Id>(contentVersionIds);
        FileUploadHandler.associateContentVersions(contentVersionIdsSet, conditionId);
        FileUploadHandler.updateContentVersions(contentVersionIdsSet, null, conditionId);
        FileUploadHandler.setLoanConditionToReview(conditionId);
    }

    private static Boolean canUserUpdateField(SObjectField objectField) {
        DescribeFieldResult describeFieldResult = objectField.getDescribe();
        return describeFieldResult.isCreateable() && describeFieldResult.isAccessible() && describeFieldResult.isUpdateable();
    }

    private static Boolean isUserLookupField(String fieldApiName, DescribeFieldResult fieldDescribe) {
        if (fieldApiName.contains('.') || fieldDescribe.getType() != Schema.DisplayType.REFERENCE) {
            return false;
        }

        for (Schema.SObjectType referenceType : fieldDescribe.getReferenceTo()) {
            if (referenceType == User.SObjectType) {
                return true;
            }
        }
        return false;
    }

    private static DescribeFieldResult describeFieldPath(String fieldApiName) {
        List<String> pathParts = fieldApiName.split('\\.');
        Schema.SObjectType currentType = Condition__c.SObjectType;

        for (Integer i = 0; i < pathParts.size() - 1; i++) {
            DescribeFieldResult relationshipDescribe = getRelationshipDescribe(currentType, pathParts[i]);
            if (relationshipDescribe == null || relationshipDescribe.getReferenceTo().isEmpty()) {
                return null;
            }
            currentType = relationshipDescribe.getReferenceTo()[0];
        }

        Map<String, SObjectField> fieldMap = currentType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(pathParts[pathParts.size() - 1])) {
            return null;
        }
        return fieldMap.get(pathParts[pathParts.size() - 1]).getDescribe();
    }

    private static DescribeFieldResult getRelationshipDescribe(Schema.SObjectType sourceType, String relationshipName) {
        for (SObjectField fieldToken : sourceType.getDescribe().fields.getMap().values()) {
            DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE && fieldDescribe.getRelationshipName() == relationshipName) {
                return fieldDescribe;
            }
        }
        return null;
    }

    private static Object extractValueFromField(String fieldName, Object value) {
        if (value instanceof String) {
            value = ((String) value).trim();
        }
        if (value == null) {
            return null;
        }

        switch on Condition__c.getSObjectType().getDescribe().fields.getMap().get(fieldName).getDescribe().getType() {
            when DATETIME {
                value = Datetime.valueOf((String) value);
            }
            when DATE {
                value = Date.valueOf((String) value);
            }
            when else {
                System.debug(LoggingLevel.DEBUG, 'LoanConditionController: Field type conversion not needed for field: ' + fieldName);
            }
        }
        return value;
    }
}