@IsTest
private class ConditionReviewServiceTest {

    @IsTest
    static void rejectConditionUpdatesFlagsAndReason() {
        Transaction__c loan = createTransaction('Reject Loan', 'LN-REJ-001');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Pay stub', UserInfo.getUserId());

        Test.startTest();
        ConditionReviewService.rejectCondition(cond.Id, 'Need clearer scan', true, null);
        Test.stopTest();

        Condition__c reloaded = [
            SELECT RemoveDocumentsFromCondition__c,
                Email_Reject_Note_To_Borrower__c,
                RejectionNotes__c,
                Status__c
            FROM Condition__c
            WHERE Id = :cond.Id
        ];
        System.assertEquals('Need clearer scan', reloaded.RejectionNotes__c);
        // Service sets marker fields; record-triggered flow may reset markers and Status__c to Requested.
        if (reloaded.Status__c == 'Requested') {
            System.assertEquals(false, reloaded.RemoveDocumentsFromCondition__c);
            System.assert(String.isBlank(reloaded.Email_Reject_Note_To_Borrower__c));
        } else {
            System.assertEquals(true, reloaded.RemoveDocumentsFromCondition__c);
            System.assertEquals('No', reloaded.Email_Reject_Note_To_Borrower__c);
        }
    }

    @IsTest
    static void rejectConditionWithoutEmailDoesNotRequireReason() {
        Transaction__c loan = createTransaction('Reject NoEmail Loan', 'LN-REJ-002');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Pay stub', UserInfo.getUserId());

        Test.startTest();
        ConditionReviewService.rejectCondition(cond.Id, null, false, null);
        Test.stopTest();

        Condition__c reloaded = [
            SELECT Email_Reject_Note_To_Borrower__c, RemoveDocumentsFromCondition__c, Status__c
            FROM Condition__c
            WHERE Id = :cond.Id
        ];
        if (reloaded.Status__c == 'Requested') {
            System.assertEquals(false, reloaded.RemoveDocumentsFromCondition__c);
            System.assert(String.isBlank(reloaded.Email_Reject_Note_To_Borrower__c));
        } else {
            System.assertEquals('No', reloaded.Email_Reject_Note_To_Borrower__c);
            System.assertEquals(true, reloaded.RemoveDocumentsFromCondition__c);
        }
    }

    @IsTest
    static void rejectConditionRequiresReasonWhenEmailing() {
        Transaction__c loan = createTransaction('Reject Bad Loan', 'LN-REJ-003');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Pay stub', UserInfo.getUserId());

        Boolean threw = false;
        Test.startTest();
        try {
            ConditionReviewService.rejectCondition(cond.Id, '', true, null);
        } catch (ConditionReviewService.ConditionReviewServiceException ex) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw);
    }

    @IsTest
    static void unassociateDocumentsRemovesContentDocumentLinks() {
        Transaction__c loan = createTransaction('Unassoc Loan', 'LN-UAS-001');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Pay stub', UserInfo.getUserId());
        ContentVersion cv = createContentVersion('unassoc.pdf');
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = cond.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        ConditionReviewService.unassociateDocuments(cond.Id, new Set<Id>{ contentDocId });
        Test.stopTest();

        List<ContentDocumentLink> remaining = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :cond.Id AND ContentDocumentId = :contentDocId
        ];
        System.assertEquals(0, remaining.size());
    }

    @IsTest
    static void moveDocumentMovesLinkToTargetOnly() {
        Transaction__c loan = createTransaction('Move Loan', 'LN-MOV-001');
        Condition__c source = createCondition(loan.Id, 'Review', 'Source', UserInfo.getUserId());
        Condition__c target = createCondition(loan.Id, 'Review', 'Target', UserInfo.getUserId());
        ContentVersion cv = createContentVersion('move.pdf');
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = source.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        ConditionReviewService.moveDocumentToCondition(contentDocId, source.Id, target.Id);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId = :contentDocId
        ];
        Set<Id> linkedEntities = new Set<Id>();
        for (ContentDocumentLink link : links) linkedEntities.add(link.LinkedEntityId);
        System.assert(linkedEntities.contains(target.Id), 'Target should have the link');
        System.assert(!linkedEntities.contains(source.Id), 'Source should no longer have the link');
    }

    @IsTest
    static void moveDocumentNoOpsWhenSameCondition() {
        Transaction__c loan = createTransaction('Move Same Loan', 'LN-MOV-002');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Same', UserInfo.getUserId());
        ContentVersion cv = createContentVersion('same.pdf');
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = cond.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        ConditionReviewService.moveDocumentToCondition(contentDocId, cond.Id, cond.Id);
        Test.stopTest();

        Integer linkCount = [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :cond.Id AND ContentDocumentId = :contentDocId
        ];
        System.assertEquals(1, linkCount);
    }

    @IsTest
    static void controllerWraps() {
        Transaction__c loan = createTransaction('Ctrl Loan', 'LN-CTRL-001');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Ctrl', UserInfo.getUserId());
        Condition__c other = createCondition(loan.Id, 'Review', 'Other', UserInfo.getUserId());
        ContentVersion cv = createContentVersion('move-ctrl.pdf');
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = cond.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        List<ConditionReviewQueueService.LoanQueueDto> queue = ConditionReviewQueueController.getQueue();
        List<ConditionReviewQueueService.LoanQueueDto> refreshed = ConditionReviewQueueController.refreshQueue();
        ConditionReviewQueueController.rejectCondition(cond.Id, 'reason', false, null);
        ConditionReviewQueueController.unassociateDocuments(other.Id, new List<Id>());
        ConditionReviewQueueController.moveDocumentToCondition(contentDocId, cond.Id, other.Id);
        TransactionCondition detail = ConditionReviewQueueController.getConditionDetail(cond.Id);
        Test.stopTest();

        System.assertNotEquals(null, queue);
        System.assertNotEquals(null, refreshed);
        System.assertNotEquals(null, detail);
    }

    @IsTest
    static void rejectConditionNullIdThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            ConditionReviewService.rejectCondition(null, 'x', false, null);
        } catch (ConditionReviewService.ConditionReviewServiceException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void unassociateDocumentsNoOpWhenEmptySet() {
        Transaction__c loan = createTransaction('Unassoc Empty Loan', 'LN-UAS-002');
        Condition__c cond = createCondition(loan.Id, 'Review', 'X', UserInfo.getUserId());
        Test.startTest();
        ConditionReviewService.unassociateDocuments(cond.Id, new Set<Id>());
        ConditionReviewService.unassociateDocuments(cond.Id, null);
        Test.stopTest();
        System.assertEquals(cond.Id, [SELECT Id FROM Condition__c WHERE Id = :cond.Id].Id);
    }

    @IsTest
    static void rejectConditionUnassociatesListedDocuments() {
        Transaction__c loan = createTransaction('Reject Unassoc Loan', 'LN-REJ-004');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Doc strip', UserInfo.getUserId());
        ContentVersion cv = createContentVersion('strip.pdf');
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = cond.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        ConditionReviewService.rejectCondition(cond.Id, 'bad doc', false, new List<Id>{ contentDocId });
        Test.stopTest();

        Integer remaining = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :cond.Id AND ContentDocumentId = :contentDocId
        ];
        System.assertEquals(0, remaining);
    }

    @IsTest
    static void approveDocumentMarksOneFileAcceptedAndLeavesOtherPending() {
        Transaction__c loan = createTransaction('Approve One Doc Loan', 'LN-APP-DOC-001');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Bank statement', UserInfo.getUserId());
        Id acceptedDocId = linkDocument(cond.Id, 'accepted.pdf');
        Id pendingDocId = linkDocument(cond.Id, 'pending.pdf');

        Test.startTest();
        ConditionReviewService.approveDocument(cond.Id, acceptedDocId, true);
        Test.stopTest();

        ContentVersion acceptedVersion = [
            SELECT Condition_Document_Review_Status__c
            FROM ContentVersion
            WHERE ContentDocumentId = :acceptedDocId AND IsLatest = TRUE
            LIMIT 1
        ];
        Condition__c reloaded = [SELECT Status__c FROM Condition__c WHERE Id = :cond.Id];
        Integer pendingStillLinked = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :cond.Id AND ContentDocumentId = :pendingDocId
        ];

        System.assertEquals('Accepted', acceptedVersion.Condition_Document_Review_Status__c);
        System.assertEquals('Review', reloaded.Status__c, 'Other pending document should keep condition in review');
        System.assertEquals(1, pendingStillLinked);
    }

    @IsTest
    static void approveLastDocumentApprovesCondition() {
        Transaction__c loan = createTransaction('Approve Last Doc Loan', 'LN-APP-DOC-002');
        Condition__c cond = createCondition(loan.Id, 'Review', 'W2', UserInfo.getUserId());
        Id contentDocId = linkDocument(cond.Id, 'w2.pdf');

        Test.startTest();
        ConditionReviewService.approveDocument(cond.Id, contentDocId, true);
        Test.stopTest();

        Condition__c reloaded = [SELECT Status__c FROM Condition__c WHERE Id = :cond.Id];
        System.assertEquals('Approved', reloaded.Status__c);
    }

    @IsTest
    static void rejectDocumentOnlyRemovesSelectedFileAndUpdatesDescription() {
        Transaction__c loan = createTransaction('Reject One Doc Loan', 'LN-REJ-DOC-001');
        Condition__c cond = createCondition(loan.Id, 'Review', 'Old description', UserInfo.getUserId());
        Id rejectedDocId = linkDocument(cond.Id, 'bad.pdf');
        Id remainingDocId = linkDocument(cond.Id, 'good.pdf');

        Test.startTest();
        ConditionReviewService.rejectDocument(
            cond.Id,
            rejectedDocId,
            'Please resend the full statement.',
            false,
            'Please upload a complete current bank statement.'
        );
        Test.stopTest();

        Integer rejectedLinks = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :cond.Id AND ContentDocumentId = :rejectedDocId
        ];
        Integer remainingLinks = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :cond.Id AND ContentDocumentId = :remainingDocId
        ];
        ContentVersion rejectedVersion = [
            SELECT Folder__c, Condition_Document_Review_Status__c
            FROM ContentVersion
            WHERE ContentDocumentId = :rejectedDocId AND IsLatest = TRUE
            LIMIT 1
        ];
        Condition__c reloaded = [
            SELECT Status__c, Description__c, RejectionNotes__c
            FROM Condition__c
            WHERE Id = :cond.Id
        ];

        System.assertEquals(0, rejectedLinks);
        System.assertEquals(1, remainingLinks);
        System.assertEquals('Rejected', rejectedVersion.Condition_Document_Review_Status__c);
        System.assertEquals('Junk', rejectedVersion.Folder__c);
        System.assertEquals('Review', reloaded.Status__c, 'Remaining pending document should stay reviewable');
        System.assertEquals('Please upload a complete current bank statement.', reloaded.Description__c);
        System.assertEquals('Please resend the full statement.', reloaded.RejectionNotes__c);
    }

    @IsTest
    static void rejectDocumentWithEmailRendersTemplateForTransactionActivity() {
        EmailTemplate template = new EmailTemplate(
            DeveloperName = 'Condition_Rejection_Test_Template',
            Name = 'Condition Rejection Test Template',
            FolderId = UserInfo.getUserId(),
            TemplateType = 'custom',
            Subject = 'Condition Rejection Notice',
            HtmlValue = '<html><body>Rejected {{{Condition__c.Name}}}: {{{Condition__c.RejectionNotes__c}}}</body></html>',
            IsActive = true
        );
        insert template;

        Condition_Settings__c settings = new Condition_Settings__c(
            Email_Rejection_Template_Name__c = template.DeveloperName
        );
        insert settings;

        RecordType personAccountRecordType = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
                AND IsPersonType = true
            LIMIT 1
        ];
        Account borrower = new Account(
            RecordTypeId = personAccountRecordType.Id,
            FirstName = 'Reject',
            LastName = 'Borrower',
            PersonEmail = 'borrower@example.com'
        );
        insert borrower;

        Transaction__c loan = createTransaction('Reject Email Loan', 'LN-REJ-EMAIL-001');
        loan.Borrower_Name__c = borrower.Id;
        update loan;

        Condition__c cond = createCondition(loan.Id, 'Review', 'Email rejection', UserInfo.getUserId());
        Id rejectedDocId = linkDocument(cond.Id, 'email-reject.pdf');

        Test.startTest();
        ConditionReviewService.rejectDocument(
            cond.Id,
            rejectedDocId,
            'Please upload a clearer copy.',
            true,
            'Please upload a clearer copy of this document.'
        );
        Test.stopTest();

        Condition__c reloaded = [
            SELECT Status__c, Description__c, RejectionNotes__c
            FROM Condition__c
            WHERE Id = :cond.Id
        ];

        System.assertEquals('Requested', reloaded.Status__c);
        System.assertEquals('Please upload a clearer copy of this document.', reloaded.Description__c);
        System.assertEquals('Please upload a clearer copy.', reloaded.RejectionNotes__c);
    }

    @IsTest
    static void moveDocumentThrowsWhenIdsMissing() {
        Boolean threw = false;
        Test.startTest();
        try {
            ConditionReviewService.moveDocumentToCondition(null, null, null);
        } catch (ConditionReviewService.ConditionReviewServiceException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw);
    }

    @IsTest
    static void controllerWrapsErrors() {
        Boolean rejectThrew = false;
        Boolean unassocThrew = false;
        Test.startTest();
        try {
            ConditionReviewQueueController.rejectCondition(null, 'r', true, null);
        } catch (AuraHandledException ex) {
            rejectThrew = true;
        }
        try {
            ConditionReviewQueueController.unassociateDocuments(null, new List<Id>{ UserInfo.getUserId() });
        } catch (AuraHandledException ex) {
            unassocThrew = true;
        }
        Test.stopTest();
        System.assertEquals(true, rejectThrew);
        System.assertEquals(true, unassocThrew);
    }

    private static Transaction__c createTransaction(String name, String loanNumber) {
        Transaction__c rec = new Transaction__c(
            Name = name,
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = loanNumber
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

    private static ContentVersion createContentVersion(String filename) {
        ContentVersion cv = new ContentVersion(
            Title = filename,
            PathOnClient = filename,
            VersionData = Blob.valueOf('test')
        );
        insert cv;
        return cv;
    }

    private static Id linkDocument(Id linkedEntityId, String filename) {
        ContentVersion cv = createContentVersion(filename);
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = linkedEntityId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        return contentDocId;
    }
}