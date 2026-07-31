public class UWMInsightsPipelineBatch implements Database.Batchable<UWM_Loan_Info__c>, Database.AllowsCallouts {
    private List<UWM_Loan_Info__c> loanInfos;

    public UWMInsightsPipelineBatch(List<UWM_Loan_Info__c> loanInfos) {
        this.loanInfos = loanInfos == null ? new List<UWM_Loan_Info__c>() : loanInfos;
    }

    public Iterable<UWM_Loan_Info__c> start(Database.BatchableContext context) {
        return loanInfos;
    }

    public void execute(Database.BatchableContext context, List<UWM_Loan_Info__c> scope) {
        PersistenceStrategy.BulkifiedSave strategy = new PersistenceStrategy.BulkifiedSave();
        List<String> errors = new List<String>();

        for (UWM_Loan_Info__c loanInfo : scope) {
            try {
                UWM_Loan_Info__c fullLoanInfo = UWMLoanInfoRepository.getInstance().getUWMLoanByLoanId(loanInfo.Id);
                if (fullLoanInfo != null) {
                    UWM_Insights_PipelineUpdateWebservice.getLoans(fullLoanInfo, strategy);
                }
            } catch (Exception e) {
                errors.add('UWM Loan Info ' + loanInfo.Id + ': ' + e.getMessage() + ' ' + e.getStackTraceString());
            }
        }

        List<Database.SaveResult> saveResults = strategy.flush();
        for (Integer i = 0; i < saveResults.size(); i++) {
            if (!saveResults[i].isSuccess()) {
                errors.add('Save result ' + i + ': ' + saveResults[i].getErrors());
            }
        }

        if (!errors.isEmpty() && !Test.isRunningTest()) {
            UWM_Insights_PipelineUpdateWebservice.sendBatchErrorEmail(String.join(errors, '\n'));
        }
    }

    public void finish(Database.BatchableContext context) {}
}