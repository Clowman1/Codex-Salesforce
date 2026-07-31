public without sharing class FileUploadHandler {
    private static final String DEFAULT_FOLDER = 'No Category';
    private static final String REVIEW_STATUS_FIELD = 'Condition_Document_Review_Status__c';
    private static final String REVIEW_PENDING = 'Pending Review';

    public static void updateContentVersions(List<Id> contentDocumentIds, String folderName, Id conditionId) {
        Set<Id> contentVersionIds = getContentVersionIds(contentDocumentIds);
        updateContentVersions(contentVersionIds, folderName, conditionId);
    }

    private static Set<Id> getContentVersionIds(List<Id> contentDocumentIds) {
        Set<Id> contentVersionIds = new Set<Id>();
        for (ContentDocument documentRecord : [
            SELECT Id, LatestPublishedVersionId
            FROM ContentDocument
            WHERE Id IN :contentDocumentIds
        ]) {
            contentVersionIds.add(documentRecord.LatestPublishedVersionId);
        }
        return contentVersionIds;
    }

    public static void associateContentVersions(Set<Id> contentVersionIdsSet, Id conditionId) {
        if (contentVersionIdsSet == null || contentVersionIdsSet.isEmpty() || conditionId == null) {
            return;
        }

        Map<Id, ContentVersion> contentVersionMap = new Map<Id, ContentVersion>([
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :contentVersionIdsSet
        ]);

        Set<Id> existingContentDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :conditionId
            AND ContentDocumentId IN (
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE Id IN :contentVersionIdsSet
            )
        ]) {
            existingContentDocumentIds.add(link.ContentDocumentId);
        }

        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
        for (Id contentVersionId : contentVersionIdsSet) {
            if (!contentVersionMap.containsKey(contentVersionId)) {
                continue;
            }
            Id contentDocumentId = contentVersionMap.get(contentVersionId).ContentDocumentId;
            if (existingContentDocumentIds.contains(contentDocumentId)) {
                continue;
            }
            contentDocumentLinks.add(
                new ContentDocumentLink(
                    ContentDocumentId = contentDocumentId,
                    LinkedEntityId = conditionId,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                )
            );
        }
        if (!contentDocumentLinks.isEmpty()) {
            Database.insert(contentDocumentLinks, false, AccessLevel.SYSTEM_MODE);
        }
    }

    public static void updateContentVersions(Set<Id> contentVersionIds, String folderName, Id conditionId) {
        if (contentVersionIds == null || contentVersionIds.isEmpty()) {
            return;
        }
        if (folderName == null) {
            folderName = DEFAULT_FOLDER;
        }

        List<ContentVersion> versionsToUpdate = new List<ContentVersion>();
        for (Id contentVersionId : contentVersionIds) {
            ContentVersion versionRecord = new ContentVersion(
                Id = contentVersionId,
                Folder__c = folderName,
                Condition__c = conditionId
            );
            if (Schema.SObjectType.ContentVersion.fields.getMap().containsKey(REVIEW_STATUS_FIELD)) {
                versionRecord.put(REVIEW_STATUS_FIELD, REVIEW_PENDING);
            }
            versionsToUpdate.add(versionRecord);
        }
        Database.update(versionsToUpdate, false, AccessLevel.SYSTEM_MODE);
    }

    public static void setLoanConditionToReview(Id conditionId) {
        if (conditionId == null) {
            return;
        }
        // allOrNone=true so any platform-level write block (e.g. guest user write
        // restrictions on Condition__c) raises a DmlException instead of being
        // silently swallowed. The exception surfaces up to BorrowerDocumentPortalController
        // and into the Apex log so the failure mode is detectable, not invisible.
        Database.update(
            new Condition__c(
                Id = conditionId,
                Status__c = 'Review'
            ),
            true,
            AccessLevel.SYSTEM_MODE
        );
    }
}