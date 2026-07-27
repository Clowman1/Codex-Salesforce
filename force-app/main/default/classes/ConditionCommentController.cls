public with sharing class ConditionCommentController {
    @AuraEnabled(cacheable=true)
    public static List<ConditionCommentService.ConditionCommentDto> getComments(
        Id conditionId,
        Boolean isPortalView
    ) {
        return ConditionCommentService.getComments(conditionId, isPortalView);
    }

    @AuraEnabled
    public static ConditionCommentService.ConditionCommentDto createComment(
        Id conditionId,
        String commentText,
        Boolean isPortalComment,
        Boolean isPublic
    ) {
        return ConditionCommentService.createComment(conditionId, commentText, isPortalComment, isPublic);
    }

    @AuraEnabled
    public static ConditionCommentService.ConditionCommentDto markCommentAsRead(Id commentId) {
        return ConditionCommentService.markAsRead(commentId);
    }

    @AuraEnabled
    public static ConditionCommentService.ConditionCommentDto toggleCommentVisibility(
        Id commentId,
        Boolean isPublic
    ) {
        return ConditionCommentService.updateVisibility(commentId, isPublic);
    }
}