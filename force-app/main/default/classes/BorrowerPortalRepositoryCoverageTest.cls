@IsTest
private class BorrowerPortalRepositoryCoverageTest {
    @IsTest
    static void loanRepositoryCoversBorrowerPortalSelectors() {
        Transaction__c hashedTransaction = new Transaction__c(
            Name = 'Loan Repo Transaction A',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-REPO-001',
            Portal_Hash_Parameter__c = 'repo-hash-001'
        );
        Transaction__c plainTransaction = new Transaction__c(
            Name = 'Loan Repo Transaction B',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-REPO-002'
        );
        insert new List<Transaction__c>{ hashedTransaction, plainTransaction };

        LoanRepository repository = LoanRepository.getInstance();

        Test.startTest();
        Map<Id, Loan> loanMap = repository.getLoanMapByIds(new Set<Id>{ hashedTransaction.Id, plainTransaction.Id });
        Loan loanById = repository.getLoanById(hashedTransaction.Id);
        Loan borrowerPortalLoan = repository.getLoanForBorrowerPortalById(hashedTransaction.Id);
        Loan missingBorrowerPortalLoan = repository.getLoanForBorrowerPortalById(null);
        Loan firstLoanWithPortalHash = repository.getFirstLoanWithPortalHash();
        List<Transaction__c> selectedTransactions = repository.selectTransactionsByIds(
            new Set<Id>{ hashedTransaction.Id, plainTransaction.Id }
        );
        List<Transaction__c> emptyTransactions = repository.selectTransactionsByIds(new Set<Id>());
        Database.QueryLocator refreshScope = repository.getBorrowerPortalHashRefreshScope();
        Test.stopTest();

        System.assertEquals(2, loanMap.size());
        System.assertEquals(hashedTransaction.Id, loanById.getId());
        System.assertEquals(hashedTransaction.Id, borrowerPortalLoan.getId());
        System.assertEquals(null, missingBorrowerPortalLoan);
        System.assertEquals(hashedTransaction.Id, firstLoanWithPortalHash.getId());
        System.assertEquals(2, selectedTransactions.size());
        System.assertEquals(0, emptyTransactions.size());
        System.assertNotEquals(null, refreshScope);
    }

    @IsTest
    static void transactionConditionRepositoryCoversQueryMethods() {
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Condition Repo Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-COND-001'
        );
        insert transactionRecord;

        String conditionTypeValue = getConditionTypeValue();
        Condition__c requestedCondition = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Status__c = 'Requested',
            Subject__c = 'Requested condition',
            Description__c = 'Requested condition',
            Assigned_To__c = UserInfo.getUserId()
        );
        setIncludeInEmail(requestedCondition, true);
        if (Schema.getGlobalDescribe().get('Condition__c').getDescribe().fields.getMap().containsKey('Income_Conditions_For__c')) {
            requestedCondition.put('Income_Conditions_For__c', 'Borrower');
        }
        if (
            conditionTypeValue != null &&
            Schema.getGlobalDescribe().get('Condition__c').getDescribe().fields.getMap().containsKey('Type__c')
        ) {
            requestedCondition.put('Type__c', conditionTypeValue);
        }

        Condition__c genericUploadCondition = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Status__c = 'Review',
            Subject__c = 'Generic Document Portal Upload',
            Description__c = 'Generic upload bucket',
            Assigned_To__c = UserInfo.getUserId()
        );
        setIncludeInEmail(genericUploadCondition, false);

        insert new List<Condition__c>{ requestedCondition, genericUploadCondition };

        TransactionConditionRepository repository = TransactionConditionRepository.getInstance();

        Test.startTest();
        List<TransactionCondition> allConditions = repository.getConditionsRelatedToLoan(transactionRecord.Id);
        List<TransactionCondition> typedConditions = TransactionConditionRepository.getConditionsByType(
            transactionRecord.Id,
            conditionTypeValue,
            new List<String>{ 'Assigned_To__c', 'Transaction__c' }
        );
        List<TransactionCondition> emptyTypedConditions = TransactionConditionRepository.getConditionsByType(
            transactionRecord.Id,
            null,
            null
        );
        List<TransactionCondition> responsibleConditions = repository.getConditionsWithResponsibleParty(transactionRecord.Id, 'Borrower');
        List<TransactionCondition> emailConditions = repository.getConditionsIncludedInEmailByLoanId(transactionRecord.Id);
        List<TransactionCondition> requestedConditions = repository.getConditionsWithStatusRequestedByLoanId(transactionRecord.Id);
        TransactionCondition loadedCondition = repository.getConditionById(requestedCondition.Id);
        TransactionCondition missingCondition = repository.getConditionById(null);
        TransactionCondition genericCondition = repository.getActiveGenericUploadConditionByLoanId(transactionRecord.Id);
        Test.stopTest();

        System.assertEquals(2, allConditions.size());
        System.assertEquals(conditionTypeValue == null ? 0 : 1, typedConditions.size());
        System.assertEquals(0, emptyTypedConditions.size());
        System.assertNotEquals(null, responsibleConditions);
        if (!responsibleConditions.isEmpty()) {
            System.assertEquals(requestedCondition.Id, responsibleConditions[0].data.Id);
        }
        System.assertEquals(1, emailConditions.size());
        System.assertEquals(requestedCondition.Id, emailConditions[0].data.Id);
        System.assertEquals(1, requestedConditions.size());
        System.assertEquals(requestedCondition.Id, loadedCondition.data.Id);
        System.assertEquals(null, missingCondition);
        System.assertEquals(genericUploadCondition.Id, genericCondition.data.Id);
    }

    @IsTest
    static void contentDocumentRepositoryResolvesIdsAndCountsLinks() {
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Document Repo Transaction',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'LN-DOC-001'
        );
        insert transactionRecord;

        Condition__c conditionRecord = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Status__c = 'Review',
            Subject__c = 'Document repo condition',
            Description__c = 'Document repo condition',
            Assigned_To__c = UserInfo.getUserId()
        );
        insert conditionRecord;

        ContentVersion transactionVersion = createContentVersion(transactionRecord.Id, 'transaction-doc.pdf');
        ContentVersion conditionVersion = createContentVersion(conditionRecord.Id, 'condition-doc.pdf');

        Set<Id> mixedFileIds = new Set<Id>{
            transactionVersion.Id,
            conditionVersion.ContentDocumentId,
            null
        };
        Set<Id> entityIds = new Set<Id>{ transactionRecord.Id, conditionRecord.Id };

        Test.startTest();
        Set<Id> resolvedContentDocumentIds = ContentDocumentRepository.resolveContentDocumentIds(mixedFileIds);
        Map<Id, Decimal> documentCounts = ContentDocumentRepository.selectLinkedDocumentCountsByEntityIds(entityIds);
        Test.stopTest();

        System.assertEquals(
            new Set<Id>{ transactionVersion.ContentDocumentId, conditionVersion.ContentDocumentId },
            resolvedContentDocumentIds
        );
        System.assertEquals(1, documentCounts.get(transactionRecord.Id));
        System.assertEquals(1, documentCounts.get(conditionRecord.Id));
    }

    private static ContentVersion createContentVersion(Id firstPublishLocationId, String fileName) {
        ContentVersion versionRecord = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = Blob.valueOf('repository test file'),
            FirstPublishLocationId = firstPublishLocationId
        );
        insert versionRecord;
        return [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
        ];
    }

    private static String getConditionTypeValue() {
        if (!Condition__c.SObjectType.getDescribe().fields.getMap().containsKey('Type__c')) {
            return null;
        }

        String fallbackValue = null;
        for (Schema.PicklistEntry entry : Condition__c.Type__c.getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            if (entry.getValue() == 'Loan Officer') {
                return entry.getValue();
            }
            if (fallbackValue == null) {
                fallbackValue = entry.getValue();
            }
        }
        return fallbackValue;
    }

    private static void setIncludeInEmail(Condition__c conditionRecord, Boolean includeInEmail) {
        Map<String, SObjectField> fieldMap = Condition__c.SObjectType.getDescribe().fields.getMap();
        if (fieldMap.containsKey('Include_In_Email__c')) {
            conditionRecord.put('Include_In_Email__c', includeInEmail);
        }
        if (fieldMap.containsKey('IncludeInEmail__c')) {
            conditionRecord.put('IncludeInEmail__c', includeInEmail);
        }
    }
}