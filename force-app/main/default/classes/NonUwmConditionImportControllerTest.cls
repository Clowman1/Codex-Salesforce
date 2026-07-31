@IsTest
private class NonUwmConditionImportControllerTest {
    private class MockTestException extends Exception {
    }

    private class OpenAiResponsesSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(
                '{"output":[{"type":"message","content":[{"type":"output_text","text":"{\\"conditions\\":[{\\"name\\":\\"Pay Stub Condition\\",\\"description\\":\\"Provide two recent pay stubs\\"}]}"}]}]}'
            );
            return response;
        }
    }

    private class OpenAiResponsesEmptyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(
                '{"output":[{"type":"message","content":[{"type":"output_text","text":"{\\"conditions\\":[]}"}]}]}'
            );
            return response;
        }
    }

    private class OpenAiResponsesDuplicateMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(
                '{"output":[{"type":"message","content":[{"type":"output_text","text":"{\\"conditions\\":[{\\"name\\":\\"Bank Docs A\\",\\"description\\":\\"Provide bank statements\\"},{\\"name\\":\\"Bank Docs B\\",\\"description\\":\\"Provide bank statements\\"}]}"}]}]}'
            );
            return response;
        }
    }

    private class OpenAiResponsesExistingDuplicateMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(
                '{"output":[{"type":"message","content":[{"type":"output_text","text":"{\\"conditions\\":[{\\"name\\":\\"Title Condition\\",\\"description\\":\\"Provide title commitment\\",\\"type\\":\\"Processor\\",\\"status\\":\\"New\\"}]}"}]}]}'
            );
            return response;
        }
    }

    private static NonUwmConditionImportDtos.FileUploadRequest buildFileRequest(String fileName, String base64Data) {
        NonUwmConditionImportDtos.FileUploadRequest request = new NonUwmConditionImportDtos.FileUploadRequest();
        request.fileName = fileName;
        request.base64Data = base64Data;
        return request;
    }

    private static NonUwmConditionImportDtos.ConditionDraft buildSelectedDraft(
        String clientKey,
        String name,
        String description,
        String type
    ) {
        NonUwmConditionImportDtos.ConditionDraft draft = new NonUwmConditionImportDtos.ConditionDraft();
        draft.clientKey = clientKey;
        draft.selected = true;
        draft.name = name;
        draft.description = description;
        draft.type = type;
        draft.status = 'New';
        draft.category = 'Generic';
        draft.canBorrowerSee = true;
        draft.includeInEmail = true;
        return draft;
    }

    private static ContentVersion insertPdfVersion(Id opportunityId, String title, String fileBody) {
        ContentVersion version = new ContentVersion(
            Title = title,
            PathOnClient = title.replace(' ', '-') + '.pdf',
            VersionData = Blob.valueOf(fileBody),
            FirstPublishLocationId = opportunityId
        );
        insert version;

        return [
            SELECT Id, ContentDocumentId, Title
            FROM ContentVersion
            WHERE Id = :version.Id
            LIMIT 1
        ];
    }

    private static Id uploadPdfAndGetDocumentId(Id opportunityId, String title, String fileBody) {
        NonUwmConditionImportDtos.UploadFilesResponse uploadResponse = NonUwmConditionCreationService.uploadPdfFiles(
            opportunityId,
            new List<NonUwmConditionImportDtos.FileUploadRequest>{
                buildFileRequest(title + '.pdf', EncodingUtil.base64Encode(Blob.valueOf(fileBody)))
            }
        );

        System.assertEquals(1, uploadResponse.files.size(), 'One uploaded document should be returned.');
        System.assertEquals(true, uploadResponse.files[0].success, 'Upload helper should create a valid PDF document.');
        System.assertNotEquals(null, uploadResponse.files[0].contentDocumentId, 'Uploaded PDF should return a ContentDocumentId.');
        return uploadResponse.files[0].contentDocumentId;
    }

    @TestSetup
    static void setupData() {
        Transaction__c loan = new Transaction__c();
        insert loan;
    }

    @IsTest
    static void testUploadAndExtractFallbackFlow() {
        Transaction__c opp = [SELECT Id FROM Transaction__c LIMIT 1];

        NonUwmConditionImportDtos.FileUploadRequest request = new NonUwmConditionImportDtos.FileUploadRequest();
        request.fileName = 'non-uwm-conditions.pdf';
        request.base64Data = EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 test file'));

        NonUwmConditionImportDtos.UploadFilesResponse uploadResponse = NonUwmConditionImportController.uploadPdfFiles(
            opp.Id,
            new List<NonUwmConditionImportDtos.FileUploadRequest>{ request }
        );

        System.assertEquals(1, uploadResponse.files.size(), 'One uploaded file result is expected.');
        System.assertEquals(true, uploadResponse.files[0].success, 'Upload should succeed.');
        System.assertNotEquals(
            null,
            uploadResponse.files[0].contentDocumentId,
            'Document should be linked to Transaction.'
        );

        Test.setMock(HttpCalloutMock.class, new OpenAiResponsesSuccessMock());
        NonUwmConditionImportDtos.ExtractionResponse extractionResponse = NonUwmConditionImportController.extractConditions(
            opp.Id,
            new List<Id>{ uploadResponse.files[0].contentDocumentId }
        );

        System.assertEquals(true, extractionResponse.success, 'Extraction response should be successful.');
        System.assert(extractionResponse.files.size() > 0, 'File extraction details should be returned.');
        if (extractionResponse.conditions.isEmpty()) {
            System.assert(
                extractionResponse.globalMessage != null,
                'Empty extraction should provide a manual-entry guidance message.'
            );
        } else {
            System.assertEquals('Processor', extractionResponse.conditions[0].type, 'Default Type should be Processor.');
            System.assertEquals('New', extractionResponse.conditions[0].status, 'Default Status should be New.');
        }
    }

    @IsTest
    static void testCreateConditionsSkipsDuplicatesAndCreatesUnique() {
        Transaction__c opp = [SELECT Id FROM Transaction__c LIMIT 1];

        insert new TransactionCondition__c(
            Transaction__c = opp.Id,
            Description__c = 'Provide two pay stubs',
            Type__c = 'Credit',
            Status__c = 'New'
        );

        NonUwmConditionImportDtos.ConditionDraft duplicateDraft = new NonUwmConditionImportDtos.ConditionDraft();
        duplicateDraft.clientKey = 'dup-1';
        duplicateDraft.selected = true;
        duplicateDraft.name = 'Duplicate';
        duplicateDraft.description = 'Provide two pay stubs';
        duplicateDraft.type = 'Credit';
        duplicateDraft.status = 'New';
        duplicateDraft.category = 'Income';
        duplicateDraft.canBorrowerSee = true;
        duplicateDraft.includeInEmail = true;

        NonUwmConditionImportDtos.ConditionDraft uniqueDraft = new NonUwmConditionImportDtos.ConditionDraft();
        uniqueDraft.clientKey = 'new-1';
        uniqueDraft.selected = true;
        uniqueDraft.name = 'Unique';
        uniqueDraft.description = 'Provide bank statements for 60 days';
        uniqueDraft.type = 'Credit';
        uniqueDraft.status = 'New';
        uniqueDraft.category = 'Assets';
        uniqueDraft.canBorrowerSee = true;
        uniqueDraft.includeInEmail = true;

        NonUwmConditionImportDtos.CreateResponse createResponse = NonUwmConditionImportController.createConditions(
            opp.Id,
            new List<NonUwmConditionImportDtos.ConditionDraft>{ duplicateDraft, uniqueDraft }
        );

        System.assertEquals(true, createResponse.success, 'Creation should succeed.');
        System.assertEquals(2, createResponse.selectedCount, 'Both selected rows are evaluated.');
        System.assertEquals(1, createResponse.createdCount, 'Only one non-duplicate condition should be created.');
        System.assertEquals(1, createResponse.skippedDuplicateCount, 'Duplicate should be skipped.');
        System.assertEquals(1, createResponse.recordIdsAffected.size(), 'One record ID should be returned.');

        Integer totalConditions = [
            SELECT COUNT()
            FROM TransactionCondition__c
            WHERE Transaction__c = :opp.Id
        ];
        System.assertEquals(2, totalConditions, 'One existing + one new condition should exist.');
    }

    @IsTest
    static void testExtractConditionsFailsForOversizedPdf() {
        Transaction__c opp = [SELECT Id FROM Transaction__c LIMIT 1];
        NonUwmConditionExtractionService.maxDirectPdfBytes = 10;

        ContentVersion version = new ContentVersion(
            Title = 'oversized-file',
            PathOnClient = 'oversized-file.pdf',
            VersionData = Blob.valueOf('%PDF-1.4 this content exceeds ten bytes'),
            FirstPublishLocationId = opp.Id
        );
        insert version;

        ContentVersion insertedVersion = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
            LIMIT 1
        ];

        NonUwmConditionImportDtos.ExtractionResponse extractionResponse = NonUwmConditionImportController.extractConditions(
            opp.Id,
            new List<Id>{ insertedVersion.ContentDocumentId }
        );

        System.assertEquals(1, extractionResponse.files.size(), 'One file status should be returned.');
        System.assertEquals(false, extractionResponse.files[0].success, 'Oversized file should fail extraction.');
        System.assert(
            extractionResponse.files[0].message.contains('Split or compress'),
            'File message should include corrective guidance.'
        );
        System.assert(
            extractionResponse.errors.size() > 0,
            'An extraction error should be recorded for oversized file.'
        );
        System.assertEquals(0, extractionResponse.conditions.size(), 'No conditions should be extracted.');
    }

    @IsTest
    static void testUploadPdfFilesValidationBranches() {
        Transaction__c opp = [SELECT Id FROM Transaction__c LIMIT 1];

        NonUwmConditionImportDtos.UploadFilesResponse missingLoanResponse = NonUwmConditionCreationService.uploadPdfFiles(
            null,
            new List<NonUwmConditionImportDtos.FileUploadRequest>{
                buildFileRequest('valid.pdf', EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 valid')))
            }
        );
        System.assertEquals('Loan context is missing.', missingLoanResponse.errors[0]);

        NonUwmConditionImportDtos.UploadFilesResponse noFilesResponse = NonUwmConditionCreationService.uploadPdfFiles(
            opp.Id,
            new List<NonUwmConditionImportDtos.FileUploadRequest>()
        );
        System.assertEquals('No files were provided.', noFilesResponse.errors[0]);

        NonUwmConditionImportDtos.UploadFilesResponse invalidPayloadResponse = NonUwmConditionCreationService.uploadPdfFiles(
            opp.Id,
            new List<NonUwmConditionImportDtos.FileUploadRequest>{
                buildFileRequest(null, null),
                buildFileRequest('notes.txt', EncodingUtil.base64Encode(Blob.valueOf('plain text'))),
                buildFileRequest('bad.pdf', 'not-valid-base64')
            }
        );

        System.assertEquals(3, invalidPayloadResponse.files.size(), 'All invalid file rows should be returned.');
        System.assertEquals('Invalid file payload.', invalidPayloadResponse.files[0].message);
        System.assertEquals('Only PDF files are supported.', invalidPayloadResponse.files[1].message);
        System.assertEquals('Could not decode uploaded file.', invalidPayloadResponse.files[2].message);
    }

    @IsTest
    static void testCreateConditionsValidationBranches() {
        Transaction__c opp = [SELECT Id FROM Transaction__c LIMIT 1];

        NonUwmConditionImportDtos.CreateResponse missingLoanResponse = NonUwmConditionCreationService.createConditions(
            null,
            new List<NonUwmConditionImportDtos.ConditionDraft>()
        );
        System.assertEquals(false, missingLoanResponse.success);
        System.assertEquals('MISSING_OPPORTUNITY', missingLoanResponse.errorCode);

        NonUwmConditionImportDtos.CreateResponse noDraftsResponse = NonUwmConditionCreationService.createConditions(
            opp.Id,
            new List<NonUwmConditionImportDtos.ConditionDraft>()
        );
        System.assertEquals(0, noDraftsResponse.selectedCount);
        System.assertEquals(0, noDraftsResponse.createdCount);
        System.assertEquals('No conditions selected for import.', noDraftsResponse.userMessage);

        insert new TransactionCondition__c(
            Transaction__c = opp.Id,
            Description__c = 'Provide tax returns',
            Type__c = 'Credit',
            Status__c = 'New'
        );

        NonUwmConditionImportDtos.CreateResponse duplicateOnlyResponse = NonUwmConditionCreationService.createConditions(
            opp.Id,
            new List<NonUwmConditionImportDtos.ConditionDraft>{
                buildSelectedDraft('dup-only', 'Duplicate Only', 'Provide tax returns', 'Credit')
            }
        );

        System.assertEquals(true, duplicateOnlyResponse.success);
        System.assertEquals(1, duplicateOnlyResponse.selectedCount);
        System.assertEquals(0, duplicateOnlyResponse.createdCount);
        System.assertEquals(1, duplicateOnlyResponse.skippedDuplicateCount);
        System.assertEquals('No new conditions to create. Duplicates were skipped.', duplicateOnlyResponse.userMessage);
    }

    @IsTest
    static void testExtractionServiceValidationAndSessionDuplicateFromAi() {
        Transaction__c opp = [SELECT Id FROM Transaction__c LIMIT 1];

        NonUwmConditionImportDtos.ExtractionResponse missingLoanResponse = NonUwmConditionExtractionService.extract(
            null,
            new List<Id>()
        );
        System.assertEquals(false, missingLoanResponse.success);
        System.assertEquals('MISSING_OPPORTUNITY', missingLoanResponse.errorCode);

        NonUwmConditionImportDtos.ExtractionResponse noDocsResponse = NonUwmConditionExtractionService.extract(
            opp.Id,
            new List<Id>()
        );
        System.assertEquals('No files selected. Please upload at least one PDF.', noDocsResponse.globalMessage);

        Id documentId = uploadPdfAndGetDocumentId(opp.Id, 'Provide bank statements', '%PDF-1.4 one');
        NonUwmConditionImportDtos.ConditionDraft firstDraft = new NonUwmConditionImportDtos.ConditionDraft();
        firstDraft.name = 'Bank Docs A';
        firstDraft.description = 'Provide bank statements';

        NonUwmConditionImportDtos.ConditionDraft secondDraft = new NonUwmConditionImportDtos.ConditionDraft();
        secondDraft.name = 'Bank Docs B';
        secondDraft.description = 'Provide bank statements';

        NonUwmConditionExtractionService.testExtractedConditionsOverride =
            new List<NonUwmConditionImportDtos.ConditionDraft>{ firstDraft, secondDraft };

        NonUwmConditionImportDtos.ExtractionResponse extractionResponse;
        try {
            extractionResponse = NonUwmConditionExtractionService.extract(
                opp.Id,
                new List<Id>{ documentId }
            );
        } finally {
            NonUwmConditionExtractionService.testExtractedConditionsOverride = null;
        }

        System.assertEquals(2, extractionResponse.conditions.size(), 'AI extraction should return both parsed rows.');

        Integer duplicateCount = 0;
        Integer defaultConfidenceCount = 0;
        for (NonUwmConditionImportDtos.ConditionDraft draft : extractionResponse.conditions) {
            System.assertEquals('Processor', draft.type);
            System.assertEquals('New', draft.status);
            System.assertEquals(true, draft.selected);
            if (draft.confidence == 75) {
                defaultConfidenceCount++;
            }
            if (draft.isDuplicate) {
                duplicateCount++;
                System.assertEquals(
                    'Duplicate in this upload session (Description + Type).',
                    draft.duplicateReason
                );
            }
        }

        System.assertEquals(1, duplicateCount, 'The second identical extracted condition should be flagged as a session duplicate.');
        System.assertEquals(2, defaultConfidenceCount, 'Missing confidence values should default during hydration.');
    }

    @IsTest
    static void testExtractionServiceMarksExistingDuplicatesFromAi() {
        Transaction__c opp = [SELECT Id FROM Transaction__c LIMIT 1];

        insert new TransactionCondition__c(
            Transaction__c = opp.Id,
            Description__c = 'Provide title commitment',
            Type__c = 'Credit',
            Status__c = 'New'
        );

        Id documentId = uploadPdfAndGetDocumentId(opp.Id, 'Provide title commitment', '%PDF-1.4 duplicate');
        NonUwmConditionImportDtos.ConditionDraft duplicateDraft = new NonUwmConditionImportDtos.ConditionDraft();
        duplicateDraft.name = 'Title Condition';
        duplicateDraft.description = 'Provide title commitment';
        duplicateDraft.type = 'Credit';
        duplicateDraft.status = 'New';

        NonUwmConditionExtractionService.testExtractedConditionsOverride =
            new List<NonUwmConditionImportDtos.ConditionDraft>{ duplicateDraft };

        NonUwmConditionImportDtos.ExtractionResponse extractionResponse;
        try {
            extractionResponse = NonUwmConditionExtractionService.extract(
                opp.Id,
                new List<Id>{ documentId }
            );
        } finally {
            NonUwmConditionExtractionService.testExtractedConditionsOverride = null;
        }

        System.assertEquals(1, extractionResponse.conditions.size());
        System.assertEquals(true, extractionResponse.conditions[0].isDuplicate);
        System.assertEquals(
            'Already exists on this loan (Description + Type).',
            extractionResponse.conditions[0].duplicateReason
        );
    }

    @IsTest
    static void testControllerMapsUnhandledExceptionsForUploadAndCreate() {
        Boolean uploadExceptionRaised = false;
        try {
            NonUwmConditionImportController.uploadPdfFiles(
                '006000000000000AAA',
                new List<NonUwmConditionImportDtos.FileUploadRequest>{
                    buildFileRequest('valid.pdf', EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 valid')))
                }
            );
        } catch (AuraHandledException ex) {
            uploadExceptionRaised = true;
            System.assert(!String.isBlank(ex.getMessage()), 'The mapped upload exception should include the underlying error message.');
        }
        System.assertEquals(true, uploadExceptionRaised, 'Upload should surface an AuraHandledException for an invalid publish location.');

        Transaction__c opp = [SELECT Id FROM Transaction__c LIMIT 1];
        NonUwmConditionImportDtos.ConditionDraft badDraft = buildSelectedDraft(
            'bad-assignee',
            'Bad Assignee',
            'Assign to an invalid user reference',
            'Processor'
        );
        badDraft.assignedToId = '001000000000000AAA';

        Boolean createExceptionRaised = false;
        try {
            NonUwmConditionImportController.createConditions(
                opp.Id,
                new List<NonUwmConditionImportDtos.ConditionDraft>{ badDraft }
            );
        } catch (AuraHandledException ex) {
            createExceptionRaised = true;
            System.assert(!String.isBlank(ex.getMessage()), 'The mapped create exception should include the underlying error message.');
        }
        System.assertEquals(true, createExceptionRaised, 'Create should surface an AuraHandledException for an invalid assignee.');

        AuraHandledException handled = NonUwmConditionImportController.mapUnhandledException(
            new MockTestException('expected test exception'),
            'safe message'
        );
        System.assert(!String.isBlank(handled.getMessage()), 'Test-visible exception mapping should return a message.');
    }

    @IsTest
    static void testParseFallbackConditionsInfersCategories() {
        List<NonUwmConditionImportDtos.ConditionDraft> drafts = NonUwmConditionExtractionService.parseFallbackConditions(
            'Provide bank statements' + '\n' +
            'Provide title commitment' + '\n' +
            'Hazard insurance binder' + '\n' +
            'Order appraisal' + '\n' +
            'short'
        );

        System.assertEquals(4, drafts.size(), 'Fallback parsing should ignore only the short line.');
        System.assertEquals('Assets', drafts[0].category);
        System.assertEquals('Title', drafts[1].category);
        System.assertEquals('HOI', drafts[2].category);
        System.assertEquals('Appraisal', drafts[3].category);
    }
}