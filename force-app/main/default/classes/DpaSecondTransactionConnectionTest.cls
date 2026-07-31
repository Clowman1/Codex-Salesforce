@IsTest
private class DpaSecondTransactionConnectionTest {
    private static Id getPersonAccountRecordTypeId() {
        List<RecordType> personAccountRecordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND DeveloperName = 'PersonAccount'
            LIMIT 1
        ];
        return personAccountRecordTypes.isEmpty() ? null : personAccountRecordTypes[0].Id;
    }

    private static Account createBorrower(String suffix) {
        Account borrower = new Account(LastName = suffix);
        Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
        if (personAccountRecordTypeId != null) {
            borrower.RecordTypeId = personAccountRecordTypeId;
        }
        insert borrower;
        return borrower;
    }

    private static Account createLender(String suffix) {
        Account lender = new Account(
            Name = 'Lender ' + suffix,
            Type = 'Investor'
        );
        insert lender;
        return lender;
    }

    private static Transaction__c createFirstTransaction(Account borrower, Account lender) {
        Transaction__c firstTransaction = new Transaction__c(
            Borrower_Name__c = borrower.Id,
            Account__c = borrower.Id,
            Status__c = 'Open',
            Lien_Position__c = '1st',
            Lender_lookup__c = lender.Id,
            Loan_Amount_1st__c = 150000,
            Loan_Type_1st_TD__c = 'Conventional',
            Loan_Program_1st__c = '30 yr Fixed',
            Rate_1st_TD__c = 5.125,
            Property_Address__c = '123 Main St',
            Property_City__c = 'Miami',
            Property_State__c = 'FL',
            Property_Postal_Code__c = '33101',
            Property_Unit__c = 'A',
            Property_Type__c = 'Single Family',
            Purchase_Date__c = Date.newInstance(2026, 5, 1),
            Appraisal__c = 'Needed',
            Appraised_Value__c = 250000,
            Purchase_Price__c = 245000,
            Processor__c = UserInfo.getUserId(),
            Closing_Date__c = Date.newInstance(2026, 6, 15),
            Funding_Date__c = Date.newInstance(2026, 6, 16),
            Disclosures_Out_Date__c = Datetime.newInstance(2026, 5, 2, 10, 0, 0),
            Disclosures_Received_Date__c = Datetime.newInstance(2026, 5, 3, 11, 0, 0),
            Rate_Lock_Status__c = 'Locked',
            Rate_Lock_Exp_Date__c = Date.newInstance(2026, 6, 30),
            Occupancy__c = 'Primary Residence'
        );
        insert firstTransaction;
        return firstTransaction;
    }

    @IsTest
    static void dpaSecondCopiesTransactionPageFieldsOnCreate() {
        Account borrower = createBorrower('Connection Copy');
        Account lender = createLender('Connection Copy');
        Transaction__c firstTransaction = createFirstTransaction(borrower, lender);

        DpaSecondTransactionService.Request requestItem = new DpaSecondTransactionService.Request();
        requestItem.firstTransactionId = firstTransaction.Id;
        requestItem.mode = DpaSecondTransactionService.MODE_AUTO;

        Test.startTest();
        List<DpaSecondTransactionService.Result> results =
            DpaSecondTransactionService.createSecondTransactions(new List<DpaSecondTransactionService.Request>{ requestItem });
        Test.stopTest();

        System.assertEquals(true, results[0].success);

        Transaction__c secondTransaction = [
            SELECT
                Status__c,
                First_Mortgage__c,
                Property_Address__c,
                Property_City__c,
                Property_State__c,
                Property_Postal_Code__c,
                Property_Unit__c,
                Property_Type__c,
                Purchase_Date__c,
                Appraisal__c,
                Appraised_Value__c,
                Purchase_Price__c,
                Processor__c,
                Closing_Date__c,
                Funding_Date__c,
                Disclosures_Out_Date__c,
                Disclosures_Received_Date__c,
                Rate_Lock_Status__c,
                Rate_Lock_Exp_Date__c,
                Occupancy__c,
                Lender_lookup__c,
                Loan_Amount_1st__c,
                Loan_Type_1st_TD__c,
                Loan_Program_1st__c,
                Rate_1st_TD__c,
                Loan_Amount_2nd__c,
                Loan_Type_2nd_TD__c,
                Loan_Program_2nd__c,
                Rate_2nd_TD__c
            FROM Transaction__c
            WHERE Id = :results[0].createdSecondTransactionId
        ];

        System.assertEquals(firstTransaction.Id, secondTransaction.First_Mortgage__c);
        System.assertEquals(firstTransaction.Property_Address__c, secondTransaction.Property_Address__c);
        System.assertEquals(firstTransaction.Property_City__c, secondTransaction.Property_City__c);
        System.assertEquals(firstTransaction.Property_State__c, secondTransaction.Property_State__c);
        System.assertEquals(firstTransaction.Property_Postal_Code__c, secondTransaction.Property_Postal_Code__c);
        System.assertEquals(firstTransaction.Property_Unit__c, secondTransaction.Property_Unit__c);
        System.assertEquals(firstTransaction.Property_Type__c, secondTransaction.Property_Type__c);
        System.assertEquals(firstTransaction.Purchase_Date__c, secondTransaction.Purchase_Date__c);
        System.assertEquals(firstTransaction.Appraisal__c, secondTransaction.Appraisal__c);
        System.assertEquals(firstTransaction.Appraised_Value__c, secondTransaction.Appraised_Value__c);
        System.assertEquals(firstTransaction.Purchase_Price__c, secondTransaction.Purchase_Price__c);
        System.assertEquals(firstTransaction.Processor__c, secondTransaction.Processor__c);
        System.assertEquals(firstTransaction.Closing_Date__c, secondTransaction.Closing_Date__c);
        System.assertEquals(firstTransaction.Funding_Date__c, secondTransaction.Funding_Date__c);
        System.assertEquals(firstTransaction.Disclosures_Out_Date__c, secondTransaction.Disclosures_Out_Date__c);
        System.assertEquals(firstTransaction.Disclosures_Received_Date__c, secondTransaction.Disclosures_Received_Date__c);
        System.assertEquals(firstTransaction.Rate_Lock_Status__c, secondTransaction.Rate_Lock_Status__c);
        System.assertEquals(firstTransaction.Rate_Lock_Exp_Date__c, secondTransaction.Rate_Lock_Exp_Date__c);
        System.assertEquals(firstTransaction.Occupancy__c, secondTransaction.Occupancy__c);
        System.assertEquals(lender.Id, secondTransaction.Lender_lookup__c);
        System.assertEquals(150000, secondTransaction.Loan_Amount_1st__c);
        System.assertEquals('Conventional', secondTransaction.Loan_Type_1st_TD__c);
        System.assertEquals('30 yr Fixed', secondTransaction.Loan_Program_1st__c);
        System.assertEquals(5.125, secondTransaction.Rate_1st_TD__c);
        System.assertEquals(150000, secondTransaction.Loan_Amount_2nd__c);
        System.assertEquals('Conventional', secondTransaction.Loan_Type_2nd_TD__c);
        System.assertEquals('30 yr Fixed', secondTransaction.Loan_Program_2nd__c);
        System.assertEquals(5.125, secondTransaction.Rate_2nd_TD__c);
    }

    @IsTest
    static void submissionFormValuesOverridePrimaryLoanInfoWithoutManualMode() {
        Account borrower = createBorrower('Connection Override');
        Account firstLender = createLender('Connection Override First');
        Account secondLender = createLender('Connection Override Second');
        Transaction__c firstTransaction = createFirstTransaction(borrower, firstLender);

        DpaSecondTransactionService.Request requestItem = new DpaSecondTransactionService.Request();
        requestItem.firstTransactionId = firstTransaction.Id;
        requestItem.lenderId = secondLender.Id;
        requestItem.loanAmount2nd = 10000;
        requestItem.loanType2nd = 'DPA 2nd';
        requestItem.loanProgram2nd = 'Closed-End Second';
        requestItem.rate2nd = 0;

        Test.startTest();
        List<DpaSecondTransactionService.Result> results =
            DpaSecondTransactionService.createSecondTransactions(new List<DpaSecondTransactionService.Request>{ requestItem });
        Test.stopTest();

        System.assertEquals(true, results[0].success);

        Transaction__c secondTransaction = [
            SELECT
                First_Mortgage__c,
                Lender_lookup__c,
                Loan_Amount_1st__c,
                Loan_Type_1st_TD__c,
                Loan_Program_1st__c,
                Rate_1st_TD__c,
                Loan_Amount_2nd__c,
                Loan_Type_2nd_TD__c,
                Loan_Program_2nd__c,
                Rate_2nd_TD__c
            FROM Transaction__c
            WHERE Id = :results[0].createdSecondTransactionId
        ];

        System.assertEquals(firstTransaction.Id, secondTransaction.First_Mortgage__c);
        System.assertEquals(secondLender.Id, secondTransaction.Lender_lookup__c);
        System.assertEquals(10000, secondTransaction.Loan_Amount_1st__c);
        System.assertEquals('DPA 2nd', secondTransaction.Loan_Type_1st_TD__c);
        System.assertEquals('Closed-End Second', secondTransaction.Loan_Program_1st__c);
        System.assertEquals(0, secondTransaction.Rate_1st_TD__c);
        System.assertEquals(10000, secondTransaction.Loan_Amount_2nd__c);
        System.assertEquals('DPA 2nd', secondTransaction.Loan_Type_2nd_TD__c);
        System.assertEquals('Closed-End Second', secondTransaction.Loan_Program_2nd__c);
        System.assertEquals(0, secondTransaction.Rate_2nd_TD__c);
    }

    @IsTest
    static void primaryStatusChangeMovesLinkedSecondStatus() {
        Account borrower = createBorrower('Connection Status');
        Account lender = createLender('Connection Status');
        Transaction__c firstTransaction = createFirstTransaction(borrower, lender);

        DpaSecondTransactionService.Request requestItem = new DpaSecondTransactionService.Request();
        requestItem.firstTransactionId = firstTransaction.Id;
        requestItem.mode = DpaSecondTransactionService.MODE_AUTO;
        List<DpaSecondTransactionService.Result> results =
            DpaSecondTransactionService.createSecondTransactions(new List<DpaSecondTransactionService.Request>{ requestItem });

        Test.startTest();
        update new Transaction__c(
            Id = firstTransaction.Id,
            Status__c = 'Processing',
            Purchase_Price__c = 255000,
            Appraised_Value__c = 260000,
            Closing_Date__c = Date.newInstance(2026, 7, 15),
            Rate_Lock_Status__c = 'Floating',
            Occupancy__c = 'Second Home'
        );
        Test.stopTest();

        Transaction__c secondTransaction = [
            SELECT
                Status__c,
                Purchase_Price__c,
                Appraised_Value__c,
                Closing_Date__c,
                Rate_Lock_Status__c,
                Occupancy__c
            FROM Transaction__c
            WHERE Id = :results[0].createdSecondTransactionId
        ];
        System.assertEquals('Processing', secondTransaction.Status__c);
        System.assertEquals(255000, secondTransaction.Purchase_Price__c);
        System.assertEquals(260000, secondTransaction.Appraised_Value__c);
        System.assertEquals(Date.newInstance(2026, 7, 15), secondTransaction.Closing_Date__c);
        System.assertEquals('Floating', secondTransaction.Rate_Lock_Status__c);
        System.assertEquals('Second Home', secondTransaction.Occupancy__c);
    }

    @IsTest
    static void secondStatusChangeDoesNotMovePrimaryStatusBackwards() {
        Account borrower = createBorrower('Connection One Way');
        Account lender = createLender('Connection One Way');
        Transaction__c firstTransaction = createFirstTransaction(borrower, lender);

        DpaSecondTransactionService.Request requestItem = new DpaSecondTransactionService.Request();
        requestItem.firstTransactionId = firstTransaction.Id;
        requestItem.mode = DpaSecondTransactionService.MODE_AUTO;
        List<DpaSecondTransactionService.Result> results =
            DpaSecondTransactionService.createSecondTransactions(new List<DpaSecondTransactionService.Request>{ requestItem });
        Transaction__c statusBeforeSecondUpdate = [
            SELECT Status__c
            FROM Transaction__c
            WHERE Id = :firstTransaction.Id
        ];

        Test.startTest();
        update new Transaction__c(
            Id = results[0].createdSecondTransactionId,
            Status__c = 'Processing'
        );
        Test.stopTest();

        Transaction__c reloadedFirst = [
            SELECT Status__c
            FROM Transaction__c
            WHERE Id = :firstTransaction.Id
        ];
        System.assertEquals(statusBeforeSecondUpdate.Status__c, reloadedFirst.Status__c);
    }

    @IsTest
    static void createSecondTransactionsHandlesGuardrails() {
        Account borrower = createBorrower('Connection Guardrails');
        Account lender = createLender('Connection Guardrails');
        Transaction__c firstTransaction = createFirstTransaction(borrower, lender);

        DpaSecondTransactionService.Request missingIdRequest = new DpaSecondTransactionService.Request();

        DpaSecondTransactionService.Request missingInfoRequest = new DpaSecondTransactionService.Request();
        missingInfoRequest.firstTransactionId = firstTransaction.Id;
        missingInfoRequest.lenderId = null;
        missingInfoRequest.loanAmount2nd = null;
        missingInfoRequest.loanType2nd = '';
        missingInfoRequest.loanProgram2nd = '';
        missingInfoRequest.rate2nd = null;

        Test.startTest();
        List<DpaSecondTransactionService.Result> missingResults =
            DpaSecondTransactionService.createSecondTransactions(new List<DpaSecondTransactionService.Request>{
                null,
                missingIdRequest
            });
        Test.stopTest();

        System.assertEquals(2, missingResults.size());
        System.assertEquals(false, missingResults[0].success);
        System.assertEquals('INVALID_INPUT', missingResults[0].errorCode);
        System.assertEquals(false, missingResults[1].success);
        System.assertEquals('INVALID_INPUT', missingResults[1].errorCode);

        Transaction__c secondLikeTransaction = new Transaction__c(
            Borrower_Name__c = borrower.Id,
            Account__c = borrower.Id,
            Status__c = 'Processing',
            Lien_Position__c = '2nd',
            Lender_lookup__c = lender.Id,
            Loan_Amount_1st__c = 150000,
            Loan_Type_1st_TD__c = 'Conventional',
            Loan_Program_1st__c = '30 yr Fixed',
            Rate_1st_TD__c = 5.125
        );
        insert secondLikeTransaction;

        DpaSecondTransactionService.Request invalidFirstRequest = new DpaSecondTransactionService.Request();
        invalidFirstRequest.firstTransactionId = secondLikeTransaction.Id;

        List<DpaSecondTransactionService.Result> invalidResults =
            DpaSecondTransactionService.createSecondTransactions(new List<DpaSecondTransactionService.Request>{
                invalidFirstRequest
            });

        System.assertEquals(false, invalidResults[0].success);
        System.assertEquals('INVALID_FIRST_TRANSACTION', invalidResults[0].errorCode);

        DpaSecondTransactionService.Request validRequest = new DpaSecondTransactionService.Request();
        validRequest.firstTransactionId = firstTransaction.Id;
        List<DpaSecondTransactionService.Result> validResults =
            DpaSecondTransactionService.createSecondTransactions(new List<DpaSecondTransactionService.Request>{
                validRequest
            });
        System.assertEquals(true, validResults[0].success);

        DpaSecondTransactionService.Request duplicateRequest = new DpaSecondTransactionService.Request();
        duplicateRequest.firstTransactionId = firstTransaction.Id;
        List<DpaSecondTransactionService.Result> duplicateResults =
            DpaSecondTransactionService.createSecondTransactions(new List<DpaSecondTransactionService.Request>{
                duplicateRequest
            });

        System.assertEquals(false, duplicateResults[0].success);
        System.assertEquals('SECOND_ALREADY_EXISTS', duplicateResults[0].errorCode);

        Transaction__c incompleteFirstTransaction = createFirstTransaction(borrower, lender);
        update new Transaction__c(
            Id = incompleteFirstTransaction.Id,
            Lender_lookup__c = null,
            Loan_Amount_1st__c = null,
            Loan_Type_1st_TD__c = null,
            Loan_Program_1st__c = null,
            Rate_1st_TD__c = null
        );

        DpaSecondTransactionService.Request incompleteRequest = new DpaSecondTransactionService.Request();
        incompleteRequest.firstTransactionId = incompleteFirstTransaction.Id;
        List<DpaSecondTransactionService.Result> incompleteResults =
            DpaSecondTransactionService.createSecondTransactions(new List<DpaSecondTransactionService.Request>{
                incompleteRequest
            });

        System.assertEquals(false, incompleteResults[0].success);
        System.assertEquals('MISSING_REQUIRED_FIELDS', incompleteResults[0].errorCode);
    }
}