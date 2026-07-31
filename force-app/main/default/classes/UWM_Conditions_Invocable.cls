/**
 * Created by toma on 12/12/2022.
 */

public with sharing class UWM_Conditions_Invocable {
    private static final String LOG_SOURCE = 'UWM Conditions Invocable';

    @InvocableMethod(Label='UWM Conditions API Do Ping Invocable')
    public static void pingApiInvocable(List<Id> ids){
        Set<Id> loanInfoIdsSet = new Set<Id>(ids);
        Map<Id,UWM_Loan_Info__c> loanInfoIdToRecordMap = UWMLoanInfoRepository.getInstance().getUWMLoanInfosByIds(loanInfoIdsSet);

        if(loanInfoIdToRecordMap.isEmpty()){
            return;
        }

        try {
            List<Condition__c> allLoanConditions = new List<Condition__c>();
            List<Condition__c> conditionsToDeleteAll = new List<Condition__c>();
            List<Custom_Log__c> logsToInsert = new List<Custom_Log__c>();
            TransactionConditionTriggerHandler.isUWMSyncEnabled = true;

            Set<Id> oppIds = new Set<Id>();
            for (UWM_Loan_Info__c loanInfo: loanInfoIdToRecordMap.values()) {
                oppIds.add(loanInfo.Transaction__c );
            }
            Map<Id,Loan> oppIdToLoanMap = LoanRepository.getInstance().getLoanMapByIds(oppIds);

            for(UWM_Loan_Info__c loanInfo: loanInfoIdToRecordMap.values()){
                try{
                    String applicationId = String.valueOf(loanInfo.Transaction__c);
                    String loanNumber = loanInfo.uwm_LoanNumber__c ;

                    List<Condition__c> loanConditions = TransactionConditionRepository.getLoanConditions(
                        new Map<String,Object>{
                            'currentLoanId' => applicationId,
                            'currentLoanNumber' => loanNumber
                        },
                        oppIdToLoanMap
                    );

                    if (!loanConditions.isEmpty()) {
                        allLoanConditions.addAll(loanConditions);
                    }

                    List<Condition__c> conditionsToDelete = TransactionConditionRepository.findConditionsNotInRequest(applicationId, loanConditions);
                    if (!conditionsToDelete.isEmpty()) {
                        conditionsToDeleteAll.addAll(conditionsToDelete);
                    }
                }catch(Exception e){
                    addErrorLog(logsToInsert, e, loanInfo.Id, loanInfo.Transaction__c);
                }
            }

            flushLogs(logsToInsert);
            TransactionConditionRepository.upsertLoanConditions(allLoanConditions);
            if (!conditionsToDeleteAll.isEmpty()) {
                Database.delete(conditionsToDeleteAll, false, System.AccessLevel.USER_MODE);
            }
        } finally {
            TransactionConditionTriggerHandler.isUWMSyncEnabled = false;
        }
    }

    @TestVisible
    private static void addErrorLog(List<Custom_Log__c> logsToInsert, Exception e, Id recordId, Id transactionId) {
        if (logsToInsert == null || e == null) {
            return;
        }
        Custom_Log__c logRecord = new Custom_Log__c(
            Source__c = LOG_SOURCE,
            Data__c = buildErrorMessage(e, recordId),
            Errors__c = extractErrors(e)
        );
        if (transactionId != null) {
            logRecord.Transaction__c = transactionId;
        }
        logsToInsert.add(logRecord);
    }

    @TestVisible
    private static String buildErrorMessage(Exception e, Id recordId) {
        String message = 'There was a problem while processing UWM loan info';
        if (recordId != null) {
            message += ' (recordId=' + String.valueOf(recordId) + ')';
        }
        message += ': ' + e.getMessage();
        if (String.isNotBlank(e.getStackTraceString())) {
            message += ' Stack: ' + e.getStackTraceString();
        }
        return message;
    }

    @TestVisible
    private static String extractErrors(Exception e) {
        if (!(e instanceof RestApiConsumer.HttpException)) {
            return null;
        }
        RestApiConsumer.HttpException httpException = (RestApiConsumer.HttpException) e;
        HttpResponse response = httpException.getResponse();
        if (response == null || String.isBlank(response.getBody())) {
            return null;
        }
        try {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            if (!responseBody.containsKey('errors') || responseBody.get('errors') == null) {
                return null;
            }
            return JSON.serialize(responseBody.get('errors'));
        } catch (Exception parseException) {
            return null;
        }
    }

    @TestVisible
    private static void flushLogs(List<Custom_Log__c> logsToInsert) {
        if (logsToInsert == null || logsToInsert.isEmpty()) {
            return;
        }
        try {
            Database.insert(logsToInsert, false);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Failed to insert Custom_Log__c: ' + e.getMessage());
        }
    }
}