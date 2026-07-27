public with sharing class ConditionCommentService {
    public class ConditionCommentDto {
        @AuraEnabled public Id id;
        @AuraEnabled public Id conditionId;
        @AuraEnabled public String commentText;
        @AuraEnabled public Boolean portalComment;
        @AuraEnabled public Boolean publicComment;
        @AuraEnabled public Boolean read;
        @AuraEnabled public String createdByName;
        @AuraEnabled public Datetime createdDate;
    }

    public static List<ConditionCommentDto> getComments(Id conditionId, Boolean isPortalView) {
        List<ConditionCommentDto> results = new List<ConditionCommentDto>();
        for (Condition_Comment__c commentRecord : ConditionCommentRepository.getInstance()
            .selectByConditionId(conditionId, !isPortalView)) {
            results.add(toDto(commentRecord, isPortalView));
        }
        return results;
    }

    public static ConditionCommentDto createComment(
        Id conditionId,
        String commentText,
        Boolean isPortalComment,
        Boolean isPublic
    ) {
        if (conditionId == null) {
            throw new ConditionCommentServiceException('A condition is required.');
        }
        if (String.isBlank(commentText)) {
            throw new ConditionCommentServiceException('Comment text is required.');
        }

        Condition_Comment__c newComment = new Condition_Comment__c(
            Condition__c = conditionId,
            Comment_Text__c = commentText.trim(),
            Portal_Comment__c = isPortalComment,
            Public__c = isPublic,
            Read__c = !isPortalComment
        );
        insert newComment;

        Condition_Comment__c createdComment = ConditionCommentRepository.getInstance().selectById(newComment.Id);
        processPostCreateSideEffects(createdComment);

        return toDto(createdComment, isPortalComment);
    }

    public static ConditionCommentDto markAsRead(Id commentId) {
        return updateReadState(commentId, true);
    }

    public static ConditionCommentDto markAsUnread(Id commentId) {
        return updateReadState(commentId, false);
    }

    public static ConditionCommentDto updateVisibility(Id commentId, Boolean isPublic) {
        Condition_Comment__c commentRecord = ConditionCommentRepository.getInstance().selectById(commentId);
        if (commentRecord == null) {
            throw new ConditionCommentServiceException('Comment not found.');
        }

        update new Condition_Comment__c(
            Id = commentId,
            Public__c = isPublic
        );

        return toDto(
            ConditionCommentRepository.getInstance().selectById(commentId),
            false
        );
    }

    private static ConditionCommentDto updateReadState(Id commentId, Boolean isRead) {
        Condition_Comment__c commentRecord = ConditionCommentRepository.getInstance().selectById(commentId);
        if (commentRecord == null) {
            throw new ConditionCommentServiceException('Comment not found.');
        }

        update new Condition_Comment__c(
            Id = commentId,
            Read__c = isRead
        );

        return toDto(
            ConditionCommentRepository.getInstance().selectById(commentId),
            false
        );
    }

    private static ConditionCommentDto toDto(Condition_Comment__c commentRecord, Boolean isPortalView) {
        ConditionCommentDto dto = new ConditionCommentDto();
        dto.id = commentRecord.Id;
        dto.conditionId = commentRecord.Condition__c;
        dto.commentText = commentRecord.Comment_Text__c;
        dto.portalComment = commentRecord.Portal_Comment__c;
        dto.publicComment = commentRecord.Public__c;
        dto.read = isPortalView && commentRecord.Portal_Comment__c ? true : commentRecord.Read__c;
        dto.createdByName = commentRecord.Created_By_Name__c;
        dto.createdDate = commentRecord.CreatedDate;
        return dto;
    }

    private static void processPostCreateSideEffects(Condition_Comment__c commentRecord) {
        if (commentRecord == null) {
            return;
        }

        if (commentRecord.Portal_Comment__c) {
            createUnreadCommentCase(commentRecord);
            return;
        }

        if (commentRecord.Public__c) {
            notifyBorrowerOfPublicInternalComment(commentRecord);
        }
    }

    private static void createUnreadCommentCase(Condition_Comment__c commentRecord) {
        Id transactionId = commentRecord.Condition__r?.Transaction__c;
        if (transactionId == null) {
            return;
        }

        Case unreadCommentCase = new Case(
            Subject = 'Unread Condition Comment',
            Status = 'New',
            Transaction__c = transactionId,
            Description = buildCaseDescription(commentRecord)
        );

        if (commentRecord.Condition__r?.Assigned_To__c != null) {
            unreadCommentCase.OwnerId = commentRecord.Condition__r.Assigned_To__c;
        }

        insert unreadCommentCase;
    }

    private static void notifyBorrowerOfPublicInternalComment(Condition_Comment__c commentRecord) {
        String borrowerEmail = commentRecord.Condition__r?.Transaction__r?.Borrower_Email__c;
        if (String.isBlank(borrowerEmail)) {
            return;
        }

        String conditionName = resolveConditionLabel(commentRecord.Condition__r);
        String transactionName = String.isBlank(commentRecord.Condition__r?.Transaction__r?.Name)
            ? 'your transaction'
            : commentRecord.Condition__r.Transaction__r.Name;
        String borrowerPortalUrl = BorrowerPortalLinkService.buildBorrowerHomeUrl(
            commentRecord.Condition__r?.Transaction__r?.Portal_Hash_Parameter__c
        );

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ borrowerEmail.trim() });
        email.setSubject('New Condition Comment - ' + UserInfo.getOrganizationName());
        email.setHtmlBody(
            buildBorrowerNotificationBody(
                transactionName,
                conditionName,
                commentRecord,
                borrowerPortalUrl,
                commentRecord.Condition__r?.Transaction__r?.Processor__r
            )
        );

        if (Test.isRunningTest()) {
            return;
        }

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }

    private static String buildCaseDescription(Condition_Comment__c commentRecord) {
        List<String> lines = new List<String>();
        lines.add('Condition: ' + resolveConditionLabel(commentRecord.Condition__r));
        lines.add('Comment: ' + defaultString(commentRecord.Comment_Text__c, ''));
        return String.join(lines, '\n');
    }

    private static String resolveConditionLabel(Condition__c conditionRecord) {
        if (conditionRecord == null) {
            return 'your condition';
        }

        if (String.isNotBlank(conditionRecord.Description__c)) {
            return conditionRecord.Description__c;
        }

        return defaultString(conditionRecord.Name, 'your condition');
    }

    @TestVisible
    private static String buildBorrowerNotificationBody(
        String transactionName,
        String conditionName,
        Condition_Comment__c commentRecord,
        String borrowerPortalUrl
    ) {
        return buildBorrowerNotificationBody(
            transactionName,
            conditionName,
            commentRecord,
            borrowerPortalUrl,
            null
        );
    }

    @TestVisible
    private static String buildBorrowerNotificationBody(
        String transactionName,
        String conditionName,
        Condition_Comment__c commentRecord,
        String borrowerPortalUrl,
        User processor
    ) {
        String safeConditionName = escapeHtml(conditionName);
        String safeTransactionName = escapeHtml(transactionName);
        String safeCommentText = escapeHtml(defaultString(commentRecord.Comment_Text__c, ''));
        String safeBorrowerPortalUrl = escapeHtml(defaultString(borrowerPortalUrl, ''));

        String emailBody = ''
            + '<p>Your loan team has left a new comment for the following condition:</p>'
            + '<p><strong>' + safeConditionName + '</strong></p>'
            + '<p>Transaction: ' + safeTransactionName + '</p>'
            + '<p>Message: ' + safeCommentText + '</p>';

        if (String.isNotBlank(safeBorrowerPortalUrl)) {
            emailBody += ''
                + '<p>Please review the update in your secure borrower portal.</p>'
                + '<p><a href="' + safeBorrowerPortalUrl + '">View in Borrower Portal</a></p>';
            return emailBody + buildProcessorSignature(processor);
        }

        return emailBody
            + '<p>Please review the update in your secure borrower portal.</p>'
            + buildProcessorSignature(processor);
    }

    private static String buildProcessorSignature(User processor) {
        if (processor == null) {
            return '';
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
            return '';
        }

        String photoUrl = escapeHtml(processor.Headshot_URL__c);
        String title = escapeHtml(processor.Title);
        String phone = escapeHtml(FormattingUtility.formatPhone(processor.Phone));
        String mobilePhone = escapeHtml(FormattingUtility.formatPhone(processor.MobilePhone));
        String fax = escapeHtml(FormattingUtility.formatPhone(processor.Fax));
        String email = escapeHtml(processor.Email);
        String nmls = escapeHtml(processor.NMLS__c);

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
                + '<img src="' + photoUrl + '" alt="' + escapeHtml(displayName) + '" width="72" height="72" '
                + 'style="display:block;border-radius:50%;width:72px;height:72px;object-fit:cover;">'
                + '</td>';

        return '<br/><table role="presentation" cellpadding="0" cellspacing="0" border="0" style="font-family:Arial,sans-serif;color:#1f2937;">'
            + '<tr>'
            + imageMarkup
            + '<td style="vertical-align:top;">'
            + '<div style="font-size:15px;line-height:20px;font-weight:bold;color:#1a2541;">' + escapeHtml(displayName) + '</div>'
            + String.join(detailLines, '')
            + '</td>'
            + '</tr>'
            + '</table>';
    }

    private static String defaultString(String value, String fallbackValue) {
        return String.isBlank(value) ? fallbackValue : value;
    }

    private static String escapeHtml(String value) {
        String escapedValue = value == null ? '' : value;
        escapedValue = escapedValue.replace('&', '&amp;');
        escapedValue = escapedValue.replace('<', '&lt;');
        escapedValue = escapedValue.replace('>', '&gt;');
        escapedValue = escapedValue.replace('"', '&quot;');
        return escapedValue.replace('\'', '&#39;');
    }

    public class ConditionCommentServiceException extends Exception {}
}