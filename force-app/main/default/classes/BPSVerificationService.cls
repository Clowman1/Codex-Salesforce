public with sharing class BPSVerificationService {
    public class VerificationContext {
        @AuraEnabled
        public Boolean shouldShowModal;
        @AuraEnabled
        public String bpsValue;
        @AuraEnabled
        public String loanNumber;
        @AuraEnabled
        public String borrowerName;
    }

    public static VerificationContext buildVerificationContext(Id transactionId) {
        if (transactionId == null) {
            throw new AuraHandledException('Transaction Id is required.');
        }

        Transaction__c transactionRecord = TransactionRepository.getInstance().getTransactionById(String.valueOf(transactionId));
        VerificationContext context = new VerificationContext();
        context.loanNumber = transactionRecord.Loan_Number__c;
        context.borrowerName = transactionRecord.Borrower_Name__r != null
            ? transactionRecord.Borrower_Name__r.Name
            : '';

        if (transactionRecord.BPS__c == null) {
            context.shouldShowModal = false;
            context.bpsValue = '';
            return context;
        }

        context.shouldShowModal = true;
        context.bpsValue = String.valueOf(transactionRecord.BPS__c.setScale(2));
        return context;
    }

    public static void saveVerification(Id transactionId, Boolean isVerified) {
        if (transactionId == null) {
            throw new AuraHandledException('Transaction Id is required.');
        }

        Boolean verified = isVerified == true;
        Transaction__c transactionUpdate = new Transaction__c(Id = transactionId);
        transactionUpdate.BPS_Verification_Completed__c = verified;

        if (verified) {
            transactionUpdate.BPS_Verification_Completed_Date_Time__c = System.now();
            transactionUpdate.BPS_Verified_By__c = UserInfo.getUserId();
        } else {
            transactionUpdate.BPS_Verification_Completed_Date_Time__c = null;
            transactionUpdate.BPS_Verified_By__c = null;
        }

        update transactionUpdate;
    }
}