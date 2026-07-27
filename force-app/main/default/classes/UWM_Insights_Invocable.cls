public with sharing class UWM_Insights_Invocable {
	@InvocableMethod(Label='UWM Insights API Do Ping Invocable')
    public static void doPingInvocable(List<Id> ids){
        PersistenceStrategy.BulkifiedSave strategy = new PersistenceStrategy.BulkifiedSave();
        for (String loanId:ids){
            System.debug('loanId '+loanId);
            List<UWM_Loan_Info__c> loans = UWMLoanInfoRepository.getInstance().getUWMLoansByLoanId(loanId);
            System.debug('uwm loans'+loans); 
            if(loans.size() != null){
                for(UWM_Loan_Info__c loan: loans){
                    System.debug('loan'+loan);
                    UWM_Insights_PipelineUpdateWebservice.getLoans(loan,strategy);
                }
            }
        }
        strategy.flush();
    }
}