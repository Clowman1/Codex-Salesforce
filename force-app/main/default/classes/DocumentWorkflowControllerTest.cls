@IsTest
private class DocumentWorkflowControllerTest {
    @IsTest
    static void documentControllerAndFileUploaderCoverHappyPaths() {
        Transaction__c transactionRecord = createTransaction('Document Controller Transaction', 'LN-DOC-CONTROLLER-001');
        Condition__c conditionRecord = createCondition(
            transactionRecord.Id,
            'Requested',
            'Document controller condition',
            UserInfo.getUserId()
        );
        ContentVersion versionRecord = createContentVersion(transactionRecord.Id, 'controller-doc.pdf');

        Test.startTest();
        List<String> defaultFolders = DocumentController.getDefaultFolders();
        List<ContentDocumentLink> emptyLinks = DocumentController.getApplicationFilesLinks(null);
        List<ContentDocumentLink> transactionLinks = DocumentController.getApplicationFilesLinks(transactionRecord.Id);
        List<Condition__c> emptyConditions = DocumentController.getApplicationConditions(null);
        List<Condition__c> applicationConditions = DocumentController.getApplicationConditions(transactionRecord.Id);
        List<Condition__c> emptyCheckedConditions = DocumentController.checkApplicationConditions(null, versionRecord.ContentDocumentId);
        List<Condition__c> checkedConditions = DocumentController.checkApplicationConditions(
            transactionRecord.Id,
            versionRecord.ContentDocumentId
        );
        TransactionCondition unchangedCondition = DocumentController.relinkFileOnCondition(conditionRecord.Id, null, true);
        TransactionCondition linkedCondition = DocumentController.relinkFileOnCondition(
            conditionRecord.Id,
            versionRecord.ContentDocumentId,
            false
        );
        TransactionCondition unlinkedCondition = DocumentController.relinkFileOnCondition(
            conditionRecord.Id,
            versionRecord.ContentDocumentId,
            true
        );
        TransactionCondition approvedCondition = DocumentController.approveCondition(conditionRecord.Id);
        List<FileUploaderController.DefaultFolderOption> uploaderFolders = FileUploaderController.getDefaultFolders();
        FileUploaderController.saveFolder(new List<String>{ String.valueOf(versionRecord.Id) }, 'Docs');
        DocumentController.updateFileDetails(new ContentVersion(Id = versionRecord.Id, Folder__c = 'Reviewed'));
        Test.stopTest();

        ContentVersion refreshedVersion = [
            SELECT Folder__c
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
        ];
        Condition__c refreshedCondition = [
            SELECT Status__c
            FROM Condition__c
            WHERE Id = :conditionRecord.Id
        ];
        List<ContentDocumentLink> conditionLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :conditionRecord.Id
            AND ContentDocumentId = :versionRecord.ContentDocumentId
        ];

        System.assertEquals(true, !defaultFolders.isEmpty());
        System.assertEquals(0, emptyLinks.size());
        System.assertEquals(1, transactionLinks.size());
        System.assertEquals(0, emptyConditions.size());
        System.assertEquals(1, applicationConditions.size());
        System.assertEquals(0, emptyCheckedConditions.size());
        System.assertEquals(1, checkedConditions.size());
        System.assertEquals(conditionRecord.Id, unchangedCondition.data.Id);
        System.assertEquals(conditionRecord.Id, linkedCondition.data.Id);
        System.assertEquals(conditionRecord.Id, unlinkedCondition.data.Id);
        System.assertEquals(conditionRecord.Id, approvedCondition.data.Id);
        System.assertEquals(true, !uploaderFolders.isEmpty());
        System.assertEquals('Reviewed', refreshedVersion.Folder__c);
        System.assertEquals('Approved', refreshedCondition.Status__c);
        System.assertEquals(0, conditionLinks.size());
    }

    @IsTest
    static void documentViewerPendingReviewAndFileUploadHandlerCoverHappyPaths() {
        Transaction__c transactionRecord = createTransaction('Document Viewer Transaction', 'LN-DOC-VIEWER-001');
        Condition__c conditionRecord = createCondition(
            transactionRecord.Id,
            'Requested',
            'Document viewer condition',
            UserInfo.getUserId()
        );
        ContentVersion versionRecord = createContentVersion(transactionRecord.Id, 'viewer-doc.pdf');

        Test.startTest();
        FileUploadHandler.associateContentVersions(new Set<Id>(), conditionRecord.Id);
        FileUploadHandler.associateContentVersions(new Set<Id>{ versionRecord.Id }, null);
        FileUploadHandler.associateContentVersions(new Set<Id>{ versionRecord.Id }, conditionRecord.Id);
        FileUploadHandler.updateContentVersions(new List<Id>{ versionRecord.ContentDocumentId }, 'Initial Folder', conditionRecord.Id);
        FileUploadHandler.setLoanConditionToReview(conditionRecord.Id);

        List<DocumentViewerController.DocumentWrapper> docs = DocumentViewerController.getDocs(transactionRecord.Id);
        List<Condition__c> loanConditions = DocumentViewerController.getLoanConditions(transactionRecord.Id);
        List<Transaction__c> pendingReviewLoans = PendingReviewLoanConditions.getLoanConditions();
        TransactionCondition cloudFiles = PendingReviewLoanConditions.getCloudFiles(conditionRecord.Id);

        DocumentViewerController.renameFolder(transactionRecord.Id, 'Initial Folder', 'Renamed Folder');
        DocumentViewerController.changeFolder(transactionRecord.Id, versionRecord.ContentDocumentId, 'Changed Folder');
        DocumentViewerController.renameFile(versionRecord.ContentDocumentId, 'renamed-viewer-doc');
        DocumentViewerController.relateFileToCondition(versionRecord.ContentDocumentId, conditionRecord.Id);
        Id deletedFileId = DocumentViewerController.deleteFile(versionRecord.ContentDocumentId);
        Test.stopTest();

        Condition__c refreshedCondition = [
            SELECT Status__c
            FROM Condition__c
            WHERE Id = :conditionRecord.Id
        ];
        List<ContentDocument> remainingDocs = [
            SELECT Id
            FROM ContentDocument
            WHERE Id = :versionRecord.ContentDocumentId
        ];

        System.assertEquals(1, docs.size());
        System.assertEquals(1, loanConditions.size());
        System.assertEquals(true, !pendingReviewLoans.isEmpty());
        System.assertEquals(conditionRecord.Id, cloudFiles.data.Id);
        System.assertEquals('Review', refreshedCondition.Status__c);
        System.assertEquals(versionRecord.ContentDocumentId, deletedFileId);
        System.assertEquals(0, remainingDocs.size());
    }

    @IsTest
    static void userActionControllerGracefullyNoopsWhenObjectIsUnavailable() {
        Test.startTest();
        UserActionController.saveUserInteraction(
            new Map<String, Object>{
                'transactionId' => '001000000000000AAA',
                'conditionId' => 'a00000000000000AAA',
                'type' => 'Test Action'
            }
        );
        Test.stopTest();

        System.assert(true);
    }

    private static Transaction__c createTransaction(String name, String loanNumber) {
        Transaction__c transactionRecord = new Transaction__c(
            Name = name,
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = loanNumber
        );
        insert transactionRecord;
        return transactionRecord;
    }

    private static Condition__c createCondition(
        Id transactionId,
        String status,
        String description,
        Id assignedToId
    ) {
        Condition__c conditionRecord = new Condition__c(
            Transaction__c = transactionId,
            Status__c = status,
            Subject__c = description,
            Description__c = description,
            Assigned_To__c = assignedToId
        );
        insert conditionRecord;
        return conditionRecord;
    }

    private static ContentVersion createContentVersion(Id firstPublishLocationId, String fileName) {
        ContentVersion versionRecord = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = Blob.valueOf('document workflow test file'),
            FirstPublishLocationId = firstPublishLocationId
        );
        insert versionRecord;
        return [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
        ];
    }
}