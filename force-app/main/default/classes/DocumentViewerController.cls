public without sharing class DocumentViewerController {
    private static final Map<String, String> FILETYPE_TO_ICON_MAP = new Map<String, String>{
        'jpg' => 'doctype:image',
        'jpeg' => 'doctype:image',
        'png' => 'doctype:image',
        'pdf' => 'doctype:pdf',
        'doc' => 'doctype:word',
        'docx' => 'doctype:word',
        'csv' => 'doctype:csv',
        'xls' => 'doctype:excel',
        'xlsx' => 'doctype:excel',
        'txt' => 'doctype:txt'
    };

    @AuraEnabled
    public static List<DocumentWrapper> getDocs(Id recordId) {
        try {
            return getWrappers(getFiles(recordId));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static List<ContentDocument> getFiles(Id recordId) {
        List<ContentDocumentLink> contentDocLinks = retrieveContentDocLinks(recordId);
        return retrieveContentDocs(getContentDocsIds(contentDocLinks));
    }

    public static List<ContentDocumentLink> retrieveContentDocLinks(Set<Id> recordIds) {
        return [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :recordIds
            WITH USER_MODE
        ];
    }

    private static List<ContentDocumentLink> retrieveContentDocLinks(Id recordId, String oldFolderName) {
        return [
            SELECT Id, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            AND ContentDocument.LatestPublishedVersion.Folder__c = :String.escapeSingleQuotes(oldFolderName)
            WITH USER_MODE
        ];
    }

    private static List<ContentDocumentLink> retrieveContentDocLinks(Id recordId) {
        return [
            SELECT Id, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            WITH USER_MODE
        ];
    }

    private static Set<Id> getContentDocsIds(List<ContentDocumentLink> contentDocLinks) {
        Set<Id> contentDocsIds = new Set<Id>();
        for (ContentDocumentLink link : contentDocLinks) {
            contentDocsIds.add(link.ContentDocumentId);
        }
        return contentDocsIds;
    }

    public static List<ContentDocument> retrieveContentDocs(Set<Id> contentDocsIds) {
        if (contentDocsIds.isEmpty()) {
            return new List<ContentDocument>();
        }
        return [
            SELECT Id, Title, FileExtension, CreatedDate, CreatedBy.Name, LatestPublishedVersionId,
                LatestPublishedVersion.Folder__c, LatestPublishedVersion.Condition__c,
                LatestPublishedVersion.Condition__r.Name
            FROM ContentDocument
            WHERE Id IN :contentDocsIds
            AND ContentDocument.FileExtension != 'snote'
            WITH USER_MODE
            ORDER BY LatestPublishedVersion.Condition__r.Name ASC
        ];
    }

    private static List<DocumentWrapper> getWrappers(List<ContentDocument> files) {
        List<DocumentWrapper> wrappers = new List<DocumentWrapper>();
        for (ContentDocument file : files) {
            String key = file.FileExtension == null ? null : file.FileExtension.toLowerCase();
            wrappers.add(new DocumentWrapper(file, FILETYPE_TO_ICON_MAP.get(key)));
        }
        return wrappers;
    }

    @AuraEnabled
    public static List<Condition__c> getLoanConditions(Id recordId) {
        try {
            return [
                SELECT Id, Name
                FROM Condition__c
                WHERE Transaction__c = :recordId
                WITH USER_MODE
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id deleteFile(Id fileId) {
        try {
            Database.delete(new ContentDocument(Id = fileId), true, AccessLevel.USER_MODE);
            return fileId;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void renameFolder(Id recordId, String oldFolderName, String newFolderName) {
        try {
            List<ContentDocumentLink> links = retrieveContentDocLinks(recordId, oldFolderName);
            List<ContentDocument> docs = retrieveContentDocs(getContentDocsIds(links));
            Database.update(assignNewFolderName(docs, newFolderName), false, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static List<ContentVersion> assignNewFolderName(List<ContentDocument> docs, String newFolderName) {
        List<ContentVersion> versionsWithNewFolderName = new List<ContentVersion>();
        for (ContentDocument doc : docs) {
            versionsWithNewFolderName.add(
                new ContentVersion(
                    Id = doc.LatestPublishedVersionId,
                    Folder__c = newFolderName
                )
            );
        }
        return versionsWithNewFolderName;
    }

    @AuraEnabled
    public static void changeFolder(Id recordId, Id fileId, String newFolderName) {
        try {
            List<ContentDocument> docs = retrieveContentDocs(new Set<Id>{ fileId });
            Database.update(assignNewFolderName(docs, newFolderName), false, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void renameFile(Id fileId, String newFileName) {
        try {
            List<ContentDocument> documents = retrieveContentDocs(new Set<Id>{ fileId });
            if (documents.isEmpty()) {
                throw new AuraHandledException('File not found.');
            }

            // Rename via latest ContentVersion only; updating ContentDocument.Title often fails with
            // INSUFFICIENT_ACCESS_OR_READONLY for users who can edit the file via the version.
            Database.update(
                new ContentVersion(Id = documents[0].LatestPublishedVersionId, Title = newFileName),
                true,
                AccessLevel.SYSTEM_MODE
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void relateFileToCondition(Id fileId, Id conditionId) {
        try {
            ContentDocument documentRecord = retrieveContentDocs(new Set<Id>{ fileId })[0];
            Set<Id> versionIds = new Set<Id>{ documentRecord.LatestPublishedVersionId };
            FileUploadHandler.updateContentVersions(versionIds, documentRecord.LatestPublishedVersion.Folder__c, conditionId);
            FileUploadHandler.setLoanConditionToReview(conditionId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage() + '. ' + e.getStackTraceString());
        }
    }

    public class DocumentWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String fileName;
        @AuraEnabled public String fileType;
        @AuraEnabled public String fileTypeIcon;
        @AuraEnabled public String folderName;
        @AuraEnabled public String conditionName;
        @AuraEnabled public Id conditionId;
        @AuraEnabled public String createdBy;
        @AuraEnabled public Datetime createdDate;

        public DocumentWrapper(ContentDocument file, String iconName) {
            id = file.Id;
            fileName = file.Title;
            fileType = file.FileExtension;
            fileTypeIcon = iconName;
            folderName = file.LatestPublishedVersion.Folder__c;
            conditionName = file.LatestPublishedVersion.Condition__r == null ? 'None' : file.LatestPublishedVersion.Condition__r.Name;
            conditionId = file.LatestPublishedVersion.Condition__c;
            createdBy = file.CreatedBy.Name;
            createdDate = file.CreatedDate;
        }
    }
}