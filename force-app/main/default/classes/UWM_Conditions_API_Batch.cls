/**
 * Created by toma on 12/28/2022.
 */

public with sharing class UWM_Conditions_API_Batch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful{
    private static final String LOG_SOURCE = 'UWM Conditions Batch';
    private final List<String> failedRecords = new List<String>();
    private final List<Custom_Log__c> pendingLogs = new List<Custom_Log__c>();
    private Id batchJobId;
    
    public Database.QueryLocator start(Database.BatchableContext bc){
        this.batchJobId = bc.getJobId();
        return Database.getQueryLocator('SELECT Id, OwnerId, Loan_Number__c FROM Transaction__c WHERE Loan_Number__c != NULL AND Lender_lookup__r.Name = \'UWM\' AND Closed__c = FALSE AND Do_Not_Include_In_UWM_Sync__c = FALSE'); //
    }
 
    public void execute(Database.BatchableContext info, List<sobject> scope) {
        UWMSettings__c uwmSettings = UWMSettings__c.getOrgDefaults();
        if(uwmSettings.CanConditionsQueueRun__c == false){
            System.debug('UWM Conditions: Exiting due to CanConditionsQueueRun__c = false');
            return;
        }

        try {
            List<Condition__c> needsToUpsert = new List<Condition__c>();
            List<Condition__c> conditionsToDeleteAll = new List<Condition__c>();
            TransactionConditionTriggerHandler.isUWMSyncEnabled = true;

            Set<Id> oppIds = new Set<Id>();
            for (sobject l : scope) {
                Transaction__c t = (Transaction__c) l;
                oppIds.add(t.id);
            }
            Map<Id,Loan> oppIdToLoanMap = LoanRepository.getInstance().getLoanMapByIds(oppIds);
            
            for (sObject loanRecord : scope) {
                Transaction__c loan = (Transaction__c)loanRecord;
                if (!oppIdToLoanMap.containsKey(loan.Id)) {
                    continue;
                }

                processLoan(oppIdToLoanMap.get(loan.Id), oppIdToLoanMap, needsToUpsert, conditionsToDeleteAll);
            }
            
            System.debug('Loan Conditions to update ' + needsToUpsert.size());
            System.debug('Size of failed records list' + failedRecords.size());   
            for (String errMsg : failedRecords) {
                System.debug(errMsg);
            }

            if(!needsToUpsert.isEmpty()){
                Database.upsert(needsToUpsert,
                                Schema.getGlobalDescribe().get('Condition__c').getDescribe().fields.getMap().get('UWM_Condition_Id__c'),
                                false,
                                System.AccessLevel.SYSTEM_MODE);
            }

            if(!conditionsToDeleteAll.isEmpty()){
                Database.delete(conditionsToDeleteAll, false, System.AccessLevel.SYSTEM_MODE);
            }
        } finally {
            TransactionConditionTriggerHandler.isUWMSyncEnabled = false;
        }
    }

    private void processLoan(
        Loan loan,
        Map<Id, Loan> oppIdToLoanMap,
        List<Condition__c> needsToUpsert,
        List<Condition__c> conditionsToDeleteAll
    ){
        try{
            List<Condition__c> newNeeds = TransactionConditionRepository.getLoanConditions(
                new Map<String,Object>{
                    'currentLoanId' => loan.getId(),
                    'currentLoanNumber' => loan.getLoanNumber()
                },
                oppIdToLoanMap
            );

            if(!newNeeds.isEmpty()){
                System.debug('NEW NEEDS SIZE: ' + newNeeds.size());
                needsToUpsert.addAll(newNeeds);
            }

            List<Condition__c> conditionsToDelete = TransactionConditionRepository.findConditionsNotInRequest(String.valueOf(loan.getId()), newNeeds);
            if (!conditionsToDelete.isEmpty()) {
                conditionsToDeleteAll.addAll(conditionsToDelete);
            }
        }catch(Exception e){
            failedRecords.add('Opportunity Id: '+loan.getId()+' Error Message: '+e.getMessage() + ' Stack: ' + e.getStackTraceString());
            addErrorLog(e, loan.getId());
        }
    }

    @TestVisible
    private void addErrorLog(Exception e, Id recordId) {
        if (e == null) {
            return;
        }
        pendingLogs.add(new Custom_Log__c(
            Source__c = LOG_SOURCE,
            Data__c = buildErrorMessage(e, recordId),
            Transaction__c = recordId,
            Errors__c = extractErrors(e)
        ));
    }

    @TestVisible
    private String buildErrorMessage(Exception e, Id recordId) {
        String message = 'There was a problem while processing UWM conditions batch';
        if (recordId != null) {
            message += ' (recordId=' + String.valueOf(recordId) + ')';
        }
        if (this.batchJobId != null) {
            message += ' (jobId=' + String.valueOf(this.batchJobId) + ')';
        }
        message += ': ' + e.getMessage();
        if (String.isNotBlank(e.getStackTraceString())) {
            message += ' Stack: ' + e.getStackTraceString();
        }
        return message;
    }

    @TestVisible
    private String extractErrors(Exception e) {
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
    private void flushLogs() {
        if (pendingLogs.isEmpty()) {
            return;
        }
        try {
            Database.insert(pendingLogs, false);
            pendingLogs.clear();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Failed to insert Custom_Log__c: ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext info) {
        flushLogs();
        if (String.isBlank(UWMSettings__c.getOrgDefaults().Emails_For_Notifications__c)) {
            return;
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.toAddresses = new List<String>{UWMSettings__c.getOrgDefaults().Emails_For_Notifications__c};
        String htmlBody = '<div> ';
        htmlBody += '<table style="width:100%;"><tr> <th>Batch Job On Opportunity Loan Conditions For Get UWM Conditions, failed</th>';
        if(failedRecords.isEmpty() && !Test.isRunningTest()){
            return;
        }
        for (String errorMessage : failedRecords){
            htmlBody += '<td> ' + errorMessage + '</td>';
        }
        htmlBody += '</tr> </table> </div>';
        mail.setHtmlBody(htmlBody);
        mail.subject = 'An error occurred while getting opportunity loan conditions from UWM';
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        mails.add(mail);
        if(!Test.isRunningTest()){
            Messaging.sendEmail(mails, false);
        }
    }

    public static void executeBatch() {
        UWM_Conditions_API_Batch batch = new UWM_Conditions_API_Batch();
  
        if (UWMSettings__c.getOrgDefaults().Conditions_Batch_Size__c == null) 
        {	
            Database.executeBatch(batch, 5);
        } else {
            Integer batchSize = UWMSettings__c.getOrgDefaults().Conditions_Batch_Size__c.intValue();
            Database.executeBatch(batch, batchSize);
        }
    }

}