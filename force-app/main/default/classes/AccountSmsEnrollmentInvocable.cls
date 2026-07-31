public with sharing class AccountSmsEnrollmentInvocable {

    public class Input {
        @InvocableVariable(required=true)
        public Id transactionId;
    }

    @InvocableMethod(label='Account SMS Drip Enrollment')
    public static void enroll(List<Input> inputs) {
        Set<Id> transactionIds = new Set<Id>();
        for (Input input : inputs) {
            if (input != null && input.transactionId != null) {
                transactionIds.add(input.transactionId);
            }
        }
        AccountSmsEnrollmentService.enrollByTransactionIds(transactionIds);
    }
}