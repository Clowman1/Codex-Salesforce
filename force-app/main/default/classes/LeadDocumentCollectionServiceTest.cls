@IsTest
private class LeadDocumentCollectionServiceTest {
    @TestSetup
    static void setupSettings() {
        insert new AesKey__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            AesKey__c = '12345678901234567890123456789012'
        );
        BorrowerPortalSettings__c settings = new BorrowerPortalSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Borrower_Home_Url__c = 'https://example.force.com/documents/s/'
        );
        if (BorrowerPortalSettings__c.SObjectType.getDescribe().fields.getMap().containsKey('Lead_Borrower_Home_Url__c')) {
            settings.put('Lead_Borrower_Home_Url__c', 'https://example.force.com/documents/s/lead');
        }
        insert settings;
    }

    @IsTest
    static void saveRequestsPopulatesHashAndSendsOnlyLeadEmail() {
        Lead leadRecord = createLead('hash@example.com');

        LeadDocumentRequestService.RequestInput input = new LeadDocumentRequestService.RequestInput();
        input.name = 'Pay Stub';
        input.description = 'Most recent pay stub';
        input.category = 'Income';
        input.type = 'Processor';
        input.includeInEmail = true;
        input.canBorrowerSee = true;

        Test.startTest();
        List<LeadDocumentRequestService.RequestItem> requests =
            LeadDocumentRequestController.saveRequests(leadRecord.Id, new List<LeadDocumentRequestService.RequestInput>{ input });
        LeadDocumentRequestController.initializeData(leadRecord.Id);
        List<LeadDocumentRequestService.EmailTemplateOption> templateOptions =
            LeadDocumentRequestController.getEmailTemplateOptions();
        LeadDocumentRequestService.EmailInformation preview = LeadDocumentRequestController.getEmailTemplatePreview(
            leadRecord.Id,
            templateOptions[0].developerName
        );
        LeadDocumentRequestController.sendEditedRequestEmail(
            leadRecord.Id,
            preview.subject,
            preview.htmlBody.replace('Good afternoon!', 'Good afternoon! Edited for Lead.')
        );
        Test.stopTest();

        Lead updatedLead = LeadDocumentRequestRepository.getInstance()
            .selectLeadsByIds(new Set<Id>{ leadRecord.Id }).get(leadRecord.Id);
        Lead_Document_Request__c updatedRequest = [
            SELECT Status__c, Requested_Date__c, Can_Borrower_See__c
            FROM Lead_Document_Request__c
            WHERE Id = :requests[0].id
        ];

        System.assertNotEquals(null, LeadDocumentRequestService.getLeadPortalHash(updatedLead));
        System.assert(LeadDocumentRequestService.buildLeadPortalLink(updatedLead).contains('?id='));
        System.assertEquals('Lead_Initial_Documents_Needed', templateOptions[0].developerName);
        System.assertEquals('Initial Documents Needed', preview.subject);
        System.assert(preview.htmlBody.contains('out of underwriting'));
        System.assert(preview.htmlBody.contains('The items needed are'));
        System.assert(preview.htmlBody.contains('Items sent thru DocuSign'));
        System.assert(preview.htmlBody.contains('mortgage underwriting process'));
        System.assert(preview.htmlBody.contains('Pay Stub'));
        System.assert(preview.htmlBody.indexOf('Pay Stub') < preview.htmlBody.indexOf('Upload Files'));
        System.assert(preview.htmlBody.indexOf('Pay Stub') < preview.htmlBody.indexOf('All the best'));
        System.assert(!preview.htmlBody.contains('{{LEAD_PORTAL_LINK}}'));
        System.assert(preview.htmlBody.contains('https://example.force.com/documents/s/lead?id='));
        System.assert(preview.htmlBody.contains('327 Plaza Real'));
        System.assertEquals('Requested', updatedRequest.Status__c);
        System.assertEquals(Date.today(), updatedRequest.Requested_Date__c);
        System.assertEquals(true, updatedRequest.Can_Borrower_See__c);

        Lead_Document_Request__c requestToDelete = createRequest(leadRecord.Id, 'Delete Me');
        LeadDocumentRequestController.deleteRequest(requestToDelete.Id);
        System.assertEquals(0, [
            SELECT COUNT()
            FROM Lead_Document_Request__c
            WHERE Id = :requestToDelete.Id
        ]);
    }

    @IsTest
    static void saveRequestsRejectsBlankRows() {
        Lead leadRecord = createLead('blank-save@example.com');
        LeadDocumentRequestService.RequestInput blankInput = new LeadDocumentRequestService.RequestInput();
        blankInput.status = 'New';
        blankInput.type = 'Processor';
        blankInput.includeInEmail = true;
        blankInput.canBorrowerSee = true;

        Boolean rejected = false;

        Test.startTest();
        try {
            LeadDocumentRequestController.saveRequests(
                leadRecord.Id,
                new List<LeadDocumentRequestService.RequestInput>{ blankInput }
            );
        } catch (LeadDocumentRequestService.LeadDocumentRequestException ex) {
            rejected = true;
        }
        Test.stopTest();

        System.assertEquals(true, rejected);
        System.assertEquals(0, [
            SELECT COUNT()
            FROM Lead_Document_Request__c
            WHERE Lead__c = :leadRecord.Id
        ]);
    }

    @IsTest
    static void saveRequestsAcceptsRowsWithRequestDetails() {
        Lead leadRecord = createLead('details-save@example.com');
        LeadDocumentRequestService.RequestInput input = new LeadDocumentRequestService.RequestInput();
        input.description = 'Please upload passport.';
        input.category = 'ID';
        input.status = 'New';
        input.type = 'Processor';
        input.includeInEmail = true;
        input.canBorrowerSee = true;

        Test.startTest();
        List<LeadDocumentRequestService.RequestItem> requests =
            LeadDocumentRequestController.saveRequests(
                leadRecord.Id,
                new List<LeadDocumentRequestService.RequestInput>{ input }
            );
        Test.stopTest();

        System.assertEquals(1, requests.size());
        System.assertEquals('Document Request', requests[0].name);
        System.assertEquals('Please upload passport.', requests[0].description);
        System.assertEquals('ID', requests[0].category);
    }

    @IsTest
    static void saveNotesAndAddCommentsForLeadRequest() {
        Lead leadRecord = createLead('notes-comments@example.com');
        Lead_Document_Request__c requestRecord = createRequest(leadRecord.Id, 'Notes Request');

        Test.startTest();
        LeadDocumentRequestService.RequestItem notesResult = LeadDocumentRequestController.saveNotes(
            requestRecord.Id,
            'Updated borrower-facing request.',
            'Internal processor note.'
        );
        LeadDocumentRequestService.RequestItem commentResult = LeadDocumentRequestController.addComment(
            requestRecord.Id,
            'Please review this note.',
            true
        );
        Test.stopTest();

        Lead_Document_Request__c updatedRequest = [
            SELECT Description__c, Internal_Notes__c, Comments__c
            FROM Lead_Document_Request__c
            WHERE Id = :requestRecord.Id
        ];

        System.assertEquals('Updated borrower-facing request.', notesResult.description);
        System.assertEquals('Internal processor note.', notesResult.internalNotes);
        System.assertEquals('Updated borrower-facing request.', updatedRequest.Description__c);
        System.assertEquals('Internal processor note.', updatedRequest.Internal_Notes__c);
        System.assert(commentResult.comments.contains('Portal'));
        System.assert(commentResult.comments.contains('Please review this note.'));
        System.assert(updatedRequest.Comments__c.contains('Please review this note.'));
    }

    @IsTest
    static void saveRequestsAcceptsModalStyleBulkPayload() {
        Lead leadRecord = createLead('modal-save@example.com');

        LeadDocumentRequestService.RequestInput firstInput = new LeadDocumentRequestService.RequestInput();
        firstInput.name = 'Bank Statement';
        firstInput.subject = 'Most recent bank statement';
        firstInput.category = 'Assets';
        firstInput.status = 'New';
        firstInput.type = 'Processor';
        firstInput.includeInEmail = true;
        firstInput.canBorrowerSee = true;

        LeadDocumentRequestService.RequestInput secondInput = new LeadDocumentRequestService.RequestInput();
        secondInput.name = 'Pay Stub';
        secondInput.description = 'Upload latest pay stub.';
        secondInput.category = 'Income';
        secondInput.status = 'New';
        secondInput.type = 'Borrower';
        secondInput.includeInEmail = true;
        secondInput.canBorrowerSee = true;

        Test.startTest();
        List<LeadDocumentRequestService.RequestItem> requests =
            LeadDocumentRequestController.saveRequests(
                leadRecord.Id,
                new List<LeadDocumentRequestService.RequestInput>{ firstInput, secondInput }
            );
        Test.stopTest();

        System.assertEquals(2, requests.size());
        System.assertEquals(2, [
            SELECT COUNT()
            FROM Lead_Document_Request__c
            WHERE Lead__c = :leadRecord.Id
            AND Status__c = 'New'
        ]);
    }

    @IsTest
    static void createRequestsFromReferencesMapsCatalogValues() {
        Lead leadRecord = createLead('reference-create@example.com');
        Lead_Document_Request_Reference__c referenceRecord = createReference(
            'Initial Borrower Docs',
            'Bank Statements',
            'Assets',
            'ASSET_GROUP'
        );

        Test.startTest();
        List<LeadDocumentRequestService.RequestItem> requests =
            LeadDocumentRequestService.createRequestsFromReferences(
                leadRecord.Id,
                new List<Id>{ referenceRecord.Id }
            );
        Test.stopTest();

        Lead_Document_Request__c createdRequest = [
            SELECT Name, Subject__c, Description__c, Category__c, Type__c,
                   Include_In_Email__c, Can_Borrower_See__c, Lead_Document_Request_Reference__c
            FROM Lead_Document_Request__c
            WHERE Lead__c = :leadRecord.Id
            LIMIT 1
        ];

        System.assertEquals(1, requests.size());
        System.assertEquals('Asset', createdRequest.Name);
        System.assertEquals('Bank Statements', createdRequest.Subject__c);
        System.assertEquals('Bank Statements', createdRequest.Description__c);
        System.assertEquals('Assets', createdRequest.Category__c);
        System.assertEquals('Processor', createdRequest.Type__c);
        System.assertEquals(true, createdRequest.Include_In_Email__c);
        System.assertEquals(true, createdRequest.Can_Borrower_See__c);
        System.assertEquals(referenceRecord.Id, createdRequest.Lead_Document_Request_Reference__c);
        System.assertEquals(referenceRecord.Id, requests[0].referenceId);
    }

    @IsTest
    static void createRequestsFromSpecialIncomeReferencesIncludesChecklistItems() {
        Lead leadRecord = createLead('special-income-reference@example.com');
        Lead_Document_Request_Reference__c referenceRecord = new Lead_Document_Request_Reference__c(
            Active__c = true,
            Borrower_Label__c = 'Alimony / Child Support',
            Borrower_Description__c = '- Court Order\n- Payment History\n- Proof of Receipt',
            Category__c = 'Income',
            Package__c = 'Special Income Types',
            Type__c = 'Initial Submission Optional',
            Condition_Group_Key__c = 'SPECIAL_INCOME_ALIMONY',
            Reference_Id__c = 'SPECIAL_INCOME_ALIMONY',
            Include_In_Email__c = true,
            Can_Borrower_See__c = true
        );
        insert referenceRecord;

        Test.startTest();
        LeadDocumentRequestService.createRequestsFromReferences(
            leadRecord.Id,
            new List<Id>{ referenceRecord.Id },
            'Loan Officer'
        );
        Test.stopTest();

        Lead_Document_Request__c createdRequest = [
            SELECT Name, Subject__c, Description__c, Category__c, Type__c
            FROM Lead_Document_Request__c
            WHERE Lead__c = :leadRecord.Id
            LIMIT 1
        ];

        System.assertEquals('Income', createdRequest.Name);
        System.assertEquals('Income', createdRequest.Category__c);
        System.assertEquals('Loan Officer', createdRequest.Type__c);
        System.assert(createdRequest.Description__c.contains('Alimony / Child Support'));
        System.assert(createdRequest.Description__c.contains('Court Order'));
        System.assert(createdRequest.Description__c.contains('Payment History'));
        System.assert(createdRequest.Description__c.contains('Proof of Receipt'));
    }

    @IsTest
    static void referenceInvocablesQueryAndCreateRequests() {
        Lead leadRecord = createLead('reference-invocable@example.com');
        Lead_Document_Request_Reference__c firstReference = createReference(
            'Initial Borrower Docs',
            'Driver License',
            'ID',
            'ID_GROUP'
        );
        Lead_Document_Request_Reference__c secondReference = createReference(
            'Additional Borrower Docs',
            'Gift Letter',
            'Gift Letter',
            'GIFT_GROUP'
        );

        LeadDocumentRequestReferenceInvocable.QueryRequest queryRequest =
            new LeadDocumentRequestReferenceInvocable.QueryRequest();
        queryRequest.referenceType = 'Initial Borrower Docs';
        LeadDocRequestCreateInvocable.Request createRequest =
            new LeadDocRequestCreateInvocable.Request();
        createRequest.leadId = leadRecord.Id;
        createRequest.references = new List<Lead_Document_Request_Reference__c>{ firstReference };
        createRequest.type = 'Loan Officer';

        Test.startTest();
        List<LeadDocumentRequestReferenceInvocable.QueryResponse> queryResponses =
            LeadDocumentRequestReferenceInvocable.getReferences(
                new List<LeadDocumentRequestReferenceInvocable.QueryRequest>{ queryRequest }
            );
        List<LeadDocRequestCreateInvocable.Response> createResponses =
            LeadDocRequestCreateInvocable.createRequests(
                new List<LeadDocRequestCreateInvocable.Request>{ createRequest }
            );
        Test.stopTest();

        System.assertEquals(1, queryResponses.size());
        System.assertEquals(1, queryResponses[0].references.size());
        System.assertEquals(firstReference.Id, queryResponses[0].references[0].Id);
        System.assertNotEquals(secondReference.Id, queryResponses[0].references[0].Id);
        System.assertEquals(true, createResponses[0].success);
        System.assertEquals(1, createResponses[0].recordIdsAffected.size());
        Lead_Document_Request__c createdRequest = [
            SELECT Type__c
            FROM Lead_Document_Request__c
            WHERE Lead__c = :leadRecord.Id
            AND Lead_Document_Request_Reference__c = :firstReference.Id
            LIMIT 1
        ];
        System.assertEquals('Loan Officer', createdRequest.Type__c);
    }

    @IsTest
    static void referenceInvocableFiltersInitialBundleLikeTransaction() {
        Lead_Document_Request_Reference__c matchingReference = createReference(
            'Initial Submission',
            'Purchase W2 Paystub',
            'Income',
            'INCOME_GROUP'
        );
        matchingReference.Loan_Purpose__c = 'Purchase';
        matchingReference.Loan_Type__c = 'Conventional';
        matchingReference.Employment_Type__c = 'W2';
        update matchingReference;

        Lead_Document_Request_Reference__c filteredReference = createReference(
            'Initial Submission',
            'Refinance Retired Award Letter',
            'Income',
            'RETIREMENT_GROUP'
        );
        filteredReference.Loan_Purpose__c = 'Refinance';
        filteredReference.Employment_Type__c = 'Retired';
        update filteredReference;

        LeadDocumentRequestReferenceInvocable.QueryRequest queryRequest =
            new LeadDocumentRequestReferenceInvocable.QueryRequest();
        queryRequest.referenceType = 'Initial Submission';
        queryRequest.loanPurpose = 'Purchase';
        queryRequest.loanType = 'Conventional';
        queryRequest.employmentType = 'W2';

        Test.startTest();
        List<LeadDocumentRequestReferenceInvocable.QueryResponse> responses =
            LeadDocumentRequestReferenceInvocable.getReferences(
                new List<LeadDocumentRequestReferenceInvocable.QueryRequest>{ queryRequest }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(1, responses[0].references.size());
        System.assertEquals(matchingReference.Id, responses[0].references[0].Id);
        System.assertNotEquals(filteredReference.Id, responses[0].references[0].Id);
    }

    @IsTest
    static void createInvocableSupportsManualOneOffRequests() {
        Lead leadRecord = createLead('manual-invocable@example.com');
        LeadDocRequestCreateInvocable.Request createRequest = new LeadDocRequestCreateInvocable.Request();
        createRequest.leadId = leadRecord.Id;
        createRequest.name = 'Custom LOE';
        createRequest.description = 'Please upload a signed letter of explanation.';
        createRequest.type = 'Processor';
        createRequest.includeInEmail = true;
        createRequest.canBorrowerSee = true;

        Test.startTest();
        List<LeadDocRequestCreateInvocable.Response> responses =
            LeadDocRequestCreateInvocable.createRequests(
                new List<LeadDocRequestCreateInvocable.Request>{ createRequest }
            );
        Test.stopTest();

        System.assertEquals(true, responses[0].success);
        System.assertEquals(1, [
            SELECT COUNT()
            FROM Lead_Document_Request__c
            WHERE Lead__c = :leadRecord.Id
            AND Name = 'Custom LOE'
            AND Lead_Document_Request_Reference__c = NULL
        ]);
    }

    @IsTest
    static void portalUploadLinksFileAndSetsReview() {
        Lead leadRecord = createLead('portal@example.com');
        LeadDocumentRequestService.populateMissingPortalHashes(new Set<Id>{ leadRecord.Id });
        Lead_Document_Request__c requestRecord = createRequest(leadRecord.Id, 'Bank Statement');
        ContentVersion version = createContentVersion('bank.pdf');
        ContentVersion genericVersion = createContentVersion('generic.pdf');
        Lead leadWithHash = LeadDocumentRequestRepository.getInstance()
            .selectLeadsByIds(new Set<Id>{ leadRecord.Id }).get(leadRecord.Id);
        String portalHash = LeadDocumentRequestService.getLeadPortalHash(leadWithHash);

        Test.startTest();
        LeadDocumentPortalController.initializeData(portalHash, false);
        LeadDocumentPortalService.PortalRequest response =
            LeadDocumentPortalController.updateRequestOnFileUpload(new List<Id>{ version.Id }, requestRecord.Id, portalHash);
        LeadDocumentPortalController.sendGenericDocumentUpload(new List<Id>{ genericVersion.Id }, portalHash);
        Test.stopTest();

        Lead_Document_Request__c updatedRequest = [
            SELECT Status__c
            FROM Lead_Document_Request__c
            WHERE Id = :requestRecord.Id
        ];
        Lead_Document_Request__c genericRequest = [
            SELECT Status__c, Subject__c, Category__c, Type__c, Can_Borrower_See__c, Include_In_Email__c
            FROM Lead_Document_Request__c
            WHERE Lead__c = :leadRecord.Id
            AND Name = 'Generic Document Portal Upload'
            LIMIT 1
        ];
        ContentVersion updatedVersion = [
            SELECT Lead_Document_Request__c
            FROM ContentVersion
            WHERE Id = :version.Id
        ];
        ContentVersion updatedGenericVersion = [
            SELECT Lead_Document_Request__c, Folder__c
            FROM ContentVersion
            WHERE Id = :genericVersion.Id
        ];
        Integer linkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :requestRecord.Id
        ];

        System.assertEquals('Review', response.status);
        System.assertEquals('Review', updatedRequest.Status__c);
        System.assertEquals('Review', genericRequest.Status__c);
        System.assertEquals('Generic Document Portal Upload', genericRequest.Subject__c);
        System.assertEquals('Generic', genericRequest.Category__c);
        System.assertEquals('Generic', genericRequest.Type__c);
        System.assertEquals(true, genericRequest.Can_Borrower_See__c);
        System.assertEquals(false, genericRequest.Include_In_Email__c);
        System.assertEquals(requestRecord.Id, updatedVersion.Lead_Document_Request__c);
        System.assertEquals(genericRequest.Id, updatedGenericVersion.Lead_Document_Request__c);
        System.assertEquals('Unassigned', updatedGenericVersion.Folder__c);
        System.assertEquals(1, linkCount);
    }

    @IsTest
    static void internalUploadLinksFileAndReturnsPreviewDocuments() {
        Lead leadRecord = createLead('internal-upload@example.com');
        Lead_Document_Request__c requestRecord = createRequest(leadRecord.Id, 'Internal Bank Statement');
        ContentVersion version = createContentVersion('internal-bank.pdf');
        ContentVersion secondVersion = createContentVersion('internal-bank-2.pdf');

        Test.startTest();
        LeadDocumentRequestService.RequestItem response =
            LeadDocumentRequestController.handleInternalFileUpload(requestRecord.Id, new List<Id>{ version.Id, secondVersion.Id });
        List<LeadDocumentRequestService.DocumentItem> documents =
            LeadDocumentRequestController.getRequestDocuments(requestRecord.Id);
        Id approvedDocumentId = documents[0].id;
        Id rejectedDocumentId = documents[1].id;
        LeadDocumentRequestService.RequestItem approvedResponse =
            LeadDocumentRequestController.approveRequestDocument(requestRecord.Id, approvedDocumentId);
        LeadDocumentRequestService.RequestItem rejectedResponse =
            LeadDocumentRequestController.rejectRequestDocument(
                requestRecord.Id,
                rejectedDocumentId,
                'Wrong document.',
                'Please upload the correct bank statement.'
            );
        Test.stopTest();

        Lead_Document_Request__c updatedRequest = [
            SELECT Status__c, Description__c
            FROM Lead_Document_Request__c
            WHERE Id = :requestRecord.Id
        ];
        ContentVersion updatedVersion = [
            SELECT Lead_Document_Request__c, Folder__c
            FROM ContentVersion
            WHERE ContentDocumentId = :approvedDocumentId
            AND IsLatest = TRUE
            LIMIT 1
        ];
        ContentVersion updatedSecondVersion = [
            SELECT Lead_Document_Request__c, Folder__c
            FROM ContentVersion
            WHERE ContentDocumentId = :rejectedDocumentId
            AND IsLatest = TRUE
            LIMIT 1
        ];

        System.assertEquals('Review', response.status);
        System.assertEquals(requestRecord.Id, updatedVersion.Lead_Document_Request__c);
        System.assertEquals('Income', updatedVersion.Folder__c);
        System.assertEquals(2, documents.size());
        System.assert(documents[0].filename.contains('internal-bank'));
        System.assert(new Set<String>{ 'Review', 'Approved' }.contains(approvedResponse.status));
        System.assertEquals('Requested', rejectedResponse.status);
        System.assertEquals('Requested', updatedRequest.Status__c);
        System.assertEquals('Please upload the correct bank statement.', updatedRequest.Description__c);
        System.assertEquals('Junk', updatedSecondVersion.Folder__c);
    }

    @IsTest
    static void portalUploadRejectsRequestOutsideActiveLeadHash() {
        Lead activeLead = createLead('active-portal@example.com');
        Lead otherLead = createLead('other-portal@example.com');
        LeadDocumentRequestService.populateMissingPortalHashes(new Set<Id>{ activeLead.Id, otherLead.Id });
        Lead_Document_Request__c otherRequest = createRequest(otherLead.Id, 'Other Lead Request');
        ContentVersion version = createContentVersion('wrong-lead.pdf');
        Lead activeLeadWithHash = LeadDocumentRequestRepository.getInstance()
            .selectLeadsByIds(new Set<Id>{ activeLead.Id }).get(activeLead.Id);

        Boolean rejected = false;

        Test.startTest();
        try {
            LeadDocumentPortalController.updateRequestOnFileUpload(
                new List<Id>{ version.Id },
                otherRequest.Id,
                LeadDocumentRequestService.getLeadPortalHash(activeLeadWithHash)
            );
        } catch (AuraHandledException ex) {
            rejected = true;
        }
        Test.stopTest();

        System.assertEquals(true, rejected);
        System.assertEquals(0, [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :otherRequest.Id
        ]);
    }

    @IsTest
    static void convertedLeadPortalReturnsTransactionRedirect() {
        Transaction__c transactionRecord = createTransaction('Redirect Loan', 'LD-REDIRECT');
        Lead leadRecord = createLead('redirect@example.com');
        leadRecord.Converted_Transaction_ID__c = transactionRecord.Id;
        update leadRecord;
        LeadDocumentRequestService.populateMissingPortalHashes(new Set<Id>{ leadRecord.Id });
        leadRecord = LeadDocumentRequestRepository.getInstance()
            .selectLeadsByIds(new Set<Id>{ leadRecord.Id }).get(leadRecord.Id);

        Test.startTest();
        LeadDocumentPortalService.PortalData data =
            LeadDocumentPortalController.initializeData(LeadDocumentRequestService.getLeadPortalHash(leadRecord), false);
        Test.stopTest();

        System.assertNotEquals(null, data.redirectUrl);
        System.assert(data.redirectUrl.contains('https://example.force.com/documents/s/'));
        System.assert(data.redirectUrl.contains('?id='));
        System.assertEquals(0, data.approvedDocuments);
        System.assertEquals(0, data.requestedDocuments);
        System.assertEquals(0, data.outstandingDocuments);
        System.assertEquals(0, data.pendingReviewDocuments);
    }

    @IsTest
    static void visualforceRedirectSendsConvertedLeadToTransactionPortal() {
        Transaction__c transactionRecord = createTransaction('Visualforce Redirect Loan', 'LD-VF-REDIRECT');
        transactionRecord.Portal_Hash_Parameter__c = 'TRANSACTION-HASH';
        update transactionRecord;
        Lead leadRecord = createLead('vf-redirect@example.com');
        leadRecord.Converted_Transaction_ID__c = transactionRecord.Id;
        leadRecord.put('Portal_Hash_Parameter__c', 'LEAD-HASH');
        update leadRecord;

        Test.startTest();
        Test.setCurrentPage(new PageReference('/apex/LeadDocumentPortalRedirect'));
        ApexPages.currentPage().getParameters().put('id', 'LEAD-HASH');
        PageReference redirectPage = new LeadDocumentPortalRedirectController().redirect();
        Test.stopTest();

        System.assertNotEquals(null, redirectPage);
        System.assertEquals('https://example.force.com/documents/s/?id=TRANSACTION-HASH', redirectPage.getUrl());
    }

    @IsTest
    static void visualforceRedirectKeepsOpenLeadOnLeadPortal() {
        LeadDocumentPortalRedirectController.testLeadHomeUrlOverride = 'https://example.force.com/leadportal/s/';

        String leadPortalUrl = LeadDocumentPortalRedirectController.buildLeadPortalUrl('ABC123');

        System.assertEquals('https://example.force.com/leadportal/s/?id=ABC123', leadPortalUrl);
    }

    @IsTest
    static void visualforceRedirectReturnsNoPageWithoutHash() {
        Test.setCurrentPage(new PageReference('/apex/LeadDocumentPortalRedirect'));

        PageReference redirectPage = new LeadDocumentPortalRedirectController().redirect();

        System.assertEquals(null, redirectPage);
    }

    @IsTest
    static void visualforceRedirectFallsBackToLeadPortalForOpenLead() {
        LeadDocumentPortalRedirectController.testLeadHomeUrlOverride = 'https://example.force.com/leadportal/s/';
        Lead leadRecord = createLead('vf-open@example.com');
        LeadDocumentRequestService.populateMissingPortalHashes(new Set<Id>{ leadRecord.Id });
        leadRecord = LeadDocumentRequestRepository.getInstance()
            .selectLeadsByIds(new Set<Id>{ leadRecord.Id }).get(leadRecord.Id);

        Test.setCurrentPage(new PageReference('/apex/LeadDocumentPortalRedirect'));
        ApexPages.currentPage().getParameters().put('id', LeadDocumentRequestService.getLeadPortalHash(leadRecord));
        PageReference redirectPage = new LeadDocumentPortalRedirectController().redirect();

        System.assertNotEquals(null, redirectPage);
        System.assertEquals(
            'https://example.force.com/leadportal/s/?id=' + LeadDocumentRequestService.getLeadPortalHash(leadRecord),
            redirectPage.getUrl()
        );
    }

    @IsTest
    static void visualforceRedirectBuildsLeadPortalUrlsFromSettingsAndQueries() {
        LeadDocumentPortalRedirectController.testLeadHomeUrlOverride = null;
        String configuredUrl = LeadDocumentPortalRedirectController.buildLeadPortalUrl('FROM-SETTING');

        LeadDocumentPortalRedirectController.testLeadHomeUrlOverride = 'https://example.force.com/leadportal/s/?source=email';
        String urlWithExistingQuery = LeadDocumentPortalRedirectController.buildLeadPortalUrl('FROM-QUERY');

        System.assertEquals('https://example.force.com/documents/s/lead?id=FROM-SETTING', configuredUrl);
        System.assertEquals('https://example.force.com/leadportal/s/?source=email&id=FROM-QUERY', urlWithExistingQuery);
    }

    @IsTest
    static void visualforceRedirectFallsBackForUnknownHash() {
        LeadDocumentPortalRedirectController.testLeadHomeUrlOverride = 'https://example.force.com/leadportal/s/';

        Test.setCurrentPage(new PageReference('/apex/LeadDocumentPortalRedirect'));
        ApexPages.currentPage().getParameters().put('id', 'UNKNOWN-HASH');
        PageReference redirectPage = new LeadDocumentPortalRedirectController().redirect();

        System.assertEquals('https://example.force.com/leadportal/s/?id=UNKNOWN-HASH', redirectPage.getUrl());
    }

    @IsTest
    static void visualforceRedirectFallsBackWhenConvertedTransactionHasNoHash() {
        LeadDocumentPortalRedirectController.testLeadHomeUrlOverride = 'https://example.force.com/leadportal/s/';
        Transaction__c transactionRecord = createTransaction('No Portal Hash Loan', 'LD-NO-HASH');
        Lead leadRecord = createLead('vf-no-hash@example.com');
        leadRecord.Converted_Transaction_ID__c = transactionRecord.Id;
        update leadRecord;
        LeadDocumentRequestService.populateMissingPortalHashes(new Set<Id>{ leadRecord.Id });
        leadRecord = LeadDocumentRequestRepository.getInstance()
            .selectLeadsByIds(new Set<Id>{ leadRecord.Id }).get(leadRecord.Id);

        Test.setCurrentPage(new PageReference('/apex/LeadDocumentPortalRedirect'));
        ApexPages.currentPage().getParameters().put('id', LeadDocumentRequestService.getLeadPortalHash(leadRecord));
        PageReference redirectPage = new LeadDocumentPortalRedirectController().redirect();

        System.assertEquals(
            'https://example.force.com/leadportal/s/?id=' + LeadDocumentRequestService.getLeadPortalHash(leadRecord),
            redirectPage.getUrl()
        );
    }

    @IsTest
    static void visualforceRedirectFallsBackWhenBorrowerHomeUrlIsBlank() {
        BorrowerPortalSettings__c settings = BorrowerPortalSettings__c.getOrgDefaults();
        settings.Borrower_Home_Url__c = '';
        update settings;
        LeadDocumentPortalRedirectController.testLeadHomeUrlOverride = 'https://example.force.com/leadportal/s/';
        Transaction__c transactionRecord = createTransaction('Blank Borrower Home Loan', 'LD-BLANK-HOME');
        BorrowerPortalService.populateMissingPortalHashes(new Set<Id>{ transactionRecord.Id });
        Lead leadRecord = createLead('vf-blank-home@example.com');
        leadRecord.Converted_Transaction_ID__c = transactionRecord.Id;
        update leadRecord;
        LeadDocumentRequestService.populateMissingPortalHashes(new Set<Id>{ leadRecord.Id });
        leadRecord = LeadDocumentRequestRepository.getInstance()
            .selectLeadsByIds(new Set<Id>{ leadRecord.Id }).get(leadRecord.Id);

        Test.setCurrentPage(new PageReference('/apex/LeadDocumentPortalRedirect'));
        ApexPages.currentPage().getParameters().put('id', LeadDocumentRequestService.getLeadPortalHash(leadRecord));
        PageReference redirectPage = new LeadDocumentPortalRedirectController().redirect();

        System.assertEquals(
            'https://example.force.com/leadportal/s/?id=' + LeadDocumentRequestService.getLeadPortalHash(leadRecord),
            redirectPage.getUrl()
        );
    }

    @IsTest
    static void leadPortalCountsUseBorrowerTileStatusMapping() {
        Lead leadRecord = createLead('portal-counts@example.com');
        Lead_Document_Request__c requestedRequest = createRequest(leadRecord.Id, 'Requested Request');
        Lead_Document_Request__c reviewRequest = createRequest(leadRecord.Id, 'Review Request');
        Lead_Document_Request__c clearedRequest = createRequest(leadRecord.Id, 'Cleared Request');
        Lead_Document_Request__c approvedRequest = createRequest(leadRecord.Id, 'Approved Request');
        reviewRequest.Status__c = 'Review';
        clearedRequest.Status__c = 'Cleared';
        approvedRequest.Status__c = 'Approved';
        update new List<Lead_Document_Request__c>{ reviewRequest, clearedRequest, approvedRequest };
        LeadDocumentRequestService.populateMissingPortalHashes(new Set<Id>{ leadRecord.Id });
        leadRecord = LeadDocumentRequestRepository.getInstance()
            .selectLeadsByIds(new Set<Id>{ leadRecord.Id }).get(leadRecord.Id);

        Test.startTest();
        LeadDocumentPortalService.PortalData data =
            LeadDocumentPortalController.initializeData(LeadDocumentRequestService.getLeadPortalHash(leadRecord), false);
        Test.stopTest();

        System.assertEquals(1, data.requestedDocuments, 'Needed tile should count Requested requests only.');
        System.assertEquals(1, data.pendingReviewDocuments, 'Uploaded tile should count Review requests only.');
        System.assertEquals(1, data.approvedDocuments, 'Approved tile should count Cleared requests only.');
        System.assertEquals(0, data.outstandingDocuments);
        System.assertEquals(3, data.requests.size(), 'Approved status requests are hidden from the borrower portal table.');
    }

    @IsTest
    static void carryForwardCreatesConditionsAndLinksFiles() {
        Transaction__c transactionRecord = createTransaction('Carry Loan', 'LD-CARRY');
        Lead leadRecord = createLead('carry@example.com');
        leadRecord.Converted_Transaction_ID__c = transactionRecord.Id;
        update leadRecord;
        Lead_Document_Request_Reference__c referenceRecord = createReference(
            'Initial Borrower Docs',
            'W2',
            'Income',
            'INCOME_GROUP'
        );
        Lead_Document_Request__c requestRecord = createRequest(leadRecord.Id, 'W2');
        requestRecord.Lead_Document_Request_Reference__c = referenceRecord.Id;
        requestRecord.Type__c = 'Loan Officer';
        update requestRecord;
        ContentVersion version = createContentVersion('w2.pdf');
        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
        ].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = requestRecord.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        LeadDocumentCarryForwardInvocable.Request invocableRequest = new LeadDocumentCarryForwardInvocable.Request();
        invocableRequest.leadId = leadRecord.Id;
        LeadDocumentCarryForwardInvocable.carryForward(new List<LeadDocumentCarryForwardInvocable.Request>{ invocableRequest });
        Test.stopTest();

        Lead_Document_Request__c convertedRequest = [
            SELECT Converted_Condition__c, Lead_Document_Request_Reference__c
            FROM Lead_Document_Request__c
            WHERE Id = :requestRecord.Id
        ];
        Condition__c conditionRecord = [
            SELECT Transaction__c, Name, Status__c, Type__c, Lead_Document_Request_Reference__c, Condition_Group_Key__c
            FROM Condition__c
            WHERE Id = :convertedRequest.Converted_Condition__c
        ];
        ContentVersion stampedVersion = [
            SELECT Condition__c
            FROM ContentVersion
            WHERE Id = :version.Id
        ];
        Integer transactionLinkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :transactionRecord.Id
            AND ContentDocumentId = :contentDocumentId
        ];

        System.assertEquals(transactionRecord.Id, conditionRecord.Transaction__c);
        System.assertEquals('W2', conditionRecord.Name);
        System.assertEquals('Requested', conditionRecord.Status__c);
        System.assertEquals('Loan Officer', conditionRecord.Type__c);
        System.assertEquals(referenceRecord.Id, convertedRequest.Lead_Document_Request_Reference__c);
        System.assertEquals(referenceRecord.Id, conditionRecord.Lead_Document_Request_Reference__c);
        System.assertEquals('INCOME_GROUP', conditionRecord.Condition_Group_Key__c);
        System.assertEquals(conditionRecord.Id, stampedVersion.Condition__c);
        System.assertEquals(1, transactionLinkCount);

        LeadDocumentCarryForwardService.carryForward(new Set<Id>{ leadRecord.Id });
        System.assertEquals(1, [
            SELECT COUNT()
            FROM Condition__c
            WHERE Transaction__c = :transactionRecord.Id
        ]);
    }

    @IsTest
    static void carryForwardFallsBackForPackageBucketType() {
        Transaction__c transactionRecord = createTransaction('Fallback Type Loan', 'LD-FALLBACK');
        Lead leadRecord = createLead('fallback-carry@example.com');
        leadRecord.Converted_Transaction_ID__c = transactionRecord.Id;
        update leadRecord;

        Lead_Document_Request__c requestRecord = createRequest(leadRecord.Id, 'Initial Package Row');
        requestRecord.Type__c = 'Initial Submission';
        update requestRecord;

        Test.startTest();
        LeadDocumentCarryForwardService.carryForward(new Set<Id>{ leadRecord.Id });
        Test.stopTest();

        Condition__c conditionRecord = [
            SELECT Type__c
            FROM Condition__c
            WHERE Transaction__c = :transactionRecord.Id
            LIMIT 1
        ];
        System.assertEquals('Processor', conditionRecord.Type__c);
    }

    @IsTest
    static void carryForwardSharedDocumentLinksAllConditionsWithoutAmbiguousStamp() {
        Transaction__c transactionRecord = createTransaction('Shared Carry Loan', 'LD-SHARED');
        Lead leadRecord = createLead('shared-carry@example.com');
        leadRecord.Converted_Transaction_ID__c = transactionRecord.Id;
        update leadRecord;

        Lead_Document_Request__c firstRequest = createRequest(leadRecord.Id, 'Shared Bank Statement');
        Lead_Document_Request__c secondRequest = createRequest(leadRecord.Id, 'Shared Asset Statement');
        ContentVersion version = createContentVersion('shared.pdf');
        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
        ].ContentDocumentId;
        insert new List<ContentDocumentLink>{
            new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = firstRequest.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ),
            new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = secondRequest.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            )
        };

        Test.startTest();
        LeadDocumentCarryForwardService.carryForward(new Set<Id>{ leadRecord.Id });
        Test.stopTest();

        Set<Id> conditionIds = new Set<Id>();
        Set<Id> requestIds = new Set<Id>{ firstRequest.Id, secondRequest.Id };
        for (Lead_Document_Request__c requestRecord : [
            SELECT Converted_Condition__c
            FROM Lead_Document_Request__c
            WHERE Id IN :requestIds
        ]) {
            conditionIds.add(requestRecord.Converted_Condition__c);
        }
        ContentVersion stampedVersion = [
            SELECT Condition__c
            FROM ContentVersion
            WHERE Id = :version.Id
        ];

        System.assertEquals(2, conditionIds.size());
        System.assertEquals(2, [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :conditionIds
            AND ContentDocumentId = :contentDocumentId
        ]);
        System.assertEquals(1, [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :transactionRecord.Id
            AND ContentDocumentId = :contentDocumentId
        ]);
        System.assertEquals(null, stampedVersion.Condition__c);
    }

    @IsTest
    static void carryForwardSkipsConvertedRequestFilesAndProcessesOpenRequests() {
        Transaction__c transactionRecord = createTransaction('Mixed Carry Loan', 'LD-MIXED');
        Lead leadRecord = createLead('mixed-carry@example.com');
        leadRecord.Converted_Transaction_ID__c = transactionRecord.Id;
        update leadRecord;

        Lead_Document_Request__c convertedRequest = createRequest(leadRecord.Id, 'Already Converted');
        Condition__c existingCondition = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Name = 'Already Converted',
            Status__c = 'Requested'
        );
        insert existingCondition;
        convertedRequest.Converted_Condition__c = existingCondition.Id;
        update convertedRequest;

        Lead_Document_Request__c openRequest = createRequest(leadRecord.Id, 'Open Request');
        Id convertedDocumentId = createLinkedDocument(convertedRequest.Id, 'converted.pdf');
        Id openDocumentId = createLinkedDocument(openRequest.Id, 'open.pdf');

        Test.startTest();
        LeadDocumentCarryForwardService.carryForward(new Set<Id>{ leadRecord.Id });
        Test.stopTest();

        Lead_Document_Request__c carriedRequest = [
            SELECT Converted_Condition__c
            FROM Lead_Document_Request__c
            WHERE Id = :openRequest.Id
        ];
        System.assertNotEquals(null, carriedRequest.Converted_Condition__c);
        System.assertEquals(2, [
            SELECT COUNT()
            FROM Condition__c
            WHERE Transaction__c = :transactionRecord.Id
        ]);
        System.assertEquals(0, [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :transactionRecord.Id
            AND ContentDocumentId = :convertedDocumentId
        ]);
        System.assertEquals(1, [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :transactionRecord.Id
            AND ContentDocumentId = :openDocumentId
        ]);
    }

    @IsTest
    static void repositorySelectorsReturnExpectedLeadDocumentData() {
        Lead leadRecord = createLead('repository.selectors@example.com');
        Lead_Document_Request__c visibleRequest = createRequest(leadRecord.Id, 'Visible Request', true, true);
        Lead_Document_Request__c hiddenRequest = createRequest(leadRecord.Id, 'Hidden Request', false, false);
        Lead_Document_Request__c approvedRequest = createRequest(leadRecord.Id, 'Approved Request', true, true);
        approvedRequest.Status__c = 'Approved';
        approvedRequest.Include_In_Email__c = false;
        update approvedRequest;
        ContentVersion version = createContentVersion('visible.pdf');
        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
        ].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = visibleRequest.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        LeadDocumentRequestRepository repository = LeadDocumentRequestRepository.getInstance();

        Test.startTest();
        Map<Id, Lead> leadsById = repository.selectLeadsByIds(new Set<Id>{ leadRecord.Id });
        Map<Id, Lead> leadsForPortalHash = repository.selectLeadsForPortalHash(new Set<Id>{ leadRecord.Id });
        List<Lead_Document_Request__c> allRequests = repository.selectByLeadIds(new Set<Id>{ leadRecord.Id });
        List<Lead_Document_Request__c> visibleRequests = repository.selectVisibleByLeadId(leadRecord.Id);
        Lead_Document_Request__c portalUploadRequest = repository.selectRequestForPortalUpload(visibleRequest.Id);
        Lead_Document_Request__c genericUploadRequest = repository.selectGenericUploadRequest(
            leadRecord.Id,
            hiddenRequest.Name
        );
        List<Lead_Document_Request__c> includedForEmail = repository.selectIncludedForEmail(leadRecord.Id);
        List<Lead_Document_Request__c> unconvertedRequests =
            repository.selectUnconvertedByLeadIds(new Set<Id>{ leadRecord.Id });
        Map<Id, Decimal> fileCounts = repository.selectLinkedDocumentCountsByRequestIds(
            new Set<Id>{ visibleRequest.Id, hiddenRequest.Id }
        );
        List<ContentVersion> versionsByLatestId = repository.selectContentVersionsByLatestIds(new Set<Id>{ version.Id });
        List<ContentVersion> latestVersionsByDocument =
            repository.selectLatestContentVersionsByDocumentIds(new Set<Id>{ contentDocumentId });
        List<ContentDocumentLink> links = repository.selectDocumentLinksByEntityIds(new Set<Id>{ visibleRequest.Id });
        Map<Id, User> usersById = repository.selectUsersByIds(new Set<Id>{ UserInfo.getUserId() });
        Test.stopTest();

        System.assertEquals(leadRecord.Id, leadsById.get(leadRecord.Id).Id);
        System.assertEquals(leadRecord.Id, leadsForPortalHash.get(leadRecord.Id).Id);
        System.assertEquals(3, allRequests.size());
        System.assertEquals(1, visibleRequests.size());
        System.assertEquals(visibleRequest.Id, visibleRequests[0].Id);
        System.assertEquals(visibleRequest.Id, portalUploadRequest.Id);
        System.assertEquals(hiddenRequest.Id, genericUploadRequest.Id);
        System.assertEquals(1, includedForEmail.size());
        System.assertEquals(visibleRequest.Id, includedForEmail[0].Id);
        System.assertEquals(3, unconvertedRequests.size());
        System.assertEquals(1, fileCounts.get(visibleRequest.Id));
        System.assertEquals(version.Id, versionsByLatestId[0].Id);
        System.assertEquals(contentDocumentId, latestVersionsByDocument[0].ContentDocumentId);
        System.assertEquals(1, links.size());
        System.assertEquals(UserInfo.getUserId(), usersById.get(UserInfo.getUserId()).Id);
    }

    @IsTest
    static void repositorySelectorsHandleEmptyInputsAndSkipConvertedRequests() {
        Lead leadRecord = createLead('repository.empty@example.com');
        Lead_Document_Request__c unconvertedRequest = createRequest(
            leadRecord.Id,
            'Unconverted Request',
            true,
            true
        );
        Lead_Document_Request__c convertedRequest = createRequest(leadRecord.Id, 'Converted Request', true, true);
        Transaction__c transactionRecord = createTransaction('Repository Coverage Transaction', 'REPO-COVERAGE');
        Condition__c conditionRecord = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Name = 'Converted Request',
            Status__c = 'Requested'
        );
        insert conditionRecord;
        convertedRequest.Converted_Condition__c = conditionRecord.Id;
        update convertedRequest;

        LeadDocumentRequestRepository repository = LeadDocumentRequestRepository.getInstance();

        Test.startTest();
        System.assertEquals(0, repository.selectLeadsByIds(null).size());
        System.assertEquals(0, repository.selectLeadsForPortalHash(new Set<Id>()).size());
        System.assertEquals(null, repository.selectLeadByPortalHash(null));
        System.assertEquals(null, repository.selectLeadByPortalHash('test-hash'));
        System.assertEquals(0, repository.selectByLeadIds(null).size());
        System.assertEquals(0, repository.selectVisibleByLeadId(null).size());
        System.assertEquals(null, repository.selectRequestForPortalUpload(null));
        System.assertEquals(null, repository.selectGenericUploadRequest(null, 'Request'));
        System.assertEquals(null, repository.selectGenericUploadRequest(leadRecord.Id, null));
        System.assertEquals(null, repository.selectFirstLeadWithPortalHash());
        System.assertEquals(0, repository.selectIncludedForEmail(null).size());
        System.assertEquals(0, repository.selectUnconvertedByLeadIds(null).size());
        List<Lead_Document_Request__c> unconvertedRequests =
            repository.selectUnconvertedByLeadIds(new Set<Id>{ leadRecord.Id });
        System.assertEquals(0, repository.selectLinkedDocumentCountsByRequestIds(null).size());
        System.assertEquals(0, repository.selectContentVersionsByLatestIds(null).size());
        System.assertEquals(0, repository.selectLatestContentVersionsByDocumentIds(null).size());
        System.assertEquals(0, repository.selectDocumentLinksByEntityIds(null).size());
        System.assertEquals(null, repository.selectEmailTemplateByDeveloperName(null));
        System.assertEquals(null, repository.selectEmailTemplateByDeveloperName('Template_That_Does_Not_Exist'));
        System.assertEquals(0, repository.selectUsersByIds(null).size());
        System.assertEquals(false, repository.hasLeadPortalHashField());
        System.assertEquals(false, repository.hasLeadPortalLinkField());
        Test.stopTest();

        System.assertEquals(1, unconvertedRequests.size());
        System.assertEquals(unconvertedRequest.Id, unconvertedRequests[0].Id);
    }

    @IsTest
    static void loanRepositorySelectorsReturnExpectedLoans() {
        Transaction__c transactionRecord = createTransaction('Loan Repository Transaction', 'LD-LOAN-REPO');
        transactionRecord.FedexTrackingNumber__c = 'FEDEX-LOAN-REPO';
        update transactionRecord;
        BorrowerPortalService.populateMissingPortalHashes(new Set<Id>{ transactionRecord.Id });

        LoanRepository repository = LoanRepository.getInstance();

        Test.startTest();
        Map<Id, Loan> loansById = repository.getLoanMapByIds(new Set<Id>{ transactionRecord.Id });
        Loan loanById = repository.getLoanById(transactionRecord.Id);
        Loan borrowerPortalLoan = repository.getLoanForBorrowerPortalById(transactionRecord.Id);
        Loan firstPortalLoan = repository.getFirstLoanWithPortalHash();
        List<Transaction__c> selectedTransactions =
            repository.selectTransactionsByIds(new Set<Id>{ transactionRecord.Id });
        Database.QueryLocator refreshScope = repository.getBorrowerPortalHashRefreshScope();
        Loan loanByFedex = repository.getLoanByFedexTrackingNumber('FEDEX-LOAN-REPO');
        Test.stopTest();

        System.assertEquals(transactionRecord.Id, loansById.get(transactionRecord.Id).getId());
        System.assertEquals(transactionRecord.Id, loanById.getId());
        System.assertEquals(transactionRecord.Id, borrowerPortalLoan.getId());
        System.assertNotEquals(null, firstPortalLoan);
        System.assertEquals(1, selectedTransactions.size());
        System.assertNotEquals(null, selectedTransactions[0].Portal_Hash_Parameter__c);
        System.assertNotEquals(null, refreshScope);
        System.assertEquals(transactionRecord.Id, loanByFedex.getId());
    }

    @IsTest
    static void controllerAndInvocableErrorPathsAreHandled() {
        Boolean requestControllerThrew = false;
        Boolean portalControllerThrew = false;
        Boolean uploadControllerThrew = false;
        Boolean internalUploadControllerThrew = false;

        Test.startTest();
        try {
            LeadDocumentRequestController.initializeData(null);
        } catch (Exception ex) {
            requestControllerThrew = true;
        }

        try {
            LeadDocumentPortalController.initializeData('not-a-valid-hash', false);
        } catch (AuraHandledException ex) {
            portalControllerThrew = true;
        }

        try {
            LeadDocumentPortalController.updateRequestOnFileUpload(new List<Id>(), null, 'not-a-valid-hash');
        } catch (AuraHandledException ex) {
            uploadControllerThrew = true;
        }

        try {
            LeadDocumentRequestController.handleInternalFileUpload(null, new List<Id>());
        } catch (Exception ex) {
            internalUploadControllerThrew = true;
        }
        System.assertEquals(0, LeadDocumentRequestController.getRequestDocuments(null).size());

        LeadDocumentCarryForwardService.forceExceptionForTest = true;
        LeadDocumentCarryForwardInvocable.Request request = new LeadDocumentCarryForwardInvocable.Request();
        request.leadId = createLead('error@example.com').Id;
        List<LeadDocumentCarryForwardInvocable.Result> results =
            LeadDocumentCarryForwardInvocable.carryForward(new List<LeadDocumentCarryForwardInvocable.Request>{ request });
        LeadDocumentCarryForwardService.forceExceptionForTest = false;
        Test.stopTest();

        System.assertEquals(true, requestControllerThrew);
        System.assertEquals(true, portalControllerThrew);
        System.assertEquals(true, uploadControllerThrew);
        System.assertEquals(true, internalUploadControllerThrew);
        System.assertEquals(false, results[0].success);
        System.assertEquals('LEAD_DOCUMENT_CARRY_FORWARD_FAILED', results[0].errorCode);
    }

    private static Lead createLead(String email) {
        LeadDocumentRequestService.testLeadHomeUrlOverride = 'https://example.force.com/documents/s/lead';
        Lead leadRecord = new Lead(
            FirstName = 'Test',
            LastName = 'Borrower',
            Company = 'Test Borrower',
            Status = 'New',
            Email = email
        );
        insert leadRecord;
        return leadRecord;
    }

    private static Lead_Document_Request__c createRequest(Id leadId, String name) {
        return createRequest(leadId, name, true, true);
    }

    private static Lead_Document_Request__c createRequest(
        Id leadId,
        String name,
        Boolean includeInEmail,
        Boolean canBorrowerSee
    ) {
        Lead_Document_Request__c requestRecord = new Lead_Document_Request__c(
            Lead__c = leadId,
            Name = name,
            Subject__c = name,
            Description__c = 'Please upload ' + name,
            Category__c = 'Income',
            Type__c = 'Processor',
            Status__c = 'Requested',
            Include_In_Email__c = includeInEmail,
            Can_Borrower_See__c = canBorrowerSee
        );
        insert requestRecord;
        return requestRecord;
    }

    private static Lead_Document_Request_Reference__c createReference(
        String referenceType,
        String borrowerLabel,
        String category,
        String groupKey
    ) {
        Lead_Document_Request_Reference__c referenceRecord = new Lead_Document_Request_Reference__c(
            Active__c = true,
            Borrower_Label__c = borrowerLabel,
            Borrower_Description__c = 'Upload two months of bank statements.',
            Category__c = category,
            Type__c = referenceType,
            Condition_Group_Key__c = groupKey,
            Reference_Id__c = referenceType.replace(' ', '_') + '_' + borrowerLabel.replace(' ', '_'),
            Include_In_Email__c = true,
            Can_Borrower_See__c = true
        );
        insert referenceRecord;
        return referenceRecord;
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

    private static ContentVersion createContentVersion(String filename) {
        ContentVersion version = new ContentVersion(
            Title = filename,
            PathOnClient = filename,
            VersionData = Blob.valueOf('test')
        );
        insert version;
        return version;
    }

    private static Id createLinkedDocument(Id linkedEntityId, String filename) {
        ContentVersion version = createContentVersion(filename);
        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :version.Id
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
