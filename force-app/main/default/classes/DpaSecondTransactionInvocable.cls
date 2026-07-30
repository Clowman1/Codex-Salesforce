public with sharing class DpaSecondTransactionInvocable {
    public class Request {
        @InvocableVariable(Required=true)
        public String parentTransactionId;

        @InvocableVariable
        public String mode;

        @InvocableVariable
        public Id lenderId;

        @InvocableVariable
        public Decimal loanAmount2nd;

        @InvocableVariable
        public String loanType2nd;

        @InvocableVariable
        public String loanProgram2nd;

        @InvocableVariable
        public Decimal rate2nd;
    }

    public class Result {
        @InvocableVariable(Label='Success' Description='Whether the operation succeeded')
        @AuraEnabled
        public Boolean success;

        @InvocableVariable(Label='User Message' Description='User-friendly message')
        @AuraEnabled
        public String userMessage;

        @InvocableVariable(Label='Error Code' Description='Machine-readable error code')
        @AuraEnabled
        public String errorCode;

        @InvocableVariable(Label='Admin Message' Description='Technical error details')
        @AuraEnabled
        public String adminMessage;

        @InvocableVariable(Label='Record IDs Affected' Description='IDs of affected records')
        @AuraEnabled
        public List<Id> recordIdsAffected;

        @InvocableVariable(Label='Errors' Description='List of error messages')
        @AuraEnabled
        public List<String> errors;

        @InvocableVariable(Label='Second Transaction ID' Description='ID of the created 2nd transaction')
        @AuraEnabled
        public Id secondTransactionId;

        @InvocableVariable(Label='Second Transaction Name' Description='Formatted name of the created 2nd transaction')
        @AuraEnabled
        public String secondTransactionName;

        public Result() {
            recordIdsAffected = new List<Id>();
            errors = new List<String>();
        }
    }

    @InvocableMethod(
        Label='DPA: Create 2nd Transaction'
        Description='Creates and links the DPA 2nd transaction to a first transaction.'
    )
    public static List<Result> createSecondTransactions(List<Request> requests) {
        List<DpaSecondTransactionService.Request> serviceRequests = new List<DpaSecondTransactionService.Request>();
        for (Request requestItem : requests) {
            DpaSecondTransactionService.Request serviceRequest = new DpaSecondTransactionService.Request();
            serviceRequest.firstTransactionId = parseId(requestItem.parentTransactionId);
            serviceRequest.mode = String.isBlank(requestItem.mode) ? DpaSecondTransactionService.MODE_AUTO : requestItem.mode;
            serviceRequest.lenderId = requestItem.lenderId;
            serviceRequest.loanAmount2nd = requestItem.loanAmount2nd;
            serviceRequest.loanType2nd = requestItem.loanType2nd;
            serviceRequest.loanProgram2nd = requestItem.loanProgram2nd;
            serviceRequest.rate2nd = requestItem.rate2nd;
            serviceRequests.add(serviceRequest);
        }

        List<DpaSecondTransactionService.Result> serviceResults =
            DpaSecondTransactionService.createSecondTransactions(serviceRequests);

        List<Result> invocableResults = new List<Result>();
        for (DpaSecondTransactionService.Result serviceResult : serviceResults) {
            Result invocableResult = new Result();
            invocableResult.success = serviceResult.success;
            invocableResult.userMessage = serviceResult.userMessage;
            invocableResult.errorCode = serviceResult.errorCode;
            invocableResult.adminMessage = serviceResult.adminMessage;
            invocableResult.recordIdsAffected = serviceResult.recordIdsAffected;
            invocableResult.errors = serviceResult.errors;
            invocableResult.secondTransactionId = serviceResult.createdSecondTransactionId;
            invocableResult.secondTransactionName = serviceResult.createdSecondTransactionName;
            invocableResults.add(invocableResult);
        }
        return invocableResults;
    }

    private static Id parseId(String rawId) {
        if (String.isBlank(rawId)) {
            return null;
        }

        try {
            return Id.valueOf(rawId.trim());
        } catch (Exception ex) {
            return null;
        }
    }
}