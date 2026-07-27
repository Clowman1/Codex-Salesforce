@IsTest
private class ConditionReviewQueueServiceTest {

    @IsTest
    static void queueIncludesReviewConditionsWithDocs() {
        Transaction__c loan = createTransaction('Queue Loan With Docs', 'LN-Q-001');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Pay stub', UserInfo.getUserId());
        ContentVersion cv = new ContentVersion(
            Title = 'paystub.pdf',
            PathOnClient = 'paystub.pdf',
            VersionData = Blob.valueOf('queue-test'),
            FirstPublishLocationId = cond.Id
        );
        insert cv;

        Test.startTest();
        List<ConditionReviewQueueService.LoanQueueDto> result = ConditionReviewQueueService.buildQueue();
        Test.stopTest();

        System.assertEquals(1, result.size(), 'One loan expected');
        ConditionReviewQueueService.LoanQueueDto dto = result[0];
        System.assertEquals(loan.Id, dto.loanId);
        System.assertEquals(1, dto.pendingConditionsCount);
        System.assertEquals(1, dto.conditions.size());
        System.assertEquals(1, dto.conditions[0].documentCount);
    }

    @IsTest
    static void queueIncludesReviewConditionsWithUnreadComments() {
        Transaction__c loan = createTransaction('Queue Loan With Comments', 'LN-Q-002');
        Condition__c cond = createCondition(loan.Id, 'Review', 'VOE', UserInfo.getUserId());
        insert new Condition_Comment__c(
            Condition__c = cond.Id,
            Comment_Text__c = 'borrower replied',
            Portal_Comment__c = true,
            Public__c = true,
            Read__c = false
        );

        Test.startTest();
        List<ConditionReviewQueueService.LoanQueueDto> result = ConditionReviewQueueService.buildQueue();
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(1, result[0].unreadCommentsCount);
    }

    @IsTest
    static void queueExcludesReviewConditionsWithNoDocsOrUnread() {
        Transaction__c loan = createTransaction('Queue Loan Empty Cond', 'LN-Q-003');
        createCondition(loan.Id, 'Review', 'Empty', UserInfo.getUserId());

        Test.startTest();
        List<ConditionReviewQueueService.LoanQueueDto> result = ConditionReviewQueueService.buildQueue();
        Test.stopTest();

        System.assertEquals(
            0,
            result.size(),
            'Review conditions with no documents or unread comments should not stay in the queue'
        );
    }

    @IsTest
    static void queueRemovesNoDocConditionAfterUnreadCommentIsRead() {
        Transaction__c loan = createTransaction('Queue Loan Closed Comment', 'LN-Q-003B');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Comment only', UserInfo.getUserId());
        Condition_Comment__c comment = new Condition_Comment__c(
            Condition__c = cond.Id,
            Comment_Text__c = 'comment only reply',
            Portal_Comment__c = true,
            Public__c = true,
            Read__c = false
        );
        insert comment;

        Test.startTest();
        List<ConditionReviewQueueService.LoanQueueDto> unreadResult = ConditionReviewQueueService.buildQueue();
        update new Condition_Comment__c(Id = comment.Id, Read__c = true);
        List<ConditionReviewQueueService.LoanQueueDto> readResult = ConditionReviewQueueService.buildQueue();
        Test.stopTest();

        System.assertEquals(1, unreadResult.size(), 'Unread no-document comment should surface in the queue');
        System.assertEquals(cond.Id, unreadResult[0].conditions[0].id);
        System.assertEquals(
            0,
            readResult.size(),
            'Reading the comment should remove the no-document condition without a status change'
        );

        Condition__c unchangedCondition = [
            SELECT Status__c
            FROM Condition__c
            WHERE Id = :cond.Id
        ];
        System.assertEquals('Review', unchangedCondition.Status__c, 'Closing the comment must not approve or reject');
    }

    @IsTest
    static void queueExcludesConditionsAssignedToOtherUser() {
        User otherUser = [SELECT Id FROM User WHERE Id != :UserInfo.getUserId() AND IsActive = TRUE LIMIT 1];
        Transaction__c loan = createTransaction('Queue Loan Other User', 'LN-Q-004');
        Condition__c cond = createCondition(loan.Id, 'Review', 'OtherUser', otherUser.Id);
        ContentVersion cv = new ContentVersion(
            Title = 'other.pdf',
            PathOnClient = 'other.pdf',
            VersionData = Blob.valueOf('test'),
            FirstPublishLocationId = cond.Id
        );
        insert cv;

        Test.startTest();
        List<ConditionReviewQueueService.LoanQueueDto> result = ConditionReviewQueueService.buildQueue();
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @IsTest
    static void queueExcludesNonReviewStatus() {
        Transaction__c loan = createTransaction('Queue Loan New Status', 'LN-Q-005');
        Condition__c cond = createCondition(loan.Id, 'New', 'NewStatus', UserInfo.getUserId());
        ContentVersion cv = new ContentVersion(
            Title = 'new.pdf', PathOnClient = 'new.pdf',
            VersionData = Blob.valueOf('test'), FirstPublishLocationId = cond.Id
        );
        insert cv;

        Test.startTest();
        List<ConditionReviewQueueService.LoanQueueDto> result = ConditionReviewQueueService.buildQueue();
        Test.stopTest();

        System.assertEquals(
            0, result.size(),
            'Non-Review condition without any unread comment must NOT surface in the queue'
        );
    }

    @IsTest
    static void queueIncludesNonReviewConditionsWithUnreadBorrowerComment() {
        // Mirrors real-world borrower portal behavior: the borrower leaves
        // a comment on a Condition that is still in Requested status. The
        // queue must surface this for the assigned processor even though
        // the Condition isn't formally in Review yet.
        Transaction__c loan = createTransaction('Queue Loan Borrower Reply', 'LN-Q-007');
        Condition__c cond = createCondition(
            loan.Id, 'Requested', 'Borrower replied while still Requested', UserInfo.getUserId()
        );
        insert new Condition_Comment__c(
            Condition__c = cond.Id,
            Comment_Text__c = 'Borrower question from portal',
            Portal_Comment__c = true,
            Public__c = true,
            Read__c = false
        );

        Test.startTest();
        List<ConditionReviewQueueService.LoanQueueDto> result = ConditionReviewQueueService.buildQueue();
        Test.stopTest();

        System.assertEquals(
            1, result.size(),
            'Non-Review condition with unread borrower comment MUST surface in the queue'
        );
        System.assertEquals(1, result[0].pendingConditionsCount);
        System.assertEquals(1, result[0].unreadCommentsCount);
        System.assertEquals(cond.Id, result[0].conditions[0].id);
    }

    @IsTest
    static void queueGroupsConditionsByLoan() {
        Transaction__c loan = createTransaction('Queue Loan Multi', 'LN-Q-006');
        Condition__c c1 = createCondition(loan.Id, 'Review', 'C1', UserInfo.getUserId());
        Condition__c c2 = createCondition(loan.Id, 'Review', 'C2', UserInfo.getUserId());
        insert new ContentVersion(Title='a.pdf', PathOnClient='a.pdf', VersionData=Blob.valueOf('a'), FirstPublishLocationId=c1.Id);
        insert new ContentVersion(Title='b.pdf', PathOnClient='b.pdf', VersionData=Blob.valueOf('b'), FirstPublishLocationId=c2.Id);

        Test.startTest();
        List<ConditionReviewQueueService.LoanQueueDto> result = ConditionReviewQueueService.buildQueue();
        Test.stopTest();

        System.assertEquals(1, result.size(), 'One loan grouping');
        System.assertEquals(2, result[0].pendingConditionsCount, 'Two conditions in the loan');
    }

    private static Transaction__c createTransaction(String name, String loanNumber) {
        Transaction__c rec = new Transaction__c(
            Name = name,
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = loanNumber,
            Borrower_First_Name__c = 'Test',
            Borrower_Last_Name__c = 'Borrower'
        );
        insert rec;
        return rec;
    }

    private static Condition__c createCondition(Id loanId, String status, String description, Id assignedToId) {
        Condition__c rec = new Condition__c(
            Transaction__c = loanId,
            Status__c = status,
            Subject__c = description,
            Description__c = description,
            Assigned_To__c = assignedToId
        );
        insert rec;
        return rec;
    }
}