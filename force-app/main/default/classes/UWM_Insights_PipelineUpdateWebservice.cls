@RestResource(UrlMapping='/insights/pipeline/ping/v1')
global without sharing class UWM_Insights_PipelineUpdateWebservice {
	@HttpPost
    global static void doPing() {
        RestResponse res = RestContext.response;
        if(res == null){
            res = new RestResponse();
        }
        List<String> output = new List<String>();
        try{
            List<UWM_Loan_Info__c> loanInfos = UWMLoanInfoRepository.getInstance().getActiveLoanPipeline();
            System.debug('loanInfos try block: '+loanInfos);
            if (!loanInfos.isEmpty()) {
                Database.executeBatch(new UWMInsightsPipelineBatch(loanInfos), 50);
            }
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Loan was updated with payload: '+output); 
        }catch(Exception e){
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('There was an error: ' + e.getMessage() + e.getStackTraceString());
            throw(e);
        }
    }
    public static void getLoans(UWM_Loan_Info__c l,PersistenceStrategy strategy){
        Map<String,Object> loan = UWM_Insights_Gateway.getLoanById(l.uwm_LoanNumber__c);
        LoanMapper.UWM_Insights_Loan mappedLoan = new LoanMapper.UWM_Insights_Loan(loan, l); 
        if(mappedLoan.modifiedLoan != null){
            strategy.persist(mappedLoan.modifiedLoan);
        }

    }
    public static void sendBatchErrorEmail(String errorMessage) {
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setPlainTextBody(errorMessage);
        message.toAddresses = new String[] { 'clowman@reachhomeloans.com','adamstephens250@gmail.com', 'development@nimbuscloudsolutions.com' };
        message.subject = 'A UWM Loan failed to update from UWM Insights batch';
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ message });
    }
}
