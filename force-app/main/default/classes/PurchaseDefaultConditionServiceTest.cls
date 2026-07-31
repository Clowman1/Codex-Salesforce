@IsTest
private class PurchaseDefaultConditionServiceTest {
    private static Account createLender(String suffix) {
        Account lender = new Account(
            Name = 'Purchase Default Lender ' + suffix,
            Type = 'Investor'
        );
        insert lender;
        return lender;
    }

    private static User getAlternateActiveUser() {
        List<User> users = [
            SELECT Id
            FROM User
            WHERE Id != :UserInfo.getUserId()
            AND IsActive = true
            LIMIT 1
        ];
        System.assert(!users.isEmpty(), 'Expected at least one alternate active user for assignment coverage.');
        return users[0];
    }

    @IsTest
    static void createsDefaultConditionsForNewPurchaseBeforeConditionalApproval() {
        Account lender = createLender('Create');
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Purchase Defaults Test',
            Status__c = 'Processing',
            Loan_Purpose__c = 'Purchase',
            Lender_lookup__c = lender.Id,
            Processor__c = UserInfo.getUserId(),
            Loan_Commitment_Date__c = Date.today().addDays(14)
        );

        Test.startTest();
        insert transactionRecord;
        Test.stopTest();

        Map<String, Condition__c> conditionsByName = new Map<String, Condition__c>();
        for (Condition__c conditionRecord : [
            SELECT Name, Category__c, Status__c, Type__c, Assigned_To__c, Can_Borrower_See__c, Include_In_Email__c, Description__c
            FROM Condition__c
            WHERE Transaction__c = :transactionRecord.Id
        ]) {
            conditionsByName.put(conditionRecord.Name, conditionRecord);
        }

        System.assertEquals(2, conditionsByName.size(), 'Purchase files should get exactly the two default purchase conditions.');
        System.assert(conditionsByName.containsKey('Escrow Deposit'), 'Escrow Deposit condition should be created.');
        System.assert(conditionsByName.containsKey('Homeowner\'s Insurance'), 'Homeowner\'s Insurance condition should be created.');
        System.assertEquals('Assets', conditionsByName.get('Escrow Deposit').Category__c);
        System.assertEquals('HOI', conditionsByName.get('Homeowner\'s Insurance').Category__c);
        System.assertEquals('New', conditionsByName.get('Escrow Deposit').Status__c);
        System.assertEquals('Processor', conditionsByName.get('Escrow Deposit').Type__c);
        System.assertEquals(UserInfo.getUserId(), conditionsByName.get('Escrow Deposit').Assigned_To__c);
        System.assertEquals(true, conditionsByName.get('Escrow Deposit').Can_Borrower_See__c);
        System.assertEquals(true, conditionsByName.get('Escrow Deposit').Include_In_Email__c);
        System.assert(
            conditionsByName.get('Escrow Deposit').Description__c.contains('Source of $ escrow deposit'),
            'Escrow Deposit description should contain the requested verbiage.'
        );
    }

    @IsTest
    static void doesNotCreateDefaultsForConditionalApprovalOrLater() {
        Account lender = createLender('CLA');
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Purchase Defaults CLA Test',
            Status__c = 'Conditionally Approved',
            Loan_Purpose__c = 'Purchase',
            Lender_lookup__c = lender.Id,
            Processor__c = UserInfo.getUserId(),
            Loan_Commitment_Date__c = Date.today().addDays(14)
        );

        Test.startTest();
        insert transactionRecord;
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Condition__c WHERE Transaction__c = :transactionRecord.Id],
            'Purchase defaults should not backfill or create after Conditional Approval.'
        );
    }

    @IsTest
    static void createsOnPurchaseUpdateOnceWithoutDuplicates() {
        Account lender = createLender('Update');
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Purchase Defaults Update Test',
            Status__c = 'Processing',
            Loan_Purpose__c = 'Refinance',
            Lender_lookup__c = lender.Id,
            Processor__c = UserInfo.getUserId(),
            Loan_Commitment_Date__c = Date.today().addDays(14)
        );
        insert transactionRecord;

        Test.startTest();
        transactionRecord.Loan_Purpose__c = 'Purchase';
        update transactionRecord;
        transactionRecord.Status__c = 'Submitted';
        update transactionRecord;
        Test.stopTest();

        System.assertEquals(
            2,
            [SELECT COUNT() FROM Condition__c WHERE Transaction__c = :transactionRecord.Id],
            'Updating a transaction after the defaults exist should not create duplicates.'
        );
    }

    @IsTest
    static void waitsForProcessorBeforeCreatingDefaults() {
        Account lender = createLender('Wait');
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Purchase Defaults Wait Test',
            Status__c = 'Submitted',
            Loan_Purpose__c = 'Purchase',
            Lender_lookup__c = lender.Id,
            OwnerId = UserInfo.getUserId(),
            Loan_Commitment_Date__c = Date.today().addDays(14)
        );
        insert transactionRecord;

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Condition__c WHERE Transaction__c = :transactionRecord.Id],
            'Purchase defaults should wait until a Processor is assigned instead of falling back to the owner.'
        );

        Test.startTest();
        transactionRecord.Processor__c = UserInfo.getUserId();
        transactionRecord.Status__c = 'Submitted';
        update transactionRecord;
        Test.stopTest();

        for (Condition__c conditionRecord : [
            SELECT Assigned_To__c
            FROM Condition__c
            WHERE Transaction__c = :transactionRecord.Id
        ]) {
            System.assertEquals(
                UserInfo.getUserId(),
                conditionRecord.Assigned_To__c,
                'Created purchase defaults should be assigned to the Processor.'
            );
        }
        System.assertEquals(
            2,
            [SELECT COUNT() FROM Condition__c WHERE Transaction__c = :transactionRecord.Id],
            'Defaults should create once the Processor is assigned before Conditional Approval.'
        );
    }

    @IsTest
    static void reassignsExistingDefaultsToProcessorBeforeConditionalApproval() {
        Account lender = createLender('Reassign');
        User processor = getAlternateActiveUser();
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Purchase Defaults Reassign Test',
            Status__c = 'Submitted',
            Loan_Purpose__c = 'Purchase',
            Lender_lookup__c = lender.Id,
            OwnerId = UserInfo.getUserId(),
            Loan_Commitment_Date__c = Date.today().addDays(14)
        );
        insert transactionRecord;

        insert new List<Condition__c>{
            new Condition__c(
                Transaction__c = transactionRecord.Id,
                Assigned_To__c = UserInfo.getUserId(),
                Name = 'Escrow Deposit',
                Category__c = 'Assets',
                Description__c = 'Test escrow condition.',
                Status__c = 'New',
                Type__c = 'Processor',
                Can_Borrower_See__c = true,
                Include_In_Email__c = true,
                IncludeInEmail__c = true
            ),
            new Condition__c(
                Transaction__c = transactionRecord.Id,
                Assigned_To__c = UserInfo.getUserId(),
                Name = 'Homeowner\'s Insurance',
                Category__c = 'HOI',
                Description__c = 'Test insurance condition.',
                Status__c = 'New',
                Type__c = 'Processor',
                Can_Borrower_See__c = true,
                Include_In_Email__c = true,
                IncludeInEmail__c = true
            )
        };

        Test.startTest();
        transactionRecord.Processor__c = processor.Id;
        transactionRecord.Status__c = 'Submitted';
        update transactionRecord;
        Test.stopTest();

        for (Condition__c conditionRecord : [
            SELECT Assigned_To__c
            FROM Condition__c
            WHERE Transaction__c = :transactionRecord.Id
        ]) {
            System.assertEquals(
                processor.Id,
                conditionRecord.Assigned_To__c,
                'Existing purchase defaults should be reassigned to the Processor on later pre-CLA saves.'
            );
        }
        System.assertEquals(
            2,
            [SELECT COUNT() FROM Condition__c WHERE Transaction__c = :transactionRecord.Id],
            'Reassignment should not create duplicate default conditions.'
        );
    }

    @IsTest
    static void reassignsExistingDefaultsToProcessorAfterConditionalApproval() {
        Account lender = createLender('ReassignPostCla');
        User processor = getAlternateActiveUser();
        // Processor is populated on insert because a Conditionally Approved save fires the
        // "Create Tasks for Processor Team" flow, which cannot create its Tasks without an owner.
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Purchase Defaults Post-CLA Reassign Test',
            Status__c = 'Conditionally Approved',
            Loan_Purpose__c = 'Purchase',
            Lender_lookup__c = lender.Id,
            OwnerId = UserInfo.getUserId(),
            Processor__c = UserInfo.getUserId(),
            Loan_Commitment_Date__c = Date.today().addDays(14)
        );
        insert transactionRecord;

        insert new List<Condition__c>{
            new Condition__c(
                Transaction__c = transactionRecord.Id,
                Assigned_To__c = UserInfo.getUserId(),
                Name = 'Escrow Deposit',
                Category__c = 'Assets',
                Description__c = 'Test escrow condition.',
                Status__c = 'New',
                Type__c = 'Processor',
                Can_Borrower_See__c = true,
                Include_In_Email__c = true,
                IncludeInEmail__c = true
            ),
            new Condition__c(
                Transaction__c = transactionRecord.Id,
                Assigned_To__c = UserInfo.getUserId(),
                Name = 'Homeowner\'s Insurance',
                Category__c = 'HOI',
                Description__c = 'Test insurance condition.',
                Status__c = 'New',
                Type__c = 'Processor',
                Can_Borrower_See__c = true,
                Include_In_Email__c = true,
                IncludeInEmail__c = true
            )
        };

        Test.startTest();
        transactionRecord.Processor__c = processor.Id;
        update transactionRecord;
        Test.stopTest();

        for (Condition__c conditionRecord : [
            SELECT Assigned_To__c
            FROM Condition__c
            WHERE Transaction__c = :transactionRecord.Id
        ]) {
            System.assertEquals(
                processor.Id,
                conditionRecord.Assigned_To__c,
                'A Processor assigned after Conditional Approval should still propagate to existing defaults.'
            );
        }
        System.assertEquals(
            2,
            [SELECT COUNT() FROM Condition__c WHERE Transaction__c = :transactionRecord.Id],
            'Post-CLA reassignment must not create new default conditions.'
        );
    }

    @IsTest
    static void leavesInactiveTransactionDefaultsUntouched() {
        Account lender = createLender('InactiveUntouched');
        User processor = getAlternateActiveUser();
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Purchase Defaults Inactive Test',
            Status__c = 'Post-Closed',
            Loan_Purpose__c = 'Purchase',
            Lender_lookup__c = lender.Id,
            OwnerId = UserInfo.getUserId(),
            Loan_Commitment_Date__c = Date.today().addDays(14)
        );
        insert transactionRecord;

        Condition__c existingCondition = new Condition__c(
            Transaction__c = transactionRecord.Id,
            Assigned_To__c = UserInfo.getUserId(),
            Name = 'Escrow Deposit',
            Category__c = 'Assets',
            Description__c = 'Test escrow condition.',
            Status__c = 'New',
            Type__c = 'Processor',
            Can_Borrower_See__c = true,
            Include_In_Email__c = true,
            IncludeInEmail__c = true
        );
        insert existingCondition;

        Test.startTest();
        transactionRecord.Processor__c = processor.Id;
        update transactionRecord;
        Test.stopTest();

        System.assertEquals(
            UserInfo.getUserId(),
            [SELECT Assigned_To__c FROM Condition__c WHERE Id = :existingCondition.Id].Assigned_To__c,
            'Closed files must keep their historical assignee.'
        );
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Condition__c WHERE Transaction__c = :transactionRecord.Id],
            'Inactive files must not have new default conditions seeded.'
        );
    }

    @IsTest
    static void retriesMissingDefaultsOnLaterPurchaseSaveBeforeConditionalApproval() {
        Account lender = createLender('Retry');
        Transaction__c transactionRecord = new Transaction__c(
            Name = 'Purchase Defaults Retry Test',
            Status__c = 'Processing',
            Loan_Purpose__c = 'Purchase',
            Lender_lookup__c = lender.Id,
            Processor__c = UserInfo.getUserId(),
            Loan_Commitment_Date__c = Date.today().addDays(14)
        );
        insert transactionRecord;

        delete [
            SELECT Id
            FROM Condition__c
            WHERE Transaction__c = :transactionRecord.Id
        ];

        Test.startTest();
        transactionRecord.Status__c = 'Submitted';
        update transactionRecord;
        Test.stopTest();

        System.assertEquals(
            2,
            [SELECT COUNT() FROM Condition__c WHERE Transaction__c = :transactionRecord.Id],
            'A later pre-Conditional Approval save should repair missing purchase default conditions.'
        );
    }
}