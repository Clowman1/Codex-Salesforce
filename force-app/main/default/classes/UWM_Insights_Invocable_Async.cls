public with sharing class UWM_Insights_Invocable_Async {
	@InvocableMethod(Label='UWM Insights API Do Ping Invocable')
    public static void doPingInvocable(List<Id> ids){
        for (String loanId : ids) {
			fetchDataUWM(loanId);
        }
    }
     
    
    @future(callout=true)
    public static void fetchDataUWM(String loanId) {
        PersistenceStrategy.BulkifiedSave strategy = new PersistenceStrategy.BulkifiedSave();
        List<UWM_Loan_Info__c> loans = UWMLoanInfoRepository.getInstance().getUWMLoansByLoanId(loanId);
        if (loans.size() != null) {
            for (UWM_Loan_Info__c loan : loans) {
                UWM_Insights_PipelineUpdateWebservice.getLoans(loan, strategy);
            }
        }  
        strategy.flush();
    }

}