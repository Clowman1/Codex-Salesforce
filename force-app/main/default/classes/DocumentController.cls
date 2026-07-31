public with sharing class DocumentController {
    @AuraEnabled
    public static TransactionCondition approveCondition(String recordId) {
        if (String.isBlank(recordId)) {
            return null;
        }
        Condition__c item = [SELECT Id, Status__c FROM Condition__c WHERE Id = :recordId WITH USER_MODE LIMIT 1];
        item.Status__c = 'Approved';
        Database.update(item, false, AccessLevel.USER_MODE);
        return TransactionConditionRepository.getInstance().getConditionById(recordId);
    }

    @AuraEnabled
    public static TransactionCondition approveConditionDocument(
        String recordId,
        String contentDocumentId,
        Boolean approveConditionWhenNoPending
    ) {
        try {
            ConditionReviewService.approveDocument(
                (Id) recordId,
                (Id) contentDocumentId,
                approveConditionWhenNoPending
            );
            return TransactionConditionRepository.getInstance().getConditionById(recordId);
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    @AuraEnabled
    public static TransactionCondition rejectConditionDocument(
        String recordId,
        String contentDocumentId,
        String rejectionReason,
        Boolean emailBorrower,
        String updatedConditionDescription
    ) {
        try {
            ConditionReviewService.rejectDocument(
                (Id) recordId,
                (Id) contentDocumentId,
                rejectionReason,
                emailBorrower,
                updatedConditionDescription
            );
            return TransactionConditionRepository.getInstance().getConditionById(recordId);
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    @AuraEnabled
    public static TransactionCondition relinkFileOnCondition(String recordId, String contentDocumentId, Boolean isLinked) {
        if (String.isBlank(recordId) || String.isBlank(contentDocumentId)) {
            return TransactionConditionRepository.getInstance().getConditionById(recordId);
        }

        if (isLinked) {
            List<ContentDocumentLink> links = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId AND ContentDocumentId = :contentDocumentId
                LIMIT 1
            ];
            if (!links.isEmpty()) {
                Database.delete(links[0], false, AccessLevel.USER_MODE);
            }
        } else {
            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = recordId,
                ShareType = 'I',
                Visibility = 'AllUsers'
            );
            Database.insert(cdl, false, AccessLevel.USER_MODE);
        }

        return TransactionConditionRepository.getInstance().getConditionById(recordId);
    }

    @AuraEnabled
    public static List<ContentDocumentLink> getApplicationFilesLinks(String applicationId) {
        if (String.isBlank(applicationId)) {
            return new List<ContentDocumentLink>();
        }
        return [
            SELECT Id, LinkedEntityId, ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :applicationId
        ];
    }

    @AuraEnabled
    public static List<Condition__c> getApplicationConditions(String applicationId) {
        if (String.isBlank(applicationId)) {
            return new List<Condition__c>();
        }
        return [
            SELECT Id, Name, (SELECT Id, ContentDocumentId FROM ContentDocumentLinks)
            FROM Condition__c
            WHERE Transaction__c = :applicationId
        ];
    }

    @AuraEnabled
    public static List<Condition__c> checkApplicationConditions(String applicationId, String contentDocId) {
        if (String.isBlank(applicationId) || String.isBlank(contentDocId)) {
            return new List<Condition__c>();
        }
        return [
            SELECT Id, Name, (SELECT Id, ContentDocumentId FROM ContentDocumentLinks WHERE ContentDocumentId = :contentDocId)
            FROM Condition__c
            WHERE Transaction__c = :applicationId
        ];
    }

    @AuraEnabled
    public static List<String> getDefaultFolders() {
        List<String> folders = new List<String>();
        for (FileUploaderController.DefaultFolderOption folder : FileUploaderController.getDefaultFolders()) {
            folders.add(folder.MasterLabel);
        }
        return folders;
    }

    @AuraEnabled
    public static void updateFileDetails(ContentVersion contentVersionToUpdate) {
        if (contentVersionToUpdate == null) {
            throw buildAuraException('No file details were provided.');
        }
        updateConditionFileDetails(
            String.valueOf(contentVersionToUpdate.ContentDocumentId),
            contentVersionToUpdate.Title,
            (String) contentVersionToUpdate.get('Folder__c')
        );
    }

    @AuraEnabled
    public static void updateConditionFileDetails(String contentDocumentId, String title, String folder) {
        try {
            if (String.isBlank(contentDocumentId)) {
                throw new IllegalArgumentException('Missing Salesforce file id.');
            }
            if (String.isBlank(title)) {
                throw new IllegalArgumentException('Document name is required.');
            }

            ContentVersion latestVersion = [
                SELECT Id, Title, FileExtension
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId
                  AND IsLatest = TRUE
                LIMIT 1
            ];

            latestVersion.Title = normalizeContentVersionTitle(title, latestVersion.FileExtension);
            Map<String, Schema.SObjectField> contentVersionFields = Schema.SObjectType.ContentVersion.fields.getMap();
            if (contentVersionFields.containsKey('Folder__c')) {
                latestVersion.put('Folder__c', folder);
            }

            Database.SaveResult updateResult = Database.update(latestVersion, false, AccessLevel.SYSTEM_MODE);
            if (!updateResult.isSuccess()) {
                throw new DmlException(updateResult.getErrors()[0].getMessage());
            }
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    private static String normalizeContentVersionTitle(String title, String fileExtension) {
        String normalizedTitle = title == null ? '' : title.trim();
        if (String.isNotBlank(fileExtension)) {
            String extensionSuffix = '.' + fileExtension;
            if (normalizedTitle.toLowerCase().endsWith(extensionSuffix.toLowerCase())) {
                normalizedTitle = normalizedTitle.substring(0, normalizedTitle.length() - extensionSuffix.length()).trim();
            }
        }
        return normalizedTitle;
    }

    private static AuraHandledException buildAuraException(Exception ex) {
        AuraHandledException auraEx = new AuraHandledException(ex.getMessage());
        auraEx.setMessage(ex.getMessage());
        return auraEx;
    }

    private static AuraHandledException buildAuraException(String message) {
        AuraHandledException auraEx = new AuraHandledException(message);
        auraEx.setMessage(message);
        return auraEx;
    }
}