@IsTest
private class LoanConditionControllerAttachmentTest {
    @IsTest
    static void getPdfAttachmentsForTransactionReturnsOnlyLinkedPdfs() {
        Transaction__c loan = createTransaction();
        Id pdfVersionId = createFile(loan.Id, 'statement', 'statement.pdf');
        createFile(loan.Id, 'notes', 'notes.txt');

        Test.startTest();
        List<LoanConditionController.PdfAttachmentOption> options =
            LoanConditionController.getPdfAttachmentsForTransaction(loan.Id);
        Test.stopTest();

        System.assertEquals(1, options.size(), 'Only linked PDFs should be returned.');
        System.assertEquals(pdfVersionId, options[0].contentVersionId);
        System.assertEquals('statement.pdf', options[0].filename);
        System.assertNotEquals(null, options[0].sizeLabel);
    }

    @IsTest
    static void buildPdfEmailAttachmentsUsesOnlyPdfVersions() {
        Transaction__c loan = createTransaction();
        Id pdfVersionId = createFile(loan.Id, 'conditions-package', 'conditions-package.pdf');
        Id textVersionId = createFile(loan.Id, 'ignore-me', 'ignore-me.txt');

        Test.startTest();
        List<Messaging.EmailFileAttachment> attachments =
            LoanConditionController.buildPdfEmailAttachments(
                new List<Object>{ String.valueOf(pdfVersionId), String.valueOf(textVersionId) }
            );
        Test.stopTest();

        System.assertEquals(1, attachments.size(), 'Only PDF versions should become email attachments.');
        System.assertEquals('conditions-package.pdf', attachments[0].getFileName());
        System.assertEquals('application/pdf', attachments[0].getContentType());
    }

    @IsTest
    static void getPdfAttachmentsForContentDocumentsReturnsUploadedPdfsOnly() {
        Transaction__c loan = createTransaction();
        Id pdfVersionId = createFile(loan.Id, 'new-email-attachment', 'new-email-attachment.pdf');
        Id textVersionId = createFile(loan.Id, 'not-a-pdf', 'not-a-pdf.txt');

        Map<Id, ContentVersion> versionsById = new Map<Id, ContentVersion>([
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :new Set<Id>{ pdfVersionId, textVersionId }
        ]);

        Test.startTest();
        List<LoanConditionController.PdfAttachmentOption> options =
            LoanConditionController.getPdfAttachmentsForContentDocuments(
                new List<Id>{
                    versionsById.get(pdfVersionId).ContentDocumentId,
                    versionsById.get(textVersionId).ContentDocumentId
                }
            );
        Test.stopTest();

        System.assertEquals(1, options.size(), 'Only uploaded PDFs should be returned.');
        System.assertEquals(pdfVersionId, options[0].contentVersionId);
        System.assertEquals('new-email-attachment.pdf', options[0].filename);
    }

    private static Transaction__c createTransaction() {
        Transaction__c loan = new Transaction__c(
            Name = 'Attachment Test Loan',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-ATTACH-001'
        );
        insert loan;
        return loan;
    }

    private static Id createFile(Id linkedEntityId, String title, String pathOnClient) {
        ContentVersion versionRecord = new ContentVersion(
            Title = title,
            PathOnClient = pathOnClient,
            VersionData = Blob.valueOf('test file body'),
            FirstPublishLocationId = linkedEntityId
        );
        insert versionRecord;
        return versionRecord.Id;
    }
}