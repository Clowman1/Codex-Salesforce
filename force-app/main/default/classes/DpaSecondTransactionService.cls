public with sharing class DpaSecondTransactionService {
    public static final String MODE_MANUAL = 'MANUAL';
    public static final String MODE_AUTO = 'AUTO';
    private static final String DPA_SECOND_LOAN_TYPE = 'DPA 2nd';
    private static final Set<String> VALID_SECOND_LIEN_LOAN_TYPES = new Set<String>{
        'Conventional',
        'Non-QM',
        'HELOC',
        DPA_SECOND_LOAN_TYPE
    };
    private static final String LOG_SOURCE = 'DpaSecondTransactionService';

    public class Request {
        public Id firstTransactionId;
        public String mode;
        public Id lenderId;
        public Decimal loanAmount2nd;
        public String loanType2nd;
        public String loanProgram2nd;
        public Decimal rate2nd;
    }

    public class Result {
        public Boolean success;
        public String userMessage;
        public String errorCode;
        public String adminMessage;
        public List<Id> recordIdsAffected;
        public List<String> errors;
        public Id createdSecondTransactionId;
        public String createdSecondTransactionName;

        public Result() {
            success = false;
            recordIdsAffected = new List<Id>();
            errors = new List<String>();
        }
    }

    public static List<Result> createSecondTransactions(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null) {
            return results;
        }

        Set<Id> firstIds = new Set<Id>();
        for (Request req : requests) {
            Result result = new Result();
            results.add(result);
            if (req != null && req.firstTransactionId != null) {
                firstIds.add(req.firstTransactionId);
            }
        }

        Map<Id, Transaction__c> firstById = TransactionRepository.getInstance().selectForDpaSecondByIds(firstIds);
        Map<Id, Transaction__c> secondByFirstId = TransactionRepository.getInstance().selectSecondTransactionsByFirstIds(firstIds);

        List<Transaction__c> secondsToInsert = new List<Transaction__c>();
        List<Integer> insertRequestIndexes = new List<Integer>();

        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            Result result = results[i];

            if (req == null || req.firstTransactionId == null) {
                populateBusinessError(
                    result,
                    'INVALID_INPUT',
                    'A first transaction is required to create a DPA 2nd transaction.'
                );
                continue;
            }

            Transaction__c firstTransaction = firstById.get(req.firstTransactionId);
            if (firstTransaction == null) {
                populateBusinessError(result, 'FIRST_NOT_FOUND', 'The selected first transaction was not found.');
                continue;
            }
            if (
                firstTransaction.First_Mortgage__c != null ||
                String.valueOf(firstTransaction.Lien_Position__c) == '2nd'
            ) {
                populateBusinessError(
                    result,
                    'INVALID_FIRST_TRANSACTION',
                    'The selected transaction must be a first transaction.'
                );
                continue;
            }

            Id existingSecondId = firstTransaction.Second_Mortgage__c;
            if (existingSecondId == null && secondByFirstId.containsKey(firstTransaction.Id)) {
                existingSecondId = secondByFirstId.get(firstTransaction.Id).Id;
            }
            if (existingSecondId != null) {
                populateBusinessError(
                    result,
                    'SECOND_ALREADY_EXISTS',
                    'A 2nd transaction is already linked to this first transaction.'
                );
                result.recordIdsAffected.add(firstTransaction.Id);
                result.recordIdsAffected.add(existingSecondId);
                continue;
            }

            Transaction__c secondTransaction = buildSecondTransaction(firstTransaction, req, result);
            if (secondTransaction == null) {
                continue;
            }

            secondsToInsert.add(secondTransaction);
            insertRequestIndexes.add(i);
        }

        if (secondsToInsert.isEmpty()) {
            return results;
        }

        Database.SaveResult[] insertResults = Database.insert(secondsToInsert, false);
        List<Transaction__c> firstsToUpdate = new List<Transaction__c>();
        List<Integer> updateRequestIndexes = new List<Integer>();
        Map<Integer, Id> insertedSecondByRequestIndex = new Map<Integer, Id>();

        for (Integer i = 0; i < insertResults.size(); i++) {
            Integer requestIndex = insertRequestIndexes[i];
            Result result = results[requestIndex];
            Database.SaveResult saveResult = insertResults[i];

            if (!saveResult.isSuccess()) {
                populateDmlError(result, saveResult, 'SECOND_INSERT_FAILED');
                logFailure('Insert second transaction failed', saveResult, requests[requestIndex].firstTransactionId);
                continue;
            }

            Id secondTransactionId = saveResult.getId();
            insertedSecondByRequestIndex.put(requestIndex, secondTransactionId);
            firstsToUpdate.add(new Transaction__c(
                Id = requests[requestIndex].firstTransactionId,
                Second_Mortgage__c = secondTransactionId
            ));
            updateRequestIndexes.add(requestIndex);
        }

        if (firstsToUpdate.isEmpty()) {
            return results;
        }

        Database.SaveResult[] updateResults = Database.update(firstsToUpdate, false);
        List<Transaction__c> secondsToDelete = new List<Transaction__c>();
        Map<Integer, Id> successfulSecondByRequestIndex = new Map<Integer, Id>();

        for (Integer i = 0; i < updateResults.size(); i++) {
            Integer requestIndex = updateRequestIndexes[i];
            Result result = results[requestIndex];
            Database.SaveResult updateResult = updateResults[i];
            Id secondId = insertedSecondByRequestIndex.get(requestIndex);

            if (!updateResult.isSuccess()) {
                populateDmlError(result, updateResult, 'FIRST_UPDATE_FAILED');
                logFailure('Update first transaction failed', updateResult, requests[requestIndex].firstTransactionId);
                if (secondId != null) {
                    secondsToDelete.add(new Transaction__c(Id = secondId));
                }
                continue;
            }

            result.success = true;
            result.errorCode = null;
            result.adminMessage = null;
            result.userMessage = 'DPA 2nd transaction created successfully.';
            result.createdSecondTransactionId = secondId;
            result.recordIdsAffected.add(requests[requestIndex].firstTransactionId);
            result.recordIdsAffected.add(secondId);
            successfulSecondByRequestIndex.put(requestIndex, secondId);
        }

        if (!secondsToDelete.isEmpty()) {
            Database.delete(secondsToDelete, false);
        }

        syncCreatedSecondStatuses(requests, successfulSecondByRequestIndex);
        populateCreatedSecondTransactionNames(results, successfulSecondByRequestIndex);

        return results;
    }

    private static void syncCreatedSecondStatuses(
        List<Request> requests,
        Map<Integer, Id> successfulSecondByRequestIndex
    ) {
        if (requests == null || successfulSecondByRequestIndex == null || successfulSecondByRequestIndex.isEmpty()) {
            return;
        }

        Map<Id, Id> secondIdByFirstId = new Map<Id, Id>();
        for (Integer requestIndex : successfulSecondByRequestIndex.keySet()) {
            if (requests[requestIndex] == null || requests[requestIndex].firstTransactionId == null) {
                continue;
            }

            secondIdByFirstId.put(
                requests[requestIndex].firstTransactionId,
                successfulSecondByRequestIndex.get(requestIndex)
            );
        }

        DpaSecondTransactionStatusSync.syncCurrentStatusesByFirstId(secondIdByFirstId);
    }

    private static Transaction__c buildSecondTransaction(Transaction__c firstTransaction, Request req, Result result) {
        String borrowerLastName = resolveBorrowerLastName(firstTransaction);

        Id lenderId = req != null && req.lenderId != null ? req.lenderId : firstTransaction.Lender_lookup__c;
        Decimal loanAmount2nd = req != null && req.loanAmount2nd != null ? req.loanAmount2nd : firstTransaction.Loan_Amount_1st__c;
        String loanType2nd = resolveSecondLienLoanType(req, firstTransaction);
        String loanProgram2nd = req != null && String.isNotBlank(req.loanProgram2nd) ? req.loanProgram2nd : firstTransaction.Loan_Program_1st__c;
        Decimal rate2nd = req != null && req.rate2nd != null ? req.rate2nd : firstTransaction.Rate_1st_TD__c;

        if (
            lenderId == null ||
            loanAmount2nd == null ||
            String.isBlank(loanType2nd) ||
            String.isBlank(loanProgram2nd) ||
            rate2nd == null
        ) {
            populateBusinessError(
                result,
                'MISSING_REQUIRED_FIELDS',
                'DPA transactions require Lender, Loan Amount, Loan Type, Loan Program, and Rate to be completed.'
            );
            return null;
        }

        return new Transaction__c(
            RecordTypeId = firstTransaction.RecordTypeId,
            Status__c = firstTransaction.Status__c,
            Lien_Position__c = '2nd',
            First_Mortgage__c = firstTransaction.Id,
            Borrower_Name__c = firstTransaction.Borrower_Name__c,
            Borrower_Last_Name__c = borrowerLastName,
            Account__c = firstTransaction.Account__c,
            Property_Address__c = firstTransaction.Property_Address__c,
            Property_City__c = firstTransaction.Property_City__c,
            Property_State__c = firstTransaction.Property_State__c,
            Property_Postal_Code__c = firstTransaction.Property_Postal_Code__c,
            Property_Unit__c = firstTransaction.Property_Unit__c,
            Property_Type__c = firstTransaction.Property_Type__c,
            Purchase_Date__c = firstTransaction.Purchase_Date__c,
            Appraisal__c = firstTransaction.Appraisal__c,
            Appraised_Value__c = firstTransaction.Appraised_Value__c,
            Purchase_Price__c = firstTransaction.Purchase_Price__c,
            Processor__c = firstTransaction.Processor__c,
            Closing_Date__c = firstTransaction.Closing_Date__c,
            Funding_Date__c = firstTransaction.Funding_Date__c,
            Disclosures_Out_Date__c = firstTransaction.Disclosures_Out_Date__c,
            Disclosures_Received_Date__c = firstTransaction.Disclosures_Received_Date__c,
            Rate_Lock_Status__c = firstTransaction.Rate_Lock_Status__c,
            Rate_Lock_Exp_Date__c = firstTransaction.Rate_Lock_Exp_Date__c,
            Occupancy__c = firstTransaction.Occupancy__c,
            Submission_Form_Date__c = firstTransaction.Submission_Form_Date__c,
            Name = formatTransactionName(borrowerLastName, null, null),
            Lender_lookup__c = lenderId,
            Loan_Amount_1st__c = loanAmount2nd,
            Loan_Type_1st_TD__c = loanType2nd,
            Loan_Program_1st__c = loanProgram2nd,
            Rate_1st_TD__c = rate2nd,
            Loan_Amount_2nd__c = loanAmount2nd,
            Loan_Type_2nd_TD__c = loanType2nd,
            Loan_Program_2nd__c = loanProgram2nd,
            Rate_2nd_TD__c = rate2nd
        );
    }

    private static String resolveSecondLienLoanType(Request req, Transaction__c firstTransaction) {
        String requestedLoanType = req != null && String.isNotBlank(req.loanType2nd)
            ? req.loanType2nd
            : firstTransaction.Loan_Type_1st_TD__c;

        if (VALID_SECOND_LIEN_LOAN_TYPES.contains(requestedLoanType)) {
            return requestedLoanType;
        }

        return DPA_SECOND_LOAN_TYPE;
    }

    private static void populateBusinessError(Result result, String errorCode, String userMessage) {
        result.success = false;
        result.errorCode = errorCode;
        result.userMessage = userMessage;
        result.adminMessage = userMessage;
        result.errors.add(userMessage);
    }

    private static void populateDmlError(Result result, Database.SaveResult saveResult, String errorCode) {
        result.success = false;
        result.errorCode = errorCode;
        result.userMessage = 'We were unable to create the DPA 2nd transaction.';
        result.adminMessage = flattenErrors(saveResult);
        result.errors.add(result.adminMessage);
    }

    private static void populateCreatedSecondTransactionNames(
        List<Result> results,
        Map<Integer, Id> secondTransactionIdsByRequestIndex
    ) {
        if (results == null || secondTransactionIdsByRequestIndex == null || secondTransactionIdsByRequestIndex.isEmpty()) {
            return;
        }

        Map<Id, Transaction__c> secondTransactionsById = TransactionRepository.getInstance()
            .selectSecondTransactionNamesByIds(new Set<Id>(secondTransactionIdsByRequestIndex.values()));

        for (Integer requestIndex : secondTransactionIdsByRequestIndex.keySet()) {
            Result result = results[requestIndex];
            Transaction__c secondTransaction = secondTransactionsById.get(secondTransactionIdsByRequestIndex.get(requestIndex));
            result.createdSecondTransactionName = formatSecondTransactionName(secondTransaction);
        }
    }

    private static String formatSecondTransactionName(Transaction__c secondTransaction) {
        if (secondTransaction == null) {
            return null;
        }

        return formatTransactionName(
            resolveBorrowerLastName(secondTransaction),
            secondTransaction.Loan_Number__c,
            secondTransaction.Loan_2nd_TD__c
        );
    }

    private static String resolveBorrowerLastName(Transaction__c transactionRecord) {
        if (transactionRecord == null) {
            return null;
        }

        if (String.isNotBlank(transactionRecord.Borrower_Last_Name__c)) {
            return transactionRecord.Borrower_Last_Name__c;
        }

        return transactionRecord.Borrower_Name__r != null
            ? transactionRecord.Borrower_Name__r.LastName
            : null;
    }

    private static String formatTransactionName(
        String borrowerLastName,
        String primaryLoanNumber,
        String secondaryLoanNumber
    ) {
        String resolvedLoanNumber = String.isNotBlank(primaryLoanNumber)
            ? primaryLoanNumber
            : secondaryLoanNumber;

        if (String.isBlank(borrowerLastName) && String.isBlank(resolvedLoanNumber)) {
            return null;
        }

        return (String.isBlank(borrowerLastName) ? '' : borrowerLastName) +
            ' - ' +
            (String.isBlank(resolvedLoanNumber) ? '' : resolvedLoanNumber);
    }

    private static String flattenErrors(Database.SaveResult saveResult) {
        List<String> messages = new List<String>();
        for (Database.Error error : saveResult.getErrors()) {
            messages.add(error.getMessage());
        }
        return String.join(messages, ' | ');
    }

    private static void logFailure(String operation, Database.SaveResult saveResult, Id firstTransactionId) {
        List<String> messages = new List<String>();
        for (Database.Error error : saveResult.getErrors()) {
            messages.add(error.getMessage());
        }
        upsertLog(operation + ' :: ' + String.join(messages, ' | '), firstTransactionId);
    }

    private static void upsertLog(String message, Id firstTransactionId) {
        try {
            Custom_Log__c logRecord = new Custom_Log__c();
            logRecord.Source__c = LOG_SOURCE;
            logRecord.Data__c = message + ' (firstTransactionId=' + String.valueOf(firstTransactionId) + ')';
            insert logRecord;
        } catch (Exception ignored) {
            System.debug('DpaSecondTransactionService logging failed: ' + ignored.getMessage());
        }
    }
}