public with sharing class ContentDocumentRepository {
    public static Set<Id> resolveContentDocumentIds(Set<Id> uploadedFileIds) {
        Set<Id> contentDocumentIds = new Set<Id>();
        Set<Id> contentVersionIds = new Set<Id>();

        for (Id uploadedFileId : uploadedFileIds) {
            if (uploadedFileId == null) {
                continue;
            }

            Schema.SObjectType fileType = uploadedFileId.getSObjectType();
            if (fileType == ContentDocument.SObjectType) {
                contentDocumentIds.add(uploadedFileId);
            } else if (fileType == ContentVersion.SObjectType) {
                contentVersionIds.add(uploadedFileId);
            }
        }

        if (!contentVersionIds.isEmpty()) {
            for (ContentVersion versionRecord : [
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id IN :contentVersionIds
            ]) {
                contentDocumentIds.add(versionRecord.ContentDocumentId);
            }
        }

        return contentDocumentIds;
    }

    public static Map<Id, Decimal> selectLinkedDocumentCountsByEntityIds(Set<Id> entityIds) {
        Map<Id, Decimal> documentCountsByEntityId = new Map<Id, Decimal>();
        if (entityIds == null || entityIds.isEmpty()) {
            return documentCountsByEntityId;
        }

        for (AggregateResult result : [
            SELECT LinkedEntityId linkedEntityId, COUNT(Id) documentCount
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :entityIds
            GROUP BY LinkedEntityId
        ]) {
            documentCountsByEntityId.put(
                (Id)result.get('linkedEntityId'),
                (Decimal)result.get('documentCount')
            );
        }

        return documentCountsByEntityId;
    }
}