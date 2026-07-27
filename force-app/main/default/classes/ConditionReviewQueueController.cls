/**
 * Thin @AuraEnabled adapter for the Pending Review Utility LWC.
 * All business logic is delegated to ConditionReviewQueueService and
 * ConditionReviewService. Comment + approve/reopen continue to flow through
 * the existing ConditionCommentController and LoanConditionController.
 */
public with sharing class ConditionReviewQueueController {
    private static final String REVIEW_STATUS_FIELD = 'Condition_Document_Review_Status__c';
    private static final String REVIEW_PENDING = 'Pending Review';

    @AuraEnabled(cacheable=true)
    public static List<ConditionReviewQueueService.LoanQueueDto> getQueue() {
        try {
            return ConditionReviewQueueService.buildQueue();
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    @AuraEnabled
    public static List<ConditionCommentService.ConditionCommentDto> getCommentsFresh(Id conditionId) {
        try {
            return ConditionCommentService.getComments(conditionId, false);
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    @AuraEnabled
    public static TransactionCondition getConditionDetail(Id conditionId) {
        try {
            return TransactionConditionRepository.getInstance().getConditionById(conditionId);
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    public class ConditionDocumentDto {
        @AuraEnabled public Id id;                  // ContentDocumentId
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public String filename;
        @AuraEnabled public String extension;
        @AuraEnabled public Decimal contentSize;    // bytes
        @AuraEnabled public String sizeLabel;       // e.g. "1.2 MB"
        @AuraEnabled public String uploadedBy;
        @AuraEnabled public Datetime uploadedDate;
        @AuraEnabled public String reviewStatus;
    }

    @AuraEnabled
    public static List<ConditionDocumentDto> getConditionDocuments(Id conditionId) {
        List<ConditionDocumentDto> result = new List<ConditionDocumentDto>();
        if (conditionId == null) {
            return result;
        }
        try {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :conditionId
            ];
            Set<Id> contentDocumentIds = new Set<Id>();
            for (ContentDocumentLink link : links) {
                contentDocumentIds.add(link.ContentDocumentId);
            }
            if (contentDocumentIds.isEmpty()) {
                return result;
            }

            String query = 'SELECT Id, Title, FileExtension, ContentSize, CreatedDate, '
                + 'CreatedBy.Name, ContentDocumentId';
            if (Schema.SObjectType.ContentVersion.fields.getMap().containsKey(REVIEW_STATUS_FIELD)) {
                query += ', ' + REVIEW_STATUS_FIELD;
            }
            query += ' FROM ContentVersion'
                + ' WHERE ContentDocumentId IN :contentDocumentIds AND IsLatest = TRUE'
                + ' ORDER BY CreatedDate DESC';

            for (ContentVersion cv : (List<ContentVersion>) Database.query(query)) {
                String reviewStatus = Schema.SObjectType.ContentVersion.fields.getMap().containsKey(REVIEW_STATUS_FIELD)
                    ? (String) cv.get(REVIEW_STATUS_FIELD)
                    : null;
                if (!String.isBlank(reviewStatus) && reviewStatus != REVIEW_PENDING) {
                    continue;
                }
                ConditionDocumentDto dto = new ConditionDocumentDto();
                dto.id = cv.ContentDocumentId;
                dto.contentVersionId = cv.Id;
                dto.filename = String.isNotBlank(cv.FileExtension)
                    ? cv.Title + '.' + cv.FileExtension
                    : cv.Title;
                dto.extension = cv.FileExtension == null ? '' : cv.FileExtension.toUpperCase();
                dto.contentSize = cv.ContentSize;
                dto.sizeLabel = formatSize(cv.ContentSize);
                dto.uploadedBy = cv.CreatedBy != null ? cv.CreatedBy.Name : null;
                dto.uploadedDate = cv.CreatedDate;
                dto.reviewStatus = reviewStatus;
                result.add(dto);
            }
            return result;
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    private static String formatSize(Decimal bytes) {
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
        Decimal mb = (kb / 1024).setScale(1, System.RoundingMode.HALF_UP);
        return mb + ' MB';
    }

    @AuraEnabled
    public static List<ConditionReviewQueueService.LoanQueueDto> refreshQueue() {
        try {
            return ConditionReviewQueueService.buildQueue();
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    @AuraEnabled
    public static void rejectCondition(
        Id conditionId,
        String rejectionReason,
        Boolean emailBorrower,
        List<Id> contentDocumentIdsToUnassociate
    ) {
        try {
            ConditionReviewService.rejectCondition(
                conditionId,
                rejectionReason,
                emailBorrower,
                contentDocumentIdsToUnassociate
            );
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    @AuraEnabled
    public static void approveDocument(
        Id conditionId,
        Id contentDocumentId,
        Boolean approveConditionWhenNoPending
    ) {
        try {
            ConditionReviewService.approveDocument(
                conditionId,
                contentDocumentId,
                approveConditionWhenNoPending
            );
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    @AuraEnabled
    public static void rejectDocument(
        Id conditionId,
        Id contentDocumentId,
        String rejectionReason,
        Boolean emailBorrower,
        String updatedConditionDescription
    ) {
        try {
            ConditionReviewService.rejectDocument(
                conditionId,
                contentDocumentId,
                rejectionReason,
                emailBorrower,
                updatedConditionDescription
            );
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    @AuraEnabled
    public static void unassociateDocuments(Id conditionId, List<Id> contentDocumentIds) {
        try {
            Set<Id> idSet = contentDocumentIds == null
                ? new Set<Id>()
                : new Set<Id>(contentDocumentIds);
            ConditionReviewService.unassociateDocuments(conditionId, idSet);
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    @AuraEnabled
    public static void moveDocumentToCondition(
        Id contentDocumentId,
        Id fromConditionId,
        Id toConditionId
    ) {
        try {
            ConditionReviewService.moveDocumentToCondition(
                contentDocumentId,
                fromConditionId,
                toConditionId
            );
        } catch (Exception ex) {
            throw buildAuraException(ex);
        }
    }

    private static AuraHandledException buildAuraException(Exception ex) {
        AuraHandledException auraEx = new AuraHandledException(ex.getMessage());
        auraEx.setMessage(ex.getMessage());
        return auraEx;
    }
}
