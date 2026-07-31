@IsTest
private class ConditionCommentControllerTest {
    @IsTest
    static void getCommentsFiltersPrivateCommentsForPortalView() {
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Comment Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-COMMENT-001',
            Borrower_First_Name__c = 'Alex',
            Borrower_Last_Name__c = 'Borrower'
        );
        insert transactionRecord;

        Condition__c conditionRecord = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Status__c = 'Requested',
            Description__c = 'Comment test condition'
        );
        insert conditionRecord;

        insert new List<Condition_Comment__c>{
            new Condition_Comment__c(
                Condition__c = conditionRecord.Id,
                Comment_Text__c = 'Public portal message',
                Portal_Comment__c = false,
                Public__c = true,
                Read__c = true
            ),
            new Condition_Comment__c(
                Condition__c = conditionRecord.Id,
                Comment_Text__c = 'Internal only message',
                Portal_Comment__c = false,
                Public__c = false,
                Read__c = true
            )
        };

        Test.startTest();
        List<ConditionCommentService.ConditionCommentDto> portalComments =
            ConditionCommentController.getComments(conditionRecord.Id, true);
        List<ConditionCommentService.ConditionCommentDto> internalComments =
            ConditionCommentController.getComments(conditionRecord.Id, false);
        Test.stopTest();

        System.assertEquals(1, portalComments.size());
        System.assertEquals('Public portal message', portalComments[0].commentText);
        System.assertEquals(2, internalComments.size());
    }

    @IsTest
    static void createCommentCreatesPortalCommentAsUnreadAndCreatesCase() {
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Portal Comment Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-COMMENT-002',
            Borrower_First_Name__c = 'Jamie',
            Borrower_Last_Name__c = 'Portal'
        );
        insert transactionRecord;

        Condition__c conditionRecord = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Status__c = 'Requested',
            Description__c = 'Portal comment condition',
            Assigned_To__c = UserInfo.getUserId()
        );
        insert conditionRecord;

        Test.startTest();
        ConditionCommentService.ConditionCommentDto newComment = ConditionCommentController.createComment(
            conditionRecord.Id,
            'Borrower uploaded a new document.',
            true,
            true
        );
        Test.stopTest();

        Condition_Comment__c storedComment = [
            SELECT Portal_Comment__c, Public__c, Read__c, Comment_Text__c
            FROM Condition_Comment__c
            WHERE Id = :newComment.id
        ];
        List<Case> unreadCommentCases = [
            SELECT Id, OwnerId, Status, Subject, Transaction__c, Description
            FROM Case
            WHERE Transaction__c = :transactionRecord.Id
        ];

        System.assertEquals(true, storedComment.Portal_Comment__c);
        System.assertEquals(true, storedComment.Public__c);
        System.assertEquals(false, storedComment.Read__c);
        System.assertEquals('Borrower uploaded a new document.', storedComment.Comment_Text__c);
        System.assertEquals(1, unreadCommentCases.size());
        System.assertEquals(UserInfo.getUserId(), unreadCommentCases[0].OwnerId);
        System.assertEquals('New', unreadCommentCases[0].Status);
        System.assertEquals('Unread Condition Comment', unreadCommentCases[0].Subject);
        System.assert(unreadCommentCases[0].Description.contains('Portal comment condition'));
    }

    @IsTest
    static void markReadAndToggleVisibilityUpdateComment() {
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Visibility Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-COMMENT-003',
            Borrower_First_Name__c = 'Morgan',
            Borrower_Last_Name__c = 'Viewer'
        );
        insert transactionRecord;

        Condition__c conditionRecord = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Status__c = 'Requested',
            Description__c = 'Visibility condition'
        );
        insert conditionRecord;

        Condition_Comment__c commentRecord = new Condition_Comment__c(
            Condition__c = conditionRecord.Id,
            Comment_Text__c = 'Internal note',
            Portal_Comment__c = false,
            Public__c = false,
            Read__c = false
        );
        insert commentRecord;

        Test.startTest();
        ConditionCommentController.markCommentAsRead(commentRecord.Id);
        ConditionCommentController.toggleCommentVisibility(commentRecord.Id, true);
        Test.stopTest();

        Condition_Comment__c refreshedComment = [
            SELECT Public__c, Read__c
            FROM Condition_Comment__c
            WHERE Id = :commentRecord.Id
        ];

        System.assertEquals(true, refreshedComment.Read__c);
        System.assertEquals(true, refreshedComment.Public__c);
    }

    @IsTest
    static void createCommentSendsBorrowerEmailForPublicInternalComment() {
        String testRecipientEmail = [
            SELECT Email
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ].Email;
        Account borrowerAccount = createBorrowerAccount(testRecipientEmail);

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Internal Public Comment Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-COMMENT-004',
            Borrower_First_Name__c = 'Jordan',
            Borrower_Last_Name__c = 'Borrower',
            Borrower_Name__c = borrowerAccount.Id,
            Portal_Hash_Parameter__c = 'ABC123'
        );
        insert transactionRecord;

        Condition__c conditionRecord = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Status__c = 'Requested',
            Description__c = 'Public email condition'
        );
        insert conditionRecord;

        Test.startTest();
        ConditionCommentController.createComment(
            conditionRecord.Id,
            'We need one more document from you.',
            false,
            true
        );
        Test.stopTest();

        List<Case> unreadCommentCases = [
            SELECT Id
            FROM Case
            WHERE Transaction__c = :transactionRecord.Id
        ];

        System.assertEquals(0, unreadCommentCases.size());
    }

    @IsTest
    static void borrowerPortalLinkServiceBuildsConfiguredHomeUrl() {
        BorrowerPortalLinkService.testBorrowerHomeUrlOverride = 'https://portal.example.com/documents/s/home';

        String borrowerPortalUrl = BorrowerPortalLinkService.buildBorrowerHomeUrl('ABC123');

        System.assertEquals(
            'https://portal.example.com/documents/s/home?id=ABC123',
            borrowerPortalUrl
        );
    }

    @IsTest
    static void borrowerNotificationBodyIncludesPortalLinkWhenConfigured() {
        Condition_Comment__c commentRecord = new Condition_Comment__c(
            Comment_Text__c = 'We need one more document from you.'
        );
        User processor = new User(
            FirstName = 'Pat',
            LastName = 'Processor',
            Title = 'Loan Processor',
            Phone = '3038591055',
            Email = 'processor@example.com',
            NMLS__c = '123456',
            Headshot_URL__c = 'https://example.com/processor.jpg?photo=1&size=small'
        );

        String emailBody = ConditionCommentService.buildBorrowerNotificationBody(
            'Transaction 123',
            'Income Documents',
            commentRecord,
            'https://portal.example.com/documents/s/home?id=ABC123',
            processor
        );

        System.assert(emailBody.contains('View in Borrower Portal'));
        System.assert(emailBody.contains('https://portal.example.com/documents/s/home?id=ABC123'));
        System.assert(emailBody.contains('Pat Processor'));
        System.assert(emailBody.contains('https://example.com/processor.jpg?photo=1&amp;size=small'));
        System.assert(emailBody.contains('(303) 859-1055'));
    }

    private static Account createBorrowerAccount(String emailAddress) {
        Id personAccountRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName = 'PersonAccount'
            LIMIT 1
        ].Id;

        Account borrowerAccount = new Account(
            RecordTypeId = personAccountRecordTypeId,
            FirstName = 'Borrower',
            LastName = 'Portal',
            PersonEmail = emailAddress
        );
        insert borrowerAccount;
        return borrowerAccount;
    }
}