@IsTest
public with sharing class BorrowerDocumentPortalControllerTest {
    private static final String TEST_AES_KEY = '12345678901234567890123456789012';

    @IsTest
    static void initializeDataReturnsBorrowerVisibleConditions() {
        BorrowerPortalEncryptionService.testKeyOverride = TEST_AES_KEY;

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Document Portal Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-BDP-001',
            Borrower_First_Name__c = 'Taylor',
            Borrower_Last_Name__c = 'Borrower',
            Loan_Officer__c = UserInfo.getUserId()
        );
        insert transactionRecord;

        Condition__c fileBackedCondition = createCondition(
            transactionRecord.Id,
            'New',
            'Need bank statement',
            true
        );
        Condition__c requestedCondition = createCondition(transactionRecord.Id, 'Requested', 'Need W2', true);
        insert new List<Condition__c>{
            fileBackedCondition,
            requestedCondition,
            createCondition(transactionRecord.Id, 'Review', 'Pending review item', true),
            createCondition(transactionRecord.Id, 'Approved', 'Approved item', true),
            createCondition(transactionRecord.Id, 'New', 'Internal only condition', false)
        };

        createContentVersion(fileBackedCondition.Id, 'bank-statement.pdf');
        createContentVersion(fileBackedCondition.Id, 'paystub.pdf');
        Condition_Comment__c clearedProcessorComment = new Condition_Comment__c(
            Condition__c = fileBackedCondition.Id,
            Comment_Text__c = 'Earlier processor update.',
            Portal_Comment__c = false,
            Public__c = true,
            Read__c = true
        );
        Condition_Comment__c borrowerReplyComment = new Condition_Comment__c(
            Condition__c = fileBackedCondition.Id,
            Comment_Text__c = 'Borrower reply after processor update.',
            Portal_Comment__c = true,
            Public__c = true,
            Read__c = false
        );
        Condition_Comment__c activeProcessorComment = new Condition_Comment__c(
            Condition__c = requestedCondition.Id,
            Comment_Text__c = 'Processor update for borrower.',
            Portal_Comment__c = false,
            Public__c = true,
            Read__c = false
        );
        insert new List<Condition_Comment__c>{
            clearedProcessorComment,
            borrowerReplyComment,
            activeProcessorComment
        };
        Test.setCreatedDate(clearedProcessorComment.Id, Datetime.now().addMinutes(-2));
        Test.setCreatedDate(borrowerReplyComment.Id, Datetime.now().addMinutes(-1));

        String hashId = BorrowerPortalService.encryptTransactionId(transactionRecord.Id);

        Test.startTest();
        BorrowerDocumentPortalController.DataWrapper wrapper =
            BorrowerDocumentPortalController.initializeData(hashId, false);
        Test.stopTest();

        System.assertNotEquals(null, wrapper);
        System.assertEquals(String.valueOf(transactionRecord.Id), wrapper.recordId);
        System.assertEquals('Taylor Borrower', wrapper.borrowerName);
        System.assertEquals(3, wrapper.conditions.size());
        System.assertEquals(1, wrapper.outstandingDocuments);
        System.assertEquals(1, wrapper.requestedDocuments);
        System.assertEquals(1, wrapper.pendingReviewDocuments);
        System.assertEquals(0, wrapper.approvedDocuments);

        Decimal fileCount = null;
        Boolean foundActiveCommentIndicator = false;
        for (BorrowerDocumentPortalController.LoanCondition condition : wrapper.conditions) {
            System.assertNotEquals('Approved', condition.status);
            if (condition.description == 'Need bank statement') {
                fileCount = condition.fileCount;
                System.assertEquals(String.valueOf(transactionRecord.Id), condition.parentId);
                System.assertEquals(2, condition.commentCount);
                System.assertEquals(0, condition.activeCommentCount);
                System.assertEquals(false, condition.hasActiveComments);
            }
            if (condition.description == 'Need W2') {
                foundActiveCommentIndicator = true;
                System.assertEquals(1, condition.commentCount);
                System.assertEquals(1, condition.activeCommentCount);
                System.assertEquals(true, condition.hasActiveComments);
            }
        }
        System.assertEquals(2, fileCount);
        System.assertEquals(true, foundActiveCommentIndicator);

        BorrowerDocumentPortalController.markProcessorCommentsViewedByBorrower(requestedCondition.Id);
        BorrowerDocumentPortalController.DataWrapper viewedWrapper =
            BorrowerDocumentPortalController.initializeData(hashId, false);
        for (BorrowerDocumentPortalController.LoanCondition condition : viewedWrapper.conditions) {
            if (condition.description == 'Need W2') {
                System.assertEquals(1, condition.commentCount);
                System.assertEquals(0, condition.activeCommentCount);
                System.assertEquals(false, condition.hasActiveComments);
            }
        }
    }

    @IsTest
    static void getFieldsForBorrowerPortalPreapprovalReturnsTransactionData() {
        BorrowerPortalEncryptionService.testKeyOverride = TEST_AES_KEY;

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Preapproval Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-BDP-002',
            Borrower_First_Name__c = 'Robin',
            Borrower_Last_Name__c = 'Buyer',
            Borrower_Income__c = 5000,
            CoBorrower_Income__c = 2500,
            Purchase_Price__c = 400000,
            Down_Payment__c = 40000,
            Interest_Rate__c = 6.5,
            Loan_Amount__c = 360000,
            LTV__c = 90,
            Property_Address__c = '123 Main St',
            Property_City__c = 'Tampa',
            Property_State__c = 'FL',
            Property_Postal_Code__c = '33602',
            Loan_Type_1st_TD__c = 'Conventional',
            Loan_Officer__c = UserInfo.getUserId()
        );
        insert transactionRecord;

        Test.startTest();
        BorrowerDocumentPortalController.BorrowerPortalPreApprovalData data =
            BorrowerDocumentPortalController.getFieldsForBorrowerPortalPreapproval(
                BorrowerPortalService.encryptTransactionId(transactionRecord.Id)
            );
        Test.stopTest();

        System.assertEquals(7500, data.monthlyIncome);
        System.assertEquals(400000, data.purchasePrice);
        System.assertEquals(40000, data.downPayment);
        System.assertEquals(360000, data.loanAmount);
        System.assertEquals(90, data.loanToValue);
        System.assertEquals('Robin', data.borrowerFirstName);
        System.assertEquals('Buyer', data.borrowerLastName);
        System.assertEquals('123 Main St', data.propertyStreet);
        System.assertEquals('Tampa', data.propertyCity);
        System.assertEquals('FL', data.propertyState);
        System.assertEquals('33602', data.propertyZip);
        System.assertEquals('Conventional', data.loanType);
    }

    @IsTest
    static void sendGenericDocumentPlatformEventsCreatesGenericCondition() {
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Generic Upload Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-BDP-003',
            Processor__c = UserInfo.getUserId()
        );
        insert transactionRecord;

        ContentVersion versionRecord = createContentVersion(transactionRecord.Id, 'generic-upload.pdf');

        Test.startTest();
        BorrowerDocumentPortalController.sendGenericDocumentPlatformEvents(
            new List<String>{ String.valueOf(versionRecord.ContentDocumentId) },
            String.valueOf(transactionRecord.Id)
        );
        Test.stopTest();

        List<Condition__c> genericConditions = [
            SELECT Id, Status__c, Subject__c, Description__c, Assigned_To__c
            FROM Condition__c
            WHERE Transaction__c = :transactionRecord.Id
            AND Subject__c = 'Unassigned'
        ];
        List<ContentDocumentLink> conditionLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :genericConditions[0].Id
            AND ContentDocumentId = :versionRecord.ContentDocumentId
        ];
        ContentVersion updatedVersion = [
            SELECT Folder__c, Condition__c, Condition_Document_Review_Status__c
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
        ];
        List<ConditionReviewQueueService.LoanQueueDto> pendingReviewItems =
            ConditionReviewQueueService.buildQueue();

        System.assertEquals(1, genericConditions.size());
        System.assertEquals('Review', genericConditions[0].Status__c);
        System.assertEquals('Unassigned', genericConditions[0].Description__c);
        System.assertEquals(UserInfo.getUserId(), genericConditions[0].Assigned_To__c);
        System.assertEquals(1, conditionLinks.size());
        System.assertEquals('Unassigned', updatedVersion.Folder__c);
        System.assertEquals(genericConditions[0].Id, updatedVersion.Condition__c);
        System.assertEquals('Pending Review', updatedVersion.Condition_Document_Review_Status__c);
        System.assertEquals(1, pendingReviewItems.size());
        System.assertEquals(genericConditions[0].Id, pendingReviewItems[0].conditions[0].id);
    }

    @IsTest
    static void getDataFromFieldNameReturnsLoanOfficerData() {
        BorrowerPortalEncryptionService.testKeyOverride = TEST_AES_KEY;
        User loanOfficer = createPortalUser();

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Contact Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-BDP-004',
            Loan_Officer__c = loanOfficer.Id
        );
        insert transactionRecord;

        Test.startTest();
        Map<String, String> contactData = BorrowerDocumentPortalController.getDataFromFieldName(
            'Loan_Officer__r',
            BorrowerPortalService.encryptTransactionId(transactionRecord.Id)
        );
        Test.stopTest();

        System.assertEquals(loanOfficer.FirstName, contactData.get('FirstName'));
        System.assertEquals(loanOfficer.LastName, contactData.get('LastName'));
        System.assertEquals(loanOfficer.Title, contactData.get('Title'));
        System.assertEquals(loanOfficer.NMLS__c, contactData.get('NMLS'));
        System.assertEquals(loanOfficer.MobilePhone, contactData.get('Phone'));
        System.assertEquals(loanOfficer.Email, contactData.get('Email'));
        System.assertEquals(loanOfficer.Headshot_URL__c, contactData.get('HeadShotUrl'));
    }

    @IsTest
    static void updateLoanConditionOnFileUploadUpdatesConditionAndVersion() {
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'File Upload Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-BDP-005'
        );
        insert transactionRecord;

        Condition__c conditionRecord = createCondition(
            transactionRecord.Id,
            'Requested',
            'Upload test condition',
            true
        );
        insert conditionRecord;

        ContentVersion versionRecord = createContentVersion(transactionRecord.Id, 'borrower-doc.pdf');

        Test.startTest();
        BorrowerDocumentPortalController.LoanCondition refreshedCondition =
            BorrowerDocumentPortalController.updateLoanConditionOnFileUpload(
                new List<Id>{ versionRecord.Id },
                conditionRecord.Id
            );
        Test.stopTest();

        Condition__c updatedCondition = [
            SELECT Status__c
            FROM Condition__c
            WHERE Id = :conditionRecord.Id
        ];
        ContentVersion updatedVersion = [
            SELECT Condition__c, Folder__c
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
        ];
        Map<Id, ContentDocumentLink> linksByEntity = new Map<Id, ContentDocumentLink>();
        for (ContentDocumentLink link : [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :versionRecord.ContentDocumentId
            AND LinkedEntityId IN (:transactionRecord.Id, :conditionRecord.Id)
        ]) {
            linksByEntity.put(link.LinkedEntityId, link);
        }

        System.assertEquals('Review', updatedCondition.Status__c, 'Condition should move to Review');
        System.assertEquals('Review', refreshedCondition.status);
        System.assertEquals(1, refreshedCondition.fileCount);
        System.assertEquals(conditionRecord.Id, updatedVersion.Condition__c);
        System.assertEquals('Upload test condition', updatedVersion.Folder__c);
        System.assert(linksByEntity.containsKey(transactionRecord.Id),
            'File should remain linked to the parent Transaction (CDL created by lightning-file-upload).');
        System.assert(linksByEntity.containsKey(conditionRecord.Id),
            'File should also be linked to the Condition (CDL created by FileUploadHandler).');
    }

    @IsTest
    static void encryptOpportunityIdReturnsDecryptableHash() {
        BorrowerPortalEncryptionService.testKeyOverride = TEST_AES_KEY;

        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Encryption Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-BDP-006'
        );
        insert transactionRecord;

        BorrowerDocumentPortalController.Request requestItem =
            new BorrowerDocumentPortalController.Request();
        requestItem.recordId = transactionRecord.Id;

        Test.startTest();
        List<String> hashes = BorrowerDocumentPortalController.encryptOpportunityId(
            new List<BorrowerDocumentPortalController.Request>{ requestItem }
        );
        Test.stopTest();

        System.assertEquals(1, hashes.size());
        System.assertEquals(transactionRecord.Id, BorrowerDocumentPortalController.decryptRecordId(hashes[0]));
    }

    private static Condition__c createCondition(
        Id transactionId,
        String status,
        String description,
        Boolean canBorrowerSee
    ) {
        return new Condition__c(
            Transaction__c = transactionId,
            Status__c = status,
            Subject__c = description,
            Description__c = description,
            Can_Borrower_See__c = canBorrowerSee
        );
    }

    private static ContentVersion createContentVersion(Id firstPublishLocationId, String fileName) {
        ContentVersion versionRecord = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = Blob.valueOf('borrower document portal test file'),
            FirstPublishLocationId = firstPublishLocationId
        );
        insert versionRecord;
        return [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
        ];
    }

    private static User createPortalUser() {
        return createPortalUser(String.valueOf(Datetime.now().getTime()));
    }

    private static User createPortalUser(String uniqueSuffix) {
        User portalUser = new User(
            Alias = 'bdpusr',
            Email = 'borrower.portal.' + uniqueSuffix + '@example.com',
            Username = 'borrower.portal.' + uniqueSuffix + '@example.com',
            FirstName = 'Taylor',
            LastName = 'Officer',
            MobilePhone = '2484567890',
            Title = 'Loan Officer',
            Phone = '9876543210',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'en_US',
            Headshot_URL__c = 'image.jpg',
            NMLS__c = '1866656'
        );
        insert portalUser;
        return portalUser;
    }
}