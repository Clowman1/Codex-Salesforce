@IsTest
private class ConditionReviewQueueControllerTest {

    @IsTest
    static void getQueueAndRefreshQueueReturnData() {
        Transaction__c loan = createTransaction('CtrlQ Loan', 'LN-CQ-001');
        Condition__c cond = createCondition(loan.Id, 'Review', 'With doc', UserInfo.getUserId());
        insert new ContentVersion(
            Title = 'q.pdf',
            PathOnClient = 'q.pdf',
            VersionData = Blob.valueOf('queue'),
            FirstPublishLocationId = cond.Id
        );

        Test.startTest();
        List<ConditionReviewQueueService.LoanQueueDto> q1 = ConditionReviewQueueController.getQueue();
        List<ConditionReviewQueueService.LoanQueueDto> q2 = ConditionReviewQueueController.refreshQueue();
        Test.stopTest();

        System.assertNotEquals(null, q1);
        System.assertNotEquals(null, q2);
        System.assert(!q1.isEmpty(), 'Queue should include the seeded condition');
    }

    @IsTest
    static void getConditionDocuments_nullIdReturnsEmpty() {
        Test.startTest();
        List<ConditionReviewQueueController.ConditionDocumentDto> docs =
            ConditionReviewQueueController.getConditionDocuments(null);
        Test.stopTest();
        System.assertEquals(0, docs.size());
    }

    @IsTest
    static void getConditionDocuments_noLinksReturnsEmpty() {
        Transaction__c loan = createTransaction('CtrlDoc Loan', 'LN-CD-001');
        Condition__c cond = createCondition(loan.Id, 'Review', 'No files', UserInfo.getUserId());

        Test.startTest();
        List<ConditionReviewQueueController.ConditionDocumentDto> docs =
            ConditionReviewQueueController.getConditionDocuments(cond.Id);
        Test.stopTest();
        System.assertEquals(0, docs.size());
    }

    @IsTest
    static void getConditionDocuments_mapsSmallFileUsesByteLabel() {
        Transaction__c loan = createTransaction('CtrlDoc Loan B', 'LN-CD-002');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Tiny', UserInfo.getUserId());
        insert new ContentVersion(
            Title = 'tiny',
            PathOnClient = 'tiny.bin',
            VersionData = Blob.valueOf('ab'),
            FirstPublishLocationId = cond.Id
        );

        Test.startTest();
        List<ConditionReviewQueueController.ConditionDocumentDto> docs =
            ConditionReviewQueueController.getConditionDocuments(cond.Id);
        Test.stopTest();

        System.assertEquals(1, docs.size());
        System.assert(docs[0].sizeLabel.endsWith(' B'), 'Small files should use byte label: ' + docs[0].sizeLabel);
        System.assertNotEquals(null, docs[0].uploadedDate);
    }

    @IsTest
    static void getConditionDocuments_mapsMediumFileUsesKbLabel() {
        Transaction__c loan = createTransaction('CtrlDoc Loan C', 'LN-CD-003');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Kb', UserInfo.getUserId());
        String payload = '0123456789'.repeat(300);
        insert new ContentVersion(
            Title = 'medium',
            PathOnClient = 'medium.txt',
            VersionData = Blob.valueOf(payload),
            FirstPublishLocationId = cond.Id
        );

        Test.startTest();
        List<ConditionReviewQueueController.ConditionDocumentDto> docs =
            ConditionReviewQueueController.getConditionDocuments(cond.Id);
        Test.stopTest();

        System.assertEquals(1, docs.size());
        System.assert(docs[0].sizeLabel.contains('KB'), 'Expected KB label, got: ' + docs[0].sizeLabel);
    }

    @IsTest
    static void getConditionDocuments_skipsAcceptedDocuments() {
        Transaction__c loan = createTransaction('CtrlDoc Loan D', 'LN-CD-004');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Accepted doc', UserInfo.getUserId());
        Id contentDocumentId = createLinkedDocument(cond.Id, 'accepted-doc');
        ContentVersion latest = [
            SELECT Id, Condition_Document_Review_Status__c
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
              AND IsLatest = TRUE
            LIMIT 1
        ];
        latest.Condition_Document_Review_Status__c = 'Accepted';
        update latest;

        Test.startTest();
        List<ConditionReviewQueueController.ConditionDocumentDto> docs =
            ConditionReviewQueueController.getConditionDocuments(cond.Id);
        Test.stopTest();

        System.assertEquals(0, docs.size(), 'Reviewed documents should not remain in the pending list.');
    }

    @IsTest
    static void getCommentsFresh_returnsThread() {
        Transaction__c loan = createTransaction('CtrlCmt Loan', 'LN-CC-001');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Thread', UserInfo.getUserId());
        insert new Condition_Comment__c(
            Condition__c = cond.Id,
            Comment_Text__c = 'hello',
            Portal_Comment__c = false,
            Public__c = true,
            Read__c = true
        );

        Test.startTest();
        List<ConditionCommentService.ConditionCommentDto> rows =
            ConditionReviewQueueController.getCommentsFresh(cond.Id);
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('hello', rows[0].commentText);
    }

    @IsTest
    static void getConditionDetail_returnsRecord() {
        Transaction__c loan = createTransaction('CtrlDet Loan', 'LN-CDT-001');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Detail', UserInfo.getUserId());

        Test.startTest();
        TransactionCondition detail = ConditionReviewQueueController.getConditionDetail(cond.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail);
    }

    @IsTest
    static void moveDocument_controllerThrowsAuraHandledWhenInvalid() {
        Boolean threw = false;
        Test.startTest();
        try {
            ConditionReviewQueueController.moveDocumentToCondition(null, null, null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void approveDocument_controllerMarksSelectedDocumentAccepted() {
        Transaction__c loan = createTransaction('CtrlApprove Loan', 'LN-CA-001');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Approve one', UserInfo.getUserId());
        Id contentDocumentId = createLinkedDocument(cond.Id, 'approve-one');

        Test.startTest();
        ConditionReviewQueueController.approveDocument(cond.Id, contentDocumentId, true);
        Test.stopTest();

        ContentVersion latest = [
            SELECT Condition_Document_Review_Status__c
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
              AND IsLatest = TRUE
            LIMIT 1
        ];
        System.assertEquals('Accepted', latest.Condition_Document_Review_Status__c);
    }

    @IsTest
    static void rejectDocument_controllerRemovesOnlySelectedDocument() {
        Transaction__c loan = createTransaction('CtrlReject Loan', 'LN-CR-001');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Reject one', UserInfo.getUserId());
        Id rejectedDocumentId = createLinkedDocument(cond.Id, 'reject-one');
        Id pendingDocumentId = createLinkedDocument(cond.Id, 'pending-one');

        Test.startTest();
        ConditionReviewQueueController.rejectDocument(
            cond.Id,
            rejectedDocumentId,
            'Wrong document',
            false,
            'Updated borrower-facing request'
        );
        Test.stopTest();

        Integer rejectedLinks = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :cond.Id
              AND ContentDocumentId = :rejectedDocumentId
        ];
        Integer pendingLinks = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :cond.Id
              AND ContentDocumentId = :pendingDocumentId
        ];
        Condition__c updatedCondition = [
            SELECT Status__c, Description__c
            FROM Condition__c
            WHERE Id = :cond.Id
        ];

        System.assertEquals(0, rejectedLinks);
        System.assertEquals(1, pendingLinks);
        System.assertEquals('Review', updatedCondition.Status__c);
        System.assertEquals('Updated borrower-facing request', updatedCondition.Description__c);
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

    private static Id createLinkedDocument(Id linkedEntityId, String title) {
        insert new ContentVersion(
            Title = title,
            PathOnClient = title + '.txt',
            VersionData = Blob.valueOf(title),
            FirstPublishLocationId = linkedEntityId
        );
        return [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Title = :title
            ORDER BY CreatedDate DESC
            LIMIT 1
        ].ContentDocumentId;
    }
}
