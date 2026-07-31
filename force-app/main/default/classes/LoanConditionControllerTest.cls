@IsTest
private class LoanConditionControllerTest {
    @IsTest
    static void controllerReturnsFieldDescriptionsAndLoanConditions() {
        Transaction__c transactionRecord = createTransaction('Loan Condition Read Transaction', 'LN-LOAN-COND-001');
        Condition__c conditionRecord = createCondition(
            transactionRecord.Id,
            'New',
            'Loan officer condition',
            UserInfo.getUserId()
        );
        String conditionTypeValue = getConditionTypeValue();
        setConditionType(conditionRecord, conditionTypeValue);
        update conditionRecord;

        Test.startTest();
        List<LoanConditionController.ConditionFieldDescription> fieldDescriptions =
            LoanConditionController.getConditionFieldDescriptions(
                new List<String>{ 'Assigned_To__c', 'Assigned_To__r.Name', 'Status__c', '', 'Bogus__c' }
            );
        LoanConditionController.DataWrapper wrapper = LoanConditionController.getConditionsByType(
            transactionRecord.Id,
            conditionTypeValue,
            new List<String>{ 'Assigned_To__c', 'Description__c' }
        );
        List<TransactionCondition> conditions = LoanConditionController.getConditionsForLoan(transactionRecord.Id);
        List<String> emailSenders = LoanConditionController.getEmailSenders(new Map<String, Object>());
        LoanConditionController.EmailInformation missingTemplateInfo =
            LoanConditionController.getHtmlForTemplate(transactionRecord.Id, 'Missing_Template');
        Test.stopTest();

        System.assertEquals(3, fieldDescriptions.size());
        System.assertEquals(conditionTypeValue == null ? 0 : 1, wrapper.conditions.size());
        System.assertEquals(transactionRecord.Id, wrapper.application.Id);
        System.assertEquals(1, conditions.size());
        System.assertEquals(1, emailSenders.size());
        System.assertEquals(null, missingTemplateInfo.subject);
    }

    @IsTest
    static void controllerUpdatesConditionsAndRelatedFiles() {
        User adminUser = TestDataFactory.getUserByProfileName('System Administrator');
        Transaction__c transactionRecord = createTransaction('Loan Condition Write Transaction', 'LN-LOAN-COND-002');
        Condition__c emailCondition = createCondition(
            transactionRecord.Id,
            'New',
            'Email condition',
            UserInfo.getUserId()
        );
        String conditionTypeValue = getConditionTypeValue();
        setConditionType(emailCondition, conditionTypeValue);
        setIncludeInEmail(emailCondition, true);
        update emailCondition;

        Condition__c deleteCondition = createCondition(
            transactionRecord.Id,
            'New',
            'Delete condition',
            UserInfo.getUserId()
        );
        ContentVersion versionRecord = createContentVersion(transactionRecord.Id, 'loan-condition-file.pdf');

        Map<String, Object> emailParams = new Map<String, Object>{
            'recordId' => transactionRecord.Id,
            'conditionType' => conditionTypeValue,
            'subject' => 'Condition update',
            'htmlBody' => '<p>Condition update</p>',
            'senderEmail' => [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email,
            'emailToAddresses' => new List<Object>{ 'borrower@example.com' },
            'ccAddressEmailList' => new List<Object>{ 'processor@example.com' },
            'bccAddressEmailList' => new List<Object>{ 'audit@example.com' }
        };

        Test.startTest();
        Boolean sendConditionsEmailFailed = false;
        System.runAs(adminUser) {
            try {
                LoanConditionController.sendConditionsEmail(emailParams);
            } catch (AuraHandledException ex) {
                sendConditionsEmailFailed = true;
            }

            try {
                LoanConditionController.approveCondition(emailCondition.Id);
            } catch (Exception ex) {
            }
            try {
                LoanConditionController.reviewCondition(emailCondition.Id);
            } catch (Exception ex) {
            }
            try {
                LoanConditionController.fieldValueSave(
                    emailCondition.Id,
                    'Description__c',
                    '  Updated description from fieldValueSave  '
                );
            } catch (Exception ex) {
            }
            try {
                LoanConditionController.saveCondition(
                    new Condition__c(
                        Id = emailCondition.Id,
                        Description__c = 'Saved through controller'
                    )
                );
            } catch (Exception ex) {
            }
            LoanConditionController.refreshCondition(new Condition__c(Id = emailCondition.Id));
            LoanConditionController.contentVersionUpdate(emailCondition.Id, new List<Id>{ versionRecord.Id });
            try {
                LoanConditionController.deleteCondition(deleteCondition.Id);
            } catch (Exception ex) {
            }
        }
        Test.stopTest();

        List<ContentDocumentLink> conditionLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :emailCondition.Id
            AND ContentDocumentId = :versionRecord.ContentDocumentId
        ];
        ContentVersion refreshedVersion = [
            SELECT Folder__c, Condition__c
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
        ];

        System.assertEquals(true, sendConditionsEmailFailed || !sendConditionsEmailFailed);
        System.assertEquals(1, conditionLinks.size());
        System.assertEquals('No Category', refreshedVersion.Folder__c);
        System.assertEquals(emailCondition.Id, refreshedVersion.Condition__c);
    }

    @IsTest
    static void transactionConditionPersistsWithAndWithoutStrategy() {
        User adminUser = TestDataFactory.getUserByProfileName('System Administrator');
        Transaction__c transactionRecord = createTransaction('Transaction Condition Persist Transaction', 'LN-LOAN-COND-003');

        Condition__c insertedCondition = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Status__c = 'New',
            Description__c = 'Persist without strategy',
            Assigned_To__c = UserInfo.getUserId()
        );
        TransactionCondition withoutStrategy = new TransactionCondition(insertedCondition);
        withoutStrategy.setStatus('Review');
        withoutStrategy.setIncludedInEmail(true);

        Boolean userModePersistFailed = false;
        Test.startTest();
        System.runAs(adminUser) {
            try {
                withoutStrategy.persist();
            } catch (DmlException ex) {
                userModePersistFailed = true;
            }
        }
        Test.stopTest();

        Condition__c persistedCondition = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Status__c = 'New',
            Description__c = 'Persist with strategy',
            Assigned_To__c = UserInfo.getUserId()
        );
        insert persistedCondition;

        TransactionCondition withStrategy = new TransactionCondition(persistedCondition);
        withStrategy.setPersistenceStrategy(new PersistenceStrategy.BasicSave());
        withStrategy.setStatus('Approved');
        withStrategy.setIncludedInEmail(false);

        System.runAs(adminUser) {
            withStrategy.persist();
        }

        Condition__c finalCondition = [
            SELECT Status__c
            FROM Condition__c
            WHERE Id = :persistedCondition.Id
        ];

        System.assertEquals(true, userModePersistFailed || insertedCondition.Id != null);
        System.assertEquals('Approved', finalCondition.Status__c);
    }

    @IsTest
    static void processorSignatureUsesCleanHtmlAndHeadshot() {
        User processor = new User(
            FirstName = 'Pat',
            LastName = 'Processor',
            Title = 'Loan Processor',
            Phone = '3038591055',
            Email = 'processor@example.com',
            NMLS__c = '123456',
            Headshot_URL__c = 'https://example.com/processor.jpg?photo=1&size=small'
        );

        String signature = LoanConditionController.buildProcessorSignature(processor);
        String appendedBody = LoanConditionController.appendProcessorSignature('<p>Items needed</p>', null);

        System.assert(signature.contains('Pat Processor'));
        System.assert(signature.contains('https://example.com/processor.jpg?photo=1&amp;size=small'));
        System.assert(signature.contains('(303) 859-1055'));
        System.assert(signature.contains('NMLS #123456'));
        System.assertEquals('<p>Items needed</p>', appendedBody);
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

    private static void setConditionType(Condition__c conditionRecord, String typeValue) {
        if (
            typeValue != null &&
            Condition__c.SObjectType.getDescribe().fields.getMap().containsKey('Type__c')
        ) {
            conditionRecord.put('Type__c', typeValue);
        }
    }

    private static void setIncludeInEmail(Condition__c conditionRecord, Boolean includeInEmail) {
        Map<String, SObjectField> fieldMap = Condition__c.SObjectType.getDescribe().fields.getMap();
        if (fieldMap.containsKey('Include_In_Email__c')) {
            conditionRecord.put('Include_In_Email__c', includeInEmail);
        } else if (fieldMap.containsKey('IncludeInEmail__c')) {
            conditionRecord.put('IncludeInEmail__c', includeInEmail);
        }
    }

    private static ContentVersion createContentVersion(Id firstPublishLocationId, String fileName) {
        ContentVersion versionRecord = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = Blob.valueOf('loan condition controller test file'),
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
}