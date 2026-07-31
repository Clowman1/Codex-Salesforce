@IsTest
private class DocumentControllerReviewDocumentTest {
    @IsTest
    static void approveConditionDocumentLeavesConditionInReviewWhenAnotherDocPending() {
        Transaction__c loan = createTransaction();
        Condition__c conditionRecord = createCondition(loan.Id, 'Review', 'Initial condition text');
        Id acceptedDocumentId = linkDocument(conditionRecord.Id, 'accepted.pdf');
        Id pendingDocumentId = linkDocument(conditionRecord.Id, 'pending.pdf');

        Test.startTest();
        TransactionCondition result = DocumentController.approveConditionDocument(
            String.valueOf(conditionRecord.Id),
            String.valueOf(acceptedDocumentId),
            true
        );
        Test.stopTest();

        Condition__c reloaded = [
            SELECT Status__c
            FROM Condition__c
            WHERE Id = :conditionRecord.Id
        ];
        ContentVersion acceptedVersion = [
            SELECT Condition_Document_Review_Status__c
            FROM ContentVersion
            WHERE ContentDocumentId = :acceptedDocumentId AND IsLatest = TRUE
            LIMIT 1
        ];
        Integer pendingLinkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :conditionRecord.Id
              AND ContentDocumentId = :pendingDocumentId
        ];

        System.assertEquals(conditionRecord.Id, result.data.Id);
        System.assertEquals('Review', reloaded.Status__c);
        System.assertEquals('Accepted', acceptedVersion.Condition_Document_Review_Status__c);
        System.assertEquals(1, pendingLinkCount);
    }

    @IsTest
    static void approveLastDocumentAfterSessionRejectionKeepsConditionRequested() {
        Transaction__c loan = createTransaction();
        Condition__c conditionRecord = createCondition(loan.Id, 'Review', 'Initial condition text');
        Id acceptedDocumentId = linkDocument(conditionRecord.Id, 'accepted.pdf');
        Id rejectedDocumentId = linkDocument(conditionRecord.Id, 'rejected.pdf');

        Test.startTest();
        DocumentController.rejectConditionDocument(
            String.valueOf(conditionRecord.Id),
            String.valueOf(rejectedDocumentId),
            'Wrong document.',
            false,
            'Please upload the correct document.'
        );
        TransactionCondition result = DocumentController.approveConditionDocument(
            String.valueOf(conditionRecord.Id),
            String.valueOf(acceptedDocumentId),
            false
        );
        Test.stopTest();

        Condition__c reloaded = [
            SELECT Status__c
            FROM Condition__c
            WHERE Id = :conditionRecord.Id
        ];

        System.assertEquals(conditionRecord.Id, result.data.Id);
        System.assertEquals(
            'Requested',
            reloaded.Status__c,
            'A document rejected in the same review session should keep the condition open.'
        );
    }

    @IsTest
    static void rejectConditionDocumentRemovesOnlySelectedDocumentAndUpdatesDescription() {
        Transaction__c loan = createTransaction();
        Condition__c conditionRecord = createCondition(loan.Id, 'Review', 'Old text');
        Id rejectedDocumentId = linkDocument(conditionRecord.Id, 'bad.pdf');
        Id remainingDocumentId = linkDocument(conditionRecord.Id, 'good.pdf');

        Test.startTest();
        TransactionCondition result = DocumentController.rejectConditionDocument(
            String.valueOf(conditionRecord.Id),
            String.valueOf(rejectedDocumentId),
            'Wrong document.',
            false,
            'Please upload the current complete statement.'
        );
        Test.stopTest();

        Condition__c reloaded = [
            SELECT Status__c, Description__c, RejectionNotes__c
            FROM Condition__c
            WHERE Id = :conditionRecord.Id
        ];
        Integer rejectedLinkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :conditionRecord.Id
              AND ContentDocumentId = :rejectedDocumentId
        ];
        Integer remainingLinkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :conditionRecord.Id
              AND ContentDocumentId = :remainingDocumentId
        ];

        System.assertEquals(conditionRecord.Id, result.data.Id);
        System.assertEquals('Review', reloaded.Status__c);
        System.assertEquals('Please upload the current complete statement.', reloaded.Description__c);
        System.assertEquals('Wrong document.', reloaded.RejectionNotes__c);
        System.assertEquals(0, rejectedLinkCount);
        System.assertEquals(1, remainingLinkCount);
    }

    @IsTest
    static void updateConditionFileDetailsRenamesLatestSalesforceFile() {
        Transaction__c loan = createTransaction();
        Condition__c conditionRecord = createCondition(loan.Id, 'Review', 'Initial condition text');
        Id contentDocumentId = linkDocument(conditionRecord.Id, 'old-name.pdf');

        Test.startTest();
        DocumentController.updateConditionFileDetails(String.valueOf(contentDocumentId), 'new-review-name.pdf', null);
        Test.stopTest();

        ContentVersion renamedVersion = [
            SELECT Title
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
              AND IsLatest = TRUE
            LIMIT 1
        ];

        System.assertEquals('new-review-name', renamedVersion.Title);
    }

    @IsTest
    static void updateFileDetailsWrapperRenamesLatestSalesforceFile() {
        Transaction__c loan = createTransaction();
        Condition__c conditionRecord = createCondition(loan.Id, 'Review', 'Initial condition text');
        Id contentDocumentId = linkDocument(conditionRecord.Id, 'wrapper-old-name.pdf');
        ContentVersion latestVersion = [
            SELECT Id, ContentDocumentId, Title, Folder__c
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
              AND IsLatest = TRUE
            LIMIT 1
        ];
        latestVersion.Title = 'wrapper-new-name.pdf';

        Test.startTest();
        DocumentController.updateFileDetails(latestVersion);
        Test.stopTest();

        ContentVersion renamedVersion = [
            SELECT Title
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
              AND IsLatest = TRUE
            LIMIT 1
        ];

        System.assertEquals('wrapper-new-name', renamedVersion.Title);
    }

    @IsTest
    static void approveConditionUpdatesRequestedCondition() {
        Transaction__c loan = createTransaction();
        Condition__c conditionRecord = createCondition(loan.Id, 'Requested', 'Initial condition text');

        Test.startTest();
        TransactionCondition result = DocumentController.approveCondition(String.valueOf(conditionRecord.Id));
        TransactionCondition blankResult = DocumentController.approveCondition(null);
        Test.stopTest();

        Condition__c reloaded = [
            SELECT Status__c
            FROM Condition__c
            WHERE Id = :conditionRecord.Id
        ];

        System.assertEquals(conditionRecord.Id, result.data.Id);
        System.assertEquals('Approved', reloaded.Status__c);
        System.assertEquals(null, blankResult);
    }

    @IsTest
    static void fileAndConditionLookupMethodsReturnExpectedRecords() {
        Transaction__c loan = createTransaction();
        Condition__c conditionRecord = createCondition(loan.Id, 'Review', 'Initial condition text');
        Id contentDocumentId = linkDocument(conditionRecord.Id, 'lookup.pdf');

        Test.startTest();
        List<ContentDocumentLink> blankFiles = DocumentController.getApplicationFilesLinks(null);
        List<Condition__c> blankConditions = DocumentController.getApplicationConditions(null);
        List<Condition__c> blankMatches = DocumentController.checkApplicationConditions(null, null);
        List<ContentDocumentLink> conditionFiles = DocumentController.getApplicationFilesLinks(String.valueOf(conditionRecord.Id));
        List<Condition__c> loanConditions = DocumentController.getApplicationConditions(String.valueOf(loan.Id));
        List<Condition__c> linkedConditions = DocumentController.checkApplicationConditions(
            String.valueOf(loan.Id),
            String.valueOf(contentDocumentId)
        );
        List<String> defaultFolders = DocumentController.getDefaultFolders();
        Test.stopTest();

        System.assertEquals(0, blankFiles.size());
        System.assertEquals(0, blankConditions.size());
        System.assertEquals(0, blankMatches.size());
        System.assertEquals(1, conditionFiles.size());
        System.assertEquals(1, loanConditions.size());
        System.assertEquals(1, linkedConditions.size());
        System.assertEquals(conditionRecord.Id, linkedConditions[0].Id);
        System.assertNotEquals(null, defaultFolders);
    }

    @IsTest
    static void relinkFileOnConditionRemovesSelectedDocumentLink() {
        Transaction__c loan = createTransaction();
        Condition__c conditionRecord = createCondition(loan.Id, 'Review', 'Initial condition text');
        Id contentDocumentId = linkDocument(conditionRecord.Id, 'relink.pdf');

        Test.startTest();
        TransactionCondition result = DocumentController.relinkFileOnCondition(
            String.valueOf(conditionRecord.Id),
            String.valueOf(contentDocumentId),
            true
        );
        Test.stopTest();

        Integer remainingLinkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :conditionRecord.Id
              AND ContentDocumentId = :contentDocumentId
        ];

        System.assertEquals(conditionRecord.Id, result.data.Id);
        System.assertEquals(0, remainingLinkCount);
    }

    @IsTest
    static void relinkFileOnConditionHandlesRelinkRequest() {
        Transaction__c loan = createTransaction();
        Condition__c conditionRecord = createCondition(loan.Id, 'Review', 'Initial condition text');
        Id contentDocumentId = linkDocument(conditionRecord.Id, 'relink-false.pdf');
        delete [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :conditionRecord.Id
              AND ContentDocumentId = :contentDocumentId
            LIMIT 1
        ];

        Test.startTest();
        TransactionCondition result = DocumentController.relinkFileOnCondition(
            String.valueOf(conditionRecord.Id),
            String.valueOf(contentDocumentId),
            false
        );
        Test.stopTest();

        System.assertEquals(conditionRecord.Id, result.data.Id);
    }

    private static Transaction__c createTransaction() {
        Transaction__c loan = new Transaction__c(
            Name = 'Document Review Controller Loan',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-DOC-REVIEW-001'
        );
        insert loan;
        return loan;
    }

    private static Condition__c createCondition(Id loanId, String status, String description) {
        Condition__c conditionRecord = new Condition__c(
            Transaction__c = loanId,
            Status__c = status,
            Subject__c = description,
            Description__c = description,
            Assigned_To__c = UserInfo.getUserId()
        );
        insert conditionRecord;
        return conditionRecord;
    }

    private static Id linkDocument(Id linkedEntityId, String filename) {
        ContentVersion versionRecord = new ContentVersion(
            Title = filename,
            PathOnClient = filename,
            VersionData = Blob.valueOf('test file body')
        );
        insert versionRecord;

        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
        ].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = linkedEntityId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        return contentDocumentId;
    }
}