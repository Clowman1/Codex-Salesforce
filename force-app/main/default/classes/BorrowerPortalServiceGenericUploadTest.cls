@IsTest
private class BorrowerPortalServiceGenericUploadTest {
    @IsTest
    static void genericUploadCreatesReviewConditionAndLinksDocuments() {
        Transaction__c loan = new Transaction__c(
            Name = 'Generic Upload Test Loan',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'GEN-UP-001',
            Borrower_First_Name__c = 'Generic',
            Borrower_Last_Name__c = 'Borrower'
        );
        insert loan;

        ContentVersion uploadedVersion = new ContentVersion(
            Title = 'generic-bank-statement',
            PathOnClient = 'generic-bank-statement.pdf',
            VersionData = Blob.valueOf('test')
        );
        insert uploadedVersion;

        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :uploadedVersion.Id
            LIMIT 1
        ].ContentDocumentId;

        Test.startTest();
        BorrowerPortalService.handleGenericUpload(new List<Id>{ uploadedVersion.Id }, loan.Id);
        Test.stopTest();

        Condition__c genericCondition = [
            SELECT Id, Status__c, Subject__c, Type__c, Assigned_To__c, Can_Borrower_See__c
            FROM Condition__c
            WHERE Transaction__c = :loan.Id
            AND Subject__c = 'Unassigned'
            LIMIT 1
        ];

        System.assertEquals('Review', genericCondition.Status__c);
        System.assertEquals('Generic Document Portal Upload', genericCondition.Type__c);
        System.assertEquals(UserInfo.getUserId(), genericCondition.Assigned_To__c);
        System.assertEquals(true, genericCondition.Can_Borrower_See__c);

        Integer conditionLinks = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :genericCondition.Id
            AND ContentDocumentId = :contentDocumentId
        ];
        System.assertEquals(1, conditionLinks);

        ContentVersion stampedVersion = [
            SELECT Folder__c, Condition__c, Condition_Document_Review_Status__c
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = TRUE
            LIMIT 1
        ];
        System.assertEquals('Unassigned', stampedVersion.Folder__c);
        System.assertEquals(genericCondition.Id, stampedVersion.Condition__c);
        System.assertEquals('Pending Review', stampedVersion.Condition_Document_Review_Status__c);
    }

    @IsTest
    static void genericUploadReusesExistingReviewConditionWithoutDuplicateLinks() {
        Transaction__c loan = new Transaction__c(
            Name = 'Generic Upload Existing Loan',
            Status__c = TestDataFactory.getOpportunityStageName(),
            Loan_Number__c = 'GEN-UP-002'
        );
        insert loan;

        Condition__c existingCondition = new Condition__c(
            Transaction__c = loan.Id,
            Status__c = 'Review',
            Subject__c = 'Unassigned',
            Type__c = 'Generic Document Portal Upload',
            Description__c = 'Unassigned',
            Assigned_To__c = UserInfo.getUserId(),
            Can_Borrower_See__c = true
        );
        insert existingCondition;

        ContentVersion uploadedVersion = new ContentVersion(
            Title = 'generic-paystub',
            PathOnClient = 'generic-paystub.pdf',
            VersionData = Blob.valueOf('test')
        );
        insert uploadedVersion;

        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :uploadedVersion.Id
            LIMIT 1
        ].ContentDocumentId;

        Test.startTest();
        BorrowerPortalService.handleGenericUpload(new List<Id>{ contentDocumentId }, loan.Id);
        BorrowerPortalService.handleGenericUpload(new List<Id>{ contentDocumentId }, loan.Id);
        Test.stopTest();

        Integer conditionCount = [
            SELECT COUNT()
            FROM Condition__c
            WHERE Transaction__c = :loan.Id
            AND Subject__c = 'Unassigned'
        ];
        System.assertEquals(1, conditionCount);

        Integer conditionLinks = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :existingCondition.Id
            AND ContentDocumentId = :contentDocumentId
        ];
        System.assertEquals(1, conditionLinks);
    }
}